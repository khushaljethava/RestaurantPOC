begin;
select plan(12);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.local');

insert into public.food_court (id, name, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Test Court',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, group_id, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-2222-0000-0000-000000000001', 'Stall B',
   'aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222'),
  ('aaaaaaaa-3333-0000-0000-000000000001', 'Stall C',
   null, '33333333-3333-3333-3333-333333333333');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2222-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'owner'),
  ('aaaaaaaa-3333-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333', 'owner');

insert into public.menu_item (id, stall_id, name, price) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Dosa', 80.00),
  ('bbbbbbbb-2222-0000-0000-000000000001',
   'aaaaaaaa-2222-0000-0000-000000000001', 'Biryani', 180.00),
  ('bbbbbbbb-3333-0000-0000-000000000001',
   'aaaaaaaa-3333-0000-0000-000000000001', 'Solo Soup', 50.00);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select set_config(
       'test.oa',
       public.create_order(
         'aaaaaaaa-1111-0000-0000-000000000001',
         'aaaaaaaa-1111-0000-0000-000000000001',
         'eeeeeeee-0000-0000-0000-000000000001',
         'pending',
         '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
       )::text, true) $$,
  'same-stall create_order'
);

select lives_ok(
  $$ select set_config(
       'test.ob',
       public.create_order(
         'aaaaaaaa-2222-0000-0000-000000000001',
         'aaaaaaaa-1111-0000-0000-000000000001',
         'eeeeeeee-0000-0000-0000-000000000002',
         'pending',
         '[{"menu_item_id":"bbbbbbbb-2222-0000-0000-000000000001","qty":1}]'::jsonb
       )::text, true) $$,
  'cross-stall create_order within group'
);

select results_eq(
  $$ select stall_id, recorded_by_stall_id from public.orders
     where id = current_setting('test.ob')::uuid $$,
  $$ values (
       'aaaaaaaa-2222-0000-0000-000000000001'::uuid,
       'aaaaaaaa-1111-0000-0000-000000000001'::uuid) $$,
  'cross-stall order keeps distinct stall_id and recorded_by'
);

select lives_ok(
  $$ select set_config(
       'test.bill',
       public.open_bill(
         'aaaaaaaa-1111-0000-0000-000000000001',
         array[
           current_setting('test.oa')::uuid,
           current_setting('test.ob')::uuid
         ],
         'ffffffff-0000-0000-0000-000000000001'
       )::text, true) $$,
  'open_bill groups two orders'
);

select results_eq(
  $$ select total from public.bill
     where id = current_setting('test.bill')::uuid $$,
  array[260.00::numeric(12,2)],
  'bill total is 80 + 180'
);

select lives_ok(
  $$ select public.pay_bill(
       current_setting('test.bill')::uuid,
       jsonb_build_array(
         jsonb_build_object(
           'method', 'cash',
           'amount', 100,
           'idempotency_key', 'ffffffff-0000-0000-0000-000000000011'),
         jsonb_build_object(
           'method', 'upi',
           'amount', 160,
           'idempotency_key', 'ffffffff-0000-0000-0000-000000000012')
       )
     ) $$,
  'split payment pays bill while orders still pending'
);

select results_eq(
  $$ select status from public.bill
     where id = current_setting('test.bill')::uuid $$,
  array['paid'],
  'bill status is paid'
);

select lives_ok(
  $$ select public.pay_bill(
       current_setting('test.bill')::uuid,
       '[{"method":"cash","amount":1,"idempotency_key":"ffffffff-0000-0000-0000-000000000020"}]'::jsonb) $$,
  're-pay on already-paid bill is idempotent'
);

select lives_ok(
  $$ select set_config(
       'test.oc',
       public.create_order(
         'aaaaaaaa-1111-0000-0000-000000000001',
         'aaaaaaaa-1111-0000-0000-000000000001',
         'eeeeeeee-0000-0000-0000-000000000003',
         'pending',
         '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
       )::text, true) $$,
  'create another order for mismatch test'
);

select lives_ok(
  $$ select set_config(
       'test.bill2',
       public.open_bill(
         'aaaaaaaa-1111-0000-0000-000000000001',
         array[current_setting('test.oc')::uuid],
         'ffffffff-0000-0000-0000-000000000002'
       )::text, true) $$,
  'open second bill'
);

select throws_ok(
  $$ select public.pay_bill(
       current_setting('test.bill2')::uuid,
       '[{"method":"cash","amount":1,"idempotency_key":"ffffffff-0000-0000-0000-000000000021"}]'::jsonb) $$,
  '22023',
  null,
  'payment sum mismatch rejected'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select throws_ok(
  $$ select public.create_order(
       'aaaaaaaa-1111-0000-0000-000000000001',
       'aaaaaaaa-3333-0000-0000-000000000001',
       gen_random_uuid(),
       'pending',
       '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
     ) $$,
  '22023',
  null,
  'standalone cannot cross-stall into a group'
);

select * from finish();
rollback;
