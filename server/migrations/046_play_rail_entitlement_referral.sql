-- ============================================================
-- MIGRATION 046: the Play (Android) rail joins entitlement and referral
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- ------------------------------------------------------------------
-- WHY (the three gaps this closes)
-- ------------------------------------------------------------------
--   The referral program (039) and the flat Play commission (042) both
--   decided "is the referrer a paying subscriber?" with
--   `subscription_entitlement(...)`, which reads ONLY the Razorpay
--   (web) table. A referrer who paid through the Android app (Play
--   Billing via Superwall) therefore:
--
--     1. could never be credited - credit_referral_commission refused
--        the credit ("referrer inactive"), so "Total earned" and
--        "Awaiting settlement" stayed at Rs.0 on /account;
--     2. could never be validated as an affiliate - validate_referral_code
--        returned 'inactive_referrer' for their code;
--     3. was told "not a subscriber" by GET /api/razorpay/entitlement,
--        so the web /account page never even mounted the Refer & earn
--        card for them (the card is gated on isEntitled).
--
--   The server also had NO record at all of who holds a Play
--   subscription - the Superwall status lives on the device, which is
--   exactly why every account on one device looked premium. This
--   migration gives the server its own per-user Play record, written
--   ONLY from verified Superwall webhooks.
--
-- ------------------------------------------------------------------
-- WHAT THIS CHANGES
-- ------------------------------------------------------------------
--   * one new table `play_subscriptions` (service-role only);
--   * one upsert RPC `play_subscription_upsert` (guarded, monotonic);
--   * one read function `subscription_entitlement_any_rail` that answers
--     "is this user paid on EITHER rail" (Razorpay preferred when both
--     are active, so existing plan naming does not change);
--   * four existing functions are recreated with ONE changed line each:
--     the referrer/is-affiliate check now reads the any-rail function.
--     Their razorpay-only behaviour is otherwise byte-for-byte the same.
--
-- ------------------------------------------------------------------
-- WHAT IT DOES NOT CHANGE
-- ------------------------------------------------------------------
--   * Nothing in the Android app. The app is not involved in any of
--     this; it keeps reading the same endpoints and RPCs.
--   * The Play grace policy mirrors the Razorpay table
--     (docs/RAZORPAY-SUBSCRIPTIONS.md §6.4):
--       active                -> yes, open-ended unless current_end set
--       cancelled / paused    -> until current_end (they paid for it)
--       expired / refunded    -> no
--   * The razorpay-only function `subscription_entitlement` is
--     untouched, so every razorpay-specific business rule that reads
--     it (affiliate rows, admin lookups) behaves exactly as before.
--
-- ------------------------------------------------------------------
-- SAFETY
-- ------------------------------------------------------------------
--   * Additive and re-runnable: create-if-not-exists +
--     create-or-replace everywhere. No data is deleted.
--   * The upsert ignores replayed events whose event_ts is older than
--     the stored row, so a retried webhook can never regress state.
--   * New functions are revoked from PUBLIC / anon / authenticated,
--     exactly like their 039/042 predecessors.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Play subscription state. One row per (user, product), written only
--    by the Node server from Svix-verified Superwall webhooks.
--    `user_id` is the Clerk user id (TEXT, like every user-scoped
--    table in this repo); rows for the anonymous device user are never
--    written (the server filters those events out).
-- ------------------------------------------------------------------
create table if not exists public.play_subscriptions (
  user_id         text not null,                 -- Clerk user id
  product_id      text not null,                 -- Play product id (soulful_yearly / soulful_monthly)
  status          text not null
    check (status in ('active', 'cancelled', 'paused', 'expired', 'refunded')),
  current_start   timestamptz,
  current_end     timestamptz,
  store           text not null default 'PLAY_STORE',
  environment     text not null default 'PRODUCTION',
  last_event_id   text,
  last_event_name text,
  event_ts        timestamptz,                   -- event time; the monotonicity guard
  raw             jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index if not exists play_subscriptions_user_updated_idx
  on public.play_subscriptions (user_id, updated_at desc);

alter table public.play_subscriptions enable row level security;

-- Deliberately NO policies: RLS with no policy denies every anon/authenticated
-- request. Only the service role (which bypasses RLS) can read or write.
revoke all on public.play_subscriptions from anon, authenticated;
grant select, insert, update on public.play_subscriptions to service_role;

-- ------------------------------------------------------------------
-- 2) Guarded upsert. Idempotent for webhook retries: an event whose
--    event_ts is not newer than the stored row is ignored, so a
--    replayed old event can never regress a newer state.
-- ------------------------------------------------------------------
create or replace function public.play_subscription_upsert(
  p_user_id text,
  p_product_id text,
  p_status text,
  p_current_start timestamptz,
  p_current_end timestamptz,
  p_store text,
  p_environment text,
  p_last_event_id text,
  p_last_event_name text,
  p_event_ts timestamptz,
  p_raw jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or p_user_id = '' or p_product_id is null or p_product_id = '' then
    raise exception 'user_id and product_id are required';
  end if;

  insert into public.play_subscriptions (
    user_id, product_id, status, current_start, current_end, store, environment,
    last_event_id, last_event_name, event_ts, raw
  ) values (
    p_user_id, p_product_id, p_status, p_current_start, p_current_end, p_store,
    p_environment, p_last_event_id, p_last_event_name, p_event_ts, coalesce(p_raw, '{}'::jsonb)
  )
  on conflict (user_id, product_id) do update set
    status = excluded.status,
    current_start = coalesce(excluded.current_start, play_subscriptions.current_start),
    current_end = excluded.current_end,
    store = excluded.store,
    environment = excluded.environment,
    last_event_id = excluded.last_event_id,
    last_event_name = excluded.last_event_name,
    event_ts = excluded.event_ts,
    raw = excluded.raw,
    updated_at = now()
  where play_subscriptions.event_ts is null
     or excluded.event_ts >= play_subscriptions.event_ts;
end;
$$;

revoke execute on function public.play_subscription_upsert(text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb) from public;
grant execute on function public.play_subscription_upsert(text, text, text, timestamptz, timestamptz, text, text, text, text, timestamptz, jsonb)
  to service_role;

-- ------------------------------------------------------------------
-- 3) Entitlement on EITHER rail. The single place the referral program,
--    the /account page and the entitlement endpoint read "is this
--    user paid?". Returns exactly one row always.
--
--    Precedence: an active Razorpay row wins (its plan slug is what
--    the UI names); otherwise an active Play row; otherwise an
--    inactive row carrying the best-known plan/end/status.
-- ------------------------------------------------------------------
create or replace function public.subscription_entitlement_any_rail(p_user_id text)
returns table (active boolean, plan text, current_end timestamptz, status text, source text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  rz_active boolean;
  rz_plan   text;
  rz_end    timestamptz;
  rz_status text;
  pl_status text;
  pl_plan   text;
  pl_end    timestamptz;
  pl_active boolean;
begin
  if p_user_id is null or p_user_id = '' then
    return query select false, null::text, null::timestamptz, 'none', 'none';
    return;
  end if;

  select se.active, se.plan_slug, se.current_end, se.status
    into rz_active, rz_plan, rz_end, rz_status
  from public.subscription_entitlement(p_user_id) se
  limit 1;
  rz_active := coalesce(rz_active, false);

  select ps.status, ps.product_id, ps.current_end
    into pl_status, pl_plan, pl_end
  from public.play_subscriptions ps
  where ps.user_id = p_user_id
  order by ps.updated_at desc
  limit 1;

  -- Play grace policy, mirroring the Razorpay table (docs §6.4):
  --   active              -> yes, open-ended unless current_end is set
  --   cancelled / paused  -> until current_end (they paid for it)
  --   expired / refunded  -> no
  pl_active := coalesce(
    case
      when pl_status = 'active' then (pl_end is null or pl_end >= now())
      when pl_status in ('cancelled', 'paused') then (coalesce(pl_end, now()) >= now())
      else false
    end,
    false
  );

  if rz_active then
    return query select true, rz_plan, rz_end, coalesce(rz_status, 'none'), 'razorpay';
  elsif pl_active then
    return query select true, pl_plan, pl_end, pl_status, 'play';
  else
    return query select false,
      coalesce(rz_plan, pl_plan),
      coalesce(rz_end, pl_end),
      coalesce(rz_status, pl_status, 'none'),
      case
        when rz_status is not null then 'razorpay'
        when pl_status is not null then 'play'
        else 'none'
      end;
  end if;
end;
$$;

revoke execute on function public.subscription_entitlement_any_rail(text) from public, anon, authenticated;
grant execute on function public.subscription_entitlement_any_rail(text) to service_role;

-- ------------------------------------------------------------------
-- 4) credit_referral_commission (042 body, ONE line changed):
--    the referrer-active check now accepts EITHER rail, so a referrer
--    who paid through Play can earn the flat Rs.51 for a friend's Play
--    purchase. Everything else - flat amount, once per referred user,
--    the partial unique index - is unchanged.
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

  -- FIRST PAYMENT ONLY, for the Play products. The partial unique index
  -- (migration 042) is the authority; this check avoids pointless work and
  -- gives an honest false instead of a silent conflict.
  if exists (
    select 1 from public.commissions c
    where c.referred_user_id = p_referred_user_id
      and c.product_id in ('soulful_yearly', 'soulful_monthly')
  ) then
    return false;
  end if;

  -- The referrer must be a paying subscriber RIGHT NOW - on EITHER rail.
  select se.active into v_active
  from public.subscription_entitlement_any_rail(v_referrer) se
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
-- 5) validate_referral_code (039 body, ONE line changed): a code held
--    by a Play-paid subscriber now validates on the web checkout too.
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

  -- Only a currently-paying subscriber is an affiliate - on EITHER rail.
  select se.active into v_active
  from public.subscription_entitlement_any_rail(v_referrer) se
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
-- 6) credit_razorpay_referral_commission (039 body, ONE line changed):
--    a web (Razorpay) payment still credits a Play-paid referrer.
--    Razorpay-only behaviour is otherwise byte-for-byte identical.
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

  -- The referrer must be an active subscriber RIGHT NOW - on EITHER rail.
  select se.active into v_active
  from public.subscription_entitlement_any_rail(v_referrer) se
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
-- 7) referral_program_summary (039 body, two lines changed):
--    is_affiliate now accepts EITHER rail, and credited_referrals now
--    counts Play credits alongside Razorpay credits. pending_amount /
--    total_amount already summed every commission row, so a Play credit
--    shows up in "Total earned" and "Awaiting settlement" unchanged.
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
  from public.subscription_entitlement_any_rail(p_user_id) se
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
         and c.product_id in ('razorpay_yearly', 'soulful_yearly', 'soulful_monthly'))::bigint as credited_referrals,
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
-- CONFIRM (read-only): every new/replaced object is in place.
-- ------------------------------------------------------------------
select
  p.proname as function_name,
  position('subscription_entitlement_any_rail' in pg_get_functiondef(p.oid)) > 0 as uses_any_rail
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'subscription_entitlement_any_rail',
    'play_subscription_upsert',
    'credit_referral_commission',
    'validate_referral_code',
    'credit_razorpay_referral_commission',
    'referral_program_summary'
  )
order by p.proname;

select tablename, indexname from pg_indexes
where schemaname = 'public'
  and tablename = 'play_subscriptions';
