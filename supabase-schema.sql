-- Run this in your Supabase SQL Editor
-- Creates the tracks table, storage bucket, and access policies

create extension if not exists pg_trgm;

-- Tracks metadata table
create table tracks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  artist_names text[] not null default '{}',
  artist_names_text text not null default '',
  album text not null default '',
  duration integer not null default 0,
  thumbnail text,
  storage_path text not null,
  status text not null default 'free' check (status in ('free', 'paid')),
  lyrics text,
  synced_lyrics text,
  created_at timestamptz not null default now()
);

create index idx_tracks_title on tracks using gin (title gin_trgm_ops);
create index idx_tracks_artist on tracks using gin (artist_names_text gin_trgm_ops);

alter table tracks enable row level security;

create policy "Allow public read"
  on tracks for select
  using (true);

-- Storage bucket for audio files (private; streamed via signed URLs)
insert into storage.buckets (id, name, public)
values ('music', 'music', false)
on conflict (id) do nothing;

-- Storage bucket for public thumbnail images
insert into storage.buckets (id, name, public)
values ('thumbnails', 'thumbnails', true)
on conflict (id) do nothing;

-- Allow service role (used by Express server) full access to the bucket
create policy "Service role full access to music bucket"
  on storage.objects for all
  to service_role
  using (bucket_id = 'music')
  with check (bucket_id = 'music');

-- ============================================================
-- MIGRATION: track premium status (run once on existing DBs)
-- Adds `status` to distinguish free tracks from paid (premium)
-- tracks. Paid tracks are locked for free users and unlocked for
-- signed-in subscribers. Run this in the Supabase SQL Editor.
-- ============================================================
alter table tracks
  add column if not exists status text not null default 'free'
  check (status in ('free', 'paid'));

-- Mark the two premium tracks as paid. Update this list as the
-- catalog grows. Free users cannot play these without a subscription.
update tracks set status = 'paid'
where title in ('Sati Neku Yevaru', 'Edu Varike Vintha Vinta');

-- ============================================================
-- MIGRATION: Lyrics (plain) + synced lyrics (LRC) columns
-- Run this in the Supabase SQL Editor on existing DBs.
-- `lyrics` holds the plain lyric text (line-separated).
-- `synced_lyrics` holds the timestamped LRC format.
-- ============================================================
alter table tracks
  add column if not exists lyrics text;
alter table tracks
  add column if not exists synced_lyrics text;
