-- 030: admin-uploaded BACKGROUND BANNER for a featured playlist (deity screen)
--
-- The reference deity screen shows a full-bleed banner behind the title and song
-- count. Until now only `specials` had a banner column (`banner_url`, migration
-- 027); a featured playlist carried just a square `icon_url` (migration 029), so
-- a per-deity banner could not be stored at all — the detail screen only ever
-- showed a banner when a `specials` row happened to share the same id.
--
-- Nullable on purpose: an unset banner means "the admin has not chosen one yet",
-- and the app then draws its own placeholder banner from the chip's gradient
-- rather than showing an empty band.

alter table public.featured_playlists
  add column if not exists banner_url text;

comment on column public.featured_playlists.banner_url is
  'Admin-uploaded 2:1 background banner for the deity detail screen. Null = the app draws its placeholder banner.';
