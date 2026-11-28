-- ============================================================
-- MIGRATION 054: five more channel links
--   WhatsApp, Pinterest, LinkedIn, TikTok, Email Marketing
-- Run this in the Supabase SQL editor.
--
-- WHAT THIS CHANGES
--   1. The click log's channel CHECK is widened to the eight channels. It is
--      widened by REPLACING THE CONSTRAINT: Postgres has no "alter constraint"
--      for a CHECK, so the old check is dropped and an equivalent, wider one is
--      added in the same statement batch. NO ROW IS TOUCHED, no table, column or
--      index is dropped, and the whole file runs as one transaction - if any
--      statement fails, nothing changes.
--      (Supabase may warn that the script contains a destructive statement:
--       that warning is triggered by `drop constraint`. The dropped object is a
--       validation rule that is immediately re-created wider, not data.)
--   2. Five brand codes are seeded, exactly like the first three: they belong to
--      `channel_*` identities that can never be an active subscriber, so the
--      existing credit rule refuses to pay ₹51 on them by construction - there is
--      no new money rule and nothing to switch off.
--
-- WHAT IS DELIBERATELY UNCHANGED
--   * `admin_channel_summary()` needs no edit: it lists every row in
--     referral_codes where is_channel, so the new channels appear in the admin
--     report automatically, with the same clicks / sign-ups / paid / revenue.
--   * The first three channels and their codes keep working exactly as before.
--
-- SAFETY
--   * Idempotent: re-running changes nothing (constraint replaced, codes
--     upserted by their unique code).
--   * No PII: the click log still stores only channel, code, path and time.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Widen the channel CHECK to the eight channels.
--    Only check constraints that mention `channel` are touched.
-- ------------------------------------------------------------------
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.referral_channel_clicks'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%channel%'
  loop
    execute format('alter table public.referral_channel_clicks drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.referral_channel_clicks
  add constraint referral_channel_clicks_channel_check
  check (channel in (
    'facebook', 'instagram', 'youtube',
    'whatsapp', 'pinterest', 'linkedin', 'tiktok', 'email'
  ));

-- ------------------------------------------------------------------
-- 2) Seed the five new brand codes. Each `channel_*` identity is not a Clerk
--    user, so it can never satisfy "referrer must be an active subscriber".
-- ------------------------------------------------------------------
insert into public.referral_codes (user_id, code, channel, is_channel) values
  ('channel_whatsapp',  'SBWAORG',  'whatsapp',  true),
  ('channel_pinterest', 'SBPINORG', 'pinterest', true),
  ('channel_linkedin',  'SBLINORG', 'linkedin',  true),
  ('channel_tiktok',    'SBTIKORG', 'tiktok',    true),
  ('channel_email',     'SBEMAILORG', 'email',   true)
on conflict (code) do update
  set channel = excluded.channel,
      is_channel = true;

-- ------------------------------------------------------------------
-- CONFIRM (read-only)
-- ------------------------------------------------------------------
select code, channel, is_channel
from public.referral_codes
where is_channel
order by channel;

select conname as channel_check, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.referral_channel_clicks'::regclass and contype = 'c';
