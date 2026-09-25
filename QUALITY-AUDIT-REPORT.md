# Soulful Bhakti — Quality Audit & Hardening (UI / UX / Backend)

Date: 2026-09-25. Scope: `Soulful Bhakti Web App` (Next.js 16 / React 19 / Clerk / Supabase /
Upstash / Pusher), `Soulful Bhakti Android App & Admin` (`server/server.js` + Flutter app).
Method: five independent read-only audits + evidence-based fixes, each change verified with the
available toolchain. No change was made from memory — every finding below was confirmed by reading
the file and quoted at its exact location.

---

## 1. Verification baselines (before / after)

| Check | Before | After |
| --- | --- | --- |
| `pnpm type-check` (tsc --noEmit) | pass | **pass** |
| `pnpm lint` (eslint) | pass | **pass** |
| `pnpm test` (node --strip-types) | 11/11 pass | **11/11 pass** |
| `next build` (Turbopack, Next 16.2.9) | pass (warning) | **pass** |
| server.js `node --check` | pass | **pass** |
| Flutter (Android) | — no SDK on this machine — | static review only; run `flutter analyze && flutter test` before release |

---

## 2. Web App — playback & player fixes (correctness first)

### 2.1 Global keyboard hijack — `components/Player.tsx`
The global `window` keydown handler called `preventDefault()` on **Space and Escape for every
keystroke** (except inside inputs). Consequences: Space on any focused button toggled playback
instead of activating the button (and `preventDefault` blocked the button's click entirely);
Escape **closed a modal AND rewound the track to 0:00** every time.
Fix: ignore keystrokes when focus is on a native interactive element
(`button, a, select, summary, audio, video, [role=…]`…), and only handle Escape when no
`[role="dialog"]` is open. `FullscreenNowPlaying` now declares `role="dialog"` so the guard applies
there too.

### 2.2 Stale-fetch race could play the WRONG track — `hooks/useGetSongById.ts`, `Player.tsx`, `PlayerContent.tsx`
Two quick taps on different songs could resolve out of order → the player rendered and **played the
first song while the store's activeId was the second**, wedging playback. Fixes:
- `useGetSongById`: stale-response guard (cleanup flips a `stale` flag; late responses are dropped).
- `Player.tsx`: `fetchedSong` is trusted only when `fetchedSong.id === activeId`.
- `PlayerContent.tsx`: the autoplay effect now early-returns when `activeId !== song.id` (mirrors
  the existing guards on the command/seek effects).

### 2.3 Synced-lyrics playhead never re-based after a seek — `hooks/useTrackLyrics.ts`
The rAF playhead effect read `progress` only once at effect start, so after a seek (seek bar or a
tapped lyric line) the highlighted line stayed at the pre-seek position and drifted for the rest of
the track; while paused it never updated. Fix: the effect now re-bases from the latest progress
(with `progress` in the deps) so the highlight jumps immediately. Guarded against the
`react-hooks/set-state-in-effect` lint rule by reading the value through a ref.

### 2.4 400 ms progress poll re-rendered whole pages — selector subscriptions
`usePlayer()` without a selector subscribes to the whole store, and `progress` changes every 400 ms
while playing — so every horizontal song row, every `MediaItem`, the sidebar, the fullscreen player
and the lyrics panel re-rendered 2.5×/sec. Converted `SongListHorizontal`, `MediaItem`,
`LyricsPanel`, `FullscreenNowPlaying`, `LikedContent` and `Sidebar` to selector subscriptions
(only the rendered fields trigger re-renders).

### 2.5 Keyboard-operable transport + seek (WCAG 2.1.1 / 4.1.2)
Player transport icons were `onClick`-only SVGs (`PlayerContent.tsx`) and both seek bars were
mouse-only `div`s (`Player.tsx`, `FullscreenNowPlaying.tsx`). All transport controls are now real
`<button aria-label=…>` with visible focus rings, and both seek bars are real
`role="slider"`s with `aria-valuenow/valuetext/min/max` and Arrow/Home/End/PageUp/PageDown support.

### 2.6 Smaller playback fixes
- `record_play` had no rejection handler → unhandled promise rejection on network errors
  (`usePreloadNextTrack.ts`, second `then` callback catches).
- Nested like/add-to-playlist buttons inside `role="button"` cards: Enter/Space on the inner button
  bubbled up and ALSO started playback (`SongItem.tsx`, `SongListHorizontal.tsx`) — keydown now
  bails out when a nested interactive element has focus.
- `useOnEscOrClickOutside`: listener re-created every render (inline `actionFn`); Escape fired even
  while typing in an input and ignored `condition`. Listener now reads the callback from a ref, and
  Escape bails out for inputs/contentEditable.
- `SongItem`/fullscreen "next track": fullscreen now honors repeat-all wrap (matches the bar).
- Missing/deleted track no longer shows an eternal "Preparing your track…" spinner — a clear,
  screen-reader-visible error state is rendered (a11y `role="status"` on the loading text).
- `useDebounce`: `delay || 500` treated `0` as 500 ms → `delay ?? 500`.
- Home "Liked Songs" link `href="liked"` (fragile from nested routes) → `/liked`.
- `MediaItem` alt was the meaningless literal `"MediaItem"` → the song title.

---

## 3. Web App — auth, API & security fixes

### 3.1 IP identity forgery (analytics poisoning + rate-limit bypass) — `app/utils/requestIp.ts`, `libs/authRateLimit.ts`
`getRequestIp` trusted the client-spoofable `x-real-ip` header **before** the platform-set headers.
On the Cloudflare Workers deployment `x-real-ip` is a plain pass-through header — an attacker could
forge any victim address into Redis keys (`utm:19:device-id:by-ip:<ip>`, re-pointing the victim's
device identity) and mint a fresh id per call, defeating the once-per-day dedup and writing
unbounded rows into the shared `utm_stats` table. Fix: the client IP now comes **only** from
`cf-connecting-ip` (Cloudflare) then the first hop of `x-forwarded-for` (Vercel/etc.). `x-real-ip`
is no longer read. `authRateLimit` shares the same helper (limiter and analytics identity agree) and
no longer lumps header-less callers into one shared `"unknown"` bucket.

### 3.2 Unauthenticated visit action was unlimited — `app/actions/trackVisitAction.ts`
The in-memory rate limiter (`libs/authRateLimit.ts`) existed but was **dead code**
(checkAuthRateLimit was never imported). `trackVisitAction` (1–2 calls per page load, unauthenticated,
writes into a table shared with five projects) is now rate-limited per IP (60/min, generous) and
returns a no-op when exceeded.

### 3.3 UTM data was stored unbounded and with PII — `app/actions/trackVisitAction.ts`
The shared `utm_stats` table received raw, uncapped UTM fields and the **full landing `href`**
(including `?reset_token=…`, `?email=…`). Fix: UTM fields are control-char-stripped, trimmed and
capped at 200 chars; `url` now stores **origin + pathname only** (no query params), capped at 2000
chars. (`libs/safeDecodeParam.ts` hygiene was already solid.)

### 3.4 Paid-track stream URLs were guessable — `actions/getTrackStreamUrl.ts`
When `R2_BASE_URL` is configured, paid tracks returned a **static public URL built from public
catalog data** (`storage_path` is readable by the anon client), so the server-side
`isPremiumUser()` gate was bypassable by fetching the URL directly. The resolver gate itself is
server-side and correct; the URL exposure needs per-request signed URLs (R2 presign) or an
edge-enforced entitlement check, which requires R2 signing credentials in the worker environment —
**not available in the current deployment env** (see `.env.example`; only `R2_BASE_URL` is set).
Action: flagged as an infrastructure follow-up — add R2 credential env vars, presign paid-track
URLs (or proxied streaming), and verify the bucket policy. Do not ship paid content on a fully
public bucket.

### 3.5 Auth-gated pages — server-side gate — `app/(site)/account/page.tsx`, `app/(site)/liked/page.tsx`
Guests were redirected client-side only (brief flash, no server check). Both pages now call
`await auth()` server-side and `redirect("/")` when unauthenticated, matching the API routes'
`requireUser` pattern. (Likes are browser-local, unchanged.)

### 3.6 `/api/turnstile` leaked internal error details — `app/api/turnstile/route.ts`
500 responses echoed `error.message` (fetch internals). Now logged server-side and answered with a
generic message, matching every other route.

### 3.7 Once-per-day visit dedup race — flagged
The SELECT-then-INSERT once-per-day guard can insert a duplicate row when two tabs open
simultaneously (the shared table cannot be migrated to add a unique constraint —
`libs/supabaseAdmin.ts` docs). Follow-up: serialize per deviceId with a short Redis lock
(`SET lock:device:<id> NX EX 5`) before the insert. Not changed here: every row written is now
capped and bounded by the new rate limit, which bounds the blast radius.

---

## 4. Web App — UI / UX / accessibility fixes (WCAG 2.2 AA)

### 4.1 Contrast — `app/globals.css` (measured, not guessed)
- Light `--tw-neutral-500 #82828A`: **3.81:1** on white / 3.40:1 on elevated (fails AA).
  → `#6E6E75` (110 110 117): **5.06:1 / 4.52:1** (passes).
- Dark `--tw-neutral-500 #737373`: **3.98:1** on surface / 3.67:1 on elevated (fails AA).
  → `#9E9E9E` (158 158 158): **7.05:1 / 6.50:1** (passes).
This one token change fixes every `text-neutral-500`, `placeholder:text-neutral-500`, song-author,
count and footer usage at once. (Ratios computed with the WCAG 2.x luminance formula; full table was
verified in-session.)
- Hindi transliteration color `#8E24AA` on dark = **2.68:1** (fails) → `#B47BD9` = **6.09:1**
  (`LyricsPanel.tsx`). All other lyric colors verified ≥ 5.2:1 on both dark surfaces.

### 4.2 Dialog semantics + focus management — `components/modals/ModalContainer.tsx`
The custom confirm-modals shell had plain `motion.div`s: no `role="dialog"`, no
`aria-modal`/`aria-labelledby`, no focus trap, no initial focus, no focus restore. Now: dialog
semantics, labelled heading, focus moved to the first control on open, a Tab loop inside the panel,
focus restored to the opener on close, and a visible focus ring instead of `focus:outline-none`.

### 4.3 Form labels (SC 1.3.1 / 3.3.2)
Placeholder-only fields now carry accessible names: search modal + search input ("Search songs…"),
create-playlist title/description, playlist-detail title/description/visibility.

### 4.4 Status / error announcements
- `role="alert"` on inline errors: search modal, `LoadMoreSongs`, `LoadMoreAlbums`, player error
  states.
- `role="status"`/`aria-live="polite"` on loading screens (`playlists`, `account`, `liked`) and the
  player "Preparing your track…" text.

### 4.5 Focus visibility + touch targets
- Visible `focus-visible` rings restored where `focus:outline-none` had removed them: `Modal.tsx`
  (content + close), `Slider.tsx` (volume thumb), `AnimatedSearchModalShell`-neighbour
  `ModalContainer`. The volume slider keeps its native Radix keyboard handling — the ring was the
  only missing piece.
- `AddToPlaylistButton` default hit area 22 px (< 24 px minimum) → padded to ≥ 26 px;
  `Modal`/`ModalContainer` close buttons enlarged.
- `Sidebar` nav rail is now real `<nav aria-label="Primary">` / `<nav aria-label="More">` landmarks;
  the avatar/auth-trigger was already labelled. `LyricsPanel` language chips announce selection with
  `aria-pressed`.

### 4.6 Not changed (with reasons)
- Global `text-neutral-400` token: 4.70:1 on white passes; the on-elevated consumers are handled by
  the neutral-500 token change + component-level classes. A global 400 change would flatten the
  visual hierarchy between 400/500 scales.
- Server-side redirects for other pages: not applicable (public content).
- Mobile-nav/tooltip keyboard visibility and prefers-reduced-motion on framer-motion shells are
  documented improvements for a follow-up pass; the Canvas particle loop and modal animations still
  run under `prefers-reduced-motion` (see §6).

---

## 5. Backend — `Soulful Bhakti Android App & Admin/server/server.js`

### 5.1 CRITICAL — Clerk admin check failed OPEN — `requireAdmin` + `/api/admin/session`
When the Clerk session token lacked an `emailAddress` claim (Clerk's **default** session-token
template does not include it), `email === ''` and the guard `if (email && !email.endsWith(...))`
was **skipped entirely** → any signed-in Clerk user was granted full admin (track/album CRUD, audio
upload, payout-affecting affiliate endpoints). Both check sites now **fail closed**
(`!email || !email.endsWith('@soulfulbhakti.com')` → token fallback or 403), and
`/api/admin/session` only reports authenticated for an explicitly authorized domain.

### 5.2 PostgREST filter escaping — `escapePostgrestValue`
The reserved-character regex was `/[,()]/` while the comment (and PostgREST docs) list `.` too, so
a `.` in a search term produced a malformed filter. `.` added.

### 5.3 Webhook price guard
`Number(data.price) <= 0` let `NaN` through (`NaN <= 0` is false) → `planPrice = NaN` could
serialize to `null` and silently drop commissions on a NOT-NULL violation. Now rejects any
non-finite or non-positive price.

### 5.4 `/api/admin/audio/file` object exfiltration
The admin route accepted **any R2 key**; now only known audio extensions are served (the bucket may
later hold artwork/other objects).

### 5.5 Follow-ups (flagged, not changed — require product/infra decisions)
- **Paid-stream paywall on `/stream/:id` (+ `/file`)**: paid tracks currently stream without an
  entitlement check and paid lyrics are public via `/tracks` etc. Enforcing the gate requires the
  subscription model to be wired (Superwall on Android, Stripe plans paused on web) — locking paid
  tracks with no way to unlock would be worse. Implement entitlement verification + Range-aware
  streaming when the premium source lands.
- **Identity binding**: referrals / playlists / likes / profile accept client-supplied `user_id`
  (service-role client bypasses RLS owner policies). Replace with a server-verified Clerk `sub`.
- **Rate limits on public mutating endpoints** and reducing `trust proxy` to the real proxy count.
- **Streaming (not buffering) for `/stream/:id/file`** to remove the per-request RAM cost.
- `admin.html` `esc()` quote escaping in attribute contexts (admin-authored content only — low).

---

## 6. Android app (Flutter) — static audit + fixes

**No Flutter SDK is installed on this machine, so these changes are NOT build-verified here.
Run `flutter analyze && flutter test` (tests exist for jaap) before merging — every change is
small and deliberately follows existing patterns.**

### 6.1 Sleep timer killed the app at the wrong time — `lib/provider/sleep_timer_provider.dart`
Re-arming the timer overwrote `_timer` without cancelling the previous one → "30 min then 15 min"
left the 30-min timer armed and the app `exit(0)`-ed early (mid-japa, mid-playback). `_timer?.cancel()`
is now called before reassignment.

### 6.2 Jaap flush permanently over-counted on partial write failure — `lib/pages/jaap/jaap_counter.dart`
`flush()` restored the WHOLE buffer when a mid-loop write failed — the already-persisted increments
were re-written on the next flush, inflating the day's count forever. Now only the unwritten
remainder is restored (`restore(n - written)`).

### 6.3 Jaap "today" pinned at build time — `lib/pages/jaap/jaap_counter.dart`
The local day was captured once per build and reused for writes/streaks/resets — a screen left open
across midnight (the stated core use case) wrote/read/re-counted yesterday. `flush`, `refreshDerived`
and `resetToday` now always use `DateTime.now()`, and a day-rollover effect reseeds the in-memory
count from the NEW day (flushing post-midnight taps first).

### 6.4 Queue removal deleted the wrong engine tracks — `lib/provider/audio_player/audio_player.dart`
`removeTracks` indexed the filtered stream (`mapIndexed` over `where()` → 0..n-1), so
"Undo add album" removed the TOP of the queue. Now computes real indices in the original list and
removes in **descending** order (each engine removal shifts later indices). Multi-select removal in
`lib/modules/player/player_queue.dart` now removes **sequentially** instead of racing
`Future.wait` against a shifting list.

### 6.5 Crash UX + logging chain — `lib/main.dart`
On the common Android path, Firebase init REPLACED `FlutterError.onError` with Crashlytics-only,
so framework errors silently stopped reaching `AppLogger`'s file log. The handler is now chained
(log + crash report). Added a friendly **release-mode `ErrorWidget.builder`** (dark card +
"Something went wrong. Please restart the app.") instead of the raw red/black error screen, with
the error recorded first.

### 6.6 Search scroll reset while typing — `lib/pages/search/tabs/all.dart`
A fresh `ScrollController` was created in `build` on every debounced keystroke (scroll reset +
leaked controllers). Now `useScrollController()` (stable, auto-disposed).

### 6.7 Flagged follow-ups (not changed)
Concurrent jaap flush interleaving (read-modify-write on the same row), `resetToday` vs in-flight
flush race, `HomeSeeAllPage` blank loading/error state, cold-start skeleton bug in
`user_artists.dart`, `usePaletteColor` global state bleed, no network timeouts on connectivity
checks, l10n gaps (`'Your Playlists'`, lyric tab labels, `Colors.red/green`), debug `print` in the
audio player, `SessionServiceUtils.sortTracks` `artists.first` RangeError, and the karaoke/original
variant switch restarting the track from 0. High-value, lower-risk than the fixed set — see the
in-line findings for exact fixes.

---

## 7. Housekeeping

- `.tmp-newpass.txt` (plaintext passwords) was untracked and NOT gitignored in the Android repo —
  added `.tmp-newpass.txt` / `*.tmp-newpass.txt` to `.gitignore`. **Do not commit that file; rotate
  those passwords if they were ever pasted into anything shared.**
- `.env` / `android/key.properties` were already correctly ignored.
- The pending, previously-uncommitted server work (jaap-chants admin routes, `020_jaap_chants.sql`,
  `admin.html`) was left untouched and uncommitted — this report's server changes are all additive
  to the working tree.

## 8. How to verify

```bash
# Web App
cd "Soulful Bhakti Web App"
pnpm type-check && pnpm lint && pnpm test && pnpm build

# Backend syntax
cd "Soulful Bhakti Android App & Admin"
node --check server/server.js

# Android (needs Flutter SDK — pinned 3.35.2 via .fvmrc)
fvm flutter analyze
fvm flutter test
```