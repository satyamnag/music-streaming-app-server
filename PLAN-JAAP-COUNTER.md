# Jaap Counter (Mantras & Stotras) — Cross-App Plan

Status: Implemented (web) / Documented (Android follow-ups).
Date: 2026-09-25.

## Goal
Let users count japa (mala repetitions) for mantras/stotras on both the Android app and the
web app, with an identical mental model: a daily vow (target, default 108), one tap = one
repetition, streaks + a 7-day strip for regularity, and a private, offline-first personal
practice (no server stores your counting).

## Shared domain model

- **Chant** — curated metadata authored by an admin: `name`, exact `chant_text`,
  `default_target`, `sort_order`, `status` (`free`/`paid`).
  Storage: Supabase `public.jaap_chants` (migration 020). RLS: public SELECT only; writes via
  service_role behind `requireAdmin` (`/api/admin/jaap-chants`). Alias endpoints exist
  (`/api/jaap-chants`); the web app reads the table directly through its anon client.
- **Counter** — one practice the user performs. Either bound to a curated chant or a custom
  (name + daily target). Counting data is **device-local**:
  - Android: drift tables `jaap_counters` + `jaap_daily_counts`.
  - Web: `localStorage` per user (`sb-local-jaap:<userId|guest>`), mirroring the browser-local
    likes/playlists precedent.
- **Day key** — local calendar day `YYYY-MM-DD`; computed at the moment of use, never cached at
  build time (midnight-rollover correctness).
- **Derived stats** — today's count; lifetime total; current streak (consecutive local days where
  count >= target, STOPPING on the first missed day; today counts only once its target is met);
  last-7-days strip (oldest first, dot = target met).

## Rules every screen must honor (from the Android implementation)

1. A tap never waits on disk: count advances in memory, persistence is debounced (~400 ms).
2. No error surface while counting: a failed write puts the UNSAVED remainder back in the
   buffer; the next tap retries.
3. Never surface DB errors mid-japa; failures are logged.
4. Reset must drop buffered taps for that day first.
5. target <= 0 must never divide (progress clamps to 0).

## Android — current state & this session's role

Already implemented and tested on Android (2026-09): counters chips + create, progress ring,
tap target with haptics + scale, streak strip, new-counter/edit dialog, drift repository
(increment upsert, resetToday, currentStreak, last7Days, lifetimeTotal), midnight-rollover
reseed, flush remainder-restore. The server admin CRUD for jaap_chants and migration 020 exist.

Follow-ups (require a Flutter SDK to build-verify — not executed in this session):
1. Surface curated server chants as pre-made counters ("Mantras & Stotras" section in the
   counters chips or an add-chant dialog), reading the public `/api/jaap-chants` endpoint.
2. Show the exact `chant_text` on the counter screen for curated chants (currently only custom
   counters exist locally, so no text is stored).
After implementation run `fvm flutter analyze && fvm flutter test`
(`test/modules/jaap/*` and `test/provider/jaap/*` exist).

## Web — implemented this session

| File | Purpose |
| --- | --- |
| `actions/getJaapChants.ts` | Server action: anon SELECT of free chants, ordered by `sort_order` then `created_at` desc |
| `types.ts` | `JaapChant` type |
| `consts/jaap.ts` | `DEFAULT_TARGET = 108`, debounce 400 ms, storage key prefix |
| `libs/browserJaap.ts` | Pure domain functions (`dayKey`, `computeCurrentStreak`, `computeLast7Days`, clamp) + per-user localStorage persistence with validation/repair |
| `libs/browserJaap.test.mjs` | node --strip-types unit tests of the pure functions |
| `store/useJaapStore.ts` | zustand store: in-memory count, pending-tap buffer, 400 ms debounced flush, `beforeunload` flush, restore-on-failure |
| `components/jaap/JaapCounterChips.tsx` | horizontal counter selector + create |
| `components/jaap/JaapProgressRing.tsx` | SVG ring, `role="progressbar"`, big tabular count |
| `components/jaap/JaapTapTarget.tsx` | real `<button>`, scale-down press feedback, aria-live count |
| `components/jaap/JaapStreakStrip.tsx` | streak number + 7 dots with day labels (a11y) |
| `components/jaap/JaapCounterModal.tsx` | create/edit (name + daily target), validation |
| `components/jaap/JaapChantsBrowse.tsx` | curated "Mantras & Stotras" section: add a free chant as a counter (dedupe by chantId) |
| `components/jaap/JaapCounterView.tsx` | page content: rings/taps/stats/chant text/edit/reset/delete |
| `app/(site)/jaap/page.tsx` (+ `loading.tsx`) | route shell with Header |
| `components/Sidebar.tsx`, `components/MobileNav.tsx` | "Japa" navigation entries |

Decisions:
- Counting works for guests too (key = `guest` when signed out), matching Android's offline
  posture. Not auth-gated (unlike /liked).
- Only `free` chants are offered on the web (the web has no premium model yet; `paid` is
  reserved for future monetization and never authored content is gated).
- Chant text is displayed verbatim (it is admin-authored canonical metadata).

## Verification
`pnpm type-check && pnpm lint && pnpm test && pnpm build`, then commit + push.