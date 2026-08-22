-- ============================================================
-- MIGRATION: Synced-lyrics TRANSLITERATION columns (English & Hindi)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor) once.
--
-- The admin "Add Sync Lyrics" editor auto-fills, via the "Update
-- Translation & Transliteration" button:
--   * synced_lyrics_en / synced_lyrics_hi  -> Google Cloud Translation
--   * synced_lyrics_en_tr                  -> Google Transliteration (Latin)
--   * synced_lyrics_hi_tr                  -> Google Transliteration (Devanagari)
--
-- The Flutter client only consumes `synced_lyrics` (the main/Telugu LRC),
-- so these columns are ignored by the app and this change is non-breaking.
-- ============================================================

alter table tracks add column if not exists synced_lyrics_en_tr text;
alter table tracks add column if not exists synced_lyrics_hi_tr text;