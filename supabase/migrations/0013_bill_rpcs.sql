-- Peer counters may mint tokens for a food stall in their group.
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
  if p_stall_id not in (select public.my_group_stall_ids()) then
    raise exception 'not allowed to mint token for this stall' using errcode = '42501';
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

-- True when both stalls share a non-null food_court group_id.
create or replace function public.stalls_same_group(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.stall a
    join public.stall b on a.group_id = b.group_id
    where a.id = p_a
      and b.id = p_b
      and a.group_id is not null
  );
$$;

comment on function public.stalls_same_group(uuid, uuid) is
  'True when both stalls share a non-null food_court group.';

grant execute on function public.stalls_same_group(uuid, uuid) to authenticated;

-- Sum of line_totals for an order.
create or replace function public.order_line_total(p_order_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(oi.line_total), 0)::numeric(12,2)
  from public.order_item oi
  where oi.order_id = p_order_id;
$$;

-- Recompute bill.total from attached orders.
create or replace function public.recompute_bill_total(p_bill_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total numeric(12,2);
begin
  select coalesce(sum(public.order_line_total(o.id)), 0)::numeric(12,2)
    into v_total
  from public.orders o
  where o.bill_id = p_bill_id
    and o.status <> 'cancelled';

  update public.bill
  set total = v_total, updated_at = now()
  where id = p_bill_id;

  return v_total;
end;
$$;

-- Relax create_order: cross-stall allowed when both stalls share a group.
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

-- Open a bill and attach unpaid orders. Idempotent on p_idempotency_key.
create or replace function public.open_bill(
  p_collected_by_stall_id uuid,
  p_order_ids uuid[],
  p_idempotency_key uuid,
  p_table_label text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_bill_id  uuid;
  v_order_id uuid;
  v_order    public.orders%rowtype;
  v_total    numeric(12,2) := 0;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if not public.is_stall_member(p_collected_by_stall_id) then
    raise exception 'not a member of collecting stall' using errcode = '42501';
  end if;

  if p_order_ids is null or cardinality(p_order_ids) = 0 then
    raise exception 'open_bill requires at least one order' using errcode = '22023';
  end if;

  select id into v_bill_id
  from public.bill
  where idempotency_key = p_idempotency_key;

  if v_bill_id is not null then
    return v_bill_id;
  end if;

  foreach v_order_id in array p_order_ids
  loop
    select * into v_order from public.orders where id = v_order_id for update;
    if not found then
      raise exception 'order not found' using errcode = 'P0002';
    end if;

    if v_order.bill_id is not null then
      raise exception 'order already on a bill' using errcode = '22023';
    end if;

    if v_order.status = 'cancelled' then
      raise exception 'cannot bill a cancelled order' using errcode = '22023';
    end if;

    if v_order.status = 'held' then
      raise exception 'cannot bill a held order' using errcode = '22023';
    end if;

    if v_order.stall_id <> p_collected_by_stall_id
       and not public.stalls_same_group(v_order.stall_id, p_collected_by_stall_id) then
      raise exception 'order stall not in collector group' using errcode = '22023';
    end if;

    v_total := v_total + public.order_line_total(v_order_id);
  end loop;

  insert into public.bill (
    collected_by_stall_id, collected_by_user_id, status,
    discount, total, table_label, idempotency_key
  ) values (
    p_collected_by_stall_id, v_uid, 'open',
    0, v_total, p_table_label, p_idempotency_key
  )
  returning id into v_bill_id;

  update public.orders
  set bill_id = v_bill_id, updated_at = now()
  where id = any (p_order_ids);

  return v_bill_id;
end;
$$;

grant execute on function public.open_bill(uuid, uuid[], uuid, text) to authenticated;

create or replace function public.attach_orders_to_bill(
  p_bill_id uuid,
  p_order_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill     public.bill%rowtype;
  v_order_id uuid;
  v_order    public.orders%rowtype;
begin
  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;

  if v_bill.status <> 'open' then
    raise exception 'can only attach to an open bill' using errcode = '22023';
  end if;

  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member of collecting stall' using errcode = '42501';
  end if;

  if p_order_ids is null or cardinality(p_order_ids) = 0 then
    raise exception 'attach requires at least one order' using errcode = '22023';
  end if;

  foreach v_order_id in array p_order_ids
  loop
    select * into v_order from public.orders where id = v_order_id for update;
    if not found then
      raise exception 'order not found' using errcode = 'P0002';
    end if;

    if v_order.bill_id is not null then
      raise exception 'order already on a bill' using errcode = '22023';
    end if;

    if v_order.status in ('cancelled', 'held') then
      raise exception 'cannot attach held or cancelled order' using errcode = '22023';
    end if;

    if v_order.stall_id <> v_bill.collected_by_stall_id
       and not public.stalls_same_group(v_order.stall_id, v_bill.collected_by_stall_id) then
      raise exception 'order stall not in collector group' using errcode = '22023';
    end if;

    update public.orders
    set bill_id = p_bill_id, updated_at = now()
    where id = v_order_id;
  end loop;

  perform public.recompute_bill_total(p_bill_id);
  return p_bill_id;
end;
$$;

grant execute on function public.attach_orders_to_bill(uuid, uuid[]) to authenticated;

-- Pay an open bill. p_payments: [{method, amount, idempotency_key}]
-- Sum of amounts must equal total - discount.
create or replace function public.pay_bill(
  p_bill_id uuid,
  p_payments jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_bill      public.bill%rowtype;
  v_pay       jsonb;
  v_sum       numeric(12,2) := 0;
  v_due       numeric(12,2);
  v_method    text;
  v_amount    numeric(12,2);
  v_pay_key   uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;

  -- Idempotent success: already paid → return.
  if v_bill.status = 'paid' then
    return p_bill_id;
  end if;

  if v_bill.status <> 'open' then
    raise exception 'bill is not open' using errcode = '22023';
  end if;

  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member of collecting stall' using errcode = '42501';
  end if;

  if p_payments is null or jsonb_typeof(p_payments) <> 'array'
     or jsonb_array_length(p_payments) = 0 then
    raise exception 'pay_bill requires at least one payment' using errcode = '22023';
  end if;

  for v_pay in select * from jsonb_array_elements(p_payments)
  loop
    v_method := v_pay->>'method';
    v_amount := (v_pay->>'amount')::numeric(12,2);
    v_pay_key := (v_pay->>'idempotency_key')::uuid;

    if v_method not in ('cash', 'upi', 'card') then
      raise exception 'invalid payment method' using errcode = '22023';
    end if;

    if v_amount is null or v_amount <= 0 then
      raise exception 'payment amount must be > 0' using errcode = '22023';
    end if;

    if v_pay_key is null then
      raise exception 'payment idempotency_key required' using errcode = '22023';
    end if;

    v_sum := v_sum + v_amount;
  end loop;

  v_due := v_bill.total - v_bill.discount;
  if v_sum <> v_due then
    raise exception 'payment sum % does not equal due %', v_sum, v_due
      using errcode = '22023';
  end if;

  for v_pay in select * from jsonb_array_elements(p_payments)
  loop
    v_method := v_pay->>'method';
    v_amount := (v_pay->>'amount')::numeric(12,2);
    v_pay_key := (v_pay->>'idempotency_key')::uuid;

    insert into public.payment (
      bill_id, method, amount, idempotency_key, created_by
    ) values (
      p_bill_id, v_method, v_amount, v_pay_key, v_uid
    )
    on conflict (idempotency_key) do nothing;
  end loop;

  update public.bill
  set status = 'paid',
      updated_at = now()
  where id = p_bill_id;

  return p_bill_id;
end;
$$;

grant execute on function public.pay_bill(uuid, jsonb, uuid) to authenticated;
