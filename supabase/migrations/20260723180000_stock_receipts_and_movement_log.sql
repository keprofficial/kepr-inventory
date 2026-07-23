-- First-class stock receipts and a unified immutable movement log.

create or replace function public.inventory_receive_stock(
  p_movement_date date, p_lines jsonb, p_note text default ''
) returns text
language plpgsql security invoker set search_path = public as $$
declare
  v_line jsonb; v_product_id bigint; v_quantity numeric;
  v_price numeric; v_reference text :=
    'RC-' || to_char(coalesce(p_movement_date,current_date),'YYYYMMDD')
    || '-' || upper(substr(md5(gen_random_uuid()::text),1,6));
begin
  if jsonb_array_length(p_lines) = 0 then
    raise exception 'Add at least one item';
  end if;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_product_id := (v_line->>'product_id')::bigint;
    v_quantity := (v_line->>'quantity')::numeric;
    if v_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
    select unit_price into v_price from inventory_products
      where id=v_product_id;
    if not found then raise exception 'Product not found'; end if;
    update inventory_stock_levels
      set quantity=quantity+v_quantity, updated_at=now()
      where location_type='warehouse' and product_id=v_product_id;
    if not found then
      insert into inventory_stock_levels(location_type,product_id,quantity)
      values('warehouse',v_product_id,v_quantity);
    end if;
    insert into inventory_stock_movements(reference,movement_type,product_id,
      quantity,unit_price,movement_date,note)
    values(v_reference,'receipt',v_product_id,v_quantity,v_price,
      coalesce(p_movement_date,current_date),coalesce(p_note,''));
  end loop;
  return v_reference;
end $$;

create or replace view public.inventory_movement_log_view
with (security_invoker = true) as
select m.reference, m.movement_type, m.movement_date::text,
       case when m.movement_type='receipt' then 'Warehouse'
            else coalesce(a.name,'Warehouse') end as destination,
       count(*)::integer as line_count,
       sum(m.quantity)::double precision as total_quantity,
       sum(m.quantity*m.unit_price)::double precision as total_value,
       max(m.id) as sort_id
from public.inventory_stock_movements m
left join public.inventory_apartments a on a.id=m.apartment_id
group by m.reference,m.movement_type,m.movement_date,a.name
order by max(m.id) desc;

grant select on public.inventory_movement_log_view to authenticated, anon;
grant execute on function public.inventory_receive_stock(date,jsonb,text)
  to authenticated, anon;
