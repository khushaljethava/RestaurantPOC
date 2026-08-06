begin;
select plan(7);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.local');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.register_stall('Alice Biryani') $$,
  'register_stall succeeds for an authenticated user'
);

select results_eq(
  $$ select count(*)::int from public.staff_membership
     where user_id = '11111111-1111-1111-1111-111111111111'
       and role = 'owner' $$,
  array[1],
  'registering makes the caller owner of the new stall'
);

select lives_ok(
  $$ select set_config(
       'test.invite_code',
       public.create_stall_invite(
         (select id from public.stall where name = 'Alice Biryani'), 'staff'),
       true) $$,
  'owner can mint a staff invite code'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select lives_ok(
  $$ select public.redeem_stall_invite(current_setting('test.invite_code')) $$,
  'a second user redeems the invite and joins the stall'
);

select results_eq(
  $$ select role from public.staff_membership
     where user_id = '44444444-4444-4444-4444-444444444444' $$,
  array['staff'],
  'redeemer gets the role encoded in the invite, not owner'
);

select throws_ok(
  $$ select public.redeem_stall_invite('NOPE-0000') $$,
  'P0002',
  null,
  'an unknown invite code is rejected'
);

reset role;
update public.stall_invite set revoked_at = now();
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select throws_ok(
  $$ select public.redeem_stall_invite(current_setting('test.invite_code')) $$,
  'P0002',
  null,
  'a revoked invite code is rejected'
);

select * from finish();
rollback;
