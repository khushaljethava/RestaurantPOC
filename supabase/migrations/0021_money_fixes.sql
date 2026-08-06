-- Money/report correctness fixes.
--
-- 1. bill.paid_at / bill.refunded_at: reporting windows must not move when a
--    row is touched later. Windowing on updated_at made a Monday sale vanish
--    from Monday's report the moment it was refunded on Tuesday, and Tuesday
--    showed nothing at all. Now a payment counts +1 in the window holding
--    paid_at and -1 in the window holding refunded_at.
-- 2. pay_bill dropped its unused p_idempotency_key. Retry safety comes from the
--    row lock plus the status check; a parameter read by nothing is a promise
--    the function does not keep.
-- 3. create_order refuses unavailable menu items (the stock-out toggle was
--    UI-only) and replays idempotency keys race-safely, scoped to the caller.

alter table public.bill
  add column if not exists paid_at     timestamptz,
  add column if not exists refunded_at timestamptz;

-- Backfill: pre-existing rows only ever had updated_at to go on.
update public.bill set paid_at = updated_at
  where paid_at is null and status in ('paid', 'refunded');
update public.bill set refunded_at = updated_at
  where refunded_at is null and status = 'refunded';

create index if not exists bill_paid_at_idx on public.bill (paid_at)
  where paid_at is not null;
create index if not exists bill_refunded_at_idx on public.bill (refunded_at)
  where refunded_at is not null;

-- Signed contribution of a bill to [p_from, p_to): +1 when paid inside it,
-- -1 when refunded inside it, 0 (or a net 0) otherwise.
create or replace function public.bill_window_sign(
  p_paid_at timestamptz,
  p_refunded_at timestamptz,
  p_from timestamptz,
  p_to timestamptz
)
returns numeric
language sql
immutable
as $$
  select
    (case when p_paid_at >= p_from and p_paid_at < p_to then 1 else 0 end)
    - (case when p_refunded_at >= p_from and p_refunded_at < p_to then 1 else 0 end)
$$;

grant execute on function public.bill_window_sign(timestamptz, timestamptz, timestamptz, timestamptz) to authenticated;

-- ponytail: bill_settlement_sign(text) left in place so nothing that still
-- calls it breaks; every reporting function below uses bill_window_sign now.

create or replace function public.collected_for_stall(
  p_collector uuid,
  p_food_stall uuid,
  p_from timestamptz,
  p_to timestamptz
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(
    public.bill_window_sign(b.paid_at, b.refunded_at, p_from, p_to)
    * public.order_line_total(o.id)
  ), 0)::numeric(12,2)
  from public.bill b
  join public.orders o on o.bill_id = b.id
  where b.collected_by_stall_id = p_collector
    and o.stall_id = p_food_stall
    and o.status <> 'cancelled'
    and (
      (b.paid_at >= p_from and b.paid_at < p_to)
      or (b.refunded_at >= p_from and b.refunded_at < p_to)
    );
$$;

