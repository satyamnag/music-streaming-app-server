# Home shelves: order, admin arrangement, splash theme

Status: implemented, built (CI `43404482172`) and verified on the POCO C51.

---

## 1. Shelf order — the same as the web home

Web home (`app/(site)/page.tsx`) renders: **Top Trending → Albums → language
shelves → Newest Arrivals → Recently Played**. The Android home now renders the
same sequence (`lib/pages/home/home.dart`):

| Position | Shelf | Source |
|---|---|---|
| 1 | Top Trending | `sections.topTrending` |
| 2 | Albums | `sections.albums` |
| 3 | Language shelves (Telugu, Sanskrit, …) | `sections.languages` |
| 4 | Newest Arrivals | `sections.newestArrivals` |
| 5 | Recently Played (only when there is history) | `recentlyPlayedTracksProvider` |

**Playlists was removed** from this page: the Liked Tracks / my-playlist cards no
longer sit between Albums and the language shelves. The `HomePlaylistsSection`
widget still exists (Library owns playlists); home simply does not render it.

The header block (wordmark, search, bell, featured-playlist carousel, deity
circles) is unchanged — those are not shelves.

## 2. Ordering rules (both clients now identical)

| Shelf | Rule | Where |
|---|---|---|
| Top Trending | admin arrangement first (`tracks.featured_order`), then global play count, then name | Android `home_tracks.dart`, web `getTopTrending` |
| Newest Arrivals | **strictly** `created_at`/release date descending — the admin pin does not apply | Android `home_tracks.dart`, web `getNewestArrivals` |
| Recently Played | most recent occurrence first, distinct by track, capped at 10 | `lib/provider/history/recent_tracks.dart` (SQL, `LIMIT 10`) |
| Albums | admin albums in `albums.featured_order`, then auto-grouped albums by play count | Android `/supabase/admin-albums`, web `getHomeAlbums` |

Two regressions were fixed on the way:

- **Newest Arrivals** used to put featured tracks first in both clients, so the
  shelf stopped being chronological as soon as anything was pinned. Removed from
  both.
- **Top Trending** ignored the admin order entirely, and the web version only
  listed tracks that already had plays — a newly pinned song never appeared.
  Both now put the arranged list first, then fall back to play counts.

## 3. Admin: "Arrange Top Trending"

`server/admin.html` already contained the *Arrange Songs* panel's markup hooks and
all of its JavaScript (`renderArrangeTracks`, `saveFeaturedTracks`,
`pinTrack`/`moveTrack`/`unpinTrack`), but it had **no sidebar entry and no
`showView` branch** — the panel was unreachable, which is why only "Arrange
Albums" was visible.

Now:

- sidebar entry **Arrange Top Trending** next to *Arrange Albums*;
- a panel with the featured-songs list (up/down/remove) and an "All songs — pin to
  feature" search;
- `showView('arrangeTracks')` and the refresh branch both call
  `loadArrangeTracks()`;
- both panels state what they drive: *Top Trending* / *Albums*, in the web app and
  the Android app.

The two panels write different columns through the existing RPCs —
`reorder_featured_tracks(p_ids)` and `reorder_featured_albums(p_ids)` — so they do
not fight each other.

## 4. Header spacing

Search now sits flush against the bell: `Gap(0)` between the two 36dp buttons and
an 8dp trailing inset, so the glyphs are **16dp apart and 16dp from the edge**
(was 18/18, and 26/18 before that). 16dp is the tightest pair that keeps both
touch targets non-overlapping. Pinned by `test/bottom_nav_geometry_test.dart`,
which measures the real widgets.

## 5. Splash follows the device theme

| Resource | Before | After |
|---|---|---|
| `drawable/launch_background.xml` (day) | black backdrop | **white** backdrop |
| `drawable-v21/launch_background.xml` (day) | black backdrop | **white** backdrop |
| `values-v31/styles.xml` splash colours | `#FF000000` | **`#FFFFFFFF`** |
| `drawable-night*` + `values-night-v31` | black | black (unchanged) |

So a listener in light mode sees the gold medallion on white, and a listener in
dark mode sees it on black. The art is a transparent PNG, so it sits on either
backdrop without a halo.

## 6. Verification

- `flutter analyze` clean on the changed files; **27 tests** pass across
  `bottom_nav_geometry`, `dynamic_sections`, `profile_screen` (and the earlier
  suites were re-run green).
- Web: `npx tsc --noEmit` passes.
- On the device: splash is **white** in light mode; home shows Top Trending first,
  then Albums, then the language shelves, then Newest Arrivals, with **no
  Playlists**; search/bell visibly tighter.

Recently Played did not appear on the device because that install has no playback
history yet — the shelf is intentionally conditional. Its ordering logic is the
SQL above (most recent first, distinct, limit 10).

## 7. Still to do by hand

- Deploy the web branch (`fix/delete-account-link`, which also carries the web
  ordering change) so `/` serves the new Top Trending rule.
- Play Console: nothing to change — no payments, data or permission behaviour was
  touched by this batch.
