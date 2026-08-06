-- SECURITY DEFINER is mandatory here, not a convenience.
-- RLS on staff_membership will itself call my_stall_ids(); if this function
-- ran with the caller's rights it would re-enter that policy forever.
-- Definer rights bypass RLS and break the cycle.
--
-- SET search_path = '' forces fully-qualified names so a caller cannot
-- shadow `public` with their own schema and hijack the lookup.

create or replace function public.my_stall_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.stall_id
  from public.staff_membership m
  where m.user_id = (select auth.uid());
$$;

comment on function public.my_stall_ids() is
  'Stalls the caller is a member of. Basis for stall-private access.';

create or replace function public.my_group_stall_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  -- own stalls
  select s.id
  from public.stall s
  where s.id in (select public.my_stall_ids())
  union
  -- every stall sharing a group with one of my stalls.
  -- group_id is not null on both sides, so a standalone stall (null group)
  -- matches nothing here and falls back to the first branch alone.
  select peer.id
  from public.stall peer
  join public.stall mine
    on mine.group_id = peer.group_id
  where mine.id in (select public.my_stall_ids())
    and peer.group_id is not null;
$$;

comment on function public.my_group_stall_ids() is
  'Own stalls plus food-court peers. Basis for group-readable data.';

grant execute on function public.my_stall_ids() to authenticated;
grant execute on function public.my_group_stall_ids() to authenticated;

-- Used by staff_membership write policies. Must be SECURITY DEFINER so the
-- policy does not re-enter RLS on staff_membership (infinite recursion).
create or replace function public.is_stall_owner(p_stall_id uuid)
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
      and m.role = 'owner'
  );
$$;

comment on function public.is_stall_owner(uuid) is
  'True if caller is owner of the given stall. Safe for use inside RLS policies.';

grant execute on function public.is_stall_owner(uuid) to authenticated;
