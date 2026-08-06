-- A food court is a federation of independent stall owners.
-- It owns no menus, no revenue and no staff.
create table public.food_court (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) > 0),
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now()
);

-- THE TENANT. group_id is nullable: a standalone single store is simply
-- a stall with no group, not a special case in application code.
create table public.stall (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) > 0),
  group_id    uuid references public.food_court (id) on delete set null,
  gst_no      text,
  currency    text not null default 'INR',
  timezone    text not null default 'Asia/Kolkata',
  logo_url    text,
  is_open     boolean not null default true,
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now()
);

create index stall_group_id_idx on public.stall (group_id);

create table public.staff_membership (
  id         uuid primary key default gen_random_uuid(),
  stall_id   uuid not null references public.stall (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       text not null check (role in ('owner', 'manager', 'staff')),
  created_at timestamptz not null default now(),
  unique (stall_id, user_id)
);

create index staff_membership_user_id_idx on public.staff_membership (user_id);
