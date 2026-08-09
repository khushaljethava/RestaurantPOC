-- join_court_as_owner: court invite + stall name → stall in group + owner.
-- Gate: npx supabase test db after 0033_join_court_as_owner.sql.
-- Synthetic users only; no production data.
begin;
select plan(5);

insert into auth.users (id, email) values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'court-op@test.local'),
  ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'new-owner@test.local');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee","role":"authenticated"}';

select set_config(
  'test.court',
  public.create_court('Invite Court')::text,
  true
);

select set_config(
  'test.code',
  public.create_group_invite(current_setting('test.court')::uuid),
  true
);

set local request.jwt.claims =
  '{"sub":"ffffffff-ffff-ffff-ffff-ffffffffffff","role":"authenticated"}';

select throws_ok(
  $$ select public.join_court_as_owner(current_setting('test.code')::text, '   '::text) $$,
  '22023',
  'stall name is required',
  'blank stall name is rejected'
);

select throws_ok(
  $$ select public.join_court_as_owner('NOPE-0000'::text, 'Raju Chaat'::text) $$,
  'P0002',
  'invalid or revoked invite code',
  'bad invite code is rejected'
);

select lives_ok(
  $$ select set_config(
       'test.stall',
       public.join_court_as_owner(current_setting('test.code')::text, 'Raju Chaat'::text)::text,
       true) $$,
  'valid court code + name creates a stall'
);

select results_eq(
  $$ select s.group_id::text, m.role
     from public.stall s
     join public.staff_membership m on m.stall_id = s.id
     where s.id = current_setting('test.stall')::uuid
       and m.user_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff' $$,
  $$ values (current_setting('test.court'), 'owner') $$,
  'new stall is in the court and caller is owner'
);

select results_eq(
  $$ select s.name from public.stall s
     where s.id = current_setting('test.stall')::uuid $$,
  $$ values ('Raju Chaat') $$,
  'stall name is stored as given'
);

select * from finish();
rollback;
