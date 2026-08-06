alter table public.bill enable row level security;
alter table public.payment enable row level security;

-- Group-readable: collector stall is in my group (covers peer bills too).
create policy bill_group_can_read
  on public.bill for select
  to authenticated
  using (
    collected_by_stall_id in (select public.my_group_stall_ids())
  );

create policy payment_group_can_read
  on public.payment for select
  to authenticated
  using (
    bill_id in (
      select b.id from public.bill b
      where b.collected_by_stall_id in (select public.my_group_stall_ids())
    )
  );

-- Direct inserts for collector members (RPCs preferred).
create policy bill_member_can_insert
  on public.bill for insert
  to authenticated
  with check (
    public.is_stall_member(collected_by_stall_id)
    and collected_by_user_id = (select auth.uid())
  );

create policy bill_member_can_update
  on public.bill for update
  to authenticated
  using (public.is_stall_member(collected_by_stall_id))
  with check (public.is_stall_member(collected_by_stall_id));

create policy payment_member_can_insert
  on public.payment for insert
  to authenticated
  with check (
    exists (
      select 1 from public.bill b
      where b.id = bill_id
        and public.is_stall_member(b.collected_by_stall_id)
    )
    and created_by = (select auth.uid())
  );

grant select, insert, update on public.bill to authenticated;
grant select, insert on public.payment to authenticated;
