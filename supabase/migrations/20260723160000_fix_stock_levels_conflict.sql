-- PostgreSQL/Supabase requires an exact UNIQUE constraint for
-- ON CONFLICT(location_type, apartment_id, product_id).
--
-- NULLS NOT DISTINCT is important because the warehouse row has a NULL
-- apartment_id. It also guarantees one warehouse stock row per product.

ALTER TABLE public.inventory_stock_levels
  DROP CONSTRAINT IF EXISTS inventory_stock_levels_location_apartment_product_key;

ALTER TABLE public.inventory_stock_levels
  ADD CONSTRAINT inventory_stock_levels_location_apartment_product_key
  UNIQUE NULLS NOT DISTINCT (location_type, apartment_id, product_id);
