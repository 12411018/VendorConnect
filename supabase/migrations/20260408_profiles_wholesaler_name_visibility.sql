-- Allow marketplace users to resolve wholesaler display names from profiles.
-- Needed for products.vendor_id -> profiles.id -> profiles.name mapping in retailer UI.

alter table public.profiles enable row level security;

drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists profiles_wholesaler_select on public.profiles;
create policy profiles_wholesaler_select
on public.profiles
for select
to authenticated
using (role = 'wholesaler');
