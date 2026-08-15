-- ============================================================
-- MIGRATION: Affiliate coupon program (safe hybrid)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Business model:
--   - Affiliates are EXTERNAL partners (marketers, channels) — not app
--     users. They are created and managed OUTSIDE the app (this SQL / an
--     admin panel). Each affiliate is issued a unique coupon code.
--   - A signed-in user enters an affiliate's coupon code in the app once
--     (attribution-only; no price change, fully Google Play compliant).
--   - When that user completes a real, paid subscription, the affiliate is
--     credited a commission — EXCLUSIVELY from verified Superwall webhooks.
--
-- Trust model (identical to migrations/003_referrals.sql):
--   - Attribution is written at most ONCE per user (unique
--     `purchaser_user_id`) and is immutable.
--   - Commission is credited ONLY by the trusted Express server (service
--     role) via `credit_affiliate_commission`, idempotent on the Superwall
--     webhook event id. The app can never self-credit.
--   - No client-supplied amounts are ever trusted.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Affiliates: external partners. No Clerk user id — these are people
--    outside the app. Managed by admin (service role) only.
-- ------------------------------------------------------------------
create table if not exists public.affiliates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_email text,
  status text not null default 'active' check (status in ('active', 'paused')),
  created_at timestamptz not null default now()
);

alter table public.affiliates enable row level security;

-- No user-facing policies: affiliate data is admin-only. The trusted
-- server (service role) bypasses RLS.

-- ------------------------------------------------------------------
-- 2) Coupons: one unique, admin-issued code per affiliate. A coupon can
--    be redeemed by many customers up to `max_redemptions` (null =
--    unlimited) and optionally until `expires_at`.
-- ------------------------------------------------------------------
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,             -- human-shareable code, e.g. BHAKTI25
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'paused')),
  max_redemptions integer,               -- null = unlimited
  redemption_count integer not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check (redemption_count >= 0),
  check (max_redemptions is null or max_redemptions >= 1)
);

alter table public.coupons enable row level security;

-- No user-facing policies: coupon codes must not be enumerable by users.

create index if not exists coupons_affiliate_idx on public.coupons (affiliate_id);

-- ------------------------------------------------------------------
-- 3) Coupon attributions: binds a purchaser to a coupon, ONCE. The
--    `purchaser_user_id` (Clerk user id) is unique, so a user can be
--    attributed to at most one affiliate, and it can never change.
-- ------------------------------------------------------------------
create table if not exists public.coupon_attributions (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  code text not null,
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,
  purchaser_user_id text not null unique, -- Clerk user id who redeemed the code
  created_at timestamptz not null default now()
);

alter table public.coupon_attributions enable row level security;

-- Users may read their own attribution (to know which affiliate they are
-- supporting).
create policy "Users can view own coupon attribution"
  on public.coupon_attributions for select
  using (auth.uid()::text = purchaser_user_id);

-- ------------------------------------------------------------------
-- 4) Affiliate commission ledger: one row per credited purchase event.
--    `source_event_id` is the Superwall webhook event id => idempotent.
--    `status` is 'pending' until payouts are made (track-first).
-- ------------------------------------------------------------------
create table if not exists public.affiliate_commissions (
  id uuid primary key default gen_random_uuid(),
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,
  purchaser_user_id text not null,       -- Clerk user id who purchased
  product_id text not null,
  plan_price numeric not null,           -- price in INR as billed
  rate_percent numeric not null,
  commission_amount numeric not null,
  status text not null default 'pending'
    check (status in ('pending', 'credited', 'paid')),
  source_event_id text not null unique,  -- Superwall webhook event id (idempotency)
  created_at timestamptz not null default now()
);

alter table public.affiliate_commissions enable row level security;

-- Admin-only table: no user-facing policies (service role bypasses RLS).

create index if not exists affiliate_commissions_affiliate_idx
  on public.affiliate_commissions (affiliate_id);

