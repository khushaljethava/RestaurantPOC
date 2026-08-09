-- delete_court
begin;
select plan(3);

insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'del-op@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'del-tenant@test.local');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

select set_config('test.court', public.create_court('Doomed Court')::text, true);
select set_config(
  'test.code',
  public.create_group_invite(current_setting('test.court')::uuid),
  true
);

set local request.jwt.claims =
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}';

select set_config(
  'test.stall',
  public.join_court_as_owner(
    current_setting('test.code')::text,
    'Temp Stall'::text
  )::text,
  true
);

select throws_ok(
  $$ select public.delete_court(current_setting('test.court')::uuid) $$,
  '42501',
  'only a court owner may delete it',
  'stall owner cannot delete the court'
);

set local request.jwt.claims =
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

select lives_ok(
  $$ select public.delete_court(current_setting('test.court')::uuid) $$,
  'court owner can delete the court'
);

set local request.jwt.claims =
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}';

select results_eq(
  $$ select s.group_id is null
     from public.stall s
     where s.id = current_setting('test.stall')::uuid $$,
  $$ values (true) $$,
  'tenant stall is detached after court delete'
);

select * from finish();
rollback;
