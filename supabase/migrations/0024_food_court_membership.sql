-- Food court operator: a landlord who runs courts and owns no stalls.
--
-- Before this, a food court was reachable only THROUGH a stall you owned, and
-- every stall owner in a court held full admin power over it. This makes the
-- court a tenant in its own right.
--
-- Gate facts:
-- 1. Callers: supabase migrator; admin courts/actions.ts (create_court,
--    rename_court, remove_stall_from_court, create_group_invite,
--    approve/reject_join_request); tests/180_court_operator.sql.
-- 2. Glob: migrations stop at 0023; no food_court_membership table and no
--    my_food_court_ids() exist.
-- 3. Writes food_court_membership(food_court_id,user_id,role); timestamptz
--    default now(). Backfill reads food_court(id, created_by).
-- 4. User: "start developement"

create table public.food_court_membership (
  id            uuid primary key default gen_random_uuid(),
  food_court_id uuid not null references public.food_court (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  -- 'manager' is accepted but not yet surfaced in the UI, which only creates
  -- owners. Allowing it now avoids a check-constraint migration later.
  role          text not null check (role in ('owner', 'manager')),
  created_at    timestamptz not null default now(),
  unique (food_court_id, user_id)
);

create index food_court_membership_user_idx
  on public.food_court_membership (user_id);

alter table public.food_court_membership enable row level security;

-- HELPERS -------------------------------------------------------------
-- SECURITY DEFINER for the same reason as my_stall_ids(): RLS on
-- food_court_membership calls these, and caller-rights execution would
-- re-enter that policy forever. search_path = '' so a caller cannot shadow
-- `public` and hijack the lookup.

create or replace function public.my_food_court_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.food_court_id
  from public.food_court_membership m
  where m.user_id = (select auth.uid());
$$;

comment on function public.my_food_court_ids() is
  'Food courts the caller operates. Basis for court-operator access.';

create or replace function public.is_court_owner(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.food_court_membership m
    where m.food_court_id = p_group_id
      and m.user_id = (select auth.uid())
      and m.role = 'owner'
  );
$$;

comment on function public.is_court_owner(uuid) is
  'True if caller owns the given food court. Safe inside RLS policies.';

-- READ-ONLY basis for operator visibility into tenant stalls.
-- Deliberately NOT folded into my_stall_ids(): that function gates every write
-- policy in the schema (0004, 0008, 0012), so widening it would silently give
-- landlords write access to their tenants' stalls.
create or replace function public.my_court_stall_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.stall s
  where s.group_id in (select public.my_food_court_ids());
$$;

comment on function public.my_court_stall_ids() is
  'Stalls in courts the caller operates. READ-ONLY basis; never a write gate.';

grant execute on function public.my_food_court_ids()  to authenticated;
grant execute on function public.is_court_owner(uuid) to authenticated;
grant execute on function public.my_court_stall_ids() to authenticated;

-- RLS -----------------------------------------------------------------
-- Every operator policy below is FOR SELECT only, except on the court's own
-- invites and join requests. An operator must never write tenant data, and
-- gets nothing at all on staff_membership: a landlord has no business seeing
-- or altering a tenant's staff roster.

create policy fcm_own_rows_can_read
  on public.food_court_membership for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or food_court_id in (select public.my_food_court_ids())
  );

create policy fcm_owner_can_insert
  on public.food_court_membership for insert
  to authenticated
  with check (public.is_court_owner(food_court_id));

create policy fcm_owner_can_delete
  on public.food_court_membership for delete
  to authenticated
  using (public.is_court_owner(food_court_id));

create policy food_court_operator_can_read
  on public.food_court for select
  to authenticated
  using (id in (select public.my_food_court_ids()));

create policy food_court_operator_can_update
  on public.food_court for update
  to authenticated
  using (public.is_court_owner(id))
  with check (public.is_court_owner(id));

create policy stall_court_operator_can_read
  on public.stall for select
  to authenticated
  using (id in (select public.my_court_stall_ids()));

create policy group_invite_operator
  on public.group_invite for all
  to authenticated
  using (group_id in (select public.my_food_court_ids()))
  with check (group_id in (select public.my_food_court_ids()));

create policy join_request_operator_can_read
  on public.group_join_request for select
  to authenticated
  using (group_id in (select public.my_food_court_ids()));

grant select, insert, delete on public.food_court_membership to authenticated;
grant update on public.food_court to authenticated;

-- RPCs ----------------------------------------------------------------

