-- ============================================================
-- MIGRATION: Home wallpaper + Featured Playlists + chip styling
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor) once.
--
-- Three additive pieces, all admin-managed from the admin portal:
--
--   1. `app_settings`  - a tiny key/value table holding the home-screen
--      wallpaper URL (key = 'home_wallpaper_url'). Key/value rather than a
--      dedicated table so future single-value app settings need no migration.
--
--   2. `featured_playlists` - the round deity chips shown under the home
--      carousel ("Venkateswara", "Krishna", "Ganesha", ...). Each chip carries
--      its own label, the keyword used to pick its tracks, a gradient/color,
--      an icon name, and a sort order. When the table is empty the app falls
--      back to its built-in defaults, so an un-migrated project keeps working.
--
--   3. A `banner_url`-style cover for each featured chip is NOT stored here:
--      the round chip is a colored circle with a glyph, matching the design.
--
-- Every column is nullable with a safe default, every table is additive, and
-- every reader degrades to the previous behaviour when a row (or the whole
-- table) is absent. Only the admin (service role, which bypasses RLS) writes.
-- ============================================================

-- ------------------------------------------------------------------
-- 1. Key/value app settings (home wallpaper)
-- ------------------------------------------------------------------
create table if not exists public.app_settings (
    key         text primary key,
    value       text,
    updated_at  timestamp with time zone default now()
);

alter table public.app_settings enable row level security;

-- Public read: the home screen needs the wallpaper without a session.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'app_settings'
      and policyname = 'App settings are publicly readable'
  ) then
    create policy "App settings are publicly readable"
      on public.app_settings for select using (true);
  end if;
end $$;

-- No insert/update/delete policy: the service role bypasses RLS and is the
-- only writer.

-- Seed the wallpaper key as an explicit empty string so "no wallpaper" is
-- unambiguous (NULL and '' both mean unset; readers treat them the same).
insert into public.app_settings (key, value)
values ('home_wallpaper_url', '')
on conflict (key) do nothing;

-- ------------------------------------------------------------------
-- 2. Featured Playlists (the round chips)
-- ------------------------------------------------------------------
create table if not exists public.featured_playlists (
    id          text primary key,
    title       text not null,
    -- Comma-separated keywords matched against a track's title/album/artists
    -- with the same word-start rule the Specials shelves use.
    keywords    text not null default '',
    -- Two hex colors for the chip's gradient ('#RRGGBB'), or NULL to use the
    -- app's theme primary. The server validates the format.
    color_from  text,
    color_to    text,
    -- Name of the glyph to draw inside the circle. The app maps this to a
    -- bundled icon and falls back to a generic one for unknown names.
    icon        text,
    sort_order  integer,
    is_hidden   boolean not null default false,
    created_at  timestamp with time zone default now(),
    updated_at  timestamp with time zone default now()
);

alter table public.featured_playlists
  add column if not exists keywords    text not null default '',
  add column if not exists color_from  text,
  add column if not exists color_to    text,
  add column if not exists icon        text,
  add column if not exists sort_order  integer,
  add column if not exists is_hidden   boolean not null default false,
  add column if not exists updated_at  timestamp with time zone default now();

alter table public.featured_playlists enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'featured_playlists'
      and policyname = 'Featured playlists are publicly readable'
  ) then
    create policy "Featured playlists are publicly readable"
      on public.featured_playlists for select using (true);
  end if;
end $$;

-- Guard the two colors at the database level (the server validates too).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'featured_playlists_color_from_hex'
  ) then
    alter table public.featured_playlists
      add constraint featured_playlists_color_from_hex
      check (color_from is null or color_from ~ '^#[0-9a-fA-F]{6}$');
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'featured_playlists_color_to_hex'
  ) then
    alter table public.featured_playlists
      add constraint featured_playlists_color_to_hex
      check (color_to is null or color_to ~ '^#[0-9a-fA-F]{6}$');
  end if;
end $$;

-- ------------------------------------------------------------------
-- 3. Wallpaper: allow the admin to store it in the same key/value table.
--    (No schema change needed beyond the table above; documented here so the
--    intent of the 'home_wallpaper_url' key is discoverable.)
-- ------------------------------------------------------------------

-- ------------------------------------------------------------------
-- Verify: expect 2 new tables and the seeded wallpaper key.
-- ------------------------------------------------------------------
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('app_settings', 'featured_playlists')
order by table_name;

select key, value from public.app_settings order by key;
