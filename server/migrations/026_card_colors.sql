-- ============================================================
-- MIGRATION: Per-track and per-album card colors
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor) once.
--
-- Adds two optional color columns to BOTH `tracks` and `albums`:
--   card_bg_color    -> the card/box background color behind the cover art
--   card_text_color  -> the color used for the card's text (track name /
--                       album name / track count / "N songs")
--
-- Values are stored as `#RRGGBB` (lowercase hex), or NULL meaning "unset",
-- in which case the app keeps its default theme colors. The admin portal
-- paints these live; the Android app and the web app read them so a color
-- chosen in the admin panel shows up on every surface without a rebuild.
--
-- Additive and safe: both columns are nullable with no default, so existing
-- rows keep working and every reader falls back to the current appearance.
-- No RLS change is needed: `tracks` and `albums` are already publicly
-- readable, and only the admin (service role) writes these columns.
-- ============================================================

alter table public.tracks
  add column if not exists card_bg_color   text,
  add column if not exists card_text_color text;

alter table public.albums
  add column if not exists card_bg_color   text,
  add column if not exists card_text_color text;

-- ------------------------------------------------------------------
-- Guard the format at the database level so a bad value can never be
-- written (the server validates too; this is defence in depth).
-- NULL stays allowed because "unset" is the default appearance.
-- ------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'tracks_card_bg_color_hex'
  ) then
    alter table public.tracks
      add constraint tracks_card_bg_color_hex
      check (card_bg_color is null or card_bg_color ~ '^#[0-9a-fA-F]{6}$');
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'tracks_card_text_color_hex'
  ) then
    alter table public.tracks
      add constraint tracks_card_text_color_hex
      check (card_text_color is null or card_text_color ~ '^#[0-9a-fA-F]{6}$');
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'albums_card_bg_color_hex'
  ) then
    alter table public.albums
      add constraint albums_card_bg_color_hex
      check (card_bg_color is null or card_bg_color ~ '^#[0-9a-fA-F]{6}$');
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'albums_card_text_color_hex'
  ) then
    alter table public.albums
      add constraint albums_card_text_color_hex
      check (card_text_color is null or card_text_color ~ '^#[0-9a-fA-F]{6}$');
  end if;
end $$;

-- ------------------------------------------------------------------
-- Verify: expect 4 rows (2 per table).
-- ------------------------------------------------------------------
select table_name, column_name
from information_schema.columns
where table_schema = 'public'
  and column_name in ('card_bg_color', 'card_text_color')
  and table_name in ('tracks', 'albums')
order by table_name, column_name;
