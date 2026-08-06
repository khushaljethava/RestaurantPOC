begin;
select plan(7);

select has_table('public', 'bill', 'bill exists');
select has_table('public', 'payment', 'payment exists');

select col_is_pk('public', 'bill', 'id', 'bill.id is PK');
select col_is_unique('public', 'bill', array['idempotency_key'],
  'bill.idempotency_key is unique');
select col_is_unique('public', 'payment', array['idempotency_key'],
  'payment.idempotency_key is unique');

select col_is_fk('public', 'orders', 'bill_id',
  'orders.bill_id references bill');

select throws_ok(
  $$ insert into public.bill (
       collected_by_stall_id, collected_by_user_id, status, total, idempotency_key)
     values (
       gen_random_uuid(), gen_random_uuid(), 'void', 0, gen_random_uuid()) $$,
  '23514',
  null,
  'bill status constrained to open/paid/refunded'
);

select * from finish();
rollback;
