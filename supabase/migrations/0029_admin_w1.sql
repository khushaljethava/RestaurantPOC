-- W1 admin foundations: business-day start, admin PIN reset, manager staff invites.
-- Callers: admin settings/staff; tests/220_admin_w1.sql.
-- User: Implement the plan as specified, it is attached for your reference.

alter table public.stall
  add column if not exists day_start_minutes int not null default 0
    check (day_start_minutes >= 0 and day_start_minutes < 1440);

create or replace function public.admin_set_staff_pin(
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
  v_uid uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_pin is null or p_pin !~ '^\d{4}$' then
    raise exception 'PIN must be 4 digits' using errcode = '22023';
  end if;

  select m.role into v_role
  from public.staff_membership m
  where m.stall_id = p_stall_id and m.user_id = v_uid;

  if v_role is null or v_role not in ('owner', 'manager') then
    raise exception 'only owner or manager may reset PIN' using errcode = '42501';
  end if;

  update public.staff_membership
  set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf'))
  where stall_id = p_stall_id and user_id = p_user_id;

  if not found then
    raise exception 'membership not found' using errcode = 'P0002';
  end if;

  perform public.write_audit(
    p_stall_id,
    'staff.pin_reset',
    'staff_membership',
    p_user_id,
    null,
    jsonb_build_object('target_user_id', p_user_id)
  );

  return true;
end;
$$;

create or replace function public.create_stall_invite(p_stall_id uuid, p_role text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_role text;
  v_code text := public.gen_invite_code();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if p_role is null or p_role not in ('manager', 'staff') then
    raise exception 'invalid invite role' using errcode = '22023';
  end if;

  select m.role into v_role
  from public.staff_membership m
  where m.stall_id = p_stall_id and m.user_id = v_uid;

  if v_role is null then
    raise exception 'not a member' using errcode = '42501';
  end if;

  if v_role = 'owner' then
    null; -- may invite manager or staff
  elsif v_role = 'manager' and p_role = 'staff' then
    null; -- managers may invite staff only
  else
    raise exception 'not allowed to create this invite' using errcode = '42501';
  end if;

  insert into public.stall_invite (code, stall_id, role, created_by)
  values (v_code, p_stall_id, p_role, v_uid);

  return v_code;
end;
$$;

grant execute on function public.admin_set_staff_pin(uuid, uuid, text) to authenticated;
grant execute on function public.create_stall_invite(uuid, text) to authenticated;
