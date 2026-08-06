-- Checks for 0021_money_fixes.sql. Callers: supabase test db. Synthetic IDs only.
begin;
select plan(5);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local');

insert into public.stall (id, name, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   '11111111-1111-1111-1111-111111111111');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner');

insert into public.menu_item (id, stall_id, name, price, is_available) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Dosa', 100.00, true),
  ('bbbbbbbb-2222-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001', 'Sold Out Idli', 40.00, false);

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Sold-out items cannot be ordered.
select throws_ok(
  $$ select public.create_order(
       'aaaaaaaa-1111-0000-0000-000000000001',
       'aaaaaaaa-1111-0000-0000-000000000001',
       'eeeeeeee-0000-0000-0000-000000000009',
       'pending',
       '[{"menu_item_id":"bbbbbbbb-2222-0000-0000-000000000001","qty":1}]'::jsonb) $$,
  '22023',
  null,
  'unavailable menu item is rejected'
);

-- Replaying an idempotency key returns the same order, not a duplicate.
select set_config(
  'test.oid',
  public.create_order(
    'aaaaaaaa-1111-0000-0000-000000000001',
    'aaaaaaaa-1111-0000-0000-000000000001',
    'eeeeeeee-0000-0000-0000-000000000001',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb
  )::text, true);

select is(
  public.create_order(
    'aaaaaaaa-1111-0000-0000-000000000001',
    'aaaaaaaa-1111-0000-0000-000000000001',
    'eeeeeeee-0000-0000-0000-000000000001',
    'pending',
    '[{"menu_item_id":"bbbbbbbb-1111-0000-0000-000000000001","qty":1}]'::jsonb),
  current_setting('test.oid')::uuid,
  'replayed idempotency key returns the original order'
);

select set_config(
  'test.bill',
  public.open_bill(
    'aaaaaaaa-1111-0000-0000-000000000001',
    array[current_setting('test.oid')::uuid],
    'ffffffff-0000-0000-0000-000000000001',
    null
  )::text, true);

select public.pay_bill(
  current_setting('test.bill')::uuid,
  jsonb_build_array(jsonb_build_object(
    'method', 'cash',
    'amount', 100,
    'idempotency_key', 'ffffffff-1111-0000-0000-000000000001'
  ))
);

-- Backdate the payment to "yesterday", then refund now.
reset role;
update public.bill
set paid_at = now() - interval '1 day'
where id = current_setting('test.bill')::uuid;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select public.refund_bill(current_setting('test.bill')::uuid, 'wrong order');

-- The refund must not rewrite yesterday's books...
select results_eq(
  $$ select coalesce(sum(revenue),0)::numeric(12,2)
     from public.sales_by_stall(
       date_trunc('day', now() - interval '1 day'),
       date_trunc('day', now())) $$,
  $$ values (100.00::numeric) $$,
  'refund today leaves yesterday revenue intact'
);

-- ...and must show up as a reversal in the window where it happened.
select results_eq(
  $$ select coalesce(sum(revenue),0)::numeric(12,2)
     from public.sales_by_stall(
       date_trunc('day', now()),
       date_trunc('day', now()) + interval '1 day') $$,
  $$ values (-100.00::numeric) $$,
  'refund books as a negative in the refund window'
);

-- Whole-period view still nets to zero.
select results_eq(
  $$ select coalesce(sum(revenue),0)::numeric(12,2)
     from public.sales_by_stall(
       now() - interval '2 days', now() + interval '1 day') $$,
  $$ values (0.00::numeric) $$,
  'paid then refunded nets to zero over a window containing both'
);

select * from finish();
rollback;
