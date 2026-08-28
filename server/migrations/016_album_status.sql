-- ============================================================
-- MIGRATION: Album paid/free (lock) status
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds a `status` column to `albums`, identical in meaning to the existing
-- `status` column on `tracks`: `'free'` (default, always playable) or `'paid'`
-- (locked for free users; shown with a lock + gated behind sign-in/paywall).
-- Additive and safe: existing albums default to `free` and keep working.
-- ============================================================

alter table public.albums
  add column if not exists status text not null default 'free';

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='albums' and column_name='status';