-- ------------------------------------------------------------------
-- 5) SECURITY DEFINER RPC: validate a coupon code. Returns whether the
--    code is redeemable and the affiliate's display name (public info
--    only — never payout or contact details). No side effects.
-- ------------------------------------------------------------------
create or replace function public.validate_coupon(p_code text)
returns table (valid boolean, affiliate_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_affiliate_name text;
begin
  if p_code is null or p_code = '' then
    return query select false, null::text;
    return;
  end if;

  select a.name into v_affiliate_name
  from public.coupons c
  join public.affiliates a on a.id = c.affiliate_id
  where c.code = p_code
    and c.status = 'active'
    and a.status = 'active'
    and (c.expires_at is null or c.expires_at > now())
  limit 1;

  if v_affiliate_name is null then
    return query select false, null::text;
  else
    return query select true, v_affiliate_name;
  end if;
end;
$$;

grant execute on function public.validate_coupon(text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- 6) SECURITY DEFINER RPC: redeem a coupon for a user. Validates the
--    code atomically (status, expiry, redemption limit), increments the
--    redemption count, and records the attribution ONCE. Idempotent via
--    the unique `purchaser_user_id`; returns a status string:
--      'redeemed'        - success, attribution recorded
--      'already_redeemed' - this user already redeemed a coupon
--      'invalid'          - unknown code
--      'inactive'         - coupon or affiliate paused
--      'expired'          - coupon past expires_at
--      'limit_reached'    - max_redemptions already used
-- ------------------------------------------------------------------
create or replace function public.redeem_coupon(p_code text, p_user_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_coupon record;
  v_redeemed boolean;
begin
  if p_code is null or p_code = '' or p_user_id is null or p_user_id = '' then
    return 'invalid';
  end if;

  -- A user can be attributed to at most one coupon, ever.
  if exists (
    select 1 from public.coupon_attributions where purchaser_user_id = p_user_id
  ) then
    return 'already_redeemed';
  end if;

  select c.*, a.status as affiliate_status into v_coupon
  from public.coupons c
  join public.affiliates a on a.id = c.affiliate_id
  where c.code = p_code
  for update of c;

  if v_coupon.id is null then
    return 'invalid';
  end if;

  if v_coupon.status <> 'active' or v_coupon.affiliate_status <> 'active' then
    return 'inactive';
  end if;

  if v_coupon.expires_at is not null and v_coupon.expires_at < now() then
    return 'expired';
  end if;

  if v_coupon.max_redemptions is not null
     and v_coupon.redemption_count >= v_coupon.max_redemptions then
    return 'limit_reached';
  end if;

  -- Claim the redemption slot atomically (row locked above).
  update public.coupons
     set redemption_count = redemption_count + 1
   where id = v_coupon.id;

  -- Record the immutable attribution.
  insert into public.coupon_attributions (coupon_id, code, affiliate_id, purchaser_user_id)
  values (v_coupon.id, v_coupon.code, v_coupon.affiliate_id, p_user_id)
  on conflict (purchaser_user_id) do nothing;

  select exists (
    select 1 from public.coupon_attributions
    where purchaser_user_id = p_user_id and coupon_id = v_coupon.id
  ) into v_redeemed;

  if v_redeemed then
    return 'redeemed';
  else
    return 'already_redeemed';
  end if;
end;
$$;

grant execute on function public.redeem_coupon(text, text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- 7) SECURITY DEFINER RPC: credit an affiliate commission from a verified
--    purchase event. Called ONLY by the trusted Express server (service
--    role) after Superwall webhook signature verification. Idempotent on
--    the webhook event id; never trusts client-supplied amounts. Returns
--    false when the purchaser has no coupon attribution (so the webhook
--    can fall back to the referral program).
-- ------------------------------------------------------------------
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

  select affiliate_id into v_affiliate_id
  from public.coupon_attributions
  where purchaser_user_id = p_purchaser_user_id;

  if v_affiliate_id is null then
    return false; -- not a coupon purchase; let the referral program handle it
  end if;

  v_amount := round((p_plan_price * p_rate_percent) / 100.0, 2);

  insert into public.affiliate_commissions (
    affiliate_id, purchaser_user_id, product_id,
    plan_price, rate_percent, commission_amount, source_event_id
  ) values (
    v_affiliate_id, p_purchaser_user_id, p_product_id,
    p_plan_price, p_rate_percent, v_amount, p_source_event_id
  )
  on conflict (source_event_id) do nothing;

  return true;
end;
$$;

-- Executable only by the service role (webhook handler). NOT granted to
-- anon/authenticated so clients can never self-credit commissions.
grant execute on function public.credit_affiliate_commission(text, text, numeric, numeric, text)
  to service_role;

-- ------------------------------------------------------------------
-- Admin helper: issue a coupon to a new affiliate.
-- Example (run manually, replace the values):
--
--   insert into public.affiliates (name, contact_email) values
--     ('My Channel', 'channel@example.com') returning id;
--   -- copy the returned id, then:
--   insert into public.coupons (code, affiliate_id, max_redemptions, expires_at)
--   values ('BHAKTI25', '<affiliate-id>', 1000, now() + interval '6 months');
--
-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select 'affiliates' as tbl, count(*) from public.affiliates
union all
select 'coupons', count(*) from public.coupons
union all
select 'coupon_attributions', count(*) from public.coupon_attributions
union all
select 'affiliate_commissions', count(*) from public.affiliate_commissions;
