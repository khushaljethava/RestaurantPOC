-- Gate: pgTAP; Glob no 160_*; User: remaining v1 gaps.
begin;
select plan(2);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.food_court (id, name, created_by) values
  ('ffffffff-0000-0000-0000-000000000001', 'Test Court',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, group_id, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Alice Stall',
   'ffffffff-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, created_by) values
  ('aaaaaaaa-2222-0000-0000-000000000001', 'Bob Stall',
   '22222222-2222-2222-2222-222222222222');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2222-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'owner');

insert into public.group_join_request (id, stall_id, group_id, status) values
  ('dddddddd-0000-0000-0000-000000000001',
   'aaaaaaaa-2222-0000-0000-000000000001',
   'ffffffff-0000-0000-0000-000000000001', 'pending');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.reject_join_request('dddddddd-0000-0000-0000-000000000001') $$,
  'owner can reject pending join request'
);

select results_eq(
  $$ select status from public.group_join_request
     where id = 'dddddddd-0000-0000-0000-000000000001' $$,
  array['rejected'],
  'request marked rejected'
);

select * from finish();
rollback;
