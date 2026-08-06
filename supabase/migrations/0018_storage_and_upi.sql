-- Menu image storage + stall UPI / Paytm Business VPA for QR collect.
-- Callers: admin menu upload, settings; mobile payment sheet QR.
-- User: add menu images, storage, cash + UPI QR with Paytm Business config.

alter table public.stall
  add column if not exists upi_vpa text
    check (upi_vpa is null or upi_vpa ~ '^[^@\s]+@[^@\s]+$'),
  add column if not exists upi_payee_name text;

comment on column public.stall.upi_vpa is
  'UPI VPA from Paytm Business (or any UPI ID), e.g. merchant@paytm';
comment on column public.stall.upi_payee_name is
  'Payee name shown on UPI apps when scanning the QR';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'menu-images',
  'menu-images',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Path convention: {stall_id}/{menu_item_id}.{ext}
-- Read: public bucket (anyone with URL). Write: owner/manager of that stall.

create policy menu_images_public_read
  on storage.objects for select
  to public
  using (bucket_id = 'menu-images');

create policy menu_images_member_insert
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'menu-images'
    and (storage.foldername(name))[1]::uuid in (select public.my_stall_ids())
    and exists (
      select 1 from public.staff_membership m
      where m.stall_id = (storage.foldername(name))[1]::uuid
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );

create policy menu_images_member_update
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'menu-images'
    and (storage.foldername(name))[1]::uuid in (select public.my_stall_ids())
    and exists (
      select 1 from public.staff_membership m
      where m.stall_id = (storage.foldername(name))[1]::uuid
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );

create policy menu_images_member_delete
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'menu-images'
    and (storage.foldername(name))[1]::uuid in (select public.my_stall_ids())
    and exists (
      select 1 from public.staff_membership m
      where m.stall_id = (storage.foldername(name))[1]::uuid
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );
