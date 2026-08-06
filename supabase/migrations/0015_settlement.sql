-- Settlement and sales reporting. Derived from bills + orders — no ledger table.
-- Callers: admin settlement/reports; mobile settlement; tests/130_settlement.sql.
-- No prior 0015_*. Glob confirmed empty. Money numeric(12,2). No file I/O.
-- User: Implement the plan as specified.

create or replace function public.bill_settlement_sign(p_status text)
returns numeric
language sql
immutable
as $$
  select case p_status
    when 'paid' then 1::numeric
    when 'refunded' then 0::numeric
    else 0::numeric
  end;
$$;

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
    public.bill_settlement_sign(b.status) * public.order_line_total(o.id)
  ), 0)::numeric(12,2)
  from public.bill b
  join public.orders o on o.bill_id = b.id
  where b.collected_by_stall_id = p_collector
    and o.stall_id = p_food_stall
    and o.status <> 'cancelled'
    and b.status in ('paid', 'refunded')
    and b.updated_at >= p_from
    and b.updated_at < p_to;
$$;

create or replace function public.settlement_pairs(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  stall_a uuid,
  stall_b uuid,
  a_owes_b numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select id from public.stall where id in (select public.my_stall_ids())
  ),
  peers as (
    select id from public.stall where id in (select public.my_group_stall_ids())
  ),
  pairs as (
    select a.id as stall_a, b.id as stall_b
    from peers a
    cross join peers b
    where a.id < b.id
      and (a.id in (select id from mine) or b.id in (select id from mine))
  )
  select
    p.stall_a,
    p.stall_b,
    (
      public.collected_for_stall(p.stall_a, p.stall_b, p_from, p_to)
      - public.collected_for_stall(p.stall_b, p.stall_a, p_from, p_to)
    )::numeric(12,2) as a_owes_b
  from pairs p
  where (
    public.collected_for_stall(p.stall_a, p.stall_b, p_from, p_to)
    - public.collected_for_stall(p.stall_b, p.stall_a, p_from, p_to)
  ) <> 0;
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
      public.bill_settlement_sign(b.status) * public.order_line_total(o.id)
    ), 0)::numeric(12,2) as revenue,
    count(*) filter (where b.status = 'paid') as order_count
  from public.orders o
  join public.bill b on b.id = o.bill_id
  where o.stall_id in (select public.my_group_stall_ids())
    and o.status <> 'cancelled'
    and b.status in ('paid', 'refunded')
    and b.updated_at >= p_from
    and b.updated_at < p_to
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
    coalesce(sum(public.bill_settlement_sign(b.status) * oi.qty), 0)::numeric(12,3) as qty,
    coalesce(sum(public.bill_settlement_sign(b.status) * oi.line_total), 0)::numeric(12,2) as revenue
  from public.order_item oi
  join public.orders o on o.id = oi.order_id
  join public.bill b on b.id = o.bill_id
  where o.stall_id in (select public.my_group_stall_ids())
    and o.status <> 'cancelled'
    and b.status in ('paid', 'refunded')
    and b.updated_at >= p_from
    and b.updated_at < p_to
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
      public.bill_settlement_sign(b.status) * p.amount
    ), 0)::numeric(12,2) as amount,
    count(*) filter (where b.status = 'paid') as payment_count
  from public.payment p
  join public.bill b on b.id = p.bill_id
  where b.collected_by_stall_id in (select public.my_group_stall_ids())
    and b.status in ('paid', 'refunded')
    and b.updated_at >= p_from
    and b.updated_at < p_to
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
      public.bill_settlement_sign(b.status) * b.total
    ), 0)::numeric(12,2) as amount,
    count(*) filter (where b.status = 'paid') as bill_count
  from public.bill b
  where b.collected_by_stall_id in (select public.my_group_stall_ids())
    and b.status in ('paid', 'refunded')
    and b.updated_at >= p_from
    and b.updated_at < p_to
  group by b.collected_by_stall_id;
$$;

grant execute on function public.bill_settlement_sign(text) to authenticated;
grant execute on function public.collected_for_stall(uuid, uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.settlement_pairs(timestamptz, timestamptz) to authenticated;
grant execute on function public.sales_by_stall(timestamptz, timestamptz) to authenticated;
grant execute on function public.sales_by_item(timestamptz, timestamptz) to authenticated;
grant execute on function public.sales_by_payment_mode(timestamptz, timestamptz) to authenticated;
grant execute on function public.sales_by_collector(timestamptz, timestamptz) to authenticated;
