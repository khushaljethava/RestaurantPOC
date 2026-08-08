-- Court operator tenancy. The load-bearing assertion here is the read/write
-- split: an operator can SEE a tenant stall but must never be able to change it.
--
-- Gate facts:
-- 1. Callers: `npx supabase test db` loads this after migrations.
-- 2. Glob: no tests/180_*.sql yet; nothing covers food_court_membership.
-- 3. No file I/O; synthetic auth.users emails and literal UUIDs only.
-- 4. User: "start developement"
begin;
select plan(8);

insert into auth.users (id, email) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'operator@test.local'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'tenant@test.local');

-- TENANT: an ordinary stall owner, no court role.
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"dddddddd-dddd-dddd-dddd-dddddddddddd","role":"authenticated"}';

select public.register_stall('Tenant Stall');

-- OPERATOR: owns no stall at all.
set local request.jwt.claims =
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';

select lives_ok(
  $$ select set_config('test.court', public.create_court('Central Court')::text, true) $$,
  'an operator with no stalls can create a court'
);

select results_eq(
  $$ select count(*)::int from public.food_court_membership
     where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and role = 'owner' $$,
  $$ values (1) $$,
  'creator is recorded as the court owner'
);

-- Put the tenant stall in the court, operator-side.
select lives_ok(
  $$ select set_config('test.code',
       public.create_group_invite(current_setting('test.court')::uuid), true) $$,
  'court owner can mint a group invite'
);

set local request.jwt.claims =
  '{"sub":"dddddddd-dddd-dddd-dddd-dddddddddddd","role":"authenticated"}';
select public.request_join_group(
  current_setting('test.code'),
  (select id from public.stall where name = 'Tenant Stall')
);

-- A tenant stall owner is NOT a court operator any more.
select throws_ok(
  $$ select public.create_group_invite(current_setting('test.court')::uuid) $$,
  '42501',
  'only a court owner may create invites',
  'a stall owner who does not operate the court cannot mint invites'
);

set local request.jwt.claims =
  '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';
select public.approve_join_request(
  (select id from public.group_join_request
   where group_id = current_setting('test.court')::uuid)
);

select results_eq(
  $$ select count(*)::int from public.my_court_stall_ids() $$,
  $$ values (1) $$,
  'operator sees the tenant stall once it has joined'
);

-- THE READ/WRITE SPLIT. Visibility must not imply control.
select is_empty(
  $$ update public.stall set name = 'Hijacked'
     where id in (select public.my_court_stall_ids()) returning id $$,
  'operator cannot update a tenant stall'
);

select is_empty(
  $$ select id from public.staff_membership
     where stall_id in (select public.my_court_stall_ids()) $$,
  'operator cannot read a tenant staff roster'
);

-- Eviction.
select lives_ok(
  $$ select public.remove_stall_from_court(
       current_setting('test.court')::uuid,
       (select id from public.stall where group_id = current_setting('test.court')::uuid)) $$,
  'court owner can remove a stall from the court'
);

select * from finish();
rollback;
