-- W4: dispute settlement + block leave while unsettled.
-- Callers: admin settlement/group; tests/230_settlement_w4.sql.

create or replace function public.dispute_settlement(p_id uuid, p_note text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.settlement_record%rowtype;
  v_role text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  select * into v_row from public.settlement_record where id = p_id for update;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if v_row.confirmed_at is not null then
    raise exception 'already confirmed' using errcode = '22023';
  end if;
  v_role := public.staff_role_for(v_row.to_stall_id, v_uid);
  if v_role is null or v_role not in ('owner', 'manager') then
    v_role := public.staff_role_for(v_row.from_stall_id, v_uid);
  end if;
  if v_role not in ('owner', 'manager') then
    raise exception 'owner/manager only' using errcode = '42501';
  end if;
  if p_note is null or length(trim(p_note)) = 0 then
    raise exception 'dispute note required' using errcode = '22023';
  end if;

  update public.settlement_record
  set disputed = true,
      dispute_note = trim(p_note),
      confirmed_by = null,
      confirmed_at = null
  where id = p_id;

  perform public.write_audit(
    v_row.to_stall_id,
    'settlement.dispute',
    'settlement_record',
    p_id,
    trim(p_note),
    jsonb_build_object('from', v_row.from_stall_id, 'to', v_row.to_stall_id)
  );

  return p_id;
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
  v_open numeric;
  v_pending int;
begin
  if not exists (
    select 1 from public.staff_membership m
    where m.stall_id = p_stall_id
      and m.user_id = v_uid
      and m.role = 'owner'
  ) then
    raise exception 'only an owner may leave a food court' using errcode = '42501';
  end if;

  -- Unconfirmed settlement marks involving this stall.
  select count(*)::int into v_pending
  from public.settlement_record r
  where (r.from_stall_id = p_stall_id or r.to_stall_id = p_stall_id)
    and r.confirmed_at is null
    and r.disputed = false;

  if coalesce(v_pending, 0) > 0 then
    raise exception 'settle pending settlements before leaving' using errcode = '22023';
  end if;

  -- Computed net still outstanding in last 14 days.
  select coalesce(sum(abs(p.a_owes_b)), 0) into v_open
  from public.settlement_pairs(
    (current_date - 14)::timestamptz,
    (current_date + 1)::timestamptz
  ) p
  where p.stall_a = p_stall_id or p.stall_b = p_stall_id;

  if coalesce(v_open, 0) > 0.009 then
    raise exception 'unsettled balances remain; settle first' using errcode = '22023';
  end if;

  update public.stall
  set group_id = null
  where id = p_stall_id;
end;
$$;

grant execute on function public.dispute_settlement(uuid, text) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
