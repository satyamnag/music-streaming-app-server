-- ============================================================
-- MIGRATION: Affiliate QR referrer codes (Phase A — backend only)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Business model (QR-based affiliate tracking):
--   * Each affiliate gets a short, unique `referrer_code` (e.g. `YT-CHANNEL1`)
--     used to build a Play Store deep link with an install-referrer:
--       https://play.google.com/store/apps/details?id=com.soulfulbhakti.app&referrer=utm_source=<referrer_code>
--   * The app reads the Google Play Install Referrer on first launch and,
--     after the user signs in, records an attribution binding that user to
--     the affiliate (stored in `affiliate_referrals`, one per user, immutable).
--   * When the attributed user completes a real paid subscription, the
--     affiliate is credited a commission — EXCLUSIVELY from verified
--     Superwall webhooks (existing `credit_affiliate_commission` pipeline,
--     unchanged).
--
-- This migration ONLY adds the backend schema. Coupons remain fully intact
-- and working; the commission pipeline is unchanged. The app-side
-- install-referrer reader + sign-in binding are built in a later phase.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Referrer code on each affiliate. Unique so a scanned QR maps to
--    exactly one affiliate. Backfilled from the affiliate id (first 8
--    chars) for existing rows; admin may rename via the admin panel.
-- ------------------------------------------------------------------
alter table public.affiliates
  add column if not exists referrer_code text;

-- Backfill existing rows with a unique code derived from the id.
update public.affiliates
   set referrer_code = upper(replace(substr(id::text, 1, 8), '-', ''))
 where referrer_code is null or referrer_code = '';

-- Enforce uniqueness + non-empty after backfill. Do it in a DO block so it
-- fails cleanly if backfill produced a collision.
do $$
begin
  if exists (
    select 1 from public.affiliates
    group by referrer_code having count(*) > 1
  ) then
    raise exception 'referrer_code collision after backfill — resolve manually';
  end if;
  alter table public.affiliates
    alter column referrer_code set not null;
  alter table public.affiliates
    add constraint affiliates_referrer_code_key unique (referrer_code);
end $$;

-- ------------------------------------------------------------------
-- 2) Affiliate referrals: binds a user to an affiliate, ONCE. The
--    `purchaser_user_id` (Clerk user id) is unique, so a user can be
--    attributed to at most one affiliate via QR, immutable.
-- ------------------------------------------------------------------
create table if not exists public.affiliate_referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_code text not null,
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,
  purchaser_user_id text not null unique, -- Clerk user id bound at first sign-in
  created_at timestamptz not null default now()
);

alter table public.affiliate_referrals enable row level security;

-- Users may read their own referral attribution (to know which affiliate
-- they were referred by).
create policy "Users can view own referral attribution"
  on public.affiliate_referrals for select
  using (auth.uid()::text = purchaser_user_id);

create index if not exists affiliate_referrals_affiliate_idx
  on public.affiliate_referrals (affiliate_id);

-- ------------------------------------------------------------------
-- 3) SECURITY DEFINER RPC: bind the signed-in user to an affiliate via a
--    QR referrer code. Validates the code, then records the attribution
--    ONCE (unique purchaser_user_id). Idempotent; returns a status string:
--      'bound'           - success, referral recorded
--      'already_bound'   - this user already has a referral
--      'invalid'         - unknown / inactive referrer code
-- ------------------------------------------------------------------
create or replace function public.bind_affiliate_referral(p_referrer_code text, p_user_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_affiliate_id uuid;
  v_bound boolean;
begin
  if p_referrer_code is null or p_referrer_code = '' or p_user_id is null or p_user_id = '' then
    return 'invalid';
  end if;

  -- A user can be attributed to at most one affiliate via QR, ever.
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
$$;

grant execute on function public.bind_affiliate_referral(text, text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='affiliates' and column_name='referrer_code';

select 'affiliate_referrals' as tbl, count(*) from public.affiliate_referrals
union all
select 'affiliates', count(*) from public.affiliates;
