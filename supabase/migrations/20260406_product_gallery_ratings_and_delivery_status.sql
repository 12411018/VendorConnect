-- Product gallery + ratings support, plus delivery lifecycle status compatibility.

-- 1) Product image gallery table (one-to-many per product)
create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  vendor_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  sort_order integer not null default 0,
  created_at timestamp with time zone not null default now()
);

create index if not exists idx_product_images_product_id
  on public.product_images(product_id);

create unique index if not exists idx_product_images_unique_url_per_product
  on public.product_images(product_id, image_url);

-- 2) Product ratings table (retailer feedback)
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

-- 3) Trigger to keep updated_at fresh for ratings rows
create or replace function public.set_updated_at_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_product_ratings_updated_at on public.product_ratings;
create trigger trg_product_ratings_updated_at
before update on public.product_ratings
for each row
execute function public.set_updated_at_timestamp();

-- 4) RLS policies (safe creation)
alter table public.product_images enable row level security;
alter table public.product_ratings enable row level security;

drop policy if exists product_images_select_all on public.product_images;
create policy product_images_select_all
on public.product_images
for select
using (true);

drop policy if exists product_images_vendor_manage on public.product_images;
create policy product_images_vendor_manage
on public.product_images
for all
using (vendor_id = auth.uid())
with check (vendor_id = auth.uid());

drop policy if exists product_ratings_select_all on public.product_ratings;
create policy product_ratings_select_all
on public.product_ratings
for select
using (true);

drop policy if exists product_ratings_retailer_upsert on public.product_ratings;
create policy product_ratings_retailer_upsert
on public.product_ratings
for all
using (retailer_id = auth.uid())
with check (retailer_id = auth.uid());

-- 5) Delivery flow statuses.
-- If your orders.status is an enum, add missing values.
do $$
begin
  begin
    alter type public.order_status add value if not exists 'processing';
  exception
    when undefined_object then null;
    when duplicate_object then null;
  end;

  begin
    alter type public.order_status add value if not exists 'delivered';
  exception
    when undefined_object then null;
    when duplicate_object then null;
  end;
end $$;

-- 6) Retailer confirmation marker.
alter table public.orders
add column if not exists retailer_confirmed_at timestamp with time zone;
