begin;
select plan(8);

select has_table('public', 'orders', 'orders exists');
select has_table('public', 'order_item', 'order_item exists');
select has_table('public', 'stall_token_seq', 'stall_token_seq exists');

select col_is_pk('public', 'orders', 'id', 'orders.id is the primary key');
select col_is_unique('public', 'orders', array['idempotency_key'],
  'idempotency_key is unique');
select col_is_null('public', 'orders', 'bill_id',
  'bill_id is nullable until M3');

select throws_ok(
  $$ insert into public.orders (
       stall_id, recorded_by_stall_id, recorded_by_user_id,
       status, idempotency_key)
     values (
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       'cooking', gen_random_uuid()) $$,
  '23514',
  null,
  'status is constrained to held/pending/ready/completed/cancelled'
);

select col_is_fk('public', 'order_item', 'order_id',
  'order_item.order_id is a foreign key');

select * from finish();
rollback;
