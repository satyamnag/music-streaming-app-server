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

## Migration 030: APPLIED and verified

Migrations in this repo are applied by hand (there is no runner). The owner ran
`server/migrations/030_featured_playlist_banner.sql`; the live database now
confirms it:

```
GET /rest/v1/featured_playlists?select=id,title,banner_url
-> 200 [{"id":"venkateswara","title":"Venkateswara","banner_url":null}, ...]
```

All five deity rows expose the column, currently null — which is exactly the
"admin has not chosen one yet" state that shows the placeholder.

### Also verified against the live database

- **The app's own data path emits the field.** Reading the running app's local
  server over `adb forward` (port 19876) returned real JSON containing
  `"bannerUrl": null` per chip. That proves DB column -> PostgREST -> local route
  -> JSON, on the device, not just in a unit test.
- **RLS still protects the table.** An anon `PATCH` with
  `Prefer: return=representation` affected `[]` rows, so the anon key (which ships
  inside the APK) cannot rewrite chips and banners. The earlier "204" was a
  no-match, not a write; nothing was modified by the check.
- **The server's own suites pass** (`node test/admin-static-verify.cjs`,
  `node test/admin-filters.test.cjs` — 25/25 PASS), so the `server.js` and
  `admin.html` edits did not break the panel's markup/JS contracts.

### Still not verified by me

The admin **upload round trip** — picking a 2:1 WebP, saving it, and seeing that
image on the deity screen — needs an admin session. `.env` holds no admin
credential (and anon cannot write), so that last step must be done in the admin
panel. Everything it depends on is now in place and verified above.

## Verification

- `flutter-verify` 40852143222 and `android-release` 40852151399 green on
  `898b0f0e`; the new tests were confirmed in the run log as executing.
- Installed as versionCode 108. On-device, BOTH reference screens were checked:
  - the deity screen (`Durga`): full-bleed PLACEHOLDER hero (gradient + glyph
    watermark), back arrow, gold-ringed lotus badge, cream title,
    "◆ 16 songs ◆", 3-column Newest Arrivals grid;
  - the specials screen (`Soulful Special`): full-bleed uploaded banner, back
    arrow, cream title, "◆ 2 songs ◆", NO icon badge (specials have no icon), and
    the same 3-column grid (third cell empty with two tracks).
- `test/deity_banner_plumbing_test.dart` guards all six links, plus the
  full-bleed / placeholder / grid invariants.

### Not yet verified

The **admin upload round trip** cannot be verified until migration 030 is
applied; the code path exists and is covered by source probes, but no real
banner has been uploaded and rendered from the database yet.
