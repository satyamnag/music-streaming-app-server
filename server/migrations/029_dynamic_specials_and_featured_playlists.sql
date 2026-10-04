-- ============================================================
-- MIGRATION: make Specials and Featured Playlists fully admin-driven
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor) once.
--
-- Both home-screen catalogues used to be HARDCODED in the app and mirrored in
-- the admin panel, with membership decided by keyword matching only:
--   * app:  lib/modules/home/sections/specials.dart          (_specialDefinitions, 10 shelves)
--   * app:  lib/modules/home/sections/featured_playlists.dart (_defaultChips, 6 chips)
--   * admin: SPECIAL_SHELVES and FEATURED_CHIPS in admin.html
--
-- This migration makes the database the only source of truth and lets the admin
-- choose exactly which tracks belong to each shelf and each playlist:
--
--   1. `specials` gains `keywords` + `match_keywords`, so a shelf's automatic
--      matching rule is data rather than code.
--   2. `featured_playlists` gains `icon_url` (an admin-uploaded chip icon; the
--      glyph name in `icon` stays as the fallback) and `match_keywords`.
--   3. `special_tracks` and `featured_playlist_tracks` hold the EXPLICIT,
--      ordered membership the admin picks by hand. They mirror `album_songs`:
--      composite primary key, `position` for ordering, cascade on delete,
--      publicly readable (the app reads them with the anon key).
--   4. The 10 shelves and 6 chips that used to be hardcoded are SEEDED here, so
--      removing the built-in lists changes nothing on screen. The seeds carry
--      `match_keywords = true` (the column default) and no explicit tracks,
--      which reproduces today's keyword-driven membership exactly.
--
-- Membership rule the app applies, per shelf/playlist:
--     effective tracks = the explicit list (in `position` order)
--                        plus tracks matching `keywords`, when match_keywords
--     so a row can be run purely by hand (match_keywords = false), purely by
--     rule, or a mix of both.
--
-- Additive and idempotent: every statement is `if not exists` / `on conflict do
-- nothing`, so re-running this file is safe.
-- ============================================================

-- ------------------------------------------------------------------
-- 1. specials: keyword rule becomes data
-- ------------------------------------------------------------------
alter table public.specials
  add column if not exists keywords       text,
  add column if not exists match_keywords boolean not null default true;

-- ------------------------------------------------------------------
-- 2. featured_playlists: admin-uploaded icon + keyword toggle
-- ------------------------------------------------------------------
alter table public.featured_playlists
  add column if not exists icon_url       text,
  add column if not exists match_keywords boolean not null default true;

-- ------------------------------------------------------------------
-- 3. Explicit, ordered track membership (mirrors album_songs)
-- ------------------------------------------------------------------
create table if not exists public.special_tracks (
    special_id  text not null references public.specials(id) on delete cascade,
    track_id    uuid not null references public.tracks(id)   on delete cascade,
    position    integer not null default 0,
    created_at  timestamp with time zone default now(),
    primary key (special_id, track_id)
);

create index if not exists special_tracks_order_idx
  on public.special_tracks (special_id, position);

create table if not exists public.featured_playlist_tracks (
    playlist_id text not null references public.featured_playlists(id) on delete cascade,
    track_id    uuid not null references public.tracks(id)            on delete cascade,
    position    integer not null default 0,
    created_at  timestamp with time zone default now(),
    primary key (playlist_id, track_id)
);

create index if not exists featured_playlist_tracks_order_idx
  on public.featured_playlist_tracks (playlist_id, position);

-- RLS ON plus a public SELECT policy, exactly like `specials` (027) and
-- `featured_playlists` (028).
--
-- The SELECT policy is NOT optional here: the app reads this catalogue through
-- the ANON key (see `supabaseClientProvider` in
-- lib/provider/server/routes/supabase_data.dart, which builds its client from
-- Env.supabaseAnonKey). With RLS on and no policy, PostgREST answers a SELECT
-- with 200 and an EMPTY list rather than an error, so the hand-picked track
-- lists would silently vanish on the home screen while every check still looked
-- green. Writes stay service-role-only: no insert/update/delete policy is
-- granted to anon or authenticated, and the admin server bypasses RLS.
alter table public.special_tracks            enable row level security;
alter table public.featured_playlist_tracks  enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'special_tracks'
      and policyname = 'Special tracks are publicly readable'
  ) then
    create policy "Special tracks are publicly readable"
      on public.special_tracks for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'featured_playlist_tracks'
      and policyname = 'Featured playlist tracks are publicly readable'
  ) then
    create policy "Featured playlist tracks are publicly readable"
      on public.featured_playlist_tracks for select using (true);
  end if;
end $$;

-- ------------------------------------------------------------------
-- 4a. Seed the 10 shelves that used to live in _specialDefinitions
--     (title/subtitle/keywords copied verbatim, so the same tracks match)
-- ------------------------------------------------------------------
insert into public.specials (id, title, subtitle, keywords, sort_order) values
  ('soulful-bhakti', 'Soulful Bhakti Special', 'Devotional favourites across every deity',
   'bhakti,bhajan,devotional,soulful', 0),
  ('ganesha', 'Ganesha Special', 'Vinayaka chants and songs',
   'ganesh,ganesha,ganapati,ganapathi,vinayaka,vighnesh,vignesh,gajanana,gajanand,vakratunda,ekadanta,lambodara', 1),
  ('venkateswara', 'Venkateswara Special', 'Balaji and Govinda songs',
   'venkateswara,venkateshwara,balaji,govinda,tirupati,srinivasa,govind', 2),
  ('krishna', 'Krishna Special', 'Krishna bhajans and kirtans',
   'krishna,govardhan,radha,murali,gopala,madhav,keshav', 3),
  ('rama', 'Rama Special', 'Rama bhajans and stotras',
   'rama,sita,hanuman,ayodhya,raghu,rama raksha', 4),
  ('shiva', 'Shiva Special', 'Shiva chants and stotras',
   'shiva,siva,mahadev,parvati,rudra,linga,kailash,shankar', 5),
  ('lakshmi', 'Lakshmi Special', 'Lakshmi and wealth stotras',
   'lakshmi,laxmi,ashtalakshmi,kanakadhara,wealth,shree,mahalakshmi,mahalaxmi,sri lakshmi,dhana', 6),
  ('vishnu', 'Vishnu Special', 'Vishnu sahasranamam and more',
   'vishnu,narayana,hari,sahasranama,sahasranamam,anantha,padmanabha', 7),
  ('parvati', 'Parvati Special', 'Devi and Shakti songs',
   'parvati,durga,devi,shakti,ambika,bhavani,mata,kaali,kali', 8),
  ('ganga', 'Ganga Special', 'Ganga and Gange stotras',
   'ganga,gange,ganges,bhagirathi,ganga maiya', 9)
on conflict (id) do nothing;

-- ------------------------------------------------------------------
-- 4b. Seed the 6 chips that used to live in _defaultChips
-- ------------------------------------------------------------------
insert into public.featured_playlists
  (id, title, keywords, color_from, color_to, icon, sort_order) values
  ('venkateswara', 'Venkateswara',
   'venkateswara,venkateshwara,balaji,govinda,govind,tirupati,srinivasa,niluvadu',
   '#f2a33c', '#d97706', 'temple', 0),
  ('krishna', 'Krishna',
   'krishna,govardhan,radha,murali,gopala,madhav,keshav,gopika',
   '#3b82f6', '#1d4ed8', 'flute', 1),
  ('ganesha', 'Ganesha',
   'ganesh,ganesha,ganapati,ganapathi,vinayaka,vighnesh,vignesh,gajanana,gajanand,vakratunda,ekadanta,lambodara',
   '#ef4444', '#b91c1c', 'ganesha', 2),
  ('rama', 'Rama',
   'rama,sita,hanuman,ayodhya,raghu,rama raksha',
   '#fb923c', '#ea580c', 'bow', 3),
  ('devi', 'Devi',
   'devi,durga,lakshmi,laxmi,parvati,shakti,ambika,bhavani,kaali,kali,mahalakshmi,mahalaxmi',
   '#ec4899', '#be185d', 'lotus', 4),
  ('chants', 'Chants',
   'mantra,mantram,stotram,stotra,ashtakam,sahasranama,sahasranamam,suprabhatam,sloka,shloka,om,chants',
   '#8b5cf6', '#6d28d9', 'om', 5)
on conflict (id) do nothing;

-- ------------------------------------------------------------------
-- Verify: expect 2 new membership tables, 10 specials and 6 playlists.
-- ------------------------------------------------------------------
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('special_tracks', 'featured_playlist_tracks')
order by table_name;

select
  (select count(*) from public.specials)            as specials_rows,
  (select count(*) from public.featured_playlists)  as playlists_rows,
  (select count(*) from public.special_tracks)      as special_track_rows,
  (select count(*) from public.featured_playlist_tracks) as playlist_track_rows;
