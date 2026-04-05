-- Secure stock decrement RPC used by retailer checkout.
-- This allows stock to update even when product UPDATE is blocked by RLS for retailer role.

begin;

create or replace function public.decrement_product_stock(
  p_product_id uuid,
  p_quantity integer,
  p_vendor_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_rows integer := 0;
begin
  if p_product_id is null or p_quantity is null or p_quantity <= 0 then
    return false;
  end if;

  update public.products
  set stock_qty = greatest(coalesce(stock_qty, 0) - p_quantity, 0)
  where id = p_product_id
    and (p_vendor_id is null or vendor_id = p_vendor_id);

  get diagnostics affected_rows = row_count;
  return affected_rows > 0;
end;
$$;

revoke all on function public.decrement_product_stock(uuid, integer, uuid) from public;
grant execute on function public.decrement_product_stock(uuid, integer, uuid) to authenticated;

commit;
