-- ============================================================
-- MIGRATION: Track language (multi-language categorization)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds a `language` column to tracks so songs can be tagged with
-- their language (e.g. Telugu, Kannada, Hindi, Tamil, Sanskrit).
-- The app groups same-language songs into "All <Language> Songs"
-- albums (derived dynamically; no separate table needed).
-- ============================================================

-- 1) Add the language column. Nullable so existing rows are untouched
--    until the admin tags them; unknown/empty language is skipped when
--    building the "All ... Songs" albums.
alter table public.tracks
  add column if not exists language text;

-- 2) Index for fast filtering/grouping by language.
create index if not exists tracks_language_idx
  on public.tracks (language);

-- 3) Verify
select id, title, album, language from public.tracks order by created_at;
