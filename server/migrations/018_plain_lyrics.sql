-- ============================================================
-- MIGRATION: Per-language PLAIN lyrics columns
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds one PLAIN (non-timed) lyrics column per language so the admin can
-- store plain lyrics for any language via the nested Plain/Sync editor.
-- Additive and safe: the app keeps deriving its plain view from synced
-- variants, and these nullable columns are simply stored. Existing `lyrics`
-- (derived plain) and `synced_lyrics_*` (LRC) are unchanged.
-- ============================================================

alter table public.tracks
  add column if not exists plain_lyrics text,
  add column if not exists plain_lyrics_en text,
  add column if not exists plain_lyrics_hi text,
  add column if not exists plain_lyrics_en_tr text,
  add column if not exists plain_lyrics_hi_tr text;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='tracks'
  and column_name in ('plain_lyrics','plain_lyrics_en','plain_lyrics_hi','plain_lyrics_en_tr','plain_lyrics_hi_tr');
