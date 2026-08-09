begin;
select plan(3);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local');

insert into public.stall (id, name, created_by, packaging_charge, packaging_charge_mode) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111', 10, 'per_order');

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
    'eeeeeeee-0000-0000-0000-000000000210',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
  )::text, true);

select set_config(
  'test.bill',
  public.open_bill(
    'aaaaaaaa-1111-0000-0000-000000000001',
    array[current_setting('test.oid')::uuid],
    'ffffffff-0000-0000-0000-000000000210',
    'T1',
    'takeaway'
  )::text, true);

select is(
  public.add_packaging_charge(current_setting('test.bill')::uuid),
  10::numeric,
  'packaging per_order applied'
);

select lives_ok(
  $$ select public.relabel_bill(current_setting('test.bill')::uuid, 'T2') $$,
  'relabel bill'
);

select is(
  public.merge_bill_labels('T2', 'T3', 'aaaaaaaa-1111-0000-0000-000000000001'),
  1,
  'merge labels moves open bill'
);

select * from finish();
rollback;

-- public receipt smoke (token may be null in fixture; just assert function exists)
select has_function('public', 'get_public_receipt', array['text']);
