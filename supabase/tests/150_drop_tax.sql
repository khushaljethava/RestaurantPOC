-- Gate: (1) supabase test runner loads supabase/tests/*.sql. (2) No 150_* yet.
-- (3) No data I/O. (4) User: implement remaining v1 gaps plan — drop tax.
begin;
select plan(3);

select hasnt_column('public', 'menu_item', 'tax_rate', 'menu_item has no tax_rate');
select hasnt_column('public', 'order_item', 'tax_rate', 'order_item has no tax_rate');
select hasnt_column('public', 'stall', 'gst_no', 'stall has no gst_no');

select * from finish();
rollback;
