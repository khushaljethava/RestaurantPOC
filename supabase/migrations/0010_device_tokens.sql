-- Device push tokens for FCM. Without Firebase project keys the app still
-- works via Realtime; this table is ready when keys are added.
create table public.device_push_token (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  stall_id   uuid not null references public.stall (id) on delete cascade,
  token      text not null check (length(trim(token)) > 0),
  platform   text not null check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now(),
  unique (user_id, stall_id, token)
);

create index device_push_token_stall_id_idx on public.device_push_token (stall_id);

alter table public.device_push_token enable row level security;

create policy device_push_token_own
  on public.device_push_token for all
  to authenticated
  using (user_id = (select auth.uid()) and stall_id in (select public.my_stall_ids()))
  with check (user_id = (select auth.uid()) and stall_id in (select public.my_stall_ids()));

grant select, insert, update, delete on public.device_push_token to authenticated;

-- Realtime: stall order screen subscribes to orders for own stall.
alter publication supabase_realtime add table public.orders;

-- ponytail: FCM dispatch is a no-op stub until Firebase server keys exist.
-- Upgrade: Edge Function on orders INSERT that reads device_push_token and
-- calls FCM HTTP v1. Clients still get sub-second updates via Realtime.
create or replace function public.notify_new_order_stub()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  return new;
end;
$$;

create trigger orders_notify_new
  after insert on public.orders
  for each row
  when (new.status = 'pending')
  execute function public.notify_new_order_stub();
