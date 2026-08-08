begin;
select plan(4);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local');

insert into public.stall (id, name, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner');

insert into public.menu_item (id, stall_id, name, price, quick_code) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Dosa', 100.00, '21');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select set_config(
  'test.oid',
  public.create_order(
    'aaaaaaaa-1111-0000-0000-000000000001',
    'aaaaaaaa-1111-0000-0000-000000000001',
    'eeeeeeee-0000-0000-0000-000000000200',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
  )::text, true);

select set_config(
  'test.bill',
  public.open_bill(
    'aaaaaaaa-1111-0000-0000-000000000001',
    array[current_setting('test.oid')::uuid],
    'ffffffff-0000-0000-0000-000000000200',
    null
  )::text, true);

select ok(
  (select token_no from public.bill where id = current_setting('test.bill')::uuid) is not null,
  'bill has token_no'
);

select lives_ok(
  $$ select public.acknowledge_order(current_setting('test.oid')::uuid) $$,
  'acknowledge_order'
);

select public.set_order_status(current_setting('test.oid')::uuid, 'ready');

select results_eq(
  $$ select pickup_status from public.bill where id = current_setting('test.bill')::uuid $$,
  array['ready'],
  'pickup ready when order ready'
);

select lives_ok(
  $$ select public.mark_bill_handed_over(current_setting('test.bill')::uuid) $$,
  'hand over'
);

select * from finish();
rollback;
