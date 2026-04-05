alter table public.orders
add column if not exists payment_lat double precision,
add column if not exists payment_lng double precision,
add column if not exists marketplace_lat double precision,
add column if not exists marketplace_lng double precision;