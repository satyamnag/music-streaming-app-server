-- ============================================================
-- MIGRATION: Referral / Affiliate program
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Trust model: attribution and commission computation happen
-- SERVER-SIDE ONLY. The app client never reports purchases; it only
-- (a) creates/reads its own referral code and (b) records the "new
-- user signed up with this referral code" attribution at sign-up.
-- Commission is credited from verified Superwall webhooks.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Referral codes: one per Clerk user (user_id = Clerk user id).
--    `code` is unguessable and unique. Created lazily the first time
--    a signed-in user opens the "Share & Earn" screen.
-- ------------------------------------------------------------------
create table if not exists public.referral_codes (
  id uuid primary key default gen_random_uuid(),
  user_id text not null unique,          -- Clerk user id of the referrer
  code text not null unique,             -- unguessable share code
  created_at timestamptz not null default now()
);

alter table public.referral_codes enable row level security;

-- Users can read only their own code.
create policy "Users can view own referral code"
  on public.referral_codes for select
  using (auth.uid()::text = user_id);

-- ------------------------------------------------------------------
-- 2) Attribution: binds a referred (new) user to a referrer's code.
--    Written ONCE at sign-up time and then immutable, so a purchase is
--    always attributed to the person who actually shared the link.
--    `referred_user_id` unique => a user can be attributed at most once.
-- ------------------------------------------------------------------
create table if not exists public.referral_attributions (
  id uuid primary key default gen_random_uuid(),
  code text not null references public.referral_codes(code) on delete cascade,
  referrer_user_id text not null,        -- Clerk user id who shared
  referred_user_id text not null unique, -- Clerk user id who signed up
  created_at timestamptz not null default now(),
  check (referrer_user_id <> referred_user_id)  -- no self-referral
);

alter table public.referral_attributions enable row level security;

-- No one may read another user's attribution graph via RLS. The trusted
-- server (service role) reads it when a webhook arrives.
create policy "Users can view own attribution"
  on public.referral_attributions for select
  using (auth.uid()::text = referrer_user_id or auth.uid()::text = referred_user_id);

-- ------------------------------------------------------------------
-- 3) Commission rates: configurable percentage per product/plan.
--    Different plans can earn different rates (e.g. yearly > monthly).
-- ------------------------------------------------------------------
create table if not exists public.commission_rates (
  product_id text primary key,           -- Play Console product id
  rate_percent numeric not null check (rate_percent >= 0 and rate_percent <= 100),
  updated_at timestamptz not null default now()
);

alter table public.commission_rates enable row level security;

-- Everyone may read the published rates (shown to users in-app).
create policy "Anyone can view commission rates"
  on public.commission_rates for select
  using (true);

-- Seed the two live plans. Adjust percentages here as your business
-- model evolves; no app update required.
insert into public.commission_rates (product_id, rate_percent) values
  ('soulful_monthly', 15),
  ('soulful_yearly', 25)
on conflict (product_id) do update set rate_percent = excluded.rate_percent;

-- ------------------------------------------------------------------
-- 4) Commission ledger: one row per credited purchase event.
--    `source_event_id` is the Superwall webhook event id => idempotent.
--    `status` is 'pending' until payouts are enabled (track-first).
-- ------------------------------------------------------------------
create table if not exists public.commissions (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id text not null,        -- Clerk user id earning commission
  referred_user_id text not null,        -- Clerk user id who purchased
  product_id text not null,
  plan_price numeric not null,           -- price in INR as billed
  rate_percent numeric not null,
  commission_amount numeric not null,
  status text not null default 'pending'
    check (status in ('pending', 'credited', 'paid')),
  source_event_id text not null unique,  -- Superwall webhook event id (idempotency)
  created_at timestamptz not null default now()
);

alter table public.commissions enable row level security;

-- Referrers can view their own earnings ledger (pending/credited/paid).
create policy "Users can view own commissions"
  on public.commissions for select
  using (auth.uid()::text = referrer_user_id);

create index if not exists commissions_referrer_idx
  on public.commissions (referrer_user_id);

