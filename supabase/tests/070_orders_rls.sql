begin;
select plan(6);

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

insert into public.orders (
  id, stall_id, recorded_by_stall_id, recorded_by_user_id,
  status, idempotency_key, token_no
) values (
  'cccccccc-2222-0000-0000-000000000001',
  'aaaaaaaa-2222-0000-0000-000000000001',
  'aaaaaaaa-2222-0000-0000-000000000001',
  '22222222-2222-2222-2222-222222222222',
  'pending', 'dddddddd-0000-0000-0000-000000000001', 1
);

insert into public.order_item (
  order_id, name, qty, unit_price, line_total
) values (
  'cccccccc-2222-0000-0000-000000000001', 'Bob Biryani', 1, 180.00,  180.00
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.orders
     where id = 'cccccccc-2222-0000-0000-000000000001' $$,
  array[1],
  'group peers can read each others orders'
);

select results_eq(
  $$ select count(*)::int from public.order_item
     where order_id = 'cccccccc-2222-0000-0000-000000000001' $$,
  array[1],
  'group peers can read order items'
);

select results_eq(
  $$ update public.orders set status = 'ready'
     where id = 'cccccccc-2222-0000-0000-000000000001'
     returning id $$,
  array[]::uuid[],
  'peer cannot update another stalls fulfilment'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is_empty(
  $$ select * from public.orders $$,
  'standalone stall sees no group orders'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select lives_ok(
  $$ update public.orders set status = 'ready'
     where id = 'cccccccc-2222-0000-0000-000000000001' $$,
  'owning stall member can update status'
);

select results_eq(
  $$ select status from public.orders
     where id = 'cccccccc-2222-0000-0000-000000000001' $$,
  array['ready'],
  'status updated to ready'
);

select * from finish();
rollback;
