-- M2: bill token, order type, packaging, quick code, pickup, search/recents, variants.
-- Callers: mobile POS/pickup/stall; tests/200_pickup_pos.sql.

alter table public.bill
  add column if not exists token_no integer,
  add column if not exists order_type text not null default 'dine_in'
    check (order_type in ('dine_in', 'takeaway', 'parcel')),
  add column if not exists pickup_status text not null default 'preparing'
    check (pickup_status in ('preparing', 'ready', 'handed_over'));

alter table public.orders
  add column if not exists order_type text not null default 'dine_in'
    check (order_type in ('dine_in', 'takeaway', 'parcel')),
  add column if not exists acknowledged_at timestamptz;

alter table public.stall
  add column if not exists packaging_charge numeric(12,2) not null default 0
    check (packaging_charge >= 0),
  add column if not exists packaging_charge_mode text not null default 'none'
    check (packaging_charge_mode in ('none', 'per_order', 'per_item'));

alter table public.menu_item
  add column if not exists quick_code text,
  add column if not exists parent_id uuid references public.menu_item (id) on delete set null;

create unique index if not exists menu_item_stall_quick_code_uidx
  on public.menu_item (stall_id, quick_code)
  where quick_code is not null;

create index if not exists menu_item_parent_id_idx on public.menu_item (parent_id);
create index if not exists bill_pickup_status_idx
  on public.bill (collected_by_stall_id, pickup_status)
  where status in ('open', 'paid');

-- open_bill: mint bill.token_no; optional shift/acting/order_type via extended signature
drop function if exists public.open_bill(uuid, uuid[], uuid, text);

