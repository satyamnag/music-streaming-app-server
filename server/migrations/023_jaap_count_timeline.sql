-- ============================================================
-- MIGRATION: Jaap count timeline (timed counting cues)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds `count_timeline` to public.jaap_chants: an optional SRT of COUNT cues —
-- each cue's start time represents ONE repetition. When the app plays the
-- japa with 'Auto count' on, the counter increments once per cue start,
-- perfectly synced to the audio. Fully additive — everything else untouched.
-- ============================================================

alter table public.jaap_chants
  add column if not exists count_timeline text;

comment on column public.jaap_chants.count_timeline is
  'Optional SRT whose cue start times each count one repetition (auto-count).';

-- ------------------------------------------------------------------
-- Verify (expect one row: count_timeline)
-- ------------------------------------------------------------------
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'jaap_chants' and column_name = 'count_timeline';