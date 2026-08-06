begin;
select plan(6);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.food_court (id, name, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Test Court',
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

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- ALLOW: alice reads stalls in her group (both A and B)
select results_eq(
  $$ select count(*)::int from public.stall $$,
  array[2],
  'group peers are visible in stall'
);

-- ALLOW: alice reads her own staff
select results_eq(
  $$ select count(*)::int from public.staff_membership $$,
  array[1],
  'alice reads only her own stall membership'
);

-- DENY: alice cannot see bob's staff even though they share a court
select is_empty(
  $$ select * from public.staff_membership
     where stall_id = 'aaaaaaaa-2222-0000-0000-000000000001' $$,
  'staff is stall-private even inside a group'
);

-- DENY: alice cannot rename bob's stall
select lives_ok(
  $$ update public.stall set name = 'Hijacked'
     where id = 'aaaaaaaa-2222-0000-0000-000000000001' $$,
  'update against a peer stall runs but matches no rows'
);

reset role;
select results_eq(
  $$ select name from public.stall
     where id = 'aaaaaaaa-2222-0000-0000-000000000001' $$,
  array['Stall B'],
  'peer stall name is unchanged - RLS filtered the update'
);

-- DENY: alice cannot grant herself a role on bob's stall
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select throws_ok(
  $$ insert into public.staff_membership (stall_id, user_id, role)
     values ('aaaaaaaa-2222-0000-0000-000000000001',
             '11111111-1111-1111-1111-111111111111', 'owner') $$,
  '42501',
  null,
  'cannot add yourself to another owner stall'
);

select * from finish();
rollback;
