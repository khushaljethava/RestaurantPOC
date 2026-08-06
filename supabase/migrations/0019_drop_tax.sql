-- No GST / tax in the product: drop tax_rate and gst_no; prices are plain amounts.
--
-- Gate facts:
-- 1. Callers: supabase migration runner applies files in supabase/migrations/
--    in lexical order; create_order/register_stall called from admin + mobile RPCs.
-- 2. No existing 0019_* file (Glob). Latest is 0018_storage_and_upi.sql.
-- 3. Schema change only — drops columns tax_rate, gst_no; no app data files.
-- 4. User: "Implement the plan as specified... Remaining v1 gaps" (drop tax task).

alter table public.order_item drop column if exists tax_rate;
alter table public.menu_item drop column if exists tax_rate;
alter table public.stall drop column if exists gst_no;

drop function if exists public.register_stall(text, text);

create or replace function public.register_stall(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_stall_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  insert into public.stall (name, created_by)
  values (p_name, v_uid)
  returning id into v_stall_id;

  insert into public.staff_membership (stall_id, user_id, role)
  values (v_stall_id, v_uid, 'owner');

  return v_stall_id;
end;
$$;

grant execute on function public.register_stall(text) to authenticated;

create or replace function public.create_order(
  p_stall_id uuid,
  p_recorded_by_stall_id uuid,
  p_idempotency_key uuid,
  p_status text,
  p_items jsonb,
  p_table_label text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_order_id  uuid;
  v_token     integer;
  v_item      jsonb;
  v_mi        public.menu_item%rowtype;
  v_qty       numeric(12,3);
  v_line      numeric(12,2);
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if p_status not in ('held', 'pending') then
    raise exception 'create_order status must be held or pending' using errcode = '22023';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'create_order requires at least one item' using errcode = '22023';
  end if;

  if not public.is_stall_member(p_recorded_by_stall_id) then
    raise exception 'not a member of recording stall' using errcode = '42501';
  end if;

  if p_stall_id <> p_recorded_by_stall_id
     and not public.stalls_same_group(p_stall_id, p_recorded_by_stall_id) then
    raise exception 'cross-stall create requires shared food court group'
      using errcode = '22023';
  end if;

  select id into v_order_id
  from public.orders
  where idempotency_key = p_idempotency_key;

  if v_order_id is not null then
    return v_order_id;
  end if;

  if p_status = 'pending' then
    v_token := public.next_token(p_stall_id);
  else
    v_token := null;
  end if;

  insert into public.orders (
    stall_id, recorded_by_stall_id, recorded_by_user_id,
    table_label, token_no, status, idempotency_key, notes, held_at
  ) values (
    p_stall_id, p_recorded_by_stall_id, v_uid,
    p_table_label, v_token, p_status, p_idempotency_key, p_notes,
    case when p_status = 'held' then now() else null end
  )
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_mi
    from public.menu_item mi
    where mi.id = (v_item->>'menu_item_id')::uuid
      and mi.stall_id = p_stall_id;

    if not found then
      raise exception 'menu item not found on stall' using errcode = 'P0002';
    end if;

    v_qty := (v_item->>'qty')::numeric(12,3);
    if v_qty is null or v_qty <= 0 then
      raise exception 'qty must be > 0' using errcode = '22023';
    end if;

    v_line := round(v_mi.price * v_qty, 2);

    insert into public.order_item (
      order_id, menu_item_id, name, qty, unit_price, line_total, notes
    ) values (
      v_order_id, v_mi.id, v_mi.name, v_qty, v_mi.price, v_line,
      v_item->>'notes'
    );
  end loop;

  return v_order_id;
end;
$$;

grant execute on function public.create_order(uuid, uuid, uuid, text, jsonb, text, text) to authenticated;
