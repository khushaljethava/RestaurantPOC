-- Member check for order write policies (any role on the stall).
create or replace function public.is_stall_member(p_stall_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_membership m
    where m.stall_id = p_stall_id
      and m.user_id = (select auth.uid())
  );
$$;

comment on function public.is_stall_member(uuid) is
  'True if caller has any staff_membership on the stall.';

grant execute on function public.is_stall_member(uuid) to authenticated;

alter table public.orders enable row level security;
alter table public.order_item enable row level security;
alter table public.stall_token_seq enable row level security;

-- Group-readable: own stall's food OR anything I recorded.
create policy orders_group_can_read
  on public.orders for select
  to authenticated
  using (
    stall_id in (select public.my_group_stall_ids())
    or recorded_by_stall_id in (select public.my_group_stall_ids())
  );

create policy order_item_group_can_read
  on public.order_item for select
  to authenticated
  using (
    order_id in (select o.id from public.orders o where
      o.stall_id in (select public.my_group_stall_ids())
      or o.recorded_by_stall_id in (select public.my_group_stall_ids()))
  );

-- Direct inserts allowed for members of the recording stall
-- (create_order RPC preferred for snapshot + token + idempotency).
create policy orders_member_can_insert
  on public.orders for insert
  to authenticated
  with check (
    public.is_stall_member(recorded_by_stall_id)
    and recorded_by_user_id = (select auth.uid())
  );

create policy order_item_member_can_insert
  on public.order_item for insert
  to authenticated
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and public.is_stall_member(o.recorded_by_stall_id)
    )
  );

-- Fulfilment updates: members of the owning stall (stall_id).
create policy orders_own_stall_can_update
  on public.orders for update
  to authenticated
  using (public.is_stall_member(stall_id))
  with check (public.is_stall_member(stall_id));

create policy stall_token_seq_member
  on public.stall_token_seq for all
  to authenticated
  using (public.is_stall_member(stall_id))
  with check (public.is_stall_member(stall_id));

grant select, insert, update on public.orders to authenticated;
grant select, insert on public.order_item to authenticated;
grant select, insert, update on public.stall_token_seq to authenticated;
