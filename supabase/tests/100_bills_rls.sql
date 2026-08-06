begin;
select plan(5);

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

insert into public.bill (
  id, collected_by_stall_id, collected_by_user_id,
  status, total, idempotency_key
) values (
  'bbbbbbbb-0000-0000-0000-000000000001',
  'aaaaaaaa-2222-0000-0000-000000000001',
  '22222222-2222-2222-2222-222222222222',
  'open', 100.00, 'dddddddd-0000-0000-0000-000000000001'
);

insert into public.payment (
  bill_id, method, amount, idempotency_key, created_by
) values (
  'bbbbbbbb-0000-0000-0000-000000000001',
  'cash', 100.00, 'dddddddd-0000-0000-0000-000000000099',
  '22222222-2222-2222-2222-222222222222'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.bill
     where id = 'bbbbbbbb-0000-0000-0000-000000000001' $$,
  array[1],
  'group peers can read each others bills'
);

select results_eq(
  $$ select count(*)::int from public.payment
     where bill_id = 'bbbbbbbb-0000-0000-0000-000000000001' $$,
  array[1],
  'group peers can read payments'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is_empty(
  $$ select * from public.bill $$,
  'standalone stall sees no group bills'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select throws_ok(
  $$ insert into public.bill (
       collected_by_stall_id, collected_by_user_id, total, idempotency_key)
     values (
       'aaaaaaaa-2222-0000-0000-000000000001',
       '11111111-1111-1111-1111-111111111111',
       50, gen_random_uuid()) $$,
  '42501',
  null,
  'peer cannot insert bill as another stalls collector'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select lives_ok(
  $$ insert into public.bill (
       collected_by_stall_id, collected_by_user_id, total, idempotency_key)
     values (
       'aaaaaaaa-2222-0000-0000-000000000001',
       '22222222-2222-2222-2222-222222222222',
       50, gen_random_uuid()) $$,
  'owning collector can insert bill'
);

select * from finish();
rollback;