-- A court with no stall. This is the operator's entry point: they own no
-- stall, so create_food_court(name, stall_id) is unusable for them.
create or replace function public.create_court(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_group_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'court name is required' using errcode = '22023';
  end if;

  insert into public.food_court (name, created_by)
  values (trim(p_name), v_uid)
  returning id into v_group_id;

  insert into public.food_court_membership (food_court_id, user_id, role)
  values (v_group_id, v_uid, 'owner');

  return v_group_id;
end;
$$;

create or replace function public.rename_court(p_group_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_court_owner(p_group_id) then
    raise exception 'only a court owner may rename it' using errcode = '42501';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'court name is required' using errcode = '22023';
  end if;

  update public.food_court set name = trim(p_name) where id = p_group_id;
end;
$$;

-- Evicting a tenant. Before this only the stall itself could leave_group(),
-- so an operator had no way to remove a stall from their own court.
create or replace function public.remove_stall_from_court(
  p_group_id uuid,
  p_stall_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_court_owner(p_group_id) then
    raise exception 'only a court owner may remove a stall' using errcode = '42501';
  end if;

  -- group_id is only a grouping label: bills and orders are stall-private and
  -- are deliberately left untouched.
  update public.stall
  set group_id = null
  where id = p_stall_id and group_id = p_group_id;
end;
$$;

grant execute on function public.create_court(text)                  to authenticated;
grant execute on function public.rename_court(uuid, text)            to authenticated;
grant execute on function public.remove_stall_from_court(uuid, uuid) to authenticated;

-- AUTHORIZATION MOVES -------------------------------------------------
-- These three authorized as "owner of SOME stall in this group", which made
-- every tenant a co-administrator of the court. They now require court
-- ownership.

create or replace function public.create_group_invite(p_group_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_code text := public.gen_invite_code();
begin
  if not public.is_court_owner(p_group_id) then
    raise exception 'only a court owner may create invites' using errcode = '42501';
  end if;

  insert into public.group_invite (code, group_id, created_by)
  values (v_code, p_group_id, v_uid);

  return v_code;
end;
$$;

create or replace function public.approve_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_req public.group_join_request;
begin
  select * into v_req from public.group_join_request where id = p_request_id;
  if not found then
    raise exception 'no such request' using errcode = 'P0002';
  end if;

  if not public.is_court_owner(v_req.group_id) then
    raise exception 'only a court owner may approve' using errcode = '42501';
  end if;

  update public.stall set group_id = v_req.group_id where id = v_req.stall_id;
  update public.group_join_request set status = 'approved' where id = p_request_id;
end;
$$;

create or replace function public.reject_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_req public.group_join_request;
begin
  select * into v_req from public.group_join_request where id = p_request_id;
  if not found then
    raise exception 'no such request' using errcode = 'P0002';
  end if;

  if not public.is_court_owner(v_req.group_id) then
    raise exception 'only a court owner may reject' using errcode = '42501';
  end if;

  update public.group_join_request set status = 'rejected' where id = p_request_id;
end;
$$;

-- create_food_court() stays for a stall owner bootstrapping a court around
-- their own stall, but must now also record them as the court's operator or
-- they could not administer what they just created.
create or replace function public.create_food_court(p_name text, p_stall_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_group_id uuid;
  v_code     text := public.gen_invite_code();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if not exists (
    select 1 from public.staff_membership m
    where m.stall_id = p_stall_id
      and m.user_id = v_uid
      and m.role = 'owner'
  ) then
    raise exception 'only an owner may create a food court' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.stall s
    where s.id = p_stall_id and s.group_id is not null
  ) then
    raise exception 'stall already in a food court' using errcode = '22023';
  end if;

  insert into public.food_court (name, created_by)
  values (p_name, v_uid)
  returning id into v_group_id;

  insert into public.food_court_membership (food_court_id, user_id, role)
  values (v_group_id, v_uid, 'owner');

  update public.stall
  set group_id = v_group_id
  where id = p_stall_id;

  insert into public.group_invite (code, group_id, created_by)
  values (v_code, v_group_id, v_uid);

  return jsonb_build_object('group_id', v_group_id, 'invite_code', v_code);
end;
$$;

-- BACKFILL ------------------------------------------------------------
-- The court's creator becomes its first operator. This is a PERMISSION
-- REMOVAL for everyone else: before, any stall owner in a court could approve
-- joins and mint invites.
insert into public.food_court_membership (food_court_id, user_id, role)
select id, created_by, 'owner'
from public.food_court
on conflict (food_court_id, user_id) do nothing;
