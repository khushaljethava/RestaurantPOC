begin;
select plan(1);

select has_extension('extensions', 'pgtap', 'pgtap extension is installed');

select * from finish();
rollback;
