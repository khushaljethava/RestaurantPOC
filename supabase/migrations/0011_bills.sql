-- Bills group 1..N orders across stalls. Payment rows live under a bill.
-- Fulfilment (order.status) and payment (bill.status) are independent.

create table public.bill (
  id                      uuid primary key default gen_random_uuid(),
  collected_by_stall_id   uuid not null references public.stall (id),
  collected_by_user_id    uuid not null references auth.users (id),
  status                  text not null default 'open'
                          check (status in ('open', 'paid', 'refunded')),
  discount                numeric(12,2) not null default 0
                          check (discount >= 0),
  total                   numeric(12,2) not null default 0
                          check (total >= 0),
  table_label             text,
  idempotency_key         uuid not null,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  unique (idempotency_key)
);

create index bill_collector_status_idx
  on public.bill (collected_by_stall_id, status);

create index bill_open_table_idx
  on public.bill (table_label)
  where status = 'open' and table_label is not null;

create table public.payment (
  id                uuid primary key default gen_random_uuid(),
  bill_id           uuid not null references public.bill (id) on delete cascade,
  method            text not null check (method in ('cash', 'upi', 'card')),
  amount            numeric(12,2) not null check (amount > 0),
  idempotency_key   uuid not null,
  created_by        uuid not null references auth.users (id),
  created_at        timestamptz not null default now(),
  unique (idempotency_key)
);

create index payment_bill_id_idx on public.payment (bill_id);

-- Wire the reserved column on orders.
alter table public.orders
  add constraint orders_bill_id_fkey
  foreign key (bill_id) references public.bill (id);

create index orders_bill_id_idx on public.orders (bill_id);
