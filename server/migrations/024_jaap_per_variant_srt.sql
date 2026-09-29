-- ============================================================
-- MIGRATION: Per-variant jaap SRT (lyrics + count timeline)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Each repetition variant (11x / 21x / 1 Mala / 10 Malas) may carry its OWN
-- lyrics SRT and its OWN count timeline, because every audio variant has a
-- different length and repetition count. Columns are optional overrides:
-- when a variant has none, the shared srt / count_timeline columns are used
-- (existing data keeps working). Fully additive — nothing else changes.
-- ============================================================

alter table public.jaap_chants
  add column if not exists srt_11 text,
  add column if not exists srt_21 text,
  add column if not exists srt_108 text,
  add column if not exists srt_1080 text,
  add column if not exists count_timeline_11 text,
  add column if not exists count_timeline_21 text,
  add column if not exists count_timeline_108 text,
  add column if not exists count_timeline_1080 text;

comment on column public.jaap_chants.srt_11 is 'Lyrics SRT specific to the 11x variant (falls back to srt).';
comment on column public.jaap_chants.srt_21 is 'Lyrics SRT specific to the 21x variant (falls back to srt).';
comment on column public.jaap_chants.srt_108 is 'Lyrics SRT specific to the 1 Mala variant (falls back to srt).';
comment on column public.jaap_chants.srt_1080 is 'Lyrics SRT specific to the 10 Malas variant (falls back to srt).';
comment on column public.jaap_chants.count_timeline_11 is 'Count timeline for the 11x variant (falls back to count_timeline).';
comment on column public.jaap_chants.count_timeline_21 is 'Count timeline for the 21x variant (falls back to count_timeline).';
comment on column public.jaap_chants.count_timeline_108 is 'Count timeline for the 1 Mala variant (falls back to count_timeline).';
comment on column public.jaap_chants.count_timeline_1080 is 'Count timeline for the 10 Malas variant (falls back to count_timeline).';

-- ------------------------------------------------------------------
-- Verify (expect 8 rows)
-- ------------------------------------------------------------------
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'jaap_chants'
  and column_name like 'srt\_%' or (table_schema = 'public' and table_name = 'jaap_chants' and column_name like 'count%timeline\_%')
order by column_name;