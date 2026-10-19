-- ============================================================
-- MIGRATION: Auto-Sync write backup columns
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds rollback support for the Auto-Sync write path.
--
-- WHY: the write path (POST /api/admin/tracks/:id/auto-sync?write=true)
-- stores machine-generated timings into the five synced_lyrics* columns.
-- Even gated on a full-confidence alignment, that is still machine output
-- replacing whatever was there before. Without a stored copy of the previous
-- value, a bad write is unrecoverable.
--
-- These columns hold the SRT text exactly as it was BEFORE the write, so
-- POST /api/admin/tracks/:id/auto-sync/rollback/:runId can restore it, and a
-- human can always reconstruct what a run replaced.
--
-- Additive and safe: new nullable columns on an audit-only table. Nothing
-- that reads `tracks` is affected, and rows written before this migration
-- simply have NULL backups (meaning "nothing was overwritten").
-- ============================================================

alter table public.lyric_auto_sync_runs
  add column if not exists wrote_to_tracks boolean not null default false,
  add column if not exists previous_srt jsonb,
  add column if not exists written_columns text[],
  add column if not exists rolled_back_at timestamptz;

-- Finding a run to roll back is by track + recency, so index that path.
create index if not exists lyric_auto_sync_runs_written_idx
  on public.lyric_auto_sync_runs (track_id, created_at desc)
  where wrote_to_tracks;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'lyric_auto_sync_runs'
  and column_name in ('wrote_to_tracks', 'previous_srt', 'written_columns', 'rolled_back_at')
order by column_name;
