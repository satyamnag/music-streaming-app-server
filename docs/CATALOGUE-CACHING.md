# Catalogue caching: why screens were slow, and what changed

Status: implemented, verified on a physical device (`RMX2027`, Android 11,
`com.soulfulbhakti.app`). Build: versionCode 97.

## 1. The report

"Home page and every other page takes so much time to load, even though we have
integrated local cache."

## 2. What was actually measured

Baseline on the device, timing the app's *own* server through
`adb forward tcp:19876 tcp:19876` so the numbers are what a screen really pays -
not a synthetic benchmark:

| Endpoint (one screen's data) | First call | Immediate repeat | Payload |
| --- | --- | --- | --- |
| `/supabase/tracks` (home) | **3406 ms** | **2866 ms** | 336 KB |
| `/supabase/admin-albums` (home) | **4086 ms** | **3699 ms** | 340 KB |
| `/supabase/playlists/<id>` (playlist) | 1886 ms | 1952 ms | - |
| `/supabase/albums` (albums) | 1774 ms | 1888 ms | 5 KB |
| `/supabase/artists` (artists) | 1673 ms | 1908 ms | 0.3 KB |
| `/supabase/browse/sections` | 2663 ms | 1883 ms | 39 KB |
| `/supabase/search?q=k` | 1816 ms | 1771 ms | 21 KB |
| Cold start (`am start -W`, first install) | **4893 ms** | - | - |

Two facts follow directly from that table:

1. **The repeat is as slow as the first.** If a cache existed and simply missed,
   a repeat would still be faster (connection reuse, warm DNS/TLS). Equal timings
   mean the request was re-issued in full every time.
2. **Even a 104-byte response (`/supabase/home-wallpaper`) took 837 ms.** The
   cost was never payload size - it was the round trip.

## 3. Root cause

`AGENTS.md`'s "never assume" applied here: the claim "we have integrated local
cache" was checked rather than accepted. Two caches existed, and neither covers
this data:

- `lib/services/image_cache/app_image_cache_manager.dart` - caches **artwork**
  through `flutter_cache_manager`. Working correctly since versionCode 92; it
  has nothing to do with track/album/playlist data.
- `ref.keepAlive()` on `homeTracksProvider` / `homeSectionsProvider` - keeps a
  provider's value for the **lifetime of the process**. Every launch starts
  empty, and it does nothing for the other screens.

The data path itself had no cache anywhere:

```
widget -> Riverpod provider -> http://127.0.0.1:PORT/supabase/...  (shelf)
       -> SupabaseClient -> https://<project>.supabase.co  (network)
```

`lib/provider/server/routes/supabase_data.dart` queried Supabase inside every
route and returned the result un-stored. Three avoidable costs sat on top:

- **`select('*')`** on the tracks list shipped the `synced_lyrics*` columns with
  every row. `_trackToJson` - the only consumer - never reads them; they are
  fetched per track by `/supabase/lyrics/<id>`. Measured: 563 KB versus 323 KB
  for the same catalogue (43% discarded on arrival).
- **`/supabase/admin-albums` fetched the entire tracks table a second time**, so
  the home screen downloaded the catalogue twice.
- **`prewarmHomeStreamsProvider`** called `resolveDirectSupabaseStream` once per
  track, and each call ran its own Supabase query - up to 100 sequential round
  trips, on the same connection the visible screen was waiting on.

`song_plays` was also read with a full-table scan on many screens, and that table
only grows.

## 4. The fix

**`lib/services/catalog_cache/catalog_cache.dart`** - a persistent
stale-while-revalidate cache, wired in at the server routes so all screens
benefit from one change rather than page-by-page edits.

- **Hit:** served from memory, or from a JSON file written by an earlier run, so
  a screen costs a file read instead of a mobile round trip.
- **Stale hit:** returned immediately; the fresh copy is fetched behind the
  request and is what the next reader sees. A reader never waits for a refresh.
- **Miss:** the caller's `fetch` is awaited exactly as before - first-launch
  latency, error propagation and route-level status codes are unchanged.
- **Failed refresh:** the previous value is kept. A warm-up can never blank a
  functioning screen.
- **Single flight:** concurrent reads of one stale key share one refresh.
- **Bounded:** disk persistence is limited to catalogue-level keys (~12 small
  files); per-track entries are memory-only and evicted oldest-first.
- **Location:** `getApplicationSupportDirectory()` (`PathUtils.getFilesDir` on
  Android), which "Clear cache" does not wipe.

Supporting changes:

| Change | Effect |
| --- | --- |
| Projected the tracks list (dropped `synced_lyrics*`) | 563 KB -> 323 KB per catalogue fetch; no response field changes |
| `/supabase/admin-albums` reads the cached catalogue | Removes a duplicate full-table download from the home screen |
| Stream URLs resolved from the cached catalogue | 100 sequential Supabase queries -> 0; miss still uses the original query |
| Every `RefreshIndicator` clears the cache first | Pull-to-refresh keeps meaning "live data", not "cached data" |
| TTL 2 min (catalogue) / 30 min (immutable per-track facts) | Freshness converges within one browsing session |

Untouched by design: every route URL, JSON shape, status code, the sign-in gate
on `/supabase/stream`, the paid-track checks, artwork caching, and all UI/UX.

## 5. Why not something else

- **A local mirror of the catalogue in SQLite/drift.** Correct but much larger:
  it duplicates the schema, needs migrations and a sync policy, and would have to
  be kept in step with every route's filtering rules. A response cache fixes the
  same latency with one new file and no schema.
- **Longer TTLs alone.** Would make screens instant but data arbitrarily stale.
  Stale-while-revalidate gives both.
- **Bumping `maxNrOfCacheObjects` / `stalePeriod` again.** Those are artwork
  settings; they were already correct and are not on this path.
- **Caching inside each `FutureProvider`.** Eleven call sites instead of one, and
  it would still miss on the first visit of each provider.

## 6. Verification

See section 7 of the commit trail and the device run recorded in the task
report: the same endpoint timings re-measured after installing versionCode 97,
plus cold start, and a check that artwork, playback, lyrics and sign-in gates
behave as before.
