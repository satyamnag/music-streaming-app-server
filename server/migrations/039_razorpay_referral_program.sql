-- ============================================================
-- MIGRATION: Razorpay referral program (039)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- ------------------------------------------------------------------
-- BUSINESS RULE (locked with the owner)
-- ------------------------------------------------------------------
--   * Every paid Razorpay subscriber is an affiliate and has a referral
--     code. Codes live in the existing `referral_codes` table (migration
--     003), created through `get_or_create_referral_code`.
--   * Any number of users may subscribe using that code.
--   * The referrer earns a FLAT amount (default Rs.51, configurable in
--     `referral_program_config`) when a referred user's FIRST payment
--     succeeds. Later renewals credit nothing ("first payment only").
--   * SINGLE LEVEL: only the direct referrer earns. There is no upline.
--   * The referrer must have an ACTIVE subscription at the moment the
--     credit is written. A lapsed referrer earns nothing.
--   * Track-only ledger: rows are `pending` until settled by hand. No
--     payout, no withdrawal, no money movement in this system.
--
-- ------------------------------------------------------------------
-- WHY THIS DOES NOT TOUCH THE EXISTING PIPELINES
-- ------------------------------------------------------------------
-- The Play/Android commission path (Superwall webhook ->
-- `credit_referral_commission` / `credit_affiliate_commission`) is left
-- exactly as it was. This migration adds:
--   * one config table,
--   * one nullable column on `razorpay_subscriptions`,
--   * one PARTIAL unique index scoped to product_id = 'razorpay_yearly',
--     so it can never constrain a 'soulful_yearly' Play row,
--   * three new functions that nothing else calls.
--
-- The Android app is not modified. Because credits are written to the
-- existing `commissions` table, the app's own "Share & Earn" screen
-- (`get_referral_summary`) already reports them with no app change.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Config: the flat referral amount. One row, enforced by a boolean
--    primary key. Change the amount with a plain UPDATE; no deploy.
-- ------------------------------------------------------------------
create table if not exists public.referral_program_config (
  id boolean primary key default true check (id),
  commission_amount numeric not null default 51 check (commission_amount >= 0),
  updated_at timestamptz not null default now()
);

insert into public.referral_program_config (id) values (true)
on conflict (id) do nothing;

alter table public.referral_program_config enable row level security;
revoke all on public.referral_program_config from anon, authenticated;
grant select on public.referral_program_config to service_role;

-- ------------------------------------------------------------------
-- 2) The referral code that was used to buy this subscription. Stored
--    on the row rather than relying on Razorpay `notes`, because the
--    create response does not guarantee notes are echoed back (see
--    `persistRazorpaySubscription`). Nullable: most purchases have none.
-- ------------------------------------------------------------------
alter table public.razorpay_subscriptions
  add column if not exists referral_code text;

-- ------------------------------------------------------------------
-- 3) FIRST PAYMENT ONLY, enforced by the database rather than by
--    application logic. At most one referral credit per referred user
--    for this program. The `where` clause scopes it to the Razorpay
--    product id, so Play rows ('soulful_yearly') are unaffected.
-- ------------------------------------------------------------------
create unique index if not exists commissions_razorpay_one_per_referred_idx
  on public.commissions (referred_user_id)
  where product_id = 'razorpay_yearly';

