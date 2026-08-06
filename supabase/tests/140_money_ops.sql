begin;
select plan(7);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local');

insert into public.stall (id, name, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner');

insert into public.menu_item (id, stall_id, name, price) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Dosa', 100.00);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select set_config(
  'test.oid',
  public.create_order(
    'aaaaaaaa-1111-0000-0000-000000000001',
    'aaaaaaaa-1111-0000-0000-000000000001',
    'eeeeeeee-0000-0000-0000-000000000001',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
  )::text, true);

select throws_ok(
  $$ select public.set_order_status(
       current_setting('test.oid')::uuid, 'cancelled', null) $$,
  '22023',
  null,
  'cancel without reason is rejected'
);

select lives_ok(
  $$ select public.set_order_status(
       current_setting('test.oid')::uuid, 'cancelled', 'customer left') $$,
  'cancel with reason succeeds'
);

select set_config(
  'test.oid2',
  public.create_order(
    'aaaaaaaa-1111-0000-0000-000000000001',
    'aaaaaaaa-1111-0000-0000-000000000001',
    'eeeeeeee-0000-0000-0000-000000000002',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
  )::text, true);

select set_config(
  'test.bill',
  public.open_bill(
    'aaaaaaaa-1111-0000-0000-000000000001',
    array[current_setting('test.oid2')::uuid],
    'ffffffff-0000-0000-0000-000000000001',
    null
  )::text, true);

select lives_ok(
  $$ select public.set_bill_discount(
       current_setting('test.bill')::uuid, 10, 'loyalty') $$,
  'discount on open bill'
);

select results_eq(
  $$ select discount from public.bill where id = current_setting('test.bill')::uuid $$,
  $$ values (10.00::numeric) $$,
  'discount persisted'
);

select public.pay_bill(
  current_setting('test.bill')::uuid,
  jsonb_build_array(jsonb_build_object(
    'method', 'cash',
    'amount', 90,
    'idempotency_key', 'ffffffff-1111-0000-0000-000000000001'
  ))
);

select lives_ok(
  $$ select public.refund_bill(
       current_setting('test.bill')::uuid, 'wrong order') $$,
  'refund paid bill'
);

select results_eq(
  $$ select status from public.bill where id = current_setting('test.bill')::uuid $$,
  array['refunded'],
  'bill status is refunded'
);

select results_eq(
  $$ select count(*)::int from public.audit_log
     where stall_id = 'aaaaaaaa-1111-0000-0000-000000000001' $$,
  array[3],
  'cancel, discount, refund each wrote audit'
);

select * from finish();
rollback;
