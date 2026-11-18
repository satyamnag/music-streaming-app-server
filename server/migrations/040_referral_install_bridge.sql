-- ============================================================
-- MIGRATION: let a Play install-referrer carry a USER referral code (040)
-- Run in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- ------------------------------------------------------------------
-- IS THIS SAFE? (read before running)
-- ------------------------------------------------------------------
--   * No table, column, index or schema is created, altered or dropped.
--   * No DELETE, TRUNCATE, DROP or UPDATE appears anywhere in this file.
--   * The ONLY thing this file changes is the body of one function,
--     `public.bind_affiliate_referral`, whose partner branch is reproduced
--     below byte for byte, so partner and coupon behaviour cannot change.
--   * It writes no data. Verification lives in a SEPARATE optional file
--     (040_verify.sql) precisely so this one can never roll anything back.
--   * Reversible: the previous definition is in
--     server/migrations/033_partner_program.sql (rollback snippet at the end).
--   * Re-running is safe: `create or replace` is idempotent.
--
-- WHY THIS EXISTS
--   The Android app reads the Play install referrer and, on sign-in, calls
--   `bind_affiliate_referral(p_referrer_code, p_user_id)`.
--   (lib/services/install_referrer/referrer_service.dart -> local Dart route
--    /supabase/referrers/bind)
--
--   That function only searched `public.affiliates`, i.e. PARTNER codes.
--   A subscriber's referral code lives in `public.referral_codes` (migration
--   003/039), so an invite link carrying their code resolved to 'invalid':
--   the friend installed, signed in, and the referral silently evaporated.
--
-- WHAT THIS CHANGES
--   One branch is prepended to `bind_affiliate_referral`:
--     if the code exists in public.referral_codes ->
--         write the immutable referral_attributions row (on conflict do nothing)
--         return 'invalid'
--
--   Returning 'invalid' is deliberate:
--     * the Android app treats 'bound'/'already_bound' as "QR affiliate" and
--       switches on the Superwall `has_affiliate_discount` audience. A friend
--       arriving through an ordinary invite must NOT be handed a partner
--       discount;
--     * returning 'invalid' still sets the app's own `affiliateReferrerBound`
--       flag, so it does not retry in a loop;
--     * the row written to referral_attributions is what the web
--       "Refer & earn" card counts, and what credit_referral_commission uses
--       when the friend later pays through Play.
--
--   Nothing is ever written to `affiliates`, `affiliate_referrals`, `coupons`,
--   `coupon_attributions` or `commissions` by this function.
-- ============================================================

create or replace function public.bind_affiliate_referral(
  p_referrer_code text, p_user_id text
)
returns text
language plpgsql
security definer
set search_path = public
as $body$
declare
  v_affiliate_id uuid;
  v_bound boolean;
  v_user_referrer text;
begin
  if p_referrer_code is null or p_referrer_code = ''
     or p_user_id is null or p_user_id = '' then
    return 'invalid';
  end if;

  -- ------------------------------------------------------------------
  -- USER REFERRAL CODES (new in 040). Resolved first, but only when the code
  -- actually exists in referral_codes, so partner codes are unaffected.
  -- ------------------------------------------------------------------
  select rc.user_id into v_user_referrer
  from public.referral_codes rc
  where upper(rc.code) = upper(trim(p_referrer_code));

  if v_user_referrer is not null then
    -- Self-referral is never attribution.
    if v_user_referrer = p_user_id then
      return 'invalid';
    end if;

    insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
    values (upper(trim(p_referrer_code)), v_user_referrer, p_user_id)
    on conflict (referred_user_id) do nothing;

    -- The attribution is written above. 'invalid' keeps the app's partner
    -- discount path switched OFF for ordinary invites. See the header.
    return 'invalid';
  end if;

  -- ------------------------------------------------------------------
  -- ORIGINAL PARTNER BRANCH - unchanged from 033_partner_program.sql.
  -- ------------------------------------------------------------------
  if exists (
    select 1 from public.affiliate_referrals where purchaser_user_id = p_user_id
  ) then
    return 'already_bound';
  end if;

  select a.id into v_affiliate_id
  from public.affiliates a
  where upper(a.referrer_code) = upper(p_referrer_code)
    and a.status = 'active'
  limit 1;

  if v_affiliate_id is null then
    return 'invalid';
  end if;

  insert into public.affiliate_referrals (referrer_code, affiliate_id, purchaser_user_id)
  values (upper(p_referrer_code), v_affiliate_id, p_user_id)
  on conflict (purchaser_user_id) do nothing;

  select exists (
    select 1 from public.affiliate_referrals
    where purchaser_user_id = p_user_id and affiliate_id = v_affiliate_id
  ) into v_bound;

  if v_bound then
    return 'bound';
  else
    return 'already_bound';
  end if;
end;
$body$;

grant execute on function public.bind_affiliate_referral(text, text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- CONFIRM the replacement took effect (read-only):
-- expect exactly one row, and the source shown in the editor should contain
-- the string "USER REFERRAL CODES" from the branch above.
-- ------------------------------------------------------------------
select
  p.proname                                    as function_name,
  pg_get_function_identity_arguments(p.oid)    as arguments,
  position('USER REFERRAL CODES' in pg_get_functiondef(p.oid)) > 0 as has_user_referral_branch
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'bind_affiliate_referral';

-- ------------------------------------------------------------------
-- ROLLBACK (if you ever want the previous behaviour back).
-- Paste ONLY this block to restore the function exactly as 033 shipped it:
--
--   create or replace function public.bind_affiliate_referral(
--     p_referrer_code text, p_user_id text
--   ) returns text language plpgsql security definer set search_path = public
--   as $body$
--   declare v_affiliate_id uuid; v_bound boolean;
--   begin
--     if p_referrer_code is null or p_referrer_code = ''
--        or p_user_id is null or p_user_id = '' then return 'invalid'; end if;
--     if exists (select 1 from public.affiliate_referrals where purchaser_user_id = p_user_id)
--     then return 'already_bound'; end if;
--     select a.id into v_affiliate_id from public.affiliates a
--     where upper(a.referrer_code) = upper(p_referrer_code) and a.status = 'active' limit 1;
--     if v_affiliate_id is null then return 'invalid'; end if;
--     insert into public.affiliate_referrals (referrer_code, affiliate_id, purchaser_user_id)
--     values (upper(p_referrer_code), v_affiliate_id, p_user_id)
--     on conflict (purchaser_user_id) do nothing;
--     select exists (select 1 from public.affiliate_referrals
--       where purchaser_user_id = p_user_id and affiliate_id = v_affiliate_id) into v_bound;
--     return case when v_bound then 'bound' else 'already_bound' end;
--   end; $body$;
-- ------------------------------------------------------------------
