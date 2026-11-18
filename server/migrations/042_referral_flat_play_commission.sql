-- ============================================================
-- MIGRATION 042: flat Rs.51 for Play referrals (was 25% of price)
-- Run in the Supabase SQL Editor.
--
-- WHY
--   The web rail (Razorpay) pays a FLAT amount from
--   referral_program_config.commission_amount (51), once per friend.
--   The Play rail credits through credit_referral_commission, which computed
--   `round(plan_price * rate_percent / 100)` from commission_rates
--   (soulful_yearly = 25), and did so on EVERY purchase event, including
--   renewals, with no "referrer must be active" check.
--
--   Result: the same referral paid differently depending on where the friend
--   subscribed, and a Play friend could pay out repeatedly.
--
-- WHAT THIS CHANGES
--   1. credit_referral_commission now reads the FLAT amount from
--      referral_program_config.commission_amount (same source as the web rail),
--      ignoring the rate the caller passes.
--   2. It credits AT MOST ONCE per referred user, for Play products
--      ('soulful_yearly' / 'soulful_monthly'), mirroring the web rail's guard.
--   3. It refuses to credit when the REFERRER is not an active subscriber at
--      that moment - the same rule the web rail applies.
--
-- WHAT IT DOES NOT CHANGE
--   * Nothing in the Android app. The app is not involved in commission maths.
--   * Nothing in server.js. The webhook keeps calling the same RPC with the
--     same five arguments; p_rate_percent is simply no longer used here.
--   * Partner/coupon commissions (credit_affiliate_commission) keep their
--     percentage model. Only the USER REFERRAL rail becomes flat.
--   * The web rail (credit_razorpay_referral_commission) is untouched.
--
-- SAFETY
--   * No data is deleted. The only new object is one partial unique index.
--   * The index is only created after proving no duplicate Play rows exist;
--     if duplicates are found the migration stops with a clear message instead
--     of failing halfway.
--   * Re-runnable: create-or-replace + create index if not exists.
-- ============================================================

-- ------------------------------------------------------------------
-- 0) Refuse to proceed if existing data would violate the new rule.
--    (Expected zero duplicates: no Play commission has ever been written.)
-- ------------------------------------------------------------------
do $$
declare
  v_dupes integer;
begin
  select count(*) into v_dupes
  from (
    select c.referred_user_id
    from public.commissions c
    where c.product_id in ('soulful_yearly', 'soulful_monthly')
    group by c.referred_user_id
    having count(*) > 1
  ) d;

  if v_dupes > 0 then
    raise exception
      'Stop: % referred user(s) already hold multiple Play commission rows. Resolve them before applying 042.',
      v_dupes;
  end if;

  raise notice 'pre-check ok - no duplicate Play commission rows';
end $$;

-- ------------------------------------------------------------------
-- 1) One Play credit per referred user, ever. Mirrors the web rail's
--    commissions_razorpay_one_per_referred_idx.
-- ------------------------------------------------------------------
create unique index if not exists commissions_play_one_per_referred_idx
  on public.commissions (referred_user_id)
  where product_id in ('soulful_yearly', 'soulful_monthly');

-- ------------------------------------------------------------------
-- 2) The function: flat amount, once, active referrer.
--    Same signature as before, so server.js needs no change.
-- ------------------------------------------------------------------
create or replace function public.credit_referral_commission(
  p_referred_user_id text,
  p_product_id text,
  p_plan_price numeric,
  p_rate_percent numeric,      -- kept for signature compatibility; NOT used
  p_source_event_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer text;
  v_amount numeric;
  v_active boolean;
begin
  if p_referred_user_id is null or p_product_id is null or p_source_event_id is null then
    raise exception 'required fields missing';
  end if;

  -- Only credit if this user was actually referred.
  select referrer_user_id into v_referrer
  from public.referral_attributions
  where referred_user_id = p_referred_user_id;

  if v_referrer is null then
    return false;
  end if;

  -- FIRST PAYMENT ONLY, for the Play products. The partial unique index above
  -- is the authority; this check avoids pointless work and gives an honest
  -- false instead of a silent conflict.
  if exists (
    select 1 from public.commissions c
    where c.referred_user_id = p_referred_user_id
      and c.product_id in ('soulful_yearly', 'soulful_monthly')
  ) then
    return false;
  end if;

  -- The referrer must be a paying subscriber RIGHT NOW, as on the web rail.
  select se.active into v_active
  from public.subscription_entitlement(v_referrer) se
  limit 1;

  if not coalesce(v_active, false) then
    return false;
  end if;

  -- FLAT amount, single source of truth shared with the web rail.
  select cfg.commission_amount into v_amount
  from public.referral_program_config cfg
  where cfg.id = true;

  if v_amount is null or v_amount <= 0 then
    return false;
  end if;

  insert into public.commissions (
    referrer_user_id, referred_user_id, product_id,
    plan_price, rate_percent, commission_amount, status, source_event_id
  ) values (
    v_referrer, p_referred_user_id, p_product_id,
    coalesce(p_plan_price, 0), 0, v_amount, 'pending', p_source_event_id
  )
  on conflict do nothing;

  -- True only when a row actually exists for this pair now.
  return exists (
    select 1 from public.commissions c
    where c.referred_user_id = p_referred_user_id
      and c.product_id = p_product_id
  );
end;
$$;

revoke execute on function public.credit_referral_commission(text, text, numeric, numeric, text) from public;
grant execute on function public.credit_referral_commission(text, text, numeric, numeric, text)
  to service_role;

-- ------------------------------------------------------------------
-- CONFIRM (read-only): the function is in place and the index exists.
-- ------------------------------------------------------------------
select
  p.proname as function_name,
  position('FLAT amount' in pg_get_functiondef(p.oid)) > 0 as has_flat_amount,
  position('subscription_entitlement' in pg_get_functiondef(p.oid)) > 0 as checks_referrer_active
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'credit_referral_commission';

select indexname from pg_indexes
where schemaname = 'public'
  and indexname = 'commissions_play_one_per_referred_idx';
