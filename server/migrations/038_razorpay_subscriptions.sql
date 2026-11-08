-- ============================================================
-- MIGRATION: Razorpay subscriptions (038)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- ------------------------------------------------------------------
-- WHAT THIS IS FOR
-- ------------------------------------------------------------------
-- Razorpay is the payment rail for subscriptions sold OUTSIDE the Play
-- app (the web funnel). The Android app never talks to Razorpay and never
-- decides entitlement: it asks the Node server, which reads this table.
--
-- Google Play requires Play Billing for the digital subscription sold
-- inside the Play-distributed app, so these tables must only ever be
-- written for purchases made outside it. Enrolling in Play's India
-- alternative-billing programme would be a separate, deliberate change.
--
-- ------------------------------------------------------------------
-- TRUST MODEL
-- ------------------------------------------------------------------
--  * Writes happen ONLY from the Node server, which verifies Razorpay's
--    payment signature / webhook HMAC before touching a row. It connects
--    with the service-role key.
--  * The app has NO direct access. RLS is enabled with no policies, and
--    EXECUTE on the entitlement function is granted to service_role only.
--    Nothing here is reachable with the anon key.
--  * user_id is TEXT, not UUID: this app keys user data by the Clerk user
--    id ("user_..."), same as the referral tables (migration 003).
-- ============================================================

-- Razorpay subscription state. One row per Razorpay subscription id.
create table if not exists public.razorpay_subscriptions (
  subscription_id   text primary key,              -- sub_XXXXXXXX
  user_id           text not null,                 -- Clerk user id
  plan_id           text not null,                 -- plan_XXXXXXXX
  plan_slug         text not null,                 -- 'monthly' | 'yearly'
  status            text not null,                 -- created|authenticated|active|pending|halted|cancelled|paused|expired|completed
  quantity          integer not null default 1,
  total_count       integer,
  paid_count        integer not null default 0,
  current_start     timestamptz,
  current_end       timestamptz,
  short_url         text,
  last_event_id     text,
  raw               jsonb not null default '{}'::jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- The entitlement function reads "newest row for this user", and the admin
-- lookups filter by user, so both directions need an index.
create index if not exists razorpay_subscriptions_user_created_idx
  on public.razorpay_subscriptions (user_id, created_at desc);

-- Webhook idempotency. Razorpay retries deliveries and duplicates are
-- documented expected behaviour; the x-razorpay-event-id header is unique
-- per event, so a primary key on it is the dedupe.
create table if not exists public.razorpay_webhook_events (
  event_id    text primary key,                    -- x-razorpay-event-id
  event_type  text not null,
  received_at timestamptz not null default now()
);

alter table public.razorpay_subscriptions  enable row level security;
alter table public.razorpay_webhook_events enable row level security;

-- Deliberately NO policies: RLS with no policy denies every anon/authenticated
-- request. Only the service role (which bypasses RLS) can read or write.
revoke all on public.razorpay_subscriptions  from anon, authenticated;
revoke all on public.razorpay_webhook_events from anon, authenticated;

grant select, insert, update on public.razorpay_subscriptions  to service_role;
grant select, insert, delete on public.razorpay_webhook_events to service_role;

-- ------------------------------------------------------------------
-- Entitlement rule (the ONLY place it is implemented)
-- ------------------------------------------------------------------
-- Mirrors the state table in docs/RAZORPAY-SUBSCRIPTIONS.md §6.4:
--   authenticated / active          -> yes (open-ended)
--   pending (failed renewal)        -> yes until current_end + 72h
--   cancelled / halted              -> yes until current_end (they paid it)
--   created / paused / expired / completed -> no
--
-- Returns zero rows when the user has no subscription; callers treat that
-- as "not entitled". `security definer` so it can read the tables, with a
-- pinned search_path so the definer rights cannot be redirected.
create or replace function public.subscription_entitlement(p_user_id text)
returns table (active boolean, plan_slug text, current_end timestamptz, status text)
language sql
stable
security definer
set search_path = public
as $$
  with latest as (
    select *
    from public.razorpay_subscriptions
    where user_id = p_user_id
    order by created_at desc
    limit 1
  )
  select
    case
      when latest.status in ('authenticated', 'active') then true
      when latest.status = 'pending'
        then coalesce(latest.current_end, now()) + interval '72 hours' > now()
      when latest.status in ('cancelled', 'halted')
        then coalesce(latest.current_end, now()) > now()
      else false
    end as active,
    latest.plan_slug,
    latest.current_end,
    latest.status
  from latest;
$$;

revoke all on function public.subscription_entitlement(text) from public, anon, authenticated;
-- Explicit, because the REVOKE above also removes PUBLIC's default EXECUTE
-- that service_role would otherwise inherit.
grant execute on function public.subscription_entitlement(text) to service_role;
