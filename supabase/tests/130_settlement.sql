-- Callers: supabase test db. No prior 130_*. Synthetic IDs only.
-- User: Implement the plan as specified.
begin;
select plan(6);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.food_court (id, name, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Settle Court',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, group_id, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-2222-0000-0000-000000000001', 'Stall B',
   'aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2222-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'owner');

insert into public.menu_item (id, stall_id, name, price) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Dosa', 100.00),
  ('bbbbbbbb-2222-0000-0000-000000000001',
   'aaaaaaaa-2222-0000-0000-000000000001', 'Coffee', 50.00);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select set_config(
  'test.ob',
  public.create_order(
    'aaaaaaaa-2222-0000-0000-000000000001',
    'aaaaaaaa-1111-0000-0000-000000000001',
    'eeeeeeee-0000-0000-0000-000000000001',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-2222-0000-0000-000000000001","qty":1}]'::jsonb
  )::text, true);

select set_config(
  'test.bill',
  public.open_bill(
    'aaaaaaaa-1111-0000-0000-000000000001',
    array[current_setting('test.ob')::uuid],
    'ffffffff-0000-0000-0000-000000000001',
    null
  )::text, true);

select public.pay_bill(
  current_setting('test.bill')::uuid,
  jsonb_build_array(jsonb_build_object(
    'method', 'cash',
    'amount', 50,
    'idempotency_key', 'ffffffff-1111-0000-0000-000000000001'
  ))
);

select results_eq(
  $$ select stall_a, stall_b, a_owes_b
     from public.settlement_pairs(
       now() - interval '1 day', now() + interval '1 day') $$,
  $$ values (
       'aaaaaaaa-1111-0000-0000-000000000001'::uuid,
       'aaaaaaaa-2222-0000-0000-000000000001'::uuid,
       50.00::numeric) $$,
  'A owes B the amount A collected for B'
);

select results_eq(
  $$ select coalesce(sum(revenue),0)::numeric(12,2) from public.sales_by_stall(
       now() - interval '1 day', now() + interval '1 day') $$,
  $$ values (50.00::numeric) $$,
  'sales_by_stall revenue equals cross-stall order total'
);

select results_eq(
  $$ select coalesce(sum(amount),0)::numeric(12,2) from public.sales_by_collector(
       now() - interval '1 day', now() + interval '1 day') $$,
  $$ values (50.00::numeric) $$,
  'collector total matches revenue (conservation)'
);

reset role;
update public.bill
set status = 'refunded', refunded_at = now(), updated_at = now()
where id = current_setting('test.bill')::uuid;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is_empty(
  $$ select * from public.settlement_pairs(
       now() - interval '1 day', now() + interval '1 day') $$,
  'refunded bill nets settlement to zero (no non-zero pairs)'
);

select results_eq(
  $$ select coalesce(sum(revenue),0)::numeric(12,2) from public.sales_by_stall(
       now() - interval '1 day', now() + interval '1 day') $$,
  $$ values (0.00::numeric) $$,
  'refund zeros sales_by_stall revenue'
);

select results_eq(
  $$ select coalesce(sum(amount),0)::numeric(12,2)
     from public.sales_by_payment_mode(
       now() - interval '1 day', now() + interval '1 day') $$,
  $$ values (0.00::numeric) $$,
  'refund zeros payment mode totals'
);

select * from finish();
rollback;
