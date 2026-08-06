-- Money ops: audit log, discount, refund, cancel with reason.
-- Callers: mobile checkout/receipt; tests/140_money_ops.sql.
-- User: Implement the plan as specified.

create table public.audit_log (
  id           uuid primary key default gen_random_uuid(),
  stall_id     uuid not null references public.stall (id) on delete cascade,
  actor_id     uuid not null references auth.users (id),
  action       text not null check (length(trim(action)) > 0),
  entity_type  text not null check (length(trim(entity_type)) > 0),
  entity_id    uuid not null,
  reason       text,
  payload      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index audit_log_stall_id_idx on public.audit_log (stall_id, created_at desc);

alter table public.audit_log enable row level security;

-- Owner/manager of the stall can read; inserts only via SECURITY DEFINER RPCs.
create policy audit_log_own_stall_read
  on public.audit_log for select
  to authenticated
  using (
    exists (
      select 1 from public.staff_membership m
      where m.stall_id = audit_log.stall_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );

grant select on public.audit_log to authenticated;

create or replace function public.write_audit(
  p_stall_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_reason text,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  insert into public.audit_log (
    stall_id, actor_id, action, entity_type, entity_id, reason, payload
  ) values (
    p_stall_id, v_uid, p_action, p_entity_type, p_entity_id, p_reason,
    coalesce(p_payload, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.set_bill_discount(
  p_bill_id uuid,
  p_discount numeric,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
begin
  if p_discount is null or p_discount < 0 then
    raise exception 'discount must be >= 0' using errcode = '22023';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'discount reason required' using errcode = '22023';
  end if;

  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;

  if v_bill.status <> 'open' then
    raise exception 'can only discount an open bill' using errcode = '22023';
  end if;

  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member of collecting stall' using errcode = '42501';
  end if;

  if p_discount > v_bill.total then
    raise exception 'discount exceeds bill total' using errcode = '22023';
  end if;

  update public.bill
  set discount = p_discount::numeric(12,2), updated_at = now()
  where id = p_bill_id;

  perform public.write_audit(
    v_bill.collected_by_stall_id,
    'bill.discount',
    'bill',
    p_bill_id,
    p_reason,
    jsonb_build_object('discount', p_discount, 'total', v_bill.total)
  );

  return p_bill_id;
end;
$$;

create or replace function public.refund_bill(p_bill_id uuid, p_reason text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
begin
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'refund reason required' using errcode = '22023';
  end if;

  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;

  if v_bill.status = 'refunded' then
    return p_bill_id;
  end if;

  if v_bill.status <> 'paid' then
    raise exception 'only paid bills can be refunded' using errcode = '22023';
  end if;

  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member of collecting stall' using errcode = '42501';
  end if;

  update public.bill
  set status = 'refunded', updated_at = now()
  where id = p_bill_id;

  perform public.write_audit(
    v_bill.collected_by_stall_id,
    'bill.refund',
    'bill',
    p_bill_id,
    p_reason,
    jsonb_build_object('total', v_bill.total, 'discount', v_bill.discount)
  );

  return p_bill_id;
end;
$$;

-- Replace set_order_status with optional reason (required when cancelling).
drop function if exists public.set_order_status(uuid, text);

create or replace function public.set_order_status(
  p_order_id uuid,
  p_status text,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_from  text;
  v_to    text := p_status;
begin
  if v_to not in ('pending', 'ready', 'completed', 'cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;

  if not public.is_stall_member(v_order.stall_id) then
    raise exception 'not a member of owning stall' using errcode = '42501';
  end if;

  v_from := v_order.status;

  if v_from = v_to then
    return p_order_id;
  end if;

  if not (
    (v_from = 'pending' and v_to in ('ready', 'cancelled'))
    or (v_from = 'ready' and v_to in ('completed', 'cancelled'))
    or (v_from = 'held' and v_to = 'cancelled')
  ) then
    raise exception 'illegal status transition: % -> %', v_from, v_to
      using errcode = '22023';
  end if;

  if v_to = 'cancelled' and (p_reason is null or length(trim(p_reason)) = 0) then
    raise exception 'cancel reason required' using errcode = '22023';
  end if;

  update public.orders
  set status = v_to, updated_at = now()
  where id = p_order_id;

  if v_to = 'cancelled' then
    perform public.write_audit(
      v_order.stall_id,
      'order.cancel',
      'order',
      p_order_id,
      p_reason,
      jsonb_build_object('from', v_from)
    );
  end if;

  return p_order_id;
end;
$$;

grant execute on function public.write_audit(uuid, text, text, uuid, text, jsonb) to authenticated;
grant execute on function public.set_bill_discount(uuid, numeric, text) to authenticated;
grant execute on function public.refund_bill(uuid, text) to authenticated;
grant execute on function public.set_order_status(uuid, text, text) to authenticated;
