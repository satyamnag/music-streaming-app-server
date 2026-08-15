-- ============================================================
-- MIGRATION: Per-affiliate configurable commission amount
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Business rule (from the admin):
--   * Affiliate marketing applies ONLY to the YEARLY plan
--     (product_id = 'soulful_yearly'). Monthly purchases never
--     credit an affiliate.
--   * The commission amount per yearly sale is DECIDED BY THE ADMIN
--     per affiliate (stored on the affiliate row), not fixed.
--
-- This supersedes the hard-coded ₹100 flat amount from migration 007.
-- ============================================================

-- 1) Per-affiliate commission amount (INR) — set by the admin.
alter table public.affiliates
  add column if not exists commission_amount numeric not null default 0
  check (commission_amount >= 0);

-- 2) Update the credit function to use the affiliate's configured amount.
create or replace function public.credit_affiliate_commission(
  p_purchaser_user_id text,
  p_product_id text,
  p_plan_price numeric,
  p_rate_percent numeric,
  p_source_event_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_affiliate_id uuid;
  v_amount numeric;
begin
  if p_purchaser_user_id is null or p_product_id is null or p_source_event_id is null then
    raise exception 'required fields missing';
  end if;

  -- Affiliate marketing applies to the YEARLY plan ONLY.
  if p_product_id <> 'soulful_yearly' then
    return false;
  end if;

  select ca.affiliate_id, a.commission_amount
    into v_affiliate_id, v_amount
  from public.coupon_attributions ca
  join public.affiliates a on a.id = ca.affiliate_id
  where ca.purchaser_user_id = p_purchaser_user_id;

  if v_affiliate_id is null then
    return false; -- not a coupon purchase; let the referral program handle it
  end if;

  -- Amount is the admin-configured flat commission for this affiliate.
  insert into public.affiliate_commissions (
    affiliate_id, purchaser_user_id, product_id,
    plan_price, rate_percent, commission_amount, source_event_id
  ) values (
    v_affiliate_id, p_purchaser_user_id, p_product_id,
    p_plan_price, 0, v_amount, p_source_event_id
  )
  on conflict (source_event_id) do nothing;

  return true;
end;
$$;

-- Executable only by the service role (webhook handler). NOT granted to
-- anon/authenticated so clients can never self-credit commissions.
-- REVOKE FROM PUBLIC is required: Postgres grants EXECUTE to PUBLIC by
-- default, which would let the anon key (extractable from the app) credit
-- itself. Both lines are mandatory.
revoke execute on function public.credit_affiliate_commission(text, text, numeric, numeric, text) from public;
grant execute on function public.credit_affiliate_commission(text, text, numeric, numeric, text)
  to service_role;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name, data_type from information_schema.columns
where table_schema='public' and table_name='affiliates' and column_name='commission_amount';

select proname, proacl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and proname = 'credit_affiliate_commission';
