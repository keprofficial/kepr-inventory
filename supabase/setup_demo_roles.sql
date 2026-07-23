-- Run after creating these three users in Supabase Authentication:
-- admin@kepr.local / admin123
-- finance@kepr.local / finance123
-- society@kepr.local / society123

insert into public.inventory_apartments(name,contact)
values('KEPR Society','Temporary society login')
on conflict do nothing;

insert into public.inventory_users(user_id,role,display_name)
select id,'inventory_admin','Main Inventory'
from auth.users where email='admin@kepr.local'
on conflict(user_id) do update set
  role=excluded.role,apartment_id=null,display_name=excluded.display_name;

insert into public.inventory_users(user_id,role,display_name)
select id,'finance_admin','Finance'
from auth.users where email='finance@kepr.local'
on conflict(user_id) do update set
  role=excluded.role,apartment_id=null,display_name=excluded.display_name;

insert into public.inventory_users(user_id,role,apartment_id,display_name)
select u.id,'apartment',a.id,'KEPR Society'
from auth.users u
cross join lateral (
  select id from public.inventory_apartments
  where name='KEPR Society' limit 1
) a
where u.email='society@kepr.local'
on conflict(user_id) do update set
  role=excluded.role,apartment_id=excluded.apartment_id,
  display_name=excluded.display_name;
