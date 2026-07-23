-- TEMPORARY NO-LOGIN ACCESS
-- Run after 20260723150000_inventory_schema.sql.
-- Remove these anon policies when staff authentication is re-enabled.

drop policy if exists "inventory anon products" on public.inventory_products;
create policy "inventory anon products" on public.inventory_products
  for all to anon using (true) with check (true);

drop policy if exists "inventory anon apartments" on public.inventory_apartments;
create policy "inventory anon apartments" on public.inventory_apartments
  for all to anon using (true) with check (true);

drop policy if exists "inventory anon stock" on public.inventory_stock_levels;
create policy "inventory anon stock" on public.inventory_stock_levels
  for all to anon using (true) with check (true);

drop policy if exists "inventory anon movements" on public.inventory_stock_movements;
create policy "inventory anon movements" on public.inventory_stock_movements
  for all to anon using (true) with check (true);

grant select, insert, update, delete on public.inventory_products,
  public.inventory_apartments, public.inventory_stock_levels,
  public.inventory_stock_movements to anon;
grant select on public.inventory_products_view, public.inventory_apartments_view,
  public.inventory_apartment_stock_view, public.inventory_transfers_view to anon;
grant usage, select on all sequences in schema public to anon;
grant execute on function public.inventory_save_product(
  bigint,text,text,numeric,numeric,numeric,text) to anon;
grant execute on function public.inventory_transfer_stock(bigint,date,jsonb)
  to anon;