-- ------------------------------------------------------------------
-- 4) Validate a code before checkout. Server-only: the answer names the
--    exact reason so the web app can explain it, and it must never be
--    reachable with an anon key.
--
--    Returns: 'valid' | 'unknown' | 'self' | 'already_attributed'
--             | 'inactive_referrer' | 'invalid'
-- ------------------------------------------------------------------
create or replace function public.validate_referral_code(
  p_code text,
  p_user_id text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_referrer text;
  v_active boolean;
begin
  if p_code is null or trim(p_code) = '' then
    return 'unknown';
  end if;
  if p_user_id is null or p_user_id = '' then
    return 'invalid';
  end if;

  v_code := upper(trim(p_code));

  select rc.user_id into v_referrer
  from public.referral_codes rc
  where upper(rc.code) = v_code;

  if v_referrer is null then
    return 'unknown';
  end if;

  -- No self-referral, ever.
  if v_referrer = p_user_id then
    return 'self';
  end if;

  -- A user is attributed at most once, for life.
  if exists (
    select 1 from public.referral_attributions
    where referred_user_id = p_user_id
  ) then
    return 'already_attributed';
  end if;

  -- Only a currently-paying subscriber is an affiliate.
  select se.active into v_active
  from public.subscription_entitlement(v_referrer) se
  limit 1;

  if not coalesce(v_active, false) then
    return 'inactive_referrer';
  end if;

  return 'valid';
end;
$$;

revoke execute on function public.validate_referral_code(text, text) from public;
grant execute on function public.validate_referral_code(text, text) to service_role;

-- ------------------------------------------------------------------
-- 5) Credit the referral, once, from a VERIFIED Razorpay payment.
--
--    Called only by the Node server (service role) after either the
--    payment-signature check in /api/razorpay/verify or the HMAC check
--    on /api/razorpay/webhook. Never callable by a client.
--
--    Attribution is written here, at first successful payment, rather
--    than when the code is typed. An abandoned checkout therefore does
--    not burn the user's single attribution.
--
--    Returns: 'credited' | 'already_credited' | 'not_attributed'
--             | 'unknown_code' | 'self_referral' | 'referrer_inactive'
--             | 'invalid'
-- ------------------------------------------------------------------
create or replace function public.credit_razorpay_referral_commission(
  p_referred_user_id text,
  p_referral_code text,
  p_source_event_id text,
  p_plan_price numeric
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_referrer text;
  v_active boolean;
  v_amount numeric;
  v_credited boolean;
begin
  if p_referred_user_id is null or p_referred_user_id = ''
     or p_source_event_id is null or p_source_event_id = '' then
    raise exception 'required fields missing';
  end if;

  -- FIRST PAYMENT ONLY. The partial unique index is the authority; this
  -- check just avoids pointless work and gives an honest answer.
  if exists (
    select 1 from public.commissions
    where referred_user_id = p_referred_user_id
      and product_id = 'razorpay_yearly'
  ) then
    return 'already_credited';
  end if;

  -- Resolve the referrer: an existing attribution always wins (it was
  -- written at sign-up and is immutable), otherwise use the code carried
  -- on the subscription row.
  select referrer_user_id into v_referrer
  from public.referral_attributions
  where referred_user_id = p_referred_user_id;

  if v_referrer is null then
    if p_referral_code is null or trim(p_referral_code) = '' then
      return 'not_attributed';
    end if;

    v_code := upper(trim(p_referral_code));

    select rc.user_id into v_referrer
    from public.referral_codes rc
    where upper(rc.code) = v_code;

    if v_referrer is null then
      return 'unknown_code';
    end if;

    if v_referrer = p_referred_user_id then
      return 'self_referral';
    end if;

    -- Write the immutable attribution. If a concurrent request already
    -- attributed this user, the conflict is ignored and the winner stands.
    insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
    values (v_code, v_referrer, p_referred_user_id)
    on conflict (referred_user_id) do nothing;

    select referrer_user_id into v_referrer
    from public.referral_attributions
    where referred_user_id = p_referred_user_id;
  end if;

  if v_referrer is null then
    return 'not_attributed';
  end if;

  if v_referrer = p_referred_user_id then
    return 'self_referral';
  end if;

  -- The referrer must be an active subscriber RIGHT NOW.
  select se.active into v_active
  from public.subscription_entitlement(v_referrer) se
  limit 1;

  if not coalesce(v_active, false) then
    return 'referrer_inactive';
  end if;

  select cfg.commission_amount into v_amount
  from public.referral_program_config cfg
  where cfg.id = true;

  if v_amount is null or v_amount <= 0 then
    return 'invalid';
  end if;

  insert into public.commissions (
    referrer_user_id, referred_user_id, product_id,
    plan_price, rate_percent, commission_amount, status, source_event_id
  ) values (
    v_referrer, p_referred_user_id, 'razorpay_yearly',
    coalesce(p_plan_price, 0), 0, v_amount, 'pending', p_source_event_id
  )
  on conflict do nothing;

  select exists (
    select 1 from public.commissions
    where referred_user_id = p_referred_user_id
      and product_id = 'razorpay_yearly'
  ) into v_credited;

  return case when v_credited then 'credited' else 'already_credited' end;
end;
$$;

revoke execute on function public.credit_razorpay_referral_commission(text, text, text, numeric) from public;
grant execute on function public.credit_razorpay_referral_commission(text, text, text, numeric)
  to service_role;

-- ------------------------------------------------------------------
-- 6) One call that answers the account page: is this user an affiliate,
--    what is their code, how many people did they refer, and what have
--    they earned. Server-only (the user id comes from the Clerk token,
--    never from a query string).
-- ------------------------------------------------------------------
create or replace function public.referral_program_summary(p_user_id text)
returns table (
  code text,
  is_affiliate boolean,
  referral_count bigint,
  credited_referrals bigint,
  pending_amount numeric,
  settled_amount numeric,
  total_amount numeric,
  amount_per_referral numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active boolean;
  v_amount numeric;
begin
  if p_user_id is null or p_user_id = '' then
    raise exception 'user_id required';
  end if;

  select se.active into v_active
  from public.subscription_entitlement(p_user_id) se
  limit 1;

  select cfg.commission_amount into v_amount
  from public.referral_program_config cfg
  where cfg.id = true;

  return query
  select
    -- A scalar subquery, so this always returns exactly ONE row even when the
    -- user has no code yet. The account page needs the amount in order to
    -- advertise "earn Rs.51 per friend" before anyone has referred.
    (select rc.code from public.referral_codes rc where rc.user_id = p_user_id) as code,
    coalesce(v_active, false) as is_affiliate,
    (select count(*) from public.referral_attributions ra
       where ra.referrer_user_id = p_user_id)::bigint as referral_count,
    (select count(*) from public.commissions c
       where c.referrer_user_id = p_user_id
         and c.product_id = 'razorpay_yearly')::bigint as credited_referrals,
    coalesce((select sum(c.commission_amount) from public.commissions c
       where c.referrer_user_id = p_user_id and c.status = 'pending'), 0) as pending_amount,
    coalesce((select sum(c.commission_amount) from public.commissions c
       where c.referrer_user_id = p_user_id
         and c.status in ('credited', 'paid')), 0) as settled_amount,
    coalesce((select sum(c.commission_amount) from public.commissions c
       where c.referrer_user_id = p_user_id), 0) as total_amount,
    coalesce(v_amount, 0) as amount_per_referral;
end;
$$;

revoke execute on function public.referral_program_summary(text) from public;
grant execute on function public.referral_program_summary(text) to service_role;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select commission_amount from public.referral_program_config where id = true;

select column_name from information_schema.columns
where table_schema = 'public'
  and table_name = 'razorpay_subscriptions'
  and column_name = 'referral_code';

select indexname from pg_indexes
where schemaname = 'public'
  and indexname = 'commissions_razorpay_one_per_referred_idx';