-- ------------------------------------------------------------------
-- 5) SECURITY DEFINER RPC: create/return the caller's referral code.
--    Runs with owner privileges so anon-key clients (the app's local
--    server) can create their own code without a session, while the
--    function enforces "one code per user".
-- ------------------------------------------------------------------
create or replace function public.get_or_create_referral_code(p_user_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if p_user_id is null or p_user_id = '' then
    raise exception 'user_id required';
  end if;

  select code into v_code
  from public.referral_codes
  where user_id = p_user_id;

  if v_code is not null then
    return v_code;
  end if;

  -- Un-guessable 12-char code, retry on (astronomically unlikely) collision.
  loop
    v_code := 'SB' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    begin
      insert into public.referral_codes (user_id, code)
      values (p_user_id, v_code);
      return v_code;
    exception when unique_violation then
      -- retry with a fresh code
      null;
    end;
  end loop;
end;
$$;

grant execute on function public.get_or_create_referral_code(text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- 6) SECURITY DEFINER RPC: record that a new user signed up with a
--    referral code. Idempotent (unique on referred_user_id). Rejects
--    self-referral. The referrer's id is looked up from the code, never
--    trusted from the client.
-- ------------------------------------------------------------------
create or replace function public.record_referral_attribution(
  p_code text,
  p_referred_user_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer text;
begin
  if p_code is null or p_code = '' or p_referred_user_id is null or p_referred_user_id = '' then
    raise exception 'code and referred_user_id required';
  end if;

  select user_id into v_referrer
  from public.referral_codes
  where code = p_code;

  if v_referrer is null then
    return false;  -- unknown code
  end if;

  if v_referrer = p_referred_user_id then
    return false;  -- self-referral
  end if;

  insert into public.referral_attributions (code, referrer_user_id, referred_user_id)
  values (p_code, v_referrer, p_referred_user_id)
  on conflict (referred_user_id) do nothing;

  return true;
end;
$$;

grant execute on function public.record_referral_attribution(text, text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- 7) SECURITY DEFINER RPC: summary of a user's referral earnings.
-- ------------------------------------------------------------------
create or replace function public.get_referral_summary(p_user_id text)
returns table (
  code text,
  referral_count bigint,
  pending_amount numeric,
  credited_amount numeric,
  total_amount numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    rc.code,
    (select count(*) from public.referral_attributions ra where ra.referrer_user_id = p_user_id)::bigint,
    coalesce((select sum(c.commission_amount) from public.commissions c
              where c.referrer_user_id = p_user_id and c.status = 'pending'), 0),
    coalesce((select sum(c.commission_amount) from public.commissions c
              where c.referrer_user_id = p_user_id and c.status in ('credited', 'paid')), 0),
    coalesce((select sum(c.commission_amount) from public.commissions c
              where c.referrer_user_id = p_user_id), 0)
  from public.referral_codes rc
  where rc.user_id = p_user_id;
end;
$$;

grant execute on function public.get_referral_summary(text)
  to anon, authenticated;

-- ------------------------------------------------------------------
-- 8) SECURITY DEFINER RPC: credit a commission from a verified purchase
--    event. Called ONLY by the trusted Express server (service role)
--    after Superwall webhook signature verification. Idempotent on the
--    webhook event id; never trusts client-supplied amounts.
-- ------------------------------------------------------------------
create or replace function public.credit_referral_commission(
  p_referred_user_id text,
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
  v_referrer text;
  v_amount numeric;
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

  v_amount := round((p_plan_price * p_rate_percent) / 100.0, 2);

  insert into public.commissions (
    referrer_user_id, referred_user_id, product_id,
    plan_price, rate_percent, commission_amount, source_event_id
  ) values (
    v_referrer, p_referred_user_id, p_product_id,
    p_plan_price, p_rate_percent, v_amount, p_source_event_id
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
revoke execute on function public.credit_referral_commission(text, text, numeric, numeric, text) from public;
grant execute on function public.credit_referral_commission(text, text, numeric, numeric, text)
  to service_role;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select product_id, rate_percent from public.commission_rates order by product_id;
