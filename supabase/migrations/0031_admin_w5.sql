-- W5: receipt footer, device revoke for managers, public receipt branding.
-- Callers: admin settings/devices/receipt; tests/240_admin_w5.sql.

alter table public.stall
  add column if not exists receipt_footer text;

-- Owners/managers can see all push tokens for their stalls (revoke UI).
drop policy if exists device_push_token_own on public.device_push_token;

create policy device_push_token_own
  on public.device_push_token for all
  to authenticated
  using (
    user_id = (select auth.uid())
    and stall_id in (select public.my_stall_ids())
  )
  with check (
    user_id = (select auth.uid())
    and stall_id in (select public.my_stall_ids())
  );

create policy device_push_token_manager_read
  on public.device_push_token for select
  to authenticated
  using (
    stall_id in (
      select m.stall_id from public.staff_membership m
      where m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );

create or replace function public.revoke_device_push_token(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_stall uuid;
  v_role text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  select stall_id into v_stall from public.device_push_token where id = p_id;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  v_role := public.staff_role_for(v_stall, v_uid);
  if v_role not in ('owner', 'manager') then
    raise exception 'owner/manager only' using errcode = '42501';
  end if;
  delete from public.device_push_token where id = p_id;
  return true;
end;
$$;

create or replace function public.get_public_receipt(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_bill_id uuid;
  v_bill public.bill%rowtype;
  v_stall public.stall%rowtype;
begin
  if p_token is null or length(trim(p_token)) < 8 then
    raise exception 'invalid token' using errcode = '22023';
  end if;
  select bill_id into v_bill_id
  from public.receipt_share_token
  where token = trim(p_token)
  limit 1;
  if v_bill_id is null then
    raise exception 'receipt not found' using errcode = 'P0002';
  end if;
  select * into v_bill from public.bill where id = v_bill_id;
  select * into v_stall from public.stall where id = v_bill.collected_by_stall_id;
  return jsonb_build_object(
    'bill_id', v_bill.id,
    'total', v_bill.total,
    'discount', v_bill.discount,
    'status', v_bill.status,
    'token_no', v_bill.token_no,
    'table_label', v_bill.table_label,
    'paid_at', v_bill.paid_at,
    'stall_name', v_stall.name,
    'logo_url', v_stall.logo_url,
    'receipt_footer', v_stall.receipt_footer,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', oi.name, 'qty', oi.qty, 'line_total', oi.line_total
      ) order by oi.created_at)
      from public.order_item oi
      join public.orders o on o.id = oi.order_id
      where o.bill_id = v_bill.id and oi.voided_at is null
    ), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'method', p.method, 'amount', p.amount
      ))
      from public.payment p where p.bill_id = v_bill.id
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function public.revoke_device_push_token(uuid) to authenticated;
grant execute on function public.get_public_receipt(text) to anon, authenticated;
