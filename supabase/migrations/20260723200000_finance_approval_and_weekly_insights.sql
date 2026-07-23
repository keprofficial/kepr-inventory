-- Three-stage control: society -> inventory check -> finance -> fulfillment.

alter table public.inventory_users
  drop constraint if exists inventory_users_role_check;
alter table public.inventory_users
  add constraint inventory_users_role_check
  check (role in ('inventory_admin','finance_admin','apartment'));
alter table public.inventory_users
  drop constraint if exists inventory_users_check;
alter table public.inventory_users
  add constraint inventory_users_apartment_role_check check (
    (role in ('inventory_admin','finance_admin') and apartment_id is null) or
    (role='apartment' and apartment_id is not null)
  );

alter table public.inventory_requests
  drop constraint if exists inventory_requests_status_check;
update public.inventory_requests set status='pending_inventory'
  where status='pending';
update public.inventory_requests set status='fulfilled'
  where status='approved';
alter table public.inventory_requests
  add constraint inventory_requests_status_check check (
    status in ('pending_inventory','pending_finance','finance_approved',
      'fulfilled','rejected')
  );
alter table public.inventory_requests alter column status
  set default 'pending_inventory';

alter table public.inventory_requests
  add column if not exists inventory_note text not null default '',
  add column if not exists inventory_checked_at timestamptz,
  add column if not exists inventory_checked_by uuid references auth.users(id),
  add column if not exists finance_note text not null default '',
  add column if not exists finance_reviewed_at timestamptz,
  add column if not exists finance_reviewed_by uuid references auth.users(id),
  add column if not exists invoice_reference text not null default '',
  add column if not exists fulfilled_at timestamptz,
  add column if not exists fulfilled_by uuid references auth.users(id);

create or replace function public.inventory_is_finance()
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from inventory_users
    where user_id=auth.uid() and role='finance_admin')
$$;

drop policy if exists "requests read own apartment or admin"
  on public.inventory_requests;
create policy "requests read by workflow role"
  on public.inventory_requests for select to authenticated using (
    inventory_is_admin() or inventory_is_finance() or apartment_id=(
      select apartment_id from inventory_users where user_id=auth.uid()
    )
  );

create or replace function public.inventory_check_request(
  p_request_id bigint,p_forward boolean,p_note text default ''
) returns text
language plpgsql security definer set search_path=public as $$
declare v_request inventory_requests%rowtype; v_line record; v_available numeric;
begin
  if not inventory_is_admin() then raise exception 'Inventory access required'; end if;
  select * into v_request from inventory_requests where id=p_request_id for update;
  if v_request.status<>'pending_inventory' then raise exception 'Ticket is not awaiting inventory'; end if;
  if not p_forward then
    update inventory_requests set status='rejected',inventory_note=coalesce(p_note,''),
      inventory_checked_at=now(),inventory_checked_by=auth.uid()
      where id=p_request_id;
    return v_request.reference;
  end if;
  for v_line in select rl.*,p.name from inventory_request_lines rl
    join inventory_products p on p.id=rl.product_id
    where rl.request_id=p_request_id loop
    select quantity into v_available from inventory_stock_levels
      where location_type='warehouse' and product_id=v_line.product_id;
    if coalesce(v_available,0)<v_line.quantity then
      raise exception '% has only % available',v_line.name,coalesce(v_available,0);
    end if;
  end loop;
  update inventory_requests set status='pending_finance',
    inventory_note=coalesce(p_note,''),inventory_checked_at=now(),
    inventory_checked_by=auth.uid() where id=p_request_id;
  return v_request.reference;
end $$;

create or replace function public.inventory_finance_review(
  p_request_id bigint,p_approve boolean,p_note text default ''
) returns text
language plpgsql security definer set search_path=public as $$
declare v_request inventory_requests%rowtype;
begin
  if not inventory_is_finance() then raise exception 'Finance access required'; end if;
  select * into v_request from inventory_requests where id=p_request_id for update;
  if v_request.status<>'pending_finance' then raise exception 'Ticket is not awaiting finance'; end if;
  update inventory_requests set status=case when p_approve then 'finance_approved'
    else 'rejected' end,finance_note=coalesce(p_note,''),
    finance_reviewed_at=now(),finance_reviewed_by=auth.uid()
    where id=p_request_id;
  return v_request.reference;
