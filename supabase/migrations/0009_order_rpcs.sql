-- Atomic daily token for a stall. Uses the stall timezone for "today".
create or replace function public.next_token(p_stall_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day   date;
  v_token integer;
begin
  if not public.is_stall_member(p_stall_id) then
    raise exception 'not a member of this stall' using errcode = '42501';
  end if;

  select (timezone(s.timezone, now()))::date
    into v_day
  from public.stall s
  where s.id = p_stall_id;

  if v_day is null then
    raise exception 'stall not found' using errcode = 'P0002';
  end if;

  insert into public.stall_token_seq (stall_id, day, last_token)
  values (p_stall_id, v_day, 1)
  on conflict (stall_id, day) do update
    set last_token = public.stall_token_seq.last_token + 1
  returning last_token into v_token;

  return v_token;
end;
$$;

grant execute on function public.next_token(uuid) to authenticated;

-- Line payload: [{menu_item_id, qty, notes?}]
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

  -- M2: recording stall must equal food stall. M3 relaxes this for cross-stall.
  if p_stall_id <> p_recorded_by_stall_id then
    raise exception 'cross-stall create is not allowed yet' using errcode = '22023';
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
      order_id, menu_item_id, name, qty, unit_price, tax_rate, line_total, notes
    ) values (
      v_order_id, v_mi.id, v_mi.name, v_qty, v_mi.price, v_mi.tax_rate, v_line,
      v_item->>'notes'
    );
  end loop;

  return v_order_id;
end;
$$;

grant execute on function public.create_order(uuid, uuid, uuid, text, jsonb, text, text) to authenticated;

create or replace function public.resume_held_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_token integer;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;

  if v_order.status <> 'held' then
    raise exception 'only held orders can be resumed' using errcode = '22023';
  end if;

  if not public.is_stall_member(v_order.recorded_by_stall_id) then
    raise exception 'not a member of recording stall' using errcode = '42501';
  end if;

  v_token := coalesce(v_order.token_no, public.next_token(v_order.stall_id));

  update public.orders
  set status = 'pending',
      token_no = v_token,
      held_at = null,
      updated_at = now()
  where id = p_order_id;

  return p_order_id;
end;
$$;

grant execute on function public.resume_held_order(uuid) to authenticated;

create or replace function public.set_order_status(p_order_id uuid, p_status text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_from  text;
  v_to    text := p_status;
begin
  if v_to not in ('pending', 'ready', 'completed', 'cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;

  if not public.is_stall_member(v_order.stall_id) then
    raise exception 'not a member of owning stall' using errcode = '42501';
  end if;

  v_from := v_order.status;

  if v_from = v_to then
    return p_order_id;
  end if;

  if not (
    (v_from = 'pending' and v_to in ('ready', 'cancelled'))
    or (v_from = 'ready' and v_to in ('completed', 'cancelled'))
    or (v_from = 'held' and v_to = 'cancelled')
  ) then
    raise exception 'illegal status transition: % -> %', v_from, v_to
      using errcode = '22023';
  end if;

  update public.orders
  set status = v_to, updated_at = now()
  where id = p_order_id;

  return p_order_id;
end;
$$;

grant execute on function public.set_order_status(uuid, text) to authenticated;
