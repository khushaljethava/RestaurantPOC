-- Real table entity. Until now `orders.table_label` was free text and the
-- "open tables" list was derived from unbilled orders, so a table only existed
-- while it had an order on it. This gives stalls a managed list to pick from.
-- orders.table_label stays text and is NOT made a foreign key: historical
-- orders reference labels that were never registered, and a renamed/deleted
-- table must not rewrite past receipts.

create table public.restaurant_table (
  id         uuid primary key default gen_random_uuid(),
  stall_id   uuid not null references public.stall (id) on delete cascade,
  label      text not null check (length(trim(label)) > 0),
  seats      integer check (seats > 0),
  is_active  boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (stall_id, label)
);

create index restaurant_table_stall_id_idx on public.restaurant_table (stall_id);

alter table public.restaurant_table enable row level security;

create policy restaurant_table_group_can_read
  on public.restaurant_table for select
  to authenticated
  using (stall_id in (select public.my_group_stall_ids()));

create policy restaurant_table_own_stall_can_write
  on public.restaurant_table for all
  to authenticated
  using (
    exists (select 1 from public.staff_membership m
            where m.stall_id = restaurant_table.stall_id
              and m.user_id = (select auth.uid())
              and m.role in ('owner', 'manager'))
  )
  with check (
    exists (select 1 from public.staff_membership m
            where m.stall_id = restaurant_table.stall_id
              and m.user_id = (select auth.uid())
              and m.role in ('owner', 'manager'))
  );

grant select, insert, update, delete on public.restaurant_table to authenticated;