end $$;

create or replace function public.inventory_fulfill_request(
  p_request_id bigint,p_invoice_reference text
) returns text
language plpgsql security definer set search_path=public as $$
declare v_request inventory_requests%rowtype; v_line record;
  v_available numeric; v_reference text := 'TR-'||to_char(current_date,'YYYYMMDD')
    ||'-'||upper(substr(md5(gen_random_uuid()::text),1,6));
begin
  if not inventory_is_admin() then raise exception 'Inventory access required'; end if;
  if length(trim(coalesce(p_invoice_reference,'')))=0 then
    raise exception 'Invoice or bill reference is required';
  end if;
  select * into v_request from inventory_requests where id=p_request_id for update;
  if v_request.status<>'finance_approved' then raise exception 'Finance approval required'; end if;
  for v_line in select rl.*,p.name,p.unit_price from inventory_request_lines rl
    join inventory_products p on p.id=rl.product_id
    where rl.request_id=p_request_id loop
    select quantity into v_available from inventory_stock_levels
      where location_type='warehouse' and product_id=v_line.product_id for update;
    if coalesce(v_available,0)<v_line.quantity then
      raise exception '% has only % available',v_line.name,coalesce(v_available,0);
    end if;
    update inventory_stock_levels set quantity=quantity-v_line.quantity,updated_at=now()
      where location_type='warehouse' and product_id=v_line.product_id;
    insert into inventory_stock_levels(location_type,apartment_id,product_id,quantity)
      values('apartment',v_request.apartment_id,v_line.product_id,v_line.quantity)
      on conflict(location_type,apartment_id,product_id)
      do update set quantity=inventory_stock_levels.quantity+excluded.quantity,
        updated_at=now();
    insert into inventory_stock_movements(reference,movement_type,product_id,
      apartment_id,quantity,unit_price,movement_date,note)
      values(v_reference,'transfer',v_line.product_id,v_request.apartment_id,
        v_line.quantity,v_line.unit_price,current_date,
        'Ticket '||v_request.reference||' · Invoice '||p_invoice_reference);
  end loop;
  update inventory_requests set status='fulfilled',
    invoice_reference=trim(p_invoice_reference),fulfilled_at=now(),
    fulfilled_by=auth.uid() where id=p_request_id;
  return v_reference;
end $$;

drop view if exists public.inventory_request_summary_view;
create view public.inventory_request_summary_view
with (security_invoker=true) as
select r.id,r.reference,r.apartment_id,a.name apartment,r.status,r.note,
  r.inventory_note,r.finance_note,r.invoice_reference,
  r.requested_at::text,r.inventory_checked_at::text,
  r.finance_reviewed_at::text,r.fulfilled_at::text,
  count(rl.id)::integer line_count,
  sum(rl.quantity)::double precision total_quantity,
  sum(rl.quantity*p.unit_price)::double precision total_value
from inventory_requests r join inventory_apartments a on a.id=r.apartment_id
join inventory_request_lines rl on rl.request_id=r.id
join inventory_products p on p.id=rl.product_id
group by r.id,a.name order by r.id desc;

create or replace view public.inventory_weekly_insights_view
with (security_invoker=true) as
select 'warehouse'::text scope,null::bigint apartment_id,
  'Stock received'::text metric,
  coalesce(sum(quantity) filter(where movement_type='receipt'),0)::double precision value
from inventory_stock_movements where movement_date>=current_date-6
union all
select 'warehouse',null,'Stock issued',
  coalesce(sum(quantity) filter(where movement_type='transfer'),0)::double precision
from inventory_stock_movements where movement_date>=current_date-6
union all
select 'apartment',u.apartment_id,'Stock consumed',
  coalesce(sum(u.quantity),0)::double precision
from inventory_usage u where usage_date>=current_date-6 group by u.apartment_id
union all
select 'apartment',r.apartment_id,'Demand raised',
  count(*)::double precision
from inventory_requests r where requested_at>=now()-interval '7 days'
group by r.apartment_id;

grant select on public.inventory_weekly_insights_view to authenticated;
grant execute on function public.inventory_is_finance(),
  public.inventory_check_request(bigint,boolean,text),
  public.inventory_finance_review(bigint,boolean,text),
  public.inventory_fulfill_request(bigint,text) to authenticated;