create or replace function public.sales_by_stall(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  stall_id uuid,
  revenue numeric,
  order_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    o.stall_id,
    coalesce(sum(
      public.bill_window_sign(b.paid_at, b.refunded_at, p_from, p_to)
      * public.order_line_total(o.id)
    ), 0)::numeric(12,2) as revenue,
    count(*) filter (where b.paid_at >= p_from and b.paid_at < p_to) as order_count
  from public.orders o
  join public.bill b on b.id = o.bill_id
  where o.stall_id in (select public.my_group_stall_ids())
    and o.status <> 'cancelled'
    and (
      (b.paid_at >= p_from and b.paid_at < p_to)
      or (b.refunded_at >= p_from and b.refunded_at < p_to)
    )
  group by o.stall_id;
$$;

create or replace function public.sales_by_item(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  menu_item_id uuid,
  item_name text,
  stall_id uuid,
  qty numeric,
  revenue numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    oi.menu_item_id,
    oi.name as item_name,
    o.stall_id,
    coalesce(sum(
      public.bill_window_sign(b.paid_at, b.refunded_at, p_from, p_to) * oi.qty
    ), 0)::numeric(12,3) as qty,
    coalesce(sum(
      public.bill_window_sign(b.paid_at, b.refunded_at, p_from, p_to) * oi.line_total
    ), 0)::numeric(12,2) as revenue
  from public.order_item oi
  join public.orders o on o.id = oi.order_id
  join public.bill b on b.id = o.bill_id
  where o.stall_id in (select public.my_group_stall_ids())
    and o.status <> 'cancelled'
    and (
      (b.paid_at >= p_from and b.paid_at < p_to)
      or (b.refunded_at >= p_from and b.refunded_at < p_to)
    )
  group by oi.menu_item_id, oi.name, o.stall_id;
$$;

create or replace function public.sales_by_payment_mode(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  method text,
  amount numeric,
  payment_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.method,
    coalesce(sum(
      public.bill_window_sign(b.paid_at, b.refunded_at, p_from, p_to) * p.amount
    ), 0)::numeric(12,2) as amount,
    count(*) filter (where b.paid_at >= p_from and b.paid_at < p_to) as payment_count
  from public.payment p
  join public.bill b on b.id = p.bill_id
  where b.collected_by_stall_id in (select public.my_group_stall_ids())
    and (
      (b.paid_at >= p_from and b.paid_at < p_to)
      or (b.refunded_at >= p_from and b.refunded_at < p_to)
    )
  group by p.method;
$$;

create or replace function public.sales_by_collector(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  collected_by_stall_id uuid,
  amount numeric,
  bill_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    b.collected_by_stall_id,
    coalesce(sum(
      public.bill_window_sign(b.paid_at, b.refunded_at, p_from, p_to) * b.total
    ), 0)::numeric(12,2) as amount,
    count(*) filter (where b.paid_at >= p_from and b.paid_at < p_to) as bill_count
  from public.bill b
  where b.collected_by_stall_id in (select public.my_group_stall_ids())
    and (
      (b.paid_at >= p_from and b.paid_at < p_to)
      or (b.refunded_at >= p_from and b.refunded_at < p_to)
    )
  group by b.collected_by_stall_id;
$$;

-- pay_bill without the unused idempotency parameter.
drop function if exists public.pay_bill(uuid, jsonb, uuid);

create or replace function public.pay_bill(
  p_bill_id uuid,
  p_payments jsonb
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
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;

  -- Idempotent success. The row lock above serialises concurrent cashiers, so
  -- the second one lands here and returns instead of double-charging.
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

  v_due := v_bill.total - v_bill.discount;
  if v_sum <> v_due then
    raise exception 'payment sum % does not equal due %', v_sum, v_due
      using errcode = '22023';
  end if;

  for v_pay in select * from jsonb_array_elements(p_payments)
  loop
    insert into public.payment (
      bill_id, method, amount, idempotency_key, created_by
    ) values (
      p_bill_id,
      v_pay->>'method',
      (v_pay->>'amount')::numeric(12,2),
      (v_pay->>'idempotency_key')::uuid,
      v_uid
    )
    on conflict (idempotency_key) do nothing;
  end loop;

  update public.bill
  set status = 'paid',
      paid_at = now(),
      updated_at = now()
  where id = p_bill_id;

  return p_bill_id;
end;
$$;

grant execute on function public.pay_bill(uuid, jsonb) to authenticated;

-- refund_bill stamps refunded_at so the reversal lands in the right window.
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
  set status = 'refunded', refunded_at = now(), updated_at = now()
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

grant execute on function public.refund_bill(uuid, text) to authenticated;

-- create_order: reject sold-out items, and make the idempotency replay both
-- race-safe and scoped to the caller's own recording stall.
create or replace function public.create_order(
  p_stall_id uuid,
  p_recorded_by_stall_id uuid,
  p_idempotency_key uuid,
  p_status text,
  p_items jsonb,
  p_table_label text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_order_id  uuid;
  v_token     integer;
  v_item      jsonb;
  v_mi        public.menu_item%rowtype;
  v_qty       numeric(12,3);
  v_line      numeric(12,2);
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if p_status not in ('held', 'pending') then
    raise exception 'create_order status must be held or pending' using errcode = '22023';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'create_order requires at least one item' using errcode = '22023';
  end if;

  if not public.is_stall_member(p_recorded_by_stall_id) then
    raise exception 'not a member of recording stall' using errcode = '42501';
  end if;

  if p_stall_id <> p_recorded_by_stall_id
     and not public.stalls_same_group(p_stall_id, p_recorded_by_stall_id) then
    raise exception 'cross-stall create requires shared food court group'
      using errcode = '22023';
  end if;

  -- Replay: only ever hand back an order this caller's stall recorded. The
  -- lookup runs with definer rights, so an unscoped one would leak ids across
  -- tenants to anyone who guessed a key.
  select id into v_order_id
  from public.orders
  where idempotency_key = p_idempotency_key
    and recorded_by_stall_id = p_recorded_by_stall_id;

  if v_order_id is not null then
    return v_order_id;
  end if;

  if p_status = 'pending' then
    v_token := public.next_token(p_stall_id);
  else
    v_token := null;
  end if;

  insert into public.orders (
    stall_id, recorded_by_stall_id, recorded_by_user_id,
    table_label, token_no, status, idempotency_key, notes, held_at
  ) values (
    p_stall_id, p_recorded_by_stall_id, v_uid,
    p_table_label, v_token, p_status, p_idempotency_key, p_notes,
    case when p_status = 'held' then now() else null end
  )
  on conflict (idempotency_key) do nothing
  returning id into v_order_id;

  -- Lost the race with a concurrent identical submit: the other transaction
  -- owns the row, so return it rather than dying on the unique index.
  if v_order_id is null then
    select id into v_order_id
    from public.orders
    where idempotency_key = p_idempotency_key
      and recorded_by_stall_id = p_recorded_by_stall_id;

    if v_order_id is null then
      raise exception 'idempotency key belongs to another stall' using errcode = '42501';
    end if;
    return v_order_id;
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_mi
    from public.menu_item mi
    where mi.id = (v_item->>'menu_item_id')::uuid
      and mi.stall_id = p_stall_id;

    if not found then
      raise exception 'menu item not found on stall' using errcode = 'P0002';
    end if;

    if not v_mi.is_available then
      raise exception 'menu item % is not available', v_mi.name using errcode = '22023';
    end if;

    v_qty := (v_item->>'qty')::numeric(12,3);
    if v_qty is null or v_qty <= 0 then
      raise exception 'qty must be > 0' using errcode = '22023';
    end if;

    v_line := round(v_mi.price * v_qty, 2);

    insert into public.order_item (
      order_id, menu_item_id, name, qty, unit_price, line_total, notes
    ) values (
      v_order_id, v_mi.id, v_mi.name, v_qty, v_mi.price, v_line,
      v_item->>'notes'
    );
  end loop;

  return v_order_id;
end;
$$;

grant execute on function public.create_order(uuid, uuid, uuid, text, jsonb, text, text) to authenticated;
