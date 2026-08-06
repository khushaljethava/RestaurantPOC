create table public.category (
  id         uuid primary key default gen_random_uuid(),
  stall_id   uuid not null references public.stall (id) on delete cascade,
  name       text not null check (length(trim(name)) > 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index category_stall_id_idx on public.category (stall_id);

create table public.menu_item (
  id           uuid primary key default gen_random_uuid(),
  stall_id     uuid not null references public.stall (id) on delete cascade,
  category_id  uuid references public.category (id) on delete set null,
  name         text not null check (length(trim(name)) > 0),
  description  text,
  image_url    text,
  price        numeric(12,2) not null check (price >= 0),
  tax_rate     numeric(5,2)  not null default 0 check (tax_rate >= 0),
  sku          text,
  barcode      text,
  is_available boolean not null default true,
  created_at   timestamptz not null default now()
);

create index menu_item_stall_id_idx on public.menu_item (stall_id);

alter table public.category  enable row level security;
alter table public.menu_item enable row level security;

create policy category_group_can_read
  on public.category for select
  to authenticated
  using (stall_id in (select public.my_group_stall_ids()));

create policy menu_item_group_can_read
  on public.menu_item for select
  to authenticated
  using (stall_id in (select public.my_group_stall_ids()));

create policy category_own_stall_can_write
  on public.category for all
  to authenticated
  using (
    exists (select 1 from public.staff_membership m
            where m.stall_id = category.stall_id
              and m.user_id = (select auth.uid())
              and m.role in ('owner', 'manager'))
  )
  with check (
    exists (select 1 from public.staff_membership m
            where m.stall_id = category.stall_id
              and m.user_id = (select auth.uid())
              and m.role in ('owner', 'manager'))
  );

create policy menu_item_own_stall_can_write
  on public.menu_item for all
  to authenticated
  using (
    exists (select 1 from public.staff_membership m
            where m.stall_id = menu_item.stall_id
              and m.user_id = (select auth.uid())
              and m.role in ('owner', 'manager'))
  )
  with check (
    exists (select 1 from public.staff_membership m
            where m.stall_id = menu_item.stall_id
              and m.user_id = (select auth.uid())
              and m.role in ('owner', 'manager'))
  );

grant select, insert, update, delete on public.category to authenticated;
grant select, insert, update, delete on public.menu_item to authenticated;
