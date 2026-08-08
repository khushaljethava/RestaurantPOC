begin;
select plan(10);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.stall (id, name, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'staff');

insert into public.menu_item (id, stall_id, name, price) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Dosa', 100.00);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.open_shift(
       'aaaaaaaa-1111-0000-0000-000000000001', 500, 'test-device') $$,
  'open_shift succeeds'
);

select throws_ok(
  $$ select public.open_shift(
       'aaaaaaaa-1111-0000-0000-000000000001', 0, 'test-device') $$,
  '22023',
  null,
  'second open_shift rejected'
);

select lives_ok(
  $$ select public.set_staff_pin(
       'aaaaaaaa-1111-0000-0000-000000000001', '1234') $$,
  'set_staff_pin'
);

select ok(
  public.verify_staff_pin(
    'aaaaaaaa-1111-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    '1234'),
  'verify correct pin'
);

select ok(
  not public.verify_staff_pin(
    'aaaaaaaa-1111-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    '9999'),
  'verify wrong pin fails'
);

select is(
  public.apply_rounding(10.4, 'rupee_1'),
  10::numeric,
  'round 10.4 -> 10'
);

select is(
  public.apply_rounding(10.6, 'rupee_1'),
  11::numeric,
  'round 10.6 -> 11'
);

select set_config(
  'test.oid',
  public.create_order(
    'aaaaaaaa-1111-0000-0000-000000000001',
    'aaaaaaaa-1111-0000-0000-000000000001',
    'eeeeeeee-0000-0000-0000-000000000191',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":2}]'::jsonb
  )::text, true);

select set_config(
  'test.bill',
  public.open_bill(
    'aaaaaaaa-1111-0000-0000-000000000001',
    array[current_setting('test.oid')::uuid],
    'ffffffff-0000-0000-0000-000000000191',
    null
  )::text, true);

select set_config(
  'test.item',
  (select id::text from public.order_item
   where order_id = current_setting('test.oid')::uuid limit 1),
  true);

select lives_ok(
  $$ select public.void_order_item(
       current_setting('test.item')::uuid, 'wrong entry') $$,
  'void_order_item'
);

select results_eq(
  $$ select total from public.bill where id = current_setting('test.bill')::uuid $$,
  $$ values (0.00::numeric) $$,
  'void zeroes bill total'
);

select set_config(
  'test.shift',
  (select id::text from public.shifts
   where stall_id = 'aaaaaaaa-1111-0000-0000-000000000001'
     and closed_at is null limit 1),
  true);

select throws_ok(
  $$ select public.close_shift(
       current_setting('test.shift')::uuid, 0, null) $$,
  '22023',
  null,
  'large variance needs reason'
);

select lives_ok(
  $$ select public.close_shift(
       current_setting('test.shift')::uuid, 0, 'counted short') $$,
  'close_shift with reason'
);

select * from finish();
rollback;
