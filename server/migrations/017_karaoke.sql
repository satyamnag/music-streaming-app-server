-- ============================================================
-- MIGRATION: Karaoke track variant
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds `karaoke_storage_path` to `tracks`: the storage-path of an optional
-- Karaoke version of the song. When set, the app offers an "Original" /
-- "Karaoke" choice on the player. Null means no karaoke version (the player
-- shows only the original). Additive and safe — existing tracks are
-- unaffected.
-- ============================================================

alter table public.tracks
  add column if not exists karaoke_storage_path text;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='tracks' and column_name='karaoke_storage_path';
