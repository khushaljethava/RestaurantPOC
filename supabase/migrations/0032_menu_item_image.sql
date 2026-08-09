-- Multi-image gallery for menu items. Cover cached on menu_item.image_url.
-- Callers: admin menu actions, mobile MenuItemSheet. Grids read image_url only.

create table public.menu_item_image (
  id            uuid primary key default gen_random_uuid(),
  menu_item_id  uuid not null references public.menu_item (id) on delete cascade,
  url           text not null,
  sort_order    int not null check (sort_order >= 0),
  created_at    timestamptz not null default now(),
  unique (menu_item_id, sort_order)
);

create index menu_item_image_item_idx on public.menu_item_image (menu_item_id);

alter table public.menu_item_image enable row level security;

create policy menu_item_image_group_can_read
  on public.menu_item_image for select
  to authenticated
  using (
    menu_item_id in (
      select i.id from public.menu_item i
      where i.stall_id in (select public.my_group_stall_ids())
    )
  );

create policy menu_item_image_own_stall_can_write
  on public.menu_item_image for all
  to authenticated
  using (
    exists (
      select 1
      from public.menu_item i
      join public.staff_membership m on m.stall_id = i.stall_id
      where i.id = menu_item_image.menu_item_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  )
  with check (
    exists (
      select 1
      from public.menu_item i
      join public.staff_membership m on m.stall_id = i.stall_id
      where i.id = menu_item_image.menu_item_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );

grant select, insert, update, delete on public.menu_item_image to authenticated;

create or replace function public.sync_menu_item_cover()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item uuid := coalesce(new.menu_item_id, old.menu_item_id);
  v_url text;
begin
  select mi.url into v_url
  from public.menu_item_image mi
  where mi.menu_item_id = v_item
  order by mi.sort_order
  limit 1;

  update public.menu_item
  set image_url = v_url
  where id = v_item;

  return coalesce(new, old);
end;
$$;

create trigger menu_item_image_sync_cover
  after insert or update or delete on public.menu_item_image
  for each row execute function public.sync_menu_item_cover();

create or replace function public.enforce_menu_item_image_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.menu_item_image where menu_item_id = new.menu_item_id) >= 8 then
    raise exception 'menu item image cap is 8';
  end if;
  return new;
end;
$$;

create trigger menu_item_image_cap
  before insert on public.menu_item_image
  for each row execute function public.enforce_menu_item_image_cap();

insert into public.menu_item_image (menu_item_id, url, sort_order)
select i.id, i.image_url, 0
from public.menu_item i
where i.image_url is not null
  and not exists (
    select 1 from public.menu_item_image g where g.menu_item_id = i.id
  );
