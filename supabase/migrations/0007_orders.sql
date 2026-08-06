-- Orders: one order belongs to exactly one stall (whose food / whose revenue).
-- Table is named "orders" — "order" is a reserved SQL keyword and breaks PostgREST.
-- bill_id is reserved for M3; unused in M2.

create table public.orders (
  id                    uuid primary key default gen_random_uuid(),
  stall_id              uuid not null references public.stall (id),
  recorded_by_stall_id  uuid not null references public.stall (id),
  recorded_by_user_id   uuid not null references auth.users (id),
  bill_id               uuid,
  table_label           text,
  token_no              integer,
  status                text not null
                        check (status in ('held', 'pending', 'ready', 'completed', 'cancelled')),
  idempotency_key       uuid not null,
  notes                 text,
  held_at               timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (idempotency_key)
);

create index orders_stall_id_idx on public.orders (stall_id);
create index orders_recorded_by_stall_id_idx on public.orders (recorded_by_stall_id);
create index orders_status_idx on public.orders (stall_id, status);

create table public.order_item (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders (id) on delete cascade,
  menu_item_id  uuid references public.menu_item (id) on delete set null,
  name          text not null check (length(trim(name)) > 0),
  qty           numeric(12,3) not null check (qty > 0),
  unit_price    numeric(12,2) not null check (unit_price >= 0),
  tax_rate      numeric(5,2)  not null default 0 check (tax_rate >= 0),
  line_total    numeric(12,2) not null check (line_total >= 0),
  notes         text,
  created_at    timestamptz not null default now()
);

create index order_item_order_id_idx on public.order_item (order_id);

-- Daily per-stall token counter.
create table public.stall_token_seq (
  stall_id   uuid not null references public.stall (id) on delete cascade,
  day        date not null,
  last_token integer not null default 0 check (last_token >= 0),
  primary key (stall_id, day)
);
