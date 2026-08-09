-- Immediate court join: create stall + owner from a group invite code.

create or replace function public.join_court_as_owner(p_code text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_invite   public.group_invite;
  v_stall_id uuid;
  v_name     text := trim(coalesce(p_name, ''));
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if length(v_name) = 0 then
    raise exception 'stall name is required' using errcode = '22023';
  end if;

  select * into v_invite
  from public.group_invite
  where code = p_code and revoked_at is null;

  if not found then
    raise exception 'invalid or revoked invite code' using errcode = 'P0002';
  end if;

  insert into public.stall (name, group_id, created_by)
  values (v_name, v_invite.group_id, v_uid)
  returning id into v_stall_id;

  insert into public.staff_membership (stall_id, user_id, role)
  values (v_stall_id, v_uid, 'owner');

  return v_stall_id;
end;
$$;

grant execute on function public.join_court_as_owner(text, text) to authenticated;
