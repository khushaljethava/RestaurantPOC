begin;
select plan(5);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.local');

insert into public.food_court (id, name, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Test Court',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, group_id, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-2222-0000-0000-000000000001', 'Stall B',
   'aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222'),
  ('aaaaaaaa-3333-0000-0000-000000000001', 'Stall C',
   null, '33333333-3333-3333-3333-333333333333');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2222-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'owner'),
  ('aaaaaaaa-3333-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333', 'owner');

insert into public.menu_item (id, stall_id, name, price) values
  ('bbbbbbbb-2222-0000-0000-000000000001',
   'aaaaaaaa-2222-0000-0000-000000000001', 'Bob Biryani', 180.00);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.menu_item
     where stall_id = 'aaaaaaaa-2222-0000-0000-000000000001' $$,
  array[1],
  'group peers can read each other menus'
);

select lives_ok(
  $$ update public.menu_item set price = 1.00
     where id = 'bbbbbbbb-2222-0000-0000-000000000001' $$,
  'repricing a peer item runs but matches nothing'
);

reset role;
select results_eq(
  $$ select price from public.menu_item
     where id = 'bbbbbbbb-2222-0000-0000-000000000001' $$,
  array[180.00::numeric(12,2)],
  'peer price is unchanged'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
select is_empty(
  $$ select * from public.menu_item $$,
  'a standalone stall sees no group menus at all'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select lives_ok(
  $$ update public.menu_item set price = 200.00
     where id = 'bbbbbbbb-2222-0000-0000-000000000001' $$,
  'an owner edits their own menu'
);

select * from finish();
rollback;
