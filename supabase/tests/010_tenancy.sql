begin;
select plan(9);

select has_table('public', 'food_court', 'food_court exists');
select has_table('public', 'stall', 'stall exists');
select has_table('public', 'staff_membership', 'staff_membership exists');

select col_is_pk('public', 'stall', 'id', 'stall.id is the primary key');
select col_is_null('public', 'stall', 'group_id',
  'stall.group_id is nullable so a standalone stall needs no group');
select col_has_default('public', 'stall', 'is_open', 'stall.is_open defaults');

select col_is_fk('public', 'staff_membership', 'stall_id',
  'staff_membership.stall_id is a foreign key');

-- one membership row per (user, stall)
select col_is_unique('public', 'staff_membership',
  array['stall_id', 'user_id'],
  'a user has at most one role per stall');

select throws_ok(
  $$ insert into public.staff_membership (stall_id, user_id, role)
     values (gen_random_uuid(), gen_random_uuid(), 'chef') $$,
  '23514',
  null,
  'role is constrained to owner/manager/staff'
);

select * from finish();
rollback;
