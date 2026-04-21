-- Add wholesaler shop name support and harden product rating constraints/policies.

alter table public.profiles
add column if not exists shop_name text;

-- Backfill shop_name for existing wholesalers when empty.
update public.profiles
set shop_name = name
where role = 'wholesaler'
  and coalesce(trim(shop_name), '') = ''
  and coalesce(trim(name), '') <> '';

-- Ensure ratings table exists (idempotent safety for fresh DBs).
create table if not exists public.product_ratings (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  retailer_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  review text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create unique index if not exists idx_product_ratings_unique_retailer_product
  on public.product_ratings(product_id, retailer_id);

create index if not exists idx_product_ratings_product_id
  on public.product_ratings(product_id);

alter table public.product_ratings enable row level security;

drop policy if exists product_ratings_select_all on public.product_ratings;
create policy product_ratings_select_all
on public.product_ratings
for select
to authenticated
using (true);

drop policy if exists product_ratings_retailer_upsert on public.product_ratings;
create policy product_ratings_retailer_upsert
on public.product_ratings
for all
to authenticated
using (retailer_id = auth.uid())
with check (retailer_id = auth.uid());
