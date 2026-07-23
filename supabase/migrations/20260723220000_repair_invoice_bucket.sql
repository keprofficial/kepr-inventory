-- Repair/ensure the private invoice bucket and its RLS policies.

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'inventory-invoices',
  'inventory-invoices',
  false,
  10485760,
  array['application/pdf','image/jpeg','image/png','image/webp']
)
on conflict(id) do update set
  name=excluded.name,
  public=false,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "inventory admin uploads invoices" on storage.objects;
create policy "inventory admin uploads invoices"
  on storage.objects for insert to authenticated with check (
    bucket_id='inventory-invoices' and public.inventory_is_admin()
  );

drop policy if exists "workflow roles read invoices" on storage.objects;
create policy "workflow roles read invoices"
  on storage.objects for select to authenticated using (
    bucket_id='inventory-invoices' and (
      public.inventory_is_admin() or public.inventory_is_finance() or exists(
        select 1
        from public.inventory_invoices i
        join public.inventory_requests r on r.id=i.request_id
        where i.storage_path=name and r.apartment_id=(
          select apartment_id
          from public.inventory_users
          where user_id=auth.uid()
        )
      )
    )
  );

drop policy if exists "inventory admin deletes failed invoice uploads"
  on storage.objects;
create policy "inventory admin deletes failed invoice uploads"
  on storage.objects for delete to authenticated using (
    bucket_id='inventory-invoices' and public.inventory_is_admin()
  );
