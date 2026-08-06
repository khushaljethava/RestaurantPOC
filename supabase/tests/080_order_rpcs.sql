begin;
select plan(9);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.stall (id, name, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner');

insert into public.menu_item (id, stall_id, name, price) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Dosa', 80.00);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select set_config(
       'test.order_id',
       public.create_order(
         'aaaaaaaa-1111-0000-0000-000000000001',
         'aaaaaaaa-1111-0000-0000-000000000001',
         'eeeeeeee-0000-0000-0000-000000000001',
         'pending',
         '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":2}]'::jsonb
       )::text,
       true) $$,
  'create_order places a pending order'
);

select results_eq(
  $$ select token_no from public.orders
     where id = current_setting('test.order_id')::uuid $$,
  array[1],
  'pending order gets token 1'
);

select results_eq(
  $$ select unit_price, line_total from public.order_item
     where order_id = current_setting('test.order_id')::uuid $$,
  $$ values (80.00::numeric(12,2), 160.00::numeric(12,2)) $$,
  'unit_price and line_total are snapshotted from menu'
);

reset role;
update public.menu_item set price = 999.00
  where id = 'bbbbbbbb-1111-0000-0000-000000000001';

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select results_eq(
  $$ select unit_price from public.order_item
     where order_id = current_setting('test.order_id')::uuid $$,
  array[80.00::numeric(12,2)],
  'menu price change does not alter historical order line'
);

select results_eq(
  $$ select public.create_order(
       'aaaaaaaa-1111-0000-0000-000000000001',
       'aaaaaaaa-1111-0000-0000-000000000001',
       'eeeeeeee-0000-0000-0000-000000000001',
       'pending',
       '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":2}]'::jsonb
     ) $$,
  $$ select current_setting('test.order_id')::uuid $$,
  'same idempotency_key returns existing order id'
);

select lives_ok(
  $$ select set_config(
       'test.held_id',
       public.create_order(
         'aaaaaaaa-1111-0000-0000-000000000001',
         'aaaaaaaa-1111-0000-0000-000000000001',
         'eeeeeeee-0000-0000-0000-000000000002',
         'held',
         '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
       )::text,
       true) $$,
  'create_order can hold an order'
);

select lives_ok(
  $$ select public.resume_held_order(current_setting('test.held_id')::uuid) $$,
  'resume_held_order promotes held to pending'
);

select results_eq(
  $$ select status, token_no is not null from public.orders
     where id = current_setting('test.held_id')::uuid $$,
  $$ values ('pending'::text, true) $$,
  'resumed order is pending with a token'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select throws_ok(
  $$ select public.set_order_status(
       current_setting('test.order_id')::uuid, 'ready') $$,
  '42501',
  null,
  'non-member cannot set_order_status'
);

select * from finish();
rollback;
