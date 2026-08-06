-- Food court bootstrap: create group, mint invite codes, leave group.
--
-- Gate facts:
-- 1. Callers: admin group/actions.ts (createFoodCourt, createGroupInvite, leaveGroup);
--    supabase test runner loads migrations then runs tests/120_food_court_rpcs.sql.
-- 2. Glob: no 0014_*.sql or create_food_court RPC exists yet.
-- 3. No file I/O; writes food_court(id,name,created_by), group_invite(code,group_id),
--    stall.group_id. Timestamps use timestamptz default now().
-- 4. User: "Implement the plan as specified, it is attached for your reference."

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

  update public.stall
  set group_id = v_group_id
  where id = p_stall_id;

  insert into public.group_invite (code, group_id, created_by)
  values (v_code, v_group_id, v_uid);

  return jsonb_build_object(
    'group_id', v_group_id,
    'invite_code', v_code
  );
end;
$$;

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
  if not exists (
    select 1 from public.stall s
    join public.staff_membership m on m.stall_id = s.id
    where s.group_id = p_group_id
      and m.user_id = v_uid
      and m.role = 'owner'
  ) then
    raise exception 'only a group member owner may create invites' using errcode = '42501';
  end if;

  insert into public.group_invite (code, group_id, created_by)
  values (v_code, p_group_id, v_uid);

  return v_code;
end;
$$;

create or replace function public.leave_group(p_stall_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not exists (
    select 1 from public.staff_membership m
    where m.stall_id = p_stall_id
      and m.user_id = v_uid
      and m.role = 'owner'
  ) then
    raise exception 'only an owner may leave a food court' using errcode = '42501';
  end if;

  update public.stall
  set group_id = null
  where id = p_stall_id;
end;
$$;

grant execute on function public.create_food_court(text, uuid) to authenticated;
grant execute on function public.create_group_invite(uuid)     to authenticated;
grant execute on function public.leave_group(uuid)             to authenticated;
