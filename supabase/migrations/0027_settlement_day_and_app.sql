-- M3/M4: settlement confirmation, app min version, receipt tokens.
-- Callers: mobile settlement/day/receipt; admin shift views.

create table if not exists public.settlement_record (
  id                uuid primary key default gen_random_uuid(),
  from_stall_id     uuid not null references public.stall (id),
  to_stall_id       uuid not null references public.stall (id),
  amount            numeric(12,2) not null check (amount > 0),
  day               date not null,
  method            text not null default 'cash' check (method in ('cash', 'upi')),
  note              text,
  marked_by         uuid not null references auth.users (id),
  marked_at         timestamptz not null default now(),
  confirmed_by      uuid references auth.users (id),
  confirmed_at      timestamptz,
  disputed          boolean not null default false,
  dispute_note      text,
  unique (from_stall_id, to_stall_id, day)
);

alter table public.settlement_record enable row level security;

create policy settlement_record_member_read on public.settlement_record
  for select to authenticated
  using (
    from_stall_id in (select public.my_stall_ids())
    or to_stall_id in (select public.my_stall_ids())
  );

grant select on public.settlement_record to authenticated;

create or replace function public.mark_settlement(
  p_from_stall uuid,
  p_to_stall uuid,
  p_day date,
  p_amount numeric,
  p_method text default 'cash',
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_role text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  v_role := public.staff_role_for(p_from_stall, v_uid);
  if v_role not in ('owner', 'manager') then
    raise exception 'owner/manager only' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be > 0' using errcode = '22023';
  end if;
  if p_method not in ('cash', 'upi') then
    raise exception 'invalid method' using errcode = '22023';
  end if;

  insert into public.settlement_record (
    from_stall_id, to_stall_id, amount, day, method, note, marked_by
  ) values (
    p_from_stall, p_to_stall, p_amount::numeric(12,2), p_day, p_method,
    nullif(trim(p_note), ''), v_uid
  )
  on conflict (from_stall_id, to_stall_id, day) do update
    set amount = excluded.amount,
        method = excluded.method,
        note = excluded.note,
        marked_by = excluded.marked_by,
        marked_at = now(),
        confirmed_by = null,
        confirmed_at = null,
        disputed = false,
        dispute_note = null
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.confirm_settlement(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.settlement_record%rowtype;
  v_role text;
begin
  select * into v_row from public.settlement_record where id = p_id for update;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  v_role := public.staff_role_for(v_row.to_stall_id, v_uid);
  if v_role not in ('owner', 'manager') then
    raise exception 'counterparty owner/manager only' using errcode = '42501';
  end if;
  update public.settlement_record
  set confirmed_by = v_uid, confirmed_at = now()
  where id = p_id;
  return p_id;
end;
$$;

create table if not exists public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

insert into public.app_config (key, value) values
  ('min_supported_version', '1.0.0')
on conflict (key) do nothing;

alter table public.app_config enable row level security;
create policy app_config_read on public.app_config for select to authenticated using (true);
grant select on public.app_config to authenticated;

create table if not exists public.receipt_share_token (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.bill (id) on delete cascade,
  token text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days')
);

create index if not exists receipt_share_token_bill_idx on public.receipt_share_token (bill_id);

alter table public.receipt_share_token enable row level security;
create policy receipt_share_member_read on public.receipt_share_token
  for select to authenticated
  using (
    exists (
      select 1 from public.bill b
      where b.id = receipt_share_token.bill_id
        and b.collected_by_stall_id in (select public.my_group_stall_ids())
    )
  );
grant select on public.receipt_share_token to authenticated;

create or replace function public.create_receipt_share_token(p_bill_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
  v_token text;
begin
  select * into v_bill from public.bill where id = p_bill_id;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  v_token := encode(extensions.gen_random_bytes(16), 'hex');
  insert into public.receipt_share_token (bill_id, token) values (p_bill_id, v_token);
  return v_token;
end;
$$;

create or replace function public.day_summary(p_stall_id uuid, p_day date default current_date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from timestamptz;
  v_to timestamptz;
  v_role text;
begin
  v_role := public.staff_role_for(p_stall_id, auth.uid());
  if v_role not in ('owner', 'manager') then
    raise exception 'owner/manager only' using errcode = '42501';
  end if;
  v_from := (p_day::text || ' 00:00:00')::timestamp AT TIME ZONE 'Asia/Kolkata';
  v_to := v_from + interval '1 day';
  return jsonb_build_object(
    'sales_total', (
      select coalesce(sum(b.total - b.discount), 0)
      from public.bill b
      where b.collected_by_stall_id = p_stall_id
        and b.status = 'paid'
        and b.paid_at >= v_from and b.paid_at < v_to
    ),
    'open_bills', (
      select count(*) from public.bill
      where collected_by_stall_id = p_stall_id and status = 'open'
    ),
    'unverified_upi', (
      select count(*) from public.payment p
      join public.bill b on b.id = p.bill_id
      where b.collected_by_stall_id = p_stall_id
        and p.method = 'upi' and p.upi_verified = false
        and b.paid_at >= v_from and b.paid_at < v_to
    ),
    'unhanded_tokens', (
      select count(*) from public.bill
      where collected_by_stall_id = p_stall_id
        and status = 'paid'
        and pickup_status = 'ready'
        and paid_at >= v_from and paid_at < v_to
    ),
    'shift_variances', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'shift_id', s.id, 'staff_id', s.staff_id,
        'variance', s.variance, 'reason', s.variance_reason
      )), '[]'::jsonb)
      from public.shifts s
      where s.stall_id = p_stall_id
        and s.closed_at >= v_from and s.closed_at < v_to
        and s.variance is not null and s.variance <> 0
    )
  );
end;
$$;

create or replace function public.my_sales_summary(p_stall_id uuid, p_shift_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_shift uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.is_stall_member(p_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  v_shift := p_shift_id;
  if v_shift is null then
    select id into v_shift from public.shifts
    where stall_id = p_stall_id and staff_id = v_uid and closed_at is null
    limit 1;
  end if;
  return jsonb_build_object(
    'orders', (
      select count(*) from public.orders
      where recorded_by_user_id = v_uid
        and recorded_by_stall_id = p_stall_id
        and (v_shift is null or exists (
          select 1 from public.bill b where b.id = orders.bill_id and b.shift_id = v_shift
        ))
    ),
    'collected', (
      select coalesce(sum(p.amount), 0) from public.payment p
      join public.bill b on b.id = p.bill_id
      where coalesce(p.acting_staff_id, p.created_by) = v_uid
        and b.collected_by_stall_id = p_stall_id
        and (v_shift is null or p.shift_id = v_shift)
    )
  );
end;
$$;

grant execute on function public.mark_settlement(uuid, uuid, date, numeric, text, text) to authenticated;
grant execute on function public.confirm_settlement(uuid) to authenticated;
grant execute on function public.create_receipt_share_token(uuid) to authenticated;
grant execute on function public.day_summary(uuid, date) to authenticated;
grant execute on function public.my_sales_summary(uuid, uuid) to authenticated;