create or replace function public.open_bill(
  p_collected_by_stall_id uuid,
  p_order_ids uuid[],
  p_idempotency_key uuid,
  p_table_label text default null,
  p_order_type text default 'dine_in',
  p_shift_id uuid default null,
  p_acting_staff_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_bill_id  uuid;
  v_order_id uuid;
  v_order    public.orders%rowtype;
  v_total    numeric(12,2) := 0;
  v_token    integer;
  v_type     text := coalesce(nullif(p_order_type, ''), 'dine_in');
  v_actor    uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if v_type not in ('dine_in', 'takeaway', 'parcel') then
    raise exception 'invalid order_type' using errcode = '22023';
  end if;
  if not public.is_stall_member(p_collected_by_stall_id) then
    raise exception 'not a member of collecting stall' using errcode = '42501';
  end if;
  if p_order_ids is null or cardinality(p_order_ids) = 0 then
    raise exception 'open_bill requires at least one order' using errcode = '22023';
  end if;

  select id into v_bill_id from public.bill where idempotency_key = p_idempotency_key;
  if v_bill_id is not null then
    return v_bill_id;
  end if;

  foreach v_order_id in array p_order_ids
  loop
    select * into v_order from public.orders where id = v_order_id for update;
    if not found then
      raise exception 'order not found' using errcode = 'P0002';
    end if;
    if v_order.bill_id is not null then
      raise exception 'order already on a bill' using errcode = '22023';
    end if;
    if v_order.status in ('cancelled', 'held') then
      raise exception 'cannot bill % order', v_order.status using errcode = '22023';
    end if;
    if v_order.stall_id <> p_collected_by_stall_id
       and not public.stalls_same_group(v_order.stall_id, p_collected_by_stall_id) then
      raise exception 'order stall not in collector group' using errcode = '22023';
    end if;
    v_total := v_total + public.order_line_total(v_order_id);
  end loop;

  v_token := public.next_token(p_collected_by_stall_id);
  v_actor := coalesce(p_acting_staff_id, v_uid);

  insert into public.bill (
    collected_by_stall_id, collected_by_user_id, status,
    discount, total, table_label, idempotency_key,
    token_no, order_type, pickup_status, shift_id, acting_staff_id
  ) values (
    p_collected_by_stall_id, v_uid, 'open',
    0, v_total, p_table_label, p_idempotency_key,
    v_token, v_type, 'preparing', p_shift_id, v_actor
  )
  returning id into v_bill_id;

  update public.orders
  set bill_id = v_bill_id, order_type = v_type, updated_at = now()
  where id = any (p_order_ids);

  return v_bill_id;
end;
$$;

grant execute on function public.open_bill(uuid, uuid[], uuid, text, text, uuid, uuid) to authenticated;

create or replace function public.refresh_bill_pickup_status(p_bill_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
  v_pending int;
  v_status text;
begin
  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if v_bill.pickup_status = 'handed_over' then
    return 'handed_over';
  end if;

  select count(*) into v_pending
  from public.orders o
  where o.bill_id = p_bill_id
    and o.status not in ('cancelled', 'ready', 'completed');

  v_status := case when v_pending = 0 then 'ready' else 'preparing' end;

  update public.bill
  set pickup_status = v_status, updated_at = now()
  where id = p_bill_id and pickup_status <> 'handed_over';

  return v_status;
end;
$$;

create or replace function public.acknowledge_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;
  if not public.is_stall_member(v_order.stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  update public.orders
  set acknowledged_at = coalesce(acknowledged_at, now()), updated_at = now()
  where id = p_order_id;
  return p_order_id;
end;
$$;

create or replace function public.mark_bill_handed_over(p_bill_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
  v_pending int;
begin
  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select count(*) into v_pending
  from public.orders o
  where o.bill_id = p_bill_id
    and o.status not in ('cancelled', 'ready', 'completed');
  if v_pending > 0 then
    raise exception 'not all orders ready' using errcode = '22023';
  end if;

  update public.bill
  set pickup_status = 'handed_over', updated_at = now()
  where id = p_bill_id;
  return p_bill_id;
end;
$$;

-- Replace set_order_status to refresh pickup.
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
      v_order.stall_id, 'order.cancel', 'order', p_order_id, p_reason,
      jsonb_build_object('from', v_from)
    );
  end if;

  if v_order.bill_id is not null and v_to in ('ready', 'completed', 'cancelled') then
    perform public.refresh_bill_pickup_status(v_order.bill_id);
  end if;

  return p_order_id;
end;
$$;

create or replace function public.search_menu_items(p_query text)
returns table (
  id uuid,
  stall_id uuid,
  name text,
  price numeric,
  is_available boolean,
  quick_code text,
  parent_id uuid,
  stall_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select mi.id, mi.stall_id, mi.name, mi.price, mi.is_available, mi.quick_code,
         mi.parent_id, s.name as stall_name
  from public.menu_item mi
  join public.stall s on s.id = mi.stall_id
  where mi.stall_id in (select public.my_group_stall_ids())
    and (
      mi.name ilike '%' || coalesce(p_query, '') || '%'
      or coalesce(mi.quick_code, '') ilike '%' || coalesce(p_query, '') || '%'
    )
  order by mi.name
  limit 50;
$$;

create or replace function public.menu_recents(
  p_stall_id uuid,
  p_limit int default 12
)
returns table (
  menu_item_id uuid,
  name text,
  price numeric,
  is_available boolean,
  quick_code text,
  times_ordered bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select oi.menu_item_id, oi.name, mi.price, mi.is_available, mi.quick_code,
         count(*)::bigint as times_ordered
  from public.order_item oi
  join public.orders o on o.id = oi.order_id
  left join public.menu_item mi on mi.id = oi.menu_item_id
  where o.stall_id = p_stall_id
    and o.created_at > now() - interval '7 days'
    and o.status <> 'cancelled'
    and oi.voided_at is null
    and oi.menu_item_id is not null
    and p_stall_id in (select public.my_group_stall_ids())
  group by oi.menu_item_id, oi.name, mi.price, mi.is_available, mi.quick_code
  order by count(*) desc
  limit greatest(coalesce(p_limit, 12), 1);
$$;

drop function if exists public.pay_bill(uuid, jsonb);

-- pay_bill: due includes rounding; stamp shift/acting/upi fields from payment jsonb
create or replace function public.pay_bill(
  p_bill_id uuid,
  p_payments jsonb,
  p_shift_id uuid default null,
  p_acting_staff_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_bill      public.bill%rowtype;
  v_pay       jsonb;
  v_sum       numeric(12,2) := 0;
  v_due       numeric(12,2);
  v_method    text;
  v_amount    numeric(12,2);
  v_pay_key   uuid;
  v_actor     uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if v_bill.status = 'paid' then
    return p_bill_id;
  end if;
  if v_bill.status <> 'open' then
    raise exception 'bill is not open' using errcode = '22023';
  end if;
  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member of collecting stall' using errcode = '42501';
  end if;
  if p_payments is null or jsonb_typeof(p_payments) <> 'array'
     or jsonb_array_length(p_payments) = 0 then
    raise exception 'pay_bill requires at least one payment' using errcode = '22023';
  end if;

  for v_pay in select * from jsonb_array_elements(p_payments)
  loop
    v_method := v_pay->>'method';
    v_amount := (v_pay->>'amount')::numeric(12,2);
    v_pay_key := (v_pay->>'idempotency_key')::uuid;
    if v_method not in ('cash', 'upi', 'card') then
      raise exception 'invalid payment method' using errcode = '22023';
    end if;
    if v_amount is null or v_amount <= 0 then
      raise exception 'payment amount must be > 0' using errcode = '22023';
    end if;
    if v_pay_key is null then
      raise exception 'payment idempotency_key required' using errcode = '22023';
    end if;
    v_sum := v_sum + v_amount;
  end loop;

  v_due := v_bill.total - v_bill.discount + coalesce(v_bill.rounding_amount, 0);
  if v_sum <> v_due then
    raise exception 'payment sum % does not equal due %', v_sum, v_due
      using errcode = '22023';
  end if;

  v_actor := coalesce(p_acting_staff_id, v_uid);

  for v_pay in select * from jsonb_array_elements(p_payments)
  loop
    insert into public.payment (
      bill_id, method, amount, idempotency_key, created_by,
      shift_id, acting_staff_id, upi_ref, card_last4, card_terminal
    ) values (
      p_bill_id,
      v_pay->>'method',
      (v_pay->>'amount')::numeric(12,2),
      (v_pay->>'idempotency_key')::uuid,
      v_uid,
      coalesce(p_shift_id, v_bill.shift_id),
      v_actor,
      nullif(v_pay->>'upi_ref', ''),
      nullif(v_pay->>'card_last4', ''),
      nullif(v_pay->>'card_terminal', '')
    )
    on conflict (idempotency_key) do nothing;
  end loop;

  update public.bill
  set status = 'paid',
      paid_at = now(),
      updated_at = now(),
      shift_id = coalesce(shift_id, p_shift_id),
      acting_staff_id = coalesce(acting_staff_id, v_actor)
  where id = p_bill_id;

  return p_bill_id;
end;
$$;

grant execute on function public.refresh_bill_pickup_status(uuid) to authenticated;
grant execute on function public.acknowledge_order(uuid) to authenticated;
grant execute on function public.mark_bill_handed_over(uuid) to authenticated;
grant execute on function public.set_order_status(uuid, text, text) to authenticated;
grant execute on function public.search_menu_items(text) to authenticated;
grant execute on function public.menu_recents(uuid, int) to authenticated;
grant execute on function public.pay_bill(uuid, jsonb, uuid, uuid) to authenticated;
