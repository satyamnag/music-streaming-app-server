# Featured-playlist / deity banner hero

Status: code complete and verified on device (v108).
**One owner action is still required: apply migration 030 to the database.**

## What the two reference screens are

Both screenshots are the SAME screen: `FeaturedPlaylistPage`
(`lib/pages/home/featured_playlist_detail.dart`), reached from two places.

| Reference | Opened from | Admin entity | Banner source |
| --- | --- | --- | --- |
| Screenshot 1 ("Ganesh Special") | the home **specials carousel** banner | `specials` | `specials.banner_url` (migration 027) |
| Screenshot 2 ("Durga") | a **deity chip** on the home row | `featured_playlists` (the admin's "featured playlist") | `featured_playlists.banner_url` (**new**, migration 030) |

## The hero

Replaced the padded `TitleBar` + rounded 8:3 artwork + centred title/count with a
single `_BannerHero`:

- full-bleed 2:1 band that runs **under the status bar** (no TitleBar on this
  page at all);
- back arrow overlaid top-left, offset by the status-bar inset;
- title in warm cream, bottom-right, with an optional gold-ringed circular icon
  above it and a `— ◆ 12 songs ◆ —` divider beneath;
- a top/bottom scrim so text stays legible over unknown artwork.

The circular icon appears only when the shelf has an uploaded icon, which is
exactly why the deity screen shows its badge and a specials banner does not.

### The placeholder (an explicit requirement)

A shelf with no banner never renders an empty band: `_placeholder` paints the
shelf's own gradient with a faint glyph watermark. A failed image download uses
the same fallback (`errorBuilder`), so broken artwork cannot leave a hole either.

### Track alignment

Unchanged by design, and asserted by test: the grid is still
`trackGridDelegate` + `HomeTrackCard` — the exact Newest Arrivals alignment the
requirement asked for. The search field above it is kept, matching that same
screen and preserving existing functionality.

## Deity banner, end to end

| Link | File | Change |
| --- | --- | --- |
| DB column | `server/migrations/030_featured_playlist_banner.sql` | `alter table featured_playlists add column if not exists banner_url text` |
| Admin API | `server/server.js` | `banner_url` added to `readFeaturedPlaylistPayload`; new `deity_banner` upload kind, WebP + 2:1 enforced from the file header |
| Admin UI | `server/admin.html` | per-row **Upload banner** / **Remove banner**, with the state spelled out ("uploaded" vs "placeholder in use") |
| Local server | `lib/provider/server/routes/supabase_data.dart` | emits `bannerUrl` |
| App model | `lib/modules/home/sections/featured_playlists.dart` | `FeaturedPlaylistRow.bannerUrl` and `FeaturedPlaylist.bannerUrl` |
| Hero | `lib/pages/home/featured_playlist_detail.dart` | uses it, or the placeholder |

`banner_url` is nullable on purpose: null means "the admin has not chosen one",
which is precisely what triggers the placeholder.

## REQUIRED: apply the migration

Migrations in this repo are applied by hand (there is no runner). Until 030 is
applied:

- the app still works — `select('*')` simply has no `banner_url`, which trims to
  null and shows the placeholder (verified on device in v108);
- but the admin **Upload banner** button will fail, because the column does not
  exist yet.

Apply `server/migrations/030_featured_playlist_banner.sql` in the Supabase SQL
editor (or `supabase db push`), then reload the admin panel.

## Verification

- `flutter-verify` 40852143222 and `android-release` 40852151399 green on
  `898b0f0e`; the new tests were confirmed in the run log as executing.
- Installed as versionCode 108. On-device: the deity screen shows the full-bleed
  placeholder hero, back arrow, ringed lotus badge, "Durga", "◆ 16 songs ◆" and
  the 3-column Newest Arrivals grid.
- `test/deity_banner_plumbing_test.dart` guards all six links, plus the
  full-bleed / placeholder / grid invariants.

### Not yet verified

The **admin upload round trip** cannot be verified until migration 030 is
applied; the code path exists and is covered by source probes, but no real
banner has been uploaded and rendered from the database yet.
