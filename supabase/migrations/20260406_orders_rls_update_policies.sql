-- Ensure orders table supports retailer confirmation and wholesaler dispatch updates.

alter table public.orders enable row level security;

-- Retailers can read their own orders.
drop policy if exists orders_retailer_select on public.orders;
create policy orders_retailer_select
on public.orders
for select
using (retailer_id = auth.uid());

-- Wholesalers can read orders assigned to them.
drop policy if exists orders_vendor_select on public.orders;
create policy orders_vendor_select
on public.orders
for select
using (vendor_id = auth.uid());

-- Retailers can place orders for themselves.
drop policy if exists orders_retailer_insert on public.orders;
create policy orders_retailer_insert
on public.orders
for insert
with check (retailer_id = auth.uid());

-- Retailers can confirm completion on their own orders.
drop policy if exists orders_retailer_update on public.orders;
create policy orders_retailer_update
on public.orders
for update
using (retailer_id = auth.uid())
with check (retailer_id = auth.uid());

-- Wholesalers can update dispatch status on orders assigned to them.
drop policy if exists orders_vendor_update on public.orders;
create policy orders_vendor_update
on public.orders
for update
using (vendor_id = auth.uid())
with check (vendor_id = auth.uid());
