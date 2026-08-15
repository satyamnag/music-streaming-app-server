-- ============================================================
-- MIGRATION: Affiliate commission — yearly-only, flat ₹100
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Business rule (from the admin):
--   * Affiliate marketing applies ONLY to the YEARLY plan
--     (product_id = 'soulful_yearly'). Monthly purchases never
--     credit an affiliate.
--   * The affiliate earns a FLAT ₹100 per successful yearly plan
--     sale (not a percentage).
--
-- The function keeps its existing signature so the webhook handler
-- (server.js) does not need to change its call shape; the flat amount
-- and product check are enforced here, server-side, as the authority.
-- ============================================================

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
begin
  if p_purchaser_user_id is null or p_product_id is null or p_source_event_id is null then
    raise exception 'required fields missing';
  end if;

  -- Affiliate marketing applies to the YEARLY plan ONLY.
  if p_product_id <> 'soulful_yearly' then
    return false;
  end if;

  select affiliate_id into v_affiliate_id
  from public.coupon_attributions
  where purchaser_user_id = p_purchaser_user_id;

  if v_affiliate_id is null then
    return false; -- not a coupon purchase; let the referral program handle it
  end if;

  -- Flat ₹100 commission per successful yearly plan sale.
  insert into public.affiliate_commissions (
    affiliate_id, purchaser_user_id, product_id,
    plan_price, rate_percent, commission_amount, source_event_id
  ) values (
    v_affiliate_id, p_purchaser_user_id, p_product_id,
    p_plan_price, 0, 100.00, p_source_event_id
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
select proname, proacl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and proname = 'credit_affiliate_commission';
