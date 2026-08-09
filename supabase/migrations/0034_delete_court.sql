-- Court operator may delete a food court. Stalls become standalone (group_id null).
-- Invites and memberships cascade; bills/orders stay on stalls.

create or replace function public.delete_court(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_court_owner(p_group_id) then
    raise exception 'only a court owner may delete it' using errcode = '42501';
  end if;

  delete from public.food_court where id = p_group_id;
end;
$$;

grant execute on function public.delete_court(uuid) to authenticated;
