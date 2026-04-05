-- Fix orders FK mapping to use profiles IDs (auth user IDs) instead of users table.
-- This resolves errors like: orders_vendor_id_fkey violation during retailer place-order flow.

begin;

alter table if exists public.orders
	drop constraint if exists orders_vendor_id_fkey;

alter table if exists public.orders
	add constraint orders_vendor_id_fkey
	foreign key (vendor_id)
	references public.profiles(id)
	on update cascade
	on delete restrict;

alter table if exists public.orders
	drop constraint if exists orders_retailer_id_fkey;

alter table if exists public.orders
	add constraint orders_retailer_id_fkey
	foreign key (retailer_id)
	references public.profiles(id)
	on update cascade
	on delete restrict;

create index if not exists idx_orders_vendor_id on public.orders(vendor_id);
create index if not exists idx_orders_retailer_id on public.orders(retailer_id);

commit;
