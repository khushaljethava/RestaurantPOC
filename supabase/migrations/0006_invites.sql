create table public.stall_invite (
  code       text primary key,
  stall_id   uuid not null references public.stall (id) on delete cascade,
  role       text not null check (role in ('manager', 'staff')),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table public.group_invite (
  code       text primary key,
  group_id   uuid not null references public.food_court (id) on delete cascade,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table public.group_join_request (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.food_court (id) on delete cascade,
  stall_id   uuid not null references public.stall (id) on delete cascade,
  status     text not null default 'pending'
             check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  unique (group_id, stall_id)
);

alter table public.stall_invite       enable row level security;
alter table public.group_invite       enable row level security;
alter table public.group_join_request enable row level security;

create policy stall_invite_own_stall
  on public.stall_invite for all
  to authenticated
  using (stall_id in (select public.my_stall_ids()))
  with check (stall_id in (select public.my_stall_ids()));

create policy group_invite_member
  on public.group_invite for all
  to authenticated
  using (
    group_id in (
      select s.group_id from public.stall s
      where s.id in (select public.my_stall_ids()) and s.group_id is not null
    )
  )
  with check (
    group_id in (
      select s.group_id from public.stall s
      where s.id in (select public.my_stall_ids()) and s.group_id is not null
    )
  );

create policy join_request_visible
  on public.group_join_request for select
  to authenticated
  using (
    stall_id in (select public.my_stall_ids())
    or group_id in (
      select s.group_id from public.stall s
      where s.id in (select public.my_stall_ids()) and s.group_id is not null
    )
  );

create or replace function public.gen_invite_code()
returns text
language sql
volatile
as $$
  select string_agg(
           substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                  (get_byte(extensions.gen_random_bytes(1), 0) % 32) + 1, 1), '')
         || '-' ||
         lpad((get_byte(extensions.gen_random_bytes(2), 0) * 256
             + get_byte(extensions.gen_random_bytes(2), 1))::text, 4, '0')
  from generate_series(1, 4);
$$;

create or replace function public.register_stall(p_name text, p_gst_no text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_stall_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  insert into public.stall (name, gst_no, created_by)
  values (p_name, p_gst_no, v_uid)
  returning id into v_stall_id;

  insert into public.staff_membership (stall_id, user_id, role)
  values (v_stall_id, v_uid, 'owner');

  return v_stall_id;
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
  v_code text := public.gen_invite_code();
begin
  if not exists (
    select 1 from public.staff_membership m
    where m.stall_id = p_stall_id
      and m.user_id = v_uid
      and m.role = 'owner'
  ) then
    raise exception 'only an owner may create invites' using errcode = '42501';
  end if;

  insert into public.stall_invite (code, stall_id, role, created_by)
  values (v_code, p_stall_id, p_role, v_uid);

  return v_code;
end;
$$;

create or replace function public.redeem_stall_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_invite public.stall_invite;
begin
  select * into v_invite
  from public.stall_invite
  where code = p_code and revoked_at is null;

  if not found then
    raise exception 'invalid or revoked invite code' using errcode = 'P0002';
  end if;

  insert into public.staff_membership (stall_id, user_id, role)
  values (v_invite.stall_id, v_uid, v_invite.role)
  on conflict (stall_id, user_id) do nothing;

  return v_invite.stall_id;
end;
$$;

create or replace function public.request_join_group(p_code text, p_stall_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_group   public.group_invite;
  v_request uuid;
begin
  if not exists (
    select 1 from public.staff_membership m
    where m.stall_id = p_stall_id and m.user_id = v_uid and m.role = 'owner'
  ) then
    raise exception 'only an owner may join a group' using errcode = '42501';
  end if;

  select * into v_group from public.group_invite
  where code = p_code and revoked_at is null;

  if not found then
    raise exception 'invalid or revoked group code' using errcode = 'P0002';
  end if;

  insert into public.group_join_request (group_id, stall_id)
  values (v_group.group_id, p_stall_id)
  on conflict (group_id, stall_id) do update set status = 'pending'
  returning id into v_request;

  return v_request;
end;
$$;

create or replace function public.approve_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.group_join_request;
begin
  select * into v_req from public.group_join_request where id = p_request_id;
  if not found then
    raise exception 'no such request' using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from public.stall s
    join public.staff_membership m on m.stall_id = s.id
    where s.group_id = v_req.group_id
      and m.user_id = v_uid
      and m.role = 'owner'
  ) then
    raise exception 'only a group member owner may approve' using errcode = '42501';
  end if;

  update public.stall set group_id = v_req.group_id where id = v_req.stall_id;
  update public.group_join_request set status = 'approved' where id = p_request_id;
end;
$$;

grant execute on function public.register_stall(text, text)      to authenticated;
grant execute on function public.create_stall_invite(uuid, text)  to authenticated;
grant execute on function public.redeem_stall_invite(text)        to authenticated;
grant execute on function public.request_join_group(text, uuid)   to authenticated;
grant execute on function public.approve_join_request(uuid)       to authenticated;

grant select, insert, update, delete on public.stall_invite to authenticated;
grant select, insert, update, delete on public.group_invite to authenticated;
grant select, insert, update on public.group_join_request to authenticated;
