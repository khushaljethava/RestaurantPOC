-- W1 admin foundations pgTAP. Callers: CI / supabase test runner.
-- User: Implement the plan as specified, it is attached for your reference.
begin;
select plan(8);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.local');

insert into public.stall (id, name, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'manager'),
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333', 'staff');

select is(
  (select day_start_minutes from public.stall
   where id = 'aaaaaaaa-1111-0000-0000-000000000001'),
  0,
  'day_start_minutes defaults to 0'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select lives_ok(
  $$ select public.create_stall_invite(
       'aaaaaaaa-1111-0000-0000-000000000001', 'staff') $$,
  'manager can mint a staff invite'
);

select throws_ok(
  $$ select public.create_stall_invite(
       'aaaaaaaa-1111-0000-0000-000000000001', 'manager') $$,
  '42501',
  null,
  'manager cannot mint a manager invite'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.admin_set_staff_pin(
       'aaaaaaaa-1111-0000-0000-000000000001',
       '33333333-3333-3333-3333-333333333333',
       '4321') $$,
  'owner can reset another member PIN'
);

select ok(
  public.verify_staff_pin(
    'aaaaaaaa-1111-0000-0000-000000000001',
    '33333333-3333-3333-3333-333333333333',
    '4321'),
  'reset PIN verifies'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select throws_ok(
  $$ select public.admin_set_staff_pin(
       'aaaaaaaa-1111-0000-0000-000000000001',
       '22222222-2222-2222-2222-222222222222',
       '9999') $$,
  '42501',
  null,
  'staff cannot reset another PIN'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select lives_ok(
  $$ select public.admin_set_staff_pin(
       'aaaaaaaa-1111-0000-0000-000000000001',
       '33333333-3333-3333-3333-333333333333',
       '1111') $$,
  'manager can reset staff PIN'
);

select throws_ok(
  $$ select public.admin_set_staff_pin(
       'aaaaaaaa-1111-0000-0000-000000000001',
       '33333333-3333-3333-3333-333333333333',
       '12') $$,
  '22023',
  null,
  'PIN must be 4 digits'
);

select * from finish();
rollback;
