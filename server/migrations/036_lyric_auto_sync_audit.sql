-- ============================================================
-- MIGRATION: Auto-Sync Lyrics audit trail
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Records every admin "Auto-Sync Lyrics" attempt and its outcome.
--
-- WHY: the feature can refuse to write anything (which is its normal,
-- expected behaviour), and it can also be asked to overwrite a track whose
-- existing synced lyrics were hand-timed. Both are decisions that must be
-- auditable after the fact — "who ran this, on which track, against which
-- audio object, and what did it decide?" — without relying on server logs
-- that the hosting platform may rotate away.
--
-- Additive and safe: a new table only. No existing column, row or policy is
-- touched, so nothing that currently reads `tracks` is affected.
-- ============================================================

create table if not exists public.lyric_auto_sync_runs (
  id                bigserial primary key,

  track_id          uuid not null,
  track_title       text,

  -- The exact audio object the transcript came from. Recorded because the
  -- single most dangerous failure mode is aligning against the WRONG audio
  -- file, and this is the only way to prove after the fact which one was used.
  storage_path      text,
  storage_sha256    text,

  -- What asked for the run.
  requested_by      text,
  model             text,
  language          text,

  -- The decision. `accepted` is true only when the propose-only gate passed
  -- for EVERY line; nothing is written to `tracks` otherwise.
  accepted          boolean not null default false,
  reason            text,
  match_rate        numeric(5,4),
  overall_confidence numeric(5,4),
  line_total        integer,
  line_placed       integer,

  -- Per-line detail (index, text, start, end, confidence, whether it was
  -- placed). Kept as jsonb so a reviewer can reconstruct exactly why a run was
  -- refused without re-calling a paid API.
  lines             jsonb,

  -- Full raw Deepgram word list, so a later accuracy review is possible
  -- without paying for the same transcription twice.
  transcript_words  jsonb,

  audio_duration    numeric(10,3),
  api_cost_note     text,

  created_at        timestamptz not null default now()
);

create index if not exists lyric_auto_sync_runs_track_idx
  on public.lyric_auto_sync_runs (track_id, created_at desc);

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'lyric_auto_sync_runs'
order by ordinal_position;
