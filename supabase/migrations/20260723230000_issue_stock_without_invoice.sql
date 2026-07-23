-- Allow warehouse fulfillment without requiring invoice metadata or a file.

create or replace function public.inventory_issue_approved_stock(
  p_request_id bigint
) returns text
language plpgsql security definer set search_path=public as $$
declare
  v_request inventory_requests%rowtype;
  v_line record;
  v_available numeric;
  v_reference text := 'TR-'||to_char(current_date,'YYYYMMDD')
    ||'-'||upper(substr(md5(gen_random_uuid()::text),1,6));
begin
  if not inventory_is_admin() then
    raise exception 'Inventory access required';
  end if;

  select * into v_request
  from inventory_requests
  where id=p_request_id
  for update;

  if not found then raise exception 'Request not found'; end if;
  if v_request.status<>'finance_approved' then
    raise exception 'Finance approval required';
  end if;

  for v_line in
    select rl.*,p.name,p.unit_price
    from inventory_request_lines rl
    join inventory_products p on p.id=rl.product_id
    where rl.request_id=p_request_id
  loop
    select quantity into v_available
    from inventory_stock_levels
    where location_type='warehouse' and product_id=v_line.product_id
    for update;

    if coalesce(v_available,0)<v_line.quantity then
      raise exception '% has only % available',
        v_line.name,coalesce(v_available,0);
    end if;

    update inventory_stock_levels
    set quantity=quantity-v_line.quantity,updated_at=now()
    where location_type='warehouse' and product_id=v_line.product_id;

    insert into inventory_stock_levels(
      location_type,apartment_id,product_id,quantity
    )
    values(
      'apartment',v_request.apartment_id,v_line.product_id,v_line.quantity
    )
    on conflict(location_type,apartment_id,product_id)
    do update set
      quantity=inventory_stock_levels.quantity+excluded.quantity,
      updated_at=now();

    insert into inventory_stock_movements(
      reference,movement_type,product_id,apartment_id,
      quantity,unit_price,movement_date,note
    )
    values(
      v_reference,'transfer',v_line.product_id,v_request.apartment_id,
      v_line.quantity,v_line.unit_price,current_date,
      'Approved demand '||v_request.reference
    );
  end loop;

  update inventory_requests
  set status='fulfilled',fulfilled_at=now(),fulfilled_by=auth.uid()
  where id=p_request_id;

  return v_reference;
end $$;

grant execute on function public.inventory_issue_approved_stock(bigint)
  to authenticated;
