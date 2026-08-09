-- V2 gaps: packaging charge, UPI verify, bill label move/merge, hold_tag.
-- Callers: mobile POS/checkout/settlement/tables/held; tests/210_v2_gaps.sql.

alter table public.orders
  add column if not exists hold_tag text;

alter table public.bill
  add column if not exists packaging_amount numeric(12,2) not null default 0
    check (packaging_amount >= 0);

create or replace function public.add_packaging_charge(p_bill_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
  v_stall public.stall%rowtype;
  v_amount numeric(12,2) := 0;
  v_item_count int := 0;
begin
  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if v_bill.status <> 'open' then
    raise exception 'can only add packaging to open bill' using errcode = '22023';
  end if;
  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  if v_bill.order_type not in ('takeaway', 'parcel') then
    return 0;
  end if;
  if coalesce(v_bill.packaging_amount, 0) > 0 then
    return v_bill.packaging_amount; -- idempotent
  end if;

  select * into v_stall from public.stall where id = v_bill.collected_by_stall_id;
  if v_stall.packaging_charge_mode = 'none' or v_stall.packaging_charge <= 0 then
    return 0;
  end if;

  if v_stall.packaging_charge_mode = 'per_order' then
    v_amount := v_stall.packaging_charge;
  else
    select coalesce(sum(oi.qty), 0)::int into v_item_count
    from public.order_item oi
    join public.orders o on o.id = oi.order_id
    where o.bill_id = p_bill_id and oi.voided_at is null and o.status <> 'cancelled';
    v_amount := round(v_stall.packaging_charge * v_item_count, 2);
  end if;

  update public.bill
  set packaging_amount = v_amount,
      total = total + v_amount,
      updated_at = now()
  where id = p_bill_id;

  return v_amount;
end;
$$;

create or replace function public.verify_upi_payment(p_payment_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pay public.payment%rowtype;
  v_bill public.bill%rowtype;
  v_role text;
begin
  select * into v_pay from public.payment where id = p_payment_id for update;
  if not found then
    raise exception 'payment not found' using errcode = 'P0002';
  end if;
  if v_pay.method <> 'upi' then
    raise exception 'not a UPI payment' using errcode = '22023';
  end if;
  select * into v_bill from public.bill where id = v_pay.bill_id;
  v_role := public.staff_role_for(v_bill.collected_by_stall_id, auth.uid());
  if v_role not in ('owner', 'manager') then
    raise exception 'owner/manager only' using errcode = '42501';
  end if;
  update public.payment set upi_verified = true where id = p_payment_id;
  return p_payment_id;
end;
$$;

create or replace function public.relabel_bill(p_bill_id uuid, p_table_label text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.bill%rowtype;
  v_label text := nullif(trim(p_table_label), '');
begin
  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
  if v_bill.status <> 'open' then
    raise exception 'can only relabel open bill' using errcode = '22023';
  end if;
  if not public.is_stall_member(v_bill.collected_by_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  update public.bill set table_label = v_label, updated_at = now() where id = p_bill_id;
  update public.orders set table_label = v_label, updated_at = now()
  where bill_id = p_bill_id and status <> 'cancelled';
  return p_bill_id;
end;
$$;

create or replace function public.merge_bill_labels(
  p_from_label text,
  p_to_label text,
  p_collector_stall_id uuid
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_from text := trim(p_from_label);
  v_to text := trim(p_to_label);
  v_n int := 0;
begin
  if v_from = '' or v_to = '' then
    raise exception 'labels required' using errcode = '22023';
  end if;
  if not public.is_stall_member(p_collector_stall_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  update public.bill
  set table_label = v_to, updated_at = now()
  where collected_by_stall_id = p_collector_stall_id
    and status = 'open'
    and table_label = v_from;
  get diagnostics v_n = row_count;

  update public.orders
  set table_label = v_to, updated_at = now()
  where recorded_by_stall_id = p_collector_stall_id
    and status in ('pending', 'ready', 'held')
    and table_label = v_from
    and (bill_id is null or exists (
      select 1 from public.bill b where b.id = orders.bill_id and b.status = 'open'
    ));

  return v_n;
end;
$$;

-- Include packaging in pay_bill due (redefine with packaging_amount).
drop function if exists public.pay_bill(uuid, jsonb, uuid, uuid);

create or replace function public.pay_bill(
  p_bill_id uuid,
  p_payments jsonb,
  p_shift_id uuid default null,
  p_acting_staff_id uuid default null
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
  v_actor     uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_bill from public.bill where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found' using errcode = 'P0002';
  end if;
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

  v_due := v_bill.total - v_bill.discount + coalesce(v_bill.rounding_amount, 0);
  if v_sum <> v_due then
    raise exception 'payment sum % does not equal due %', v_sum, v_due
      using errcode = '22023';
  end if;

  v_actor := coalesce(p_acting_staff_id, v_uid);

  for v_pay in select * from jsonb_array_elements(p_payments)
  loop
    insert into public.payment (
      bill_id, method, amount, idempotency_key, created_by,
      shift_id, acting_staff_id, upi_ref, card_last4, card_terminal
    ) values (
      p_bill_id,
      v_pay->>'method',
      (v_pay->>'amount')::numeric(12,2),
      (v_pay->>'idempotency_key')::uuid,
      v_uid,
      coalesce(p_shift_id, v_bill.shift_id),
      v_actor,
      nullif(v_pay->>'upi_ref', ''),
      nullif(v_pay->>'card_last4', ''),
      nullif(v_pay->>'card_terminal', '')
    )
    on conflict (idempotency_key) do nothing;
  end loop;

  update public.bill
  set status = 'paid',
      paid_at = now(),
      updated_at = now(),
      shift_id = coalesce(shift_id, p_shift_id),
      acting_staff_id = coalesce(acting_staff_id, v_actor)
  where id = p_bill_id;

  return p_bill_id;
end;
$$;

grant execute on function public.add_packaging_charge(uuid) to authenticated;
grant execute on function public.verify_upi_payment(uuid) to authenticated;
grant execute on function public.relabel_bill(uuid, text) to authenticated;
grant execute on function public.merge_bill_labels(text, text, uuid) to authenticated;
grant execute on function public.pay_bill(uuid, jsonb, uuid, uuid) to authenticated;


-- Public read-only receipt by share token (anon + authenticated).
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
  return jsonb_build_object(
    'bill_id', v_bill.id,
    'total', v_bill.total,
    'discount', v_bill.discount,
    'status', v_bill.status,
    'token_no', v_bill.token_no,
    'table_label', v_bill.table_label,
    'paid_at', v_bill.paid_at,
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

grant execute on function public.get_public_receipt(text) to anon, authenticated;

-- Enrich day_summary with payment modes / discounts / refunds.
create or replace function public.day_summary(p_stall_id uuid, p_day date default current_date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from timestamptz;
  v_to timestamptz;
  v_role text;
begin
  v_role := public.staff_role_for(p_stall_id, auth.uid());
  if v_role not in ('owner', 'manager') then
    raise exception 'owner/manager only' using errcode = '42501';
  end if;
  v_from := (p_day::text || ' 00:00:00')::timestamp AT TIME ZONE 'Asia/Kolkata';
  v_to := v_from + interval '1 day';
  return jsonb_build_object(
    'sales_total', (
      select coalesce(sum(b.total - b.discount), 0)
      from public.bill b
      where b.collected_by_stall_id = p_stall_id
        and b.status = 'paid'
        and b.paid_at >= v_from and b.paid_at < v_to
    ),
    'discounts_total', (
      select coalesce(sum(b.discount), 0)
      from public.bill b
      where b.collected_by_stall_id = p_stall_id
        and b.status = 'paid'
        and b.paid_at >= v_from and b.paid_at < v_to
        and b.discount > 0
    ),
    'refunds_total', (
      select coalesce(sum(p.amount), 0)
      from public.payment p
      join public.bill b on b.id = p.bill_id
      where b.collected_by_stall_id = p_stall_id
        and p.amount < 0
        and b.paid_at >= v_from and b.paid_at < v_to
    ),
    'payment_modes', coalesce((
      select jsonb_object_agg(method, total) from (
        select p.method, sum(p.amount) as total
        from public.payment p
        join public.bill b on b.id = p.bill_id
        where b.collected_by_stall_id = p_stall_id
          and b.status = 'paid'
          and b.paid_at >= v_from and b.paid_at < v_to
          and p.amount > 0
        group by p.method
      ) s
    ), '{}'::jsonb),
    'open_bills', (
      select count(*) from public.bill
      where collected_by_stall_id = p_stall_id and status = 'open'
    ),
    'unverified_upi', (
      select count(*) from public.payment p
      join public.bill b on b.id = p.bill_id
      where b.collected_by_stall_id = p_stall_id
        and p.method = 'upi' and p.upi_verified = false
        and b.paid_at >= v_from and b.paid_at < v_to
    ),
    'unhanded_tokens', (
      select count(*) from public.bill
      where collected_by_stall_id = p_stall_id
        and status = 'paid'
        and pickup_status = 'ready'
        and paid_at >= v_from and paid_at < v_to
    ),
    'shift_variances', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'shift_id', s.id, 'staff_id', s.staff_id,
        'variance', s.variance, 'reason', s.variance_reason
      )), '[]'::jsonb)
      from public.shifts s
      where s.stall_id = p_stall_id
        and s.closed_at >= v_from and s.closed_at < v_to
        and s.variance is not null and s.variance <> 0
    )
  );
end;
$$;

grant execute on function public.day_summary(uuid, date) to authenticated;
