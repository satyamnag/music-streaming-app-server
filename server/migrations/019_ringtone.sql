-- ============================================================
-- MIGRATION: Per-track ringtone file
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds `ringtone_storage_path` to `tracks`: the R2 object key of the song's
-- ringtone clip. Android's RingtoneManager accepts MP3/OGG/WAV/M4A but NOT
-- .opus, so this is deliberately a separate file from the streamed original.
-- Null means "no ringtone available for this track"; the player then hides the
-- ringtone action for that track.
--
-- Additive and safe - existing tracks are unaffected.
-- ============================================================

alter table public.tracks
  add column if not exists ringtone_storage_path text;

-- ------------------------------------------------------------------
-- Verify (expect exactly one row: ringtone_storage_path)
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema = 'public'
  and table_name = 'tracks'
  and column_name = 'ringtone_storage_path';
