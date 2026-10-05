-- ============================================================
-- MIGRATION: Per-track mini player background colour
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor) once.
--
-- Adds ONE optional colour column to `tracks`:
--   miniplayer_bg_color -> the background colour of the compact mini player
--                          while that track is the active one
--
-- Stored as `#RRGGBB` (any case), or NULL meaning "unset", in which case the
-- mini player keeps its current appearance (the theme's card surface at the
-- configured opacity over a blur). The admin portal paints it live; the Android
-- app reads it so a colour chosen in the admin panel shows up without a rebuild.
--
-- Why a separate column rather than reusing `card_bg_color`: the two answer
-- different questions. `card_bg_color` is the tile the track sits on inside a
-- grid or shelf; this is the bar at the bottom of the screen while the track is
-- playing. A track can reasonably want one and not the other, and reusing the
-- card colour would silently repaint every mini player whose track already has a
-- card colour.
--
-- Additive and safe: the column is nullable with no default, so existing rows keep
-- working and the reader falls back to today's appearance. No RLS change is
-- needed: `tracks` is already publicly readable and only the admin (service role)
-- writes it.
-- ============================================================

alter table public.tracks
  add column if not exists miniplayer_bg_color text;

-- ------------------------------------------------------------------
-- Guard the format at the database level so a bad value can never be
-- written (the server validates too; this is defence in depth).
-- NULL stays allowed because "unset" keeps the theme's own surface.
-- ------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'tracks_miniplayer_bg_color_hex'
  ) then
    alter table public.tracks
      add constraint tracks_miniplayer_bg_color_hex
      check (miniplayer_bg_color is null
             or miniplayer_bg_color ~ '^#[0-9a-fA-F]{6}$');
  end if;
end $$;

-- ------------------------------------------------------------------
-- Verify: expect exactly 1 row.
-- ------------------------------------------------------------------
select table_name, column_name, is_nullable, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'tracks'
  and column_name = 'miniplayer_bg_color';
