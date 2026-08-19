-- ============================================================
-- MIGRATION: Admin-created albums
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Business model:
--   * An album is a named collection with a cover photo, created by the
--     admin. Tracks are assigned to an album via a dropdown in the admin
--     track form (tracks.album_id FK).
--   * Albums created here are shown under the home "Albums" component
--     alongside the existing auto-grouped albums (grouped by the track's
--     legacy `album` text column).
--   * Clicking an album plays its assigned tracks from first to last.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Albums: admin-created named collections with a cover photo.
-- ------------------------------------------------------------------
create table if not exists public.albums (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cover_url text,                 -- cover photo URL (R2/CDN or thumbnail)
  created_at timestamptz not null default now()
);

alter table public.albums enable row level security;

-- No user-facing policies: album data is admin-managed (service role
-- bypasses RLS). Read-only access for the app flows through the local
-- server (service role), not the anon key.

create index if not exists albums_created_idx on public.albums (created_at desc);

-- ------------------------------------------------------------------
-- 2) Associate tracks with an album. Nullable so existing tracks
--    (without an admin album) keep working exactly as before.
-- ------------------------------------------------------------------
alter table public.tracks
  add column if not exists album_id uuid references public.albums(id) on delete set null;

create index if not exists tracks_album_id_idx on public.tracks (album_id);

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='albums';

select column_name from information_schema.columns
where table_schema='public' and table_name='tracks' and column_name='album_id';
