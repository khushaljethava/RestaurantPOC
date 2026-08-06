-- Gate facts:
-- 1. Callers: `npx supabase test db` loads this after migrations.
-- 2. Glob: no tests/120_*.sql yet.
-- 3. No file I/O; synthetic auth.users emails only.
-- 4. User: "Implement the plan as specified, it is attached for your reference."
begin;
select plan(6);

insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner_a@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner_b@test.local');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

select public.register_stall('Court Starter');

select lives_ok(
  $$ select set_config(
       'test.create_fc',
       public.create_food_court(
         'Test Court',
         (select id from public.stall where name = 'Court Starter')
       )::text,
       true) $$,
  'owner can create a food court for their stall'
);

select results_eq(
  $$ select (s.group_id is not null) from public.stall s where s.name = 'Court Starter' $$,
  array[true],
  'creating a food court attaches the stall'
);

select lives_ok(
  $$ select set_config(
       'test.group_code',
       public.create_group_invite(
         ((current_setting('test.create_fc'))::jsonb->>'group_id')::uuid
       ),
       true) $$,
  'owner can mint another group invite code'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}';

select public.register_stall('Joiner Stall');

select lives_ok(
  $$ select public.request_join_group(
       current_setting('test.group_code'),
       (select id from public.stall where name = 'Joiner Stall')
     ) $$,
  'peer owner can request join with the new code'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

select lives_ok(
  $$ select public.leave_group(
       (select id from public.stall where name = 'Court Starter')
     ) $$,
  'owner can leave the food court'
);

select results_eq(
  $$ select s.group_id is null from public.stall s where s.name = 'Court Starter' $$,
  array[true],
  'leave_group clears group_id'
);

select * from finish();
rollback;
