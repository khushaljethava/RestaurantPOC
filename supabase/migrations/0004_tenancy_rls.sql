alter table public.stall            enable row level security;
alter table public.staff_membership enable row level security;
alter table public.food_court       enable row level security;

-- STALL ---------------------------------------------------------------
-- Readable across the group: you must see a peer's stall to order from it.
create policy stall_group_member_can_read
  on public.stall for select
  to authenticated
  using (id in (select public.my_group_stall_ids()));

-- Writable only by an owner or manager OF THAT STALL.
create policy stall_owner_can_update
  on public.stall for update
  to authenticated
  using (
    exists (
      select 1 from public.staff_membership m
      where m.stall_id = stall.id
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );

-- Anyone signed in may create a stall; they become its creator.
create policy stall_authenticated_can_insert
  on public.stall for insert
  to authenticated
  with check (created_by = (select auth.uid()));

-- STAFF MEMBERSHIP ----------------------------------------------------
-- Stall-private. Group membership grants NOTHING here: revenue sharing is a
-- business decision, but letting a peer add users to your stall is an attack.
create policy staff_own_stall_can_read
  on public.staff_membership for select
  to authenticated
  using (stall_id in (select public.my_stall_ids()));

-- Write policies use is_stall_owner() (SECURITY DEFINER) to avoid RLS recursion.
create policy staff_owner_can_insert
  on public.staff_membership for insert
  to authenticated
  with check (public.is_stall_owner(stall_id));

create policy staff_owner_can_update
  on public.staff_membership for update
  to authenticated
  using (public.is_stall_owner(stall_id))
  with check (public.is_stall_owner(stall_id));

create policy staff_owner_can_delete
  on public.staff_membership for delete
  to authenticated
  using (public.is_stall_owner(stall_id));

-- FOOD COURT ----------------------------------------------------------
create policy food_court_member_can_read
  on public.food_court for select
  to authenticated
  using (
    id in (
      select s.group_id from public.stall s
      where s.id in (select public.my_stall_ids())
        and s.group_id is not null
    )
  );

create policy food_court_authenticated_can_insert
  on public.food_court for insert
  to authenticated
  with check (created_by = (select auth.uid()));

-- Explicit grants required: Supabase no longer auto-exposes new public tables.
grant select, insert, update on public.stall to authenticated;
grant select, insert, update, delete on public.staff_membership to authenticated;
grant select, insert on public.food_court to authenticated;
