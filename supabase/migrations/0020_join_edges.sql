-- Gate facts: (1) supabase migrator + admin group actions call reject_join_request;
-- live-poll will use bill realtime. (2) Glob: no 0020 yet. (3) No data files.
-- (4) User: Implement remaining v1 gaps plan.

create or replace function public.reject_join_request(p_request_id uuid)
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

  if v_req.status <> 'pending' then
    raise exception 'request is not pending' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.stall s
    join public.staff_membership m on m.stall_id = s.id
    where s.group_id = v_req.group_id
      and m.user_id = v_uid
      and m.role = 'owner'
  ) then
    raise exception 'only a group member owner may reject' using errcode = '42501';
  end if;

  update public.group_join_request set status = 'rejected' where id = p_request_id;
end;
$$;

grant execute on function public.reject_join_request(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.bill;
exception
  when duplicate_object then null;
end;
$$;
