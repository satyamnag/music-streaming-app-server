-- ============================================================
-- MIGRATION: Jaap audio variants + shared metadata
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Extends public.jaap_chants so an admin can manage a jaap's AUDIO:
--   * four repetition variants ("Daily Prayers" 11x / 21x, "1 Mala" 108x,
--     "10 Malas" 1080x), each an .opus file hosted on Cloudflare R2
--     (audio_11 / audio_21 / audio_108 / audio_1080 hold the R2 keys)
--   * one shared cover image (cover_url, a Supabase thumbnails public URL)
--   * one shared SRT / synced-lyrics text (srt)
--   * updated_at so the panel can see when a jaap was last touched
--
-- Fully additive: existing columns (name, chant_text, default_target,
-- sort_order, status, created_at) and the public SELECT-only RLS policy are
-- unchanged, so the existing jaap-counter apps keep working untouched.
-- ============================================================

alter table public.jaap_chants
  add column if not exists cover_url text,
  add column if not exists srt text,
  add column if not exists audio_11 text,
  add column if not exists audio_21 text,
  add column if not exists audio_108 text,
  add column if not exists audio_1080 text,
  add column if not exists updated_at timestamptz not null default now();

comment on column public.jaap_chants.cover_url is 'Shared cover image (Supabase thumbnails public URL).';
comment on column public.jaap_chants.srt is 'Shared SRT / synced lyrics text for all audio variants.';
comment on column public.jaap_chants.audio_11 is 'R2 key of the Daily Prayers 11x audio (.opus).';
comment on column public.jaap_chants.audio_21 is 'R2 key of the Daily Prayers 21x audio (.opus).';
comment on column public.jaap_chants.audio_108 is 'R2 key of the 1 Mala (108x) audio (.opus).';
comment on column public.jaap_chants.audio_1080 is 'R2 key of the 10 Malas (1080x) audio (.opus).';

-- ------------------------------------------------------------------
-- Verify (expect the 7 new columns below)
-- ------------------------------------------------------------------
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'jaap_chants'
  and column_name in ('cover_url','srt','audio_11','audio_21','audio_108','audio_1080','updated_at')
order by column_name;