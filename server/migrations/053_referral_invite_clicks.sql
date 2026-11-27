-- ============================================================
-- MIGRATION 053: clicks on a subscriber's short invite link
-- Run this in the Supabase SQL editor.
--
-- WHY
--   Every subscriber now gets a short invite link, https://soulfulbhakti.com/i/<CODE>
--   (the web app forwards it to the API's /r/<CODE>, which validates the code and
--   302s to the Play Store with the code in the install referrer). Recording the
--   click gives the affiliate report a leading indicator: how many people opened
--   the link, before any of them installs and signs in.
--
-- WHAT THIS ADDS
--   * `referral_invite_clicks` - one row per visit: the code, the path, the time.
--     No IP, no user agent, no other PII.
--
-- SAFETY
--   * Additive only: one table, one index. No DROP/DELETE/UPDATE/ALTER of
--     anything that already exists.
--   * RLS with no policy plus an explicit REVOKE: only the service role can read
--     or write it, exactly like the channel click log.
-- ============================================================

create table if not exists public.referral_invite_clicks (
  id          uuid primary key default gen_random_uuid(),
  code        text not null,
  source_path text,
  created_at  timestamptz not null default now()
);

create index if not exists referral_invite_clicks_code_idx
  on public.referral_invite_clicks (code, created_at desc);

alter table public.referral_invite_clicks enable row level security;
revoke all on public.referral_invite_clicks from anon, authenticated;
grant select, insert on public.referral_invite_clicks to service_role;

-- ------------------------------------------------------------------
-- CONFIRM (read-only)
-- ------------------------------------------------------------------
select tablename from pg_tables
where schemaname = 'public' and tablename = 'referral_invite_clicks';

select indexname from pg_indexes
where schemaname = 'public' and indexname = 'referral_invite_clicks_code_idx';
