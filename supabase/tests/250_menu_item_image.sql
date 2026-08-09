begin;
select plan(9);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.food_court (id, name, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Test Court',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, group_id, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-2222-0000-0000-000000000001', 'Stall B',
   'aaaaaaaa-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2222-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'owner');

insert into public.menu_item (id, stall_id, name, price, image_url) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001',
   'Samosa', 40.00, 'https://example.test/samosa.jpg');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ insert into public.menu_item_image (id, menu_item_id, url, sort_order)
     values ('cccccccc-0000-0000-0000-000000000001',
             'bbbbbbbb-1111-0000-0000-000000000001',
             'https://example.test/samosa.jpg', 0) $$,
  'owner can insert gallery row'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array['https://example.test/samosa.jpg'::text],
  'cover stays first image url'
);

select lives_ok(
  $$ insert into public.menu_item_image (id, menu_item_id, url, sort_order)
     values ('cccccccc-0000-0000-0000-000000000002',
             'bbbbbbbb-1111-0000-0000-000000000001',
             'https://example.test/samosa-2.jpg', 1) $$,
  'owner can add second image'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array['https://example.test/samosa.jpg'::text],
  'cover remains sort_order 0 after second upload'
);

select lives_ok(
  $$ delete from public.menu_item_image
     where id = 'cccccccc-0000-0000-0000-000000000001' $$,
  'owner can delete cover image'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array['https://example.test/samosa-2.jpg'::text],
  'cover follows remaining lowest sort_order'
);

select lives_ok(
  $$ delete from public.menu_item_image
     where menu_item_id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  'owner can delete last image'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array[null::text],
  'cover null when gallery empty'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

-- Peer lacks write policy on another stall's menu item.
select throws_ok(
  $$ insert into public.menu_item_image (menu_item_id, url, sort_order)
     values ('bbbbbbbb-1111-0000-0000-000000000001',
             'https://example.test/evil.jpg', 0) $$,
  '42501',
  null,
  'peer insert blocked by RLS'
);

reset role;

select * from finish();
rollback;
