-- W4 settlement dispute + leave guard. Callers: CI / supabase test runner.
begin;
select plan(4);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.food_court (id, name, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'Court',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, group_id, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'A',
   'cccccccc-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-2222-0000-0000-000000000002', 'B',
   'cccccccc-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2222-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222', 'owner');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select set_config(
  'test.sid',
  public.mark_settlement(
    'aaaaaaaa-1111-0000-0000-000000000001',
    'aaaaaaaa-2222-0000-0000-000000000002',
    current_date,
    100,
    'cash',
    null
  )::text,
  true
);

select lives_ok(
  $$ select public.dispute_settlement(
       current_setting('test.sid')::uuid, 'wrong amount') $$,
  'either party owner can dispute'
);

select throws_ok(
  $$ select public.dispute_settlement(
       current_setting('test.sid')::uuid, '') $$,
  '22023',
  null,
  'dispute needs a note'
);

-- Remake pending (undisputed) settlement then leave should fail
select public.mark_settlement(
  'aaaaaaaa-1111-0000-0000-000000000001',
  'aaaaaaaa-2222-0000-0000-000000000002',
  current_date,
  50,
  'cash',
  null
);

select throws_ok(
  $$ select public.leave_group('aaaaaaaa-1111-0000-0000-000000000001') $$,
  '22023',
  null,
  'cannot leave with pending settlement'
);

-- Confirm then leave when pairs empty should work if no pair nets
reset role;
update public.settlement_record set confirmed_at = now(), confirmed_by =
  '22222222-2222-2222-2222-222222222222', disputed = false;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.leave_group('aaaaaaaa-1111-0000-0000-000000000001') $$,
  'leave ok when no pending and no pair nets'
);

select * from finish();
rollback;
