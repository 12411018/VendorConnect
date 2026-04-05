alter table public.profiles
add column if not exists wallet_balance numeric(12, 2) not null default 0;

create or replace function public.credit_wholesaler_wallet(
  p_vendor_id uuid,
  p_amount numeric
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_balance numeric(12, 2);
begin
  update public.profiles
  set wallet_balance = coalesce(wallet_balance, 0) + greatest(coalesce(p_amount, 0), 0)
  where id = p_vendor_id
  returning wallet_balance into updated_balance;

  return coalesce(updated_balance, 0);
end;
$$;

grant execute on function public.credit_wholesaler_wallet(uuid, numeric) to authenticated;