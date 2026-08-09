begin;
select plan(3);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.stall (id, name, created_by, receipt_footer) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111', 'Thank you');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'staff');

insert into public.device_push_token (id, user_id, stall_id, token, platform) values
  ('dddddddd-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222',
   'aaaaaaaa-1111-0000-0000-000000000001',
   'tok-bob', 'android');

select is(
  (select receipt_footer from public.stall
   where id = 'aaaaaaaa-1111-0000-0000-000000000001'),
  'Thank you',
  'receipt_footer column works'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.revoke_device_push_token(
       'dddddddd-0000-0000-0000-000000000001') $$,
  'owner can revoke staff device token'
);

select throws_ok(
  $$ select public.revoke_device_push_token(
       'dddddddd-0000-0000-0000-000000000099') $$,
  'P0002',
  null,
  'missing token not found'
);

select * from finish();
rollback;
