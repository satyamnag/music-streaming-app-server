-- ============================================================
-- MIGRATION: Allow a song to appear in MULTIPLE albums
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Business model:
--   * A single song can now be part of many admin-created albums.
--   * `tracks.album_id` remains (nullable) as the "primary" album so the
--     legacy single-album UI, home grouping and the existing app flows keep
--     working exactly as before.
--   * The new `album_songs` join table records every album membership
--     (many-to-many) and the display order (position) within each album.
--
-- This is additive and safe: if you do not run it, the app keeps behaving
-- exactly as before (single album per song, grouped by tracks.album_id).
-- ============================================================

-- ------------------------------------------------------------------
-- 1) album_songs: many-to-many membership with per-album order.
--    Deleting an album or a track removes its rows here (cascade).
-- ------------------------------------------------------------------
create table if not exists public.album_songs (
  album_id uuid not null references public.albums(id) on delete cascade,
  track_id uuid not null references public.tracks(id) on delete cascade,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (album_id, track_id)
);

alter table public.album_songs enable row level security;

-- Publicly readable (same as `albums` and `tracks`): the on-device local
-- server reads it through the anon key. Writes stay admin-only. Idempotent:
-- drop-then-create makes re-running the migration safe.
drop policy if exists "album_songs are publicly readable" on public.album_songs;
create policy "album_songs are publicly readable"
  on public.album_songs
  for select
  using (true);

create index if not exists album_songs_album_idx on public.album_songs (album_id, position);
create index if not exists album_songs_track_idx on public.album_songs (track_id);

-- ------------------------------------------------------------------
-- 2) Backfill: existing tracks that already have a primary album_id
--    become members of that album at position 0. No-op if empty.
-- ------------------------------------------------------------------
insert into public.album_songs (album_id, track_id, position, created_at)
select t.album_id, t.id, coalesce(t.featured_order, 0)::int, now()
from public.tracks t
where t.album_id is not null
on conflict (album_id, track_id) do nothing;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='album_songs';
