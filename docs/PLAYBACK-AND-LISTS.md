# Track lists and playback

Two rules are applied consistently across the app. Both are easy to regress
silently, so this records them and where they are enforced.

## 1. Ten tracks, then "see more"

Every surface that lists tracks reveals **ten** of them and then offers a way to
see more, so no screen opens on an endless wall of cards:

| surface | page size | enforced in |
| --- | --- | --- |
| Home rows (Newest Arrivals, Top Trending) | 10 | `HomeTrackSection.pageSize` |
| Home row (Recently Played) | 10 | `HomeRecentlyPlayedTracksSection.pageSize` |
| Home rows (`<Language> Songs`) | 10 | `_LanguageSection.pageSize` |
| Albums / Newest Arrivals / Top Trending / language screens | 10 | `HomeSeeAllPage.pageSize` |
| Deity screens | 10 | `FeaturedPlaylistPage.pageSize` |
| Album screens, Recently Played screen | 10 | `kPresentationInitialVisibleTracks` / `TrackGridSection.pageSize` |

`test/ten_track_first_page_test.dart` fails if any of those drift back.

### The same card everywhere

A track is drawn with the SAME shared card wherever it appears: the home rows,
the "see all" grids, the deity screens, the album screens and Recently Played
all render `HomeTrackCard` inside `trackGridDelegate`. The album screens used to
be a table of rows (`# / Title / Album / Duration`) while the deity screen drew
cover cards for the same tracks, which read as two different products.

`TrackGridSection` (`lib/components/track_card/track_grid_section.dart`) owns
that anatomy for whole screens: it renders the shared grid, reveals one page at a
time and asks the collection for its next server page only when the reveal
window runs past what is already loaded.

Album screens opt into it with `TrackPresentationOptions.tracksAsCards`, which
also drops the column header row (cards have no columns) and the "select all"
checkbox (cards have no per-card checkbox; the collection actions apply to the
whole album).

## 2. Playback starts immediately and the mini player is always there

### The queue is prepared LAZILY

`JustAudioEngine` builds its queue with `useLazyPreparation: true` — the
just_audio default, and what its API documentation describes as loading children
"as late as possible before needed for playback".

It used to pass `false` (eager) to avoid a seam between tracks. Eager preparation
makes the engine load EVERY child of the queue before the first one can start,
and in this app every child is a request to the local stream server, which
resolves a signed URL and issues an upstream HEAD before serving a byte. Tapping
a track in a 20-track album opened 20 streams first (the "it takes so long to
start" report), and one failed child could fail the whole `setAudioSource` call,
so the tapped track sometimes never played at all.

`test/gapless_playback_test.dart` pins the decision, and the queue-edit rules
that keep a playing track from being torn down (edits mutate the live queue;
the position is captured before any rebuild).

### The tapped index is re-located after de-duplication

`AudioPlayerNotifier.load()` de-duplicates identical stream URIs before it builds
the queue. The caller's `initialIndex` indexes the list it passed in, so after a
drop it could point at a different track — or past the end, where
`openPlaylist`'s `initialIndex <= length - 1` assert fails and the platform call
throws, which is how a play tap could produce no audio at all. The tapped track
is therefore resolved from the original list first and re-located in the filtered
one (`resolvedIndex`), and a failure to open the queue is logged and reported
instead of escaping as an unhandled async error.

### The mini player is on screen whenever the full-screen player is closed

`SlidingUpPanel` reports the mini player's collapsed state through
`navigationPanelHeight` as `kNavigationBarHeight * (1 - position)`:
`kNavigationBarHeight` (64) when collapsed, `0` when fully open.

`miniPlayerVisibleAt(height)` (`lib/modules/player/player_overlay_collapsed.dart`)
is the whole rule: visible when the panel is collapsed. It replaces an equality
against a literal `50` — the navigation bar's height *before* it grew to 64 — so
closing the full-screen player left the mini player hidden permanently, and the
listener had no player on screen until they happened to drag the panel through
the 49..50 band again. `test/miniplayer_visibility_test.dart` pins it.

### A tap is not refused on an unresolved sign-in

`PremiumAccess.requireSignInToPlay` reads a synchronous mirror of the auth state
that starts signed OUT and is filled by the first resolved state. A tap during
the first moments of a cold start could therefore be treated as signed out and
show a sign-in dialog to a user who is signed in — and play nothing. The gate now
waits (bounded, 5 s) when the auth provider has not resolved yet, and only
prompts for a state that really resolved as signed out. The local stream server
remains the authoritative byte-level gate.
