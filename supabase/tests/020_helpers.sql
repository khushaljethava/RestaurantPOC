begin;
select plan(6);

select has_function('public', 'my_stall_ids', 'my_stall_ids exists');
select has_function('public', 'my_group_stall_ids', 'my_group_stall_ids exists');

-- Two owners: alice runs stall A, bob runs stall B. Both are in one food court.
-- carol runs stall C, standalone.
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

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.my_stall_ids() $$,
  array[1],
  'alice is a member of exactly her own stall'
);

select results_eq(
  $$ select count(*)::int from public.my_group_stall_ids() $$,
  array[2],
  'alice sees both stalls in her food court'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.my_group_stall_ids() $$,
  array[1],
  'a standalone stall sees only itself, with no group rows'
);

select results_eq(
  $$ select * from public.my_group_stall_ids() $$,
  array['aaaaaaaa-3333-0000-0000-000000000001'::uuid],
  'carol never sees the food court stalls'
);

select * from finish();
rollback;
