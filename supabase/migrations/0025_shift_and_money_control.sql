-- M1: shift/cash session, PIN, acting staff, amend/void, discount caps, partial refund, rounding.
-- Callers: mobile shift/lock/order/checkout; tests/190_shift_money.sql.

alter table public.stall
  add column if not exists rounding_rule text not null default 'rupee_1'
    check (rounding_rule in ('none', 'rupee_1', 'rupee_5')),
  add column if not exists discount_staff_cap_pct numeric(5,2) not null default 10
    check (discount_staff_cap_pct >= 0 and discount_staff_cap_pct <= 100),
  add column if not exists discount_staff_cap_flat numeric(12,2) not null default 100
    check (discount_staff_cap_flat >= 0),
  add column if not exists discount_manager_cap_pct numeric(5,2) not null default 50
    check (discount_manager_cap_pct >= 0 and discount_manager_cap_pct <= 100),
  add column if not exists variance_reason_threshold numeric(12,2) not null default 50
    check (variance_reason_threshold >= 0);

alter table public.staff_membership
  add column if not exists pin_hash text;

create table if not exists public.shifts (
  id              uuid primary key default gen_random_uuid(),
  stall_id        uuid not null references public.stall (id) on delete cascade,
  staff_id        uuid not null references auth.users (id),
  device_id       text not null default 'unknown',
  opened_at       timestamptz not null default now(),
  closed_at       timestamptz,
  opening_float   numeric(12,2) not null default 0 check (opening_float >= 0),
  declared_cash   numeric(12,2),
  expected_cash   numeric(12,2),
  variance        numeric(12,2),
  variance_reason text,
  notes           text,
  constraint shifts_closed_fields check (
    (closed_at is null and declared_cash is null)
    or (closed_at is not null and declared_cash is not null)
  )
);

create unique index if not exists shifts_one_open_per_staff_stall
  on public.shifts (stall_id, staff_id)
  where closed_at is null;

create index if not exists shifts_stall_opened_idx
  on public.shifts (stall_id, opened_at desc);

create table if not exists public.cash_movements (
  id          uuid primary key default gen_random_uuid(),
  shift_id    uuid not null references public.shifts (id) on delete cascade,
  kind        text not null check (kind in ('paid_in', 'paid_out')),
  amount      numeric(12,2) not null check (amount > 0),
  reason      text not null check (length(trim(reason)) > 0),
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now()
);

create index if not exists cash_movements_shift_idx on public.cash_movements (shift_id);

alter table public.shifts enable row level security;
alter table public.cash_movements enable row level security;

create policy shifts_member_read on public.shifts for select to authenticated
  using (stall_id in (select public.my_stall_ids()));

create policy cash_movements_member_read on public.cash_movements for select to authenticated
  using (
    exists (
      select 1 from public.shifts s
      where s.id = cash_movements.shift_id
        and s.stall_id in (select public.my_stall_ids())
    )
  );

grant select on public.shifts to authenticated;
grant select on public.cash_movements to authenticated;

alter table public.bill
  add column if not exists shift_id uuid references public.shifts (id),
  add column if not exists acting_staff_id uuid references auth.users (id),
  add column if not exists discount_reason text,
  add column if not exists discount_approver_id uuid references auth.users (id),
  add column if not exists rounding_amount numeric(12,2) not null default 0;

alter table public.payment
  add column if not exists shift_id uuid references public.shifts (id),
  add column if not exists acting_staff_id uuid references auth.users (id),
  add column if not exists upi_ref text,
  add column if not exists upi_verified boolean not null default false,
  add column if not exists card_last4 text,
  add column if not exists card_terminal text,
  add column if not exists screenshot_path text;

alter table public.order_item
  add column if not exists voided_at timestamptz,
  add column if not exists void_reason text,
  add column if not exists voided_by uuid references auth.users (id);

create table if not exists public.refund_line (
  id              uuid primary key default gen_random_uuid(),
  bill_id         uuid not null references public.bill (id) on delete cascade,
  order_item_id   uuid references public.order_item (id) on delete set null,
  qty             numeric(12,3) not null check (qty > 0),
  amount          numeric(12,2) not null check (amount > 0),
  method          text not null check (method in ('cash', 'upi', 'card', 'adjust')),
  reason          text not null check (length(trim(reason)) > 0),
  approved_by     uuid references auth.users (id),
  acting_staff_id uuid references auth.users (id),
  shift_id        uuid references public.shifts (id),
  created_by      uuid not null references auth.users (id),
  created_at      timestamptz not null default now()
);

create index if not exists refund_line_bill_idx on public.refund_line (bill_id);

alter table public.refund_line enable row level security;

create policy refund_line_group_read on public.refund_line for select to authenticated
  using (
    exists (
      select 1 from public.bill b
      where b.id = refund_line.bill_id
        and b.collected_by_stall_id in (select public.my_group_stall_ids())
    )
  );

grant select on public.refund_line to authenticated;

create or replace function public.staff_role_for(p_stall_id uuid, p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role
  from public.staff_membership m
  where m.stall_id = p_stall_id and m.user_id = p_user_id
  limit 1;
$$;

create or replace function public.require_open_shift(p_stall_id uuid, p_staff_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select id into v_id
  from public.shifts
  where stall_id = p_stall_id and staff_id = p_staff_id and closed_at is null
  order by opened_at desc
  limit 1;
  if v_id is null then
    raise exception 'open shift required' using errcode = 'P0001';
  end if;
  return v_id;
end;
$$;

create or replace function public.apply_rounding(p_amount numeric, p_rule text)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_rule = 'none' then
    return round(p_amount, 2);
  elsif p_rule = 'rupee_5' then
    return round(p_amount / 5) * 5;
  else
    return round(p_amount, 0);
  end if;
end;
$$;

create or replace function public.set_staff_pin(p_stall_id uuid, p_pin text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_pin is null or p_pin !~ '^\d{4}$' then
    raise exception 'PIN must be 4 digits' using errcode = '22023';
  end if;
  if not public.is_stall_member(p_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  update public.staff_membership
  set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf'))
  where stall_id = p_stall_id and user_id = v_uid;

  if not found then
    raise exception 'membership not found' using errcode = 'P0002';
  end if;
  return true;
end;
$$;

create or replace function public.verify_staff_pin(
  p_stall_id uuid,
  p_user_id uuid,
  p_pin text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.is_stall_member(p_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select pin_hash into v_hash
  from public.staff_membership
  where stall_id = p_stall_id and user_id = p_user_id;

  if v_hash is null then
    return false;
  end if;
  return v_hash = extensions.crypt(p_pin, v_hash);
end;
$$;

create or replace function public.open_shift(
  p_stall_id uuid,
  p_opening_float numeric,
  p_device_id text default 'unknown'
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
  if not public.is_stall_member(p_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  if p_opening_float is null or p_opening_float < 0 then
    raise exception 'opening float must be >= 0' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.shifts
    where stall_id = p_stall_id and staff_id = v_uid and closed_at is null
  ) then
    raise exception 'shift already open' using errcode = '22023';
  end if;

  insert into public.shifts (stall_id, staff_id, device_id, opening_float)
  values (
    p_stall_id, v_uid, coalesce(nullif(trim(p_device_id), ''), 'unknown'),
    p_opening_float::numeric(12,2)
  )
  returning id into v_id;

  perform public.write_audit(
    p_stall_id, 'shift.open', 'shift', v_id, null,
    jsonb_build_object('opening_float', p_opening_float, 'device_id', p_device_id)
  );
  return v_id;
end;
$$;

create or replace function public.add_cash_movement(
  p_shift_id uuid,
  p_kind text,
  p_amount numeric,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_shift public.shifts%rowtype;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_kind not in ('paid_in', 'paid_out') then
    raise exception 'invalid kind' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be > 0' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'reason required' using errcode = '22023';
  end if;

  select * into v_shift from public.shifts where id = p_shift_id for update;
  if not found then
    raise exception 'shift not found' using errcode = 'P0002';
  end if;
  if v_shift.closed_at is not null then
    raise exception 'shift already closed' using errcode = '22023';
  end if;
  if not public.is_stall_member(v_shift.stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  insert into public.cash_movements (shift_id, kind, amount, reason, created_by)
  values (p_shift_id, p_kind, p_amount::numeric(12,2), trim(p_reason), v_uid)
  returning id into v_id;

  perform public.write_audit(
    v_shift.stall_id, 'shift.cash_movement', 'shift', p_shift_id, p_reason,
    jsonb_build_object('kind', p_kind, 'amount', p_amount)
  );
  return v_id;
end;
$$;

create or replace function public.shift_expected_cash(p_shift_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_shift public.shifts%rowtype;
  v_cash_sales numeric := 0;
  v_cash_refunds numeric := 0;
  v_paid_in numeric := 0;
  v_paid_out numeric := 0;
begin
  select * into v_shift from public.shifts where id = p_shift_id;
  if not found then
    raise exception 'shift not found' using errcode = 'P0002';
  end if;

  select coalesce(sum(p.amount), 0) into v_cash_sales
  from public.payment p
  join public.bill b on b.id = p.bill_id
  where p.shift_id = p_shift_id and p.method = 'cash' and b.status = 'paid';

  select coalesce(sum(r.amount), 0) into v_cash_refunds
  from public.refund_line r
  where r.shift_id = p_shift_id and r.method = 'cash';

  select coalesce(sum(amount), 0) into v_paid_in
  from public.cash_movements where shift_id = p_shift_id and kind = 'paid_in';

  select coalesce(sum(amount), 0) into v_paid_out
  from public.cash_movements where shift_id = p_shift_id and kind = 'paid_out';

  return v_shift.opening_float + v_cash_sales - v_cash_refunds + v_paid_in - v_paid_out;
end;
$$;

create or replace function public.close_shift(
  p_shift_id uuid,
  p_declared_cash numeric,
  p_variance_reason text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_shift public.shifts%rowtype;
  v_expected numeric;
  v_variance numeric;
  v_threshold numeric;
  v_open_bills int;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_declared_cash is null or p_declared_cash < 0 then
    raise exception 'declared cash must be >= 0' using errcode = '22023';
  end if;

  select * into v_shift from public.shifts where id = p_shift_id for update;
  if not found then
    raise exception 'shift not found' using errcode = 'P0002';
  end if;
  if v_shift.closed_at is not null then
    raise exception 'shift already closed' using errcode = '22023';
  end if;
  if v_shift.staff_id <> v_uid
     and public.staff_role_for(v_shift.stall_id, v_uid) not in ('owner', 'manager') then
    raise exception 'cannot close another staff shift' using errcode = '42501';
  end if;

  select count(*) into v_open_bills
  from public.bill
  where shift_id = p_shift_id and status = 'open';

  v_expected := public.shift_expected_cash(p_shift_id);
  v_variance := p_declared_cash - v_expected;

  select variance_reason_threshold into v_threshold
  from public.stall where id = v_shift.stall_id;

  if abs(v_variance) > coalesce(v_threshold, 50)
     and (p_variance_reason is null or length(trim(p_variance_reason)) = 0) then
    raise exception 'variance reason required' using errcode = '22023';
  end if;

  update public.shifts set
    closed_at = now(),
    declared_cash = p_declared_cash::numeric(12,2),
    expected_cash = v_expected::numeric(12,2),
    variance = v_variance::numeric(12,2),
    variance_reason = nullif(trim(p_variance_reason), ''),
    notes = nullif(trim(p_notes), '')
  where id = p_shift_id;

  perform public.write_audit(
    v_shift.stall_id, 'shift.close', 'shift', p_shift_id, p_variance_reason,
    jsonb_build_object(
      'declared', p_declared_cash,
      'expected', v_expected,
      'variance', v_variance,
      'open_bills', v_open_bills
    )
  );
  return p_shift_id;
end;
$$;

create or replace function public.current_open_shift(p_stall_id uuid)
returns public.shifts
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.shifts%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  select * into v_row
  from public.shifts
  where stall_id = p_stall_id and staff_id = v_uid and closed_at is null
  order by opened_at desc
  limit 1;
  return v_row;
end;
$$;

create or replace function public.amend_order_item_qty(
  p_order_item_id uuid,
  p_qty numeric,
  p_acting_staff_id uuid default null,
  p_manager_pin_ok boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.order_item%rowtype;
  v_order public.orders%rowtype;
  v_bill public.bill%rowtype;
  v_actor uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_qty is null or p_qty <= 0 then
    raise exception 'qty must be > 0' using errcode = '22023';
  end if;

  select * into v_item from public.order_item where id = p_order_item_id for update;
  if not found then
    raise exception 'order item not found' using errcode = 'P0002';
  end if;
  if v_item.voided_at is not null then
    raise exception 'item already voided' using errcode = '22023';
  end if;

  select * into v_order from public.orders where id = v_item.order_id for update;
  if not public.is_stall_member(v_order.stall_id)
     and not public.is_stall_member(v_order.recorded_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  if v_order.status in ('cancelled', 'completed') then
    raise exception 'cannot amend this order status' using errcode = '22023';
  end if;

  if v_order.bill_id is not null then
    select * into v_bill from public.bill where id = v_order.bill_id;
    if v_bill.status in ('paid', 'refunded') then
      raise exception 'cannot amend paid bill; use refund' using errcode = '22023';
    end if;
  end if;

  if v_order.status = 'ready' and not p_manager_pin_ok
     and public.staff_role_for(v_order.stall_id, v_uid) = 'staff' then
    raise exception 'manager approval required' using errcode = '42501';
  end if;

  v_actor := coalesce(p_acting_staff_id, v_uid);

  update public.order_item
  set qty = p_qty,
      line_total = round((unit_price * p_qty), 2)
  where id = p_order_item_id;

  if v_order.bill_id is not null then
    perform public.recompute_bill_total(v_order.bill_id);
  end if;

  perform public.write_audit(
    v_order.stall_id, 'order.amend_qty', 'order_item', p_order_item_id, null,
    jsonb_build_object('qty', p_qty, 'acting_staff_id', v_actor)
  );
  return p_order_item_id;
end;
$$;

create or replace function public.void_order_item(
  p_order_item_id uuid,
  p_reason text,
  p_acting_staff_id uuid default null,
  p_manager_pin_ok boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.order_item%rowtype;
  v_order public.orders%rowtype;
  v_bill public.bill%rowtype;
  v_actor uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'void reason required' using errcode = '22023';
  end if;

  select * into v_item from public.order_item where id = p_order_item_id for update;
  if not found then
    raise exception 'order item not found' using errcode = 'P0002';
  end if;
  if v_item.voided_at is not null then
    return p_order_item_id;
  end if;

  select * into v_order from public.orders where id = v_item.order_id for update;
  if not public.is_stall_member(v_order.stall_id)
     and not public.is_stall_member(v_order.recorded_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  if v_order.bill_id is not null then
    select * into v_bill from public.bill where id = v_order.bill_id;
    if v_bill.status in ('paid', 'refunded') then
      raise exception 'cannot void on paid bill; use refund' using errcode = '22023';
    end if;
  end if;

  if v_order.status = 'ready' and not p_manager_pin_ok
     and public.staff_role_for(v_order.stall_id, v_uid) = 'staff' then
    raise exception 'manager approval required' using errcode = '42501';
  end if;

  v_actor := coalesce(p_acting_staff_id, v_uid);

  update public.order_item
  set voided_at = now(), void_reason = trim(p_reason), voided_by = v_actor,
      line_total = 0
  where id = p_order_item_id;

  if v_order.bill_id is not null then
    perform public.recompute_bill_total(v_order.bill_id);
  end if;

  perform public.write_audit(
    v_order.stall_id, 'order.void_line', 'order_item', p_order_item_id, p_reason,
    jsonb_build_object('acting_staff_id', v_actor)
  );
  return p_order_item_id;
end;
$$;

drop function if exists public.set_bill_discount(uuid, numeric, text);

create or replace function public.set_bill_discount(
  p_bill_id uuid,
  p_discount numeric,
  p_reason text,
  p_approver_id uuid default null,
  p_acting_staff_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bill public.bill%rowtype;
  v_role text;
  v_stall public.stall%rowtype;
  v_cap numeric;
  v_actor uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
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

  v_actor := coalesce(p_acting_staff_id, v_uid);
  v_role := public.staff_role_for(v_bill.collected_by_stall_id, v_actor);
  select * into v_stall from public.stall where id = v_bill.collected_by_stall_id;

  if v_role = 'staff' then
    v_cap := greatest(
      v_stall.discount_staff_cap_flat,
      round(v_bill.total * v_stall.discount_staff_cap_pct / 100, 2)
    );
    if p_discount > v_cap and p_approver_id is null then
      raise exception 'discount exceeds staff cap; manager approval required'
        using errcode = '42501';
    end if;
  elsif v_role = 'manager' then
    v_cap := round(v_bill.total * v_stall.discount_manager_cap_pct / 100, 2);
    if p_discount > v_cap and p_approver_id is null then
      raise exception 'discount exceeds manager cap; owner approval required'
        using errcode = '42501';
    end if;
  end if;

  if p_approver_id is not null then
    if public.staff_role_for(v_bill.collected_by_stall_id, p_approver_id)
       not in ('owner', 'manager') then
      raise exception 'approver must be manager or owner' using errcode = '42501';
    end if;
  end if;

  update public.bill set
    discount = p_discount::numeric(12,2),
    discount_reason = trim(p_reason),
    discount_approver_id = p_approver_id,
    acting_staff_id = v_actor,
    updated_at = now()
  where id = p_bill_id;

  perform public.write_audit(
    v_bill.collected_by_stall_id, 'bill.discount', 'bill', p_bill_id, p_reason,
    jsonb_build_object(
      'discount', p_discount, 'total', v_bill.total,
      'approver_id', p_approver_id, 'acting_staff_id', v_actor
    )
  );
  return p_bill_id;
end;
$$;

create or replace function public.partial_refund_bill(
  p_bill_id uuid,
  p_lines jsonb,
  p_reason text,
  p_method text default 'cash',
  p_approver_id uuid default null,
  p_acting_staff_id uuid default null,
  p_shift_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bill public.bill%rowtype;
  v_actor uuid;
  v_line jsonb;
  v_item public.order_item%rowtype;
  v_qty numeric;
  v_amount numeric;
  v_total_refund numeric := 0;
  v_role text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'refund reason required' using errcode = '22023';
  end if;
  if p_method not in ('cash', 'upi', 'card', 'adjust') then
    raise exception 'invalid refund method' using errcode = '22023';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'refund lines required' using errcode = '22023';
  end if;

  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if v_bill.status not in ('paid', 'refunded') then
    raise exception 'only paid bills can be refunded' using errcode = '22023';
  end if;
  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  v_actor := coalesce(p_acting_staff_id, v_uid);
  v_role := public.staff_role_for(v_bill.collected_by_stall_id, v_actor);
  if v_role = 'staff' and p_approver_id is null then
    raise exception 'manager approval required for refund' using errcode = '42501';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select * into v_item from public.order_item
    where id = (v_line->>'order_item_id')::uuid;
    if not found then
      raise exception 'order item not found' using errcode = 'P0002';
    end if;
    v_qty := coalesce((v_line->>'qty')::numeric, v_item.qty);
    if v_qty <= 0 or v_qty > v_item.qty then
      raise exception 'invalid refund qty' using errcode = '22023';
    end if;
    v_amount := round((v_item.unit_price * v_qty), 2);
    v_total_refund := v_total_refund + v_amount;

    insert into public.refund_line (
      bill_id, order_item_id, qty, amount, method, reason,
      approved_by, acting_staff_id, shift_id, created_by
    ) values (
      p_bill_id, v_item.id, v_qty, v_amount, p_method, trim(p_reason),
      p_approver_id, v_actor, p_shift_id, v_uid
    );
  end loop;

  if (
    select coalesce(sum(amount), 0) from public.refund_line where bill_id = p_bill_id
  ) >= (v_bill.total - v_bill.discount) then
    update public.bill
    set status = 'refunded', refunded_at = now(), updated_at = now()
    where id = p_bill_id;
  end if;

  perform public.write_audit(
    v_bill.collected_by_stall_id, 'bill.partial_refund', 'bill', p_bill_id, p_reason,
    jsonb_build_object(
      'amount', v_total_refund, 'method', p_method,
      'approver_id', p_approver_id, 'acting_staff_id', v_actor
    )
  );
  return p_bill_id;
end;
$$;

drop function if exists public.refund_bill(uuid, text);

create or replace function public.refund_bill(
  p_bill_id uuid,
  p_reason text,
  p_acting_staff_id uuid default null,
  p_approver_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bill public.bill%rowtype;
  v_actor uuid;
  v_role text;
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

  v_actor := coalesce(p_acting_staff_id, v_uid);
  v_role := public.staff_role_for(v_bill.collected_by_stall_id, v_actor);
  if v_role = 'staff' and p_approver_id is null then
    raise exception 'manager approval required for refund' using errcode = '42501';
  end if;

  update public.bill
  set status = 'refunded', refunded_at = coalesce(refunded_at, now()), updated_at = now()
  where id = p_bill_id;

  perform public.write_audit(
    v_bill.collected_by_stall_id, 'bill.refund', 'bill', p_bill_id, p_reason,
    jsonb_build_object(
      'total', v_bill.total, 'discount', v_bill.discount,
      'acting_staff_id', v_actor, 'approver_id', p_approver_id
    )
  );
  return p_bill_id;
end;
$$;

create or replace function public.apply_bill_rounding(p_bill_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
  v_rule text;
  v_due numeric;
  v_rounded numeric;
  v_delta numeric;
begin
  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if v_bill.status <> 'open' then
    raise exception 'can only round open bill' using errcode = '22023';
  end if;
  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select rounding_rule into v_rule from public.stall where id = v_bill.collected_by_stall_id;
  v_due := v_bill.total - v_bill.discount;
  v_rounded := public.apply_rounding(v_due, v_rule);
  v_delta := v_rounded - v_due;

  update public.bill
  set rounding_amount = v_delta::numeric(12,2), updated_at = now()
  where id = p_bill_id;

  return v_rounded;
end;
$$;

-- Exclude voided lines from order/bill totals.
create or replace function public.order_line_total(p_order_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(oi.line_total), 0)::numeric(12,2)
  from public.order_item oi
  where oi.order_id = p_order_id
    and oi.voided_at is null;
$$;

grant execute on function public.staff_role_for(uuid, uuid) to authenticated;
grant execute on function public.set_staff_pin(uuid, text) to authenticated;
grant execute on function public.verify_staff_pin(uuid, uuid, text) to authenticated;
grant execute on function public.open_shift(uuid, numeric, text) to authenticated;
grant execute on function public.add_cash_movement(uuid, text, numeric, text) to authenticated;
grant execute on function public.shift_expected_cash(uuid) to authenticated;
grant execute on function public.close_shift(uuid, numeric, text, text) to authenticated;
grant execute on function public.current_open_shift(uuid) to authenticated;
grant execute on function public.amend_order_item_qty(uuid, numeric, uuid, boolean) to authenticated;
grant execute on function public.void_order_item(uuid, text, uuid, boolean) to authenticated;
grant execute on function public.set_bill_discount(uuid, numeric, text, uuid, uuid) to authenticated;
grant execute on function public.partial_refund_bill(uuid, jsonb, text, text, uuid, uuid, uuid) to authenticated;
grant execute on function public.refund_bill(uuid, text, uuid, uuid) to authenticated;
grant execute on function public.apply_bill_rounding(uuid) to authenticated;
grant execute on function public.apply_rounding(numeric, text) to authenticated;
grant execute on function public.require_open_shift(uuid, uuid) to authenticated;
