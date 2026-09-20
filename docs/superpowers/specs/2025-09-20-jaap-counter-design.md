# Jaap Counter — Design Spec

**Status:** Approved (design), pending implementation plan
**Date:** 2025-09-20
**Feature:** Jaap Counter (bottom-nav destination in the Soulful Bhakti Android app)

---

## 1. Purpose

Let a devotee count mantra repetitions (japa) without losing count, keep a daily
practice, fulfil a vow (sankalpa) such as 108 or 1,008 repetitions, and see
whether they are maintaining regularity over days and weeks.

Seven user-stated goals, grouped into what the app must actually do:

| Stated goal | Delivered by |
|---|---|
| Count jaapa without losing count | The tap target + persisted daily count |
| Maintain a daily practice | Per-counter daily target + automatic daily total |
| Focus the mind | Distraction-free single screen; immediate haptic feedback |
| Keep a vow (sankalpa) such as 108 / 1,008 | Per-counter `dailyTarget` |
| Track spiritual discipline over days/weeks | Current streak + 7-day dot strip |
| Reduce mental distraction | One screen, no tabs, no modals during counting |

"Focus the mind" and "reduce mental distraction" are outcomes, not features.
They are served by making the counting screen minimal and interruption-free.

---

## 2. Scope

### In scope (v1)

- Multiple **named** counters, each with its own daily target
- One running count per counter per day, with an **automatic daily total**
- Progress ring toward the day's target
- Current **streak** (consecutive days meeting target) and a **7-day dot strip**
- Lifetime total per counter
- Manage: create, rename, change target, reset today, delete
- Bottom-nav destination immediately after Home

### Explicitly out of scope (v1)

- Session Start/Finish — rejected: a user who forgets to start loses everything,
  and there is no "today so far" number. The running model was chosen instead.
- Full calendar / history page — a 7-day strip covers the stated need
- Charts, sound effects, cloud sync
- **Voice recitation via Deepgram** — separate spec, see §8

---

## 3. Data model

Two new Drift tables. `schemaVersion` **12 → 13**.

### `jaap_counters`

| Column | Type | Notes |
|---|---|---|
| `id` | int, autoIncrement | PK |
| `name` | text | required, non-empty after trim |
| `dailyTarget` | int | default 108; must be `> 0` |
| `sortOrder` | int | user-defined ordering of chips |
| `createdAt` | dateTime | default now |

### `jaap_daily_counts`

| Column | Type | Notes |
|---|---|---|
| `id` | int, autoIncrement | PK |
| `counterId` | int | FK → `jaap_counters.id`, **ON DELETE CASCADE** |
| `day` | text | local calendar date, `YYYY-MM-DD` |
| `count` | int | default 0 |
| `updatedAt` | dateTime | default now |

**Unique constraint:** `(counterId, day)` — makes every write an idempotent
upsert and prevents duplicate day rows.

### Rationale for key decisions

- **`day` is a local calendar date string, not a `DateTime`.** Streaks and the
  7-day strip are calendar-day questions. Storing the local calendar day makes
  "did they practise on the 3rd?" a simple indexed equality and avoids
  timezone bugs where a 23:30 tap lands on the wrong day.
- **The target lives on the counter, not the daily row.** The vow (108 vs 1,008)
  is a property of the practice, not of a given day. Changing the target
  therefore does not rewrite history.
- **Deleting a counter cascades.** Follows the existing `LocalPlaylistSongsTable`
  pattern in this repo.
- **Not per-tap event rows.** Japa is high-repetition: a 1,008-day would create
  1,008 rows. Daily aggregation keeps writes bounded and queries natural.

### Migration

A `from12To13` step creating both tables, following the existing chain in
`lib/models/database/database.dart`. Requires regenerating the drift schema
snapshot for v13 and a migration test.

---

## 4. Navigation and UI

### Navigation

- One entry added to `getNavbarTileList` in `lib/collections/side_bar_tiles.dart`,
  inserted **immediately after `home`** so the bar reads
  `home · jaap · search · library · stats`.
- The same entry added to `getSidebarTileList` so the desktop sidebar matches.
- New `SangeetIcons.jaap` glyph (`lib/collections/spotube_icons.dart` is a
  hand-written file, not generated).
- New route in `lib/collections/routes.dart`: `path: "jaap"`,
  `page: JaapCounterRoute.page`, with `@RoutePage()` on the page.
  Requires `build_runner` regeneration of `routes.gr.dart`.

**Known layout caveat:** this takes the bottom bar from 4 to 5 items — the
Material maximum. Each target becomes narrower. This must be checked on a
narrow device and reported honestly if cramped.

### Screen: `JaapCounterPage` — one screen, no tabs

A single, minimal screen by design (focus / reduced distraction is a stated
goal). Top to bottom:

1. **Counter selector** — horizontal chips of the user's counters; tap to
   switch; a `+` opens the create dialog.
2. **Today's progress** — large `count / target` (e.g. **73 / 108**) with a
   progress ring.
3. **The tap target** — one large, full-width button. **Each press = one
   repetition.** Haptic feedback and ring animation.
4. **Discipline strip** — current streak (e.g. "🔥 12 days") plus a 7-day dot
   strip: filled = target met, hollow = not met.
5. **Lifetime total** — small, secondary.
6. **Manage** — overflow menu: rename, change target, reset today, delete.

### Tap behaviour

- Increments **in memory first**, so feedback is immediate and never waits on
  disk.
- Persists to `jaap_daily_counts` **debounced (~400 ms)**, plus a **forced flush**
  on screen exit and on app background, so a kill loses at most a fraction of a
  second.
- Crossing the daily target fires **one** subtle confirmation (haptic + ring
  completion). **No modal** — that would interrupt japa.
- Counting **continues past the target** (people do extra) and keeps displaying.

### New counter dialog

- `name`: required, trimmed, non-empty
- `dailyTarget`: numeric, `> 0`, default 108
- Validation follows the existing admin/admin.html patterns already in this repo.

### Error handling

- A failed or corrupt daily-row write must **never block a tap**. The screen
  keeps counting in memory and retries on the next tap.
- **No error dialog is ever shown during counting.** Surfacing an error mid-japa
  defeats the purpose of the screen.

---

## 5. Architecture

- **Storage:** local Drift only, mirroring `LocalLikedSongsTable`. No Supabase
  table, no server endpoint, no cloud sync in v1.
- **Access:** a repository/provider layer over `databaseProvider`, so the UI
  never touches Drift directly and the logic is unit-testable.
- **Date handling:** today's local date is computed once per screen build from a
  single injected clock, so day-rollover behaviour is testable.
- **Files (expected):**
  - `lib/models/database/tables/jaap_counters.dart`
  - `lib/models/database/tables/jaap_daily_counts.dart`
  - `lib/provider/jaap/jaap_provider.dart` (repository + state)
  - `lib/pages/jaap/jaap_counter.dart` (the page)
  - `lib/modules/jaap/…` (widgets: tap target, ring, dot strip, chips)
  - edits to `database.dart`, `side_bar_tiles.dart`, `routes.dart`,
    `spotube_icons.dart`, `app_en.arb`

---

## 6. Testing strategy

**Unit / repository**

- Upsert increments the correct `(counterId, day)` row
- A new day starts a new row; the previous day is untouched
- Streak calculation: consecutive days, a gap resets it, today counts only if target met
- 7-day strip returns exactly 7 days in order, correctly filled/hollow
- Deleting a counter cascades its daily rows
- Target change does not alter past days

**Widget**

- Tapping the target increments the displayed count
- The ring reflects progress toward the target
- Crossing the target fires the confirmation exactly once
- The dot strip renders the right number of filled dots
- Switching counter chips switches the displayed count

**Migration**

- v12 → v13 creates both tables with the expected columns

**Static / CI**

- `flutter analyze` clean on all touched files
- `flutter test` green
- Release build verified via **GitHub Actions** (per standing instruction —
  never a local release build)

---

## 7. Risks and constraints

| Risk | Mitigation |
|---|---|
| 5 bottom-nav items feels cramped | Verify on a narrow device; report honestly; fall back to 4 items + a Home entry point if unusable |
| Every tap writing to SQLite | Debounced writes + forced flush; bounded by design (daily aggregation, not per-tap rows) |
| Day rollover at midnight with the app open | Inject a clock; recompute the date on resume and on tap |
| Pre-existing broken test harness (`schema_v*.dart` reference enums that no longer exist) | Documented as a known defect. **Not** a prerequisite here: the v13 snapshot is generated fresh rather than hand-patched |
| Timezone correctness | Local calendar date stored as text; no UTC conversion for day boundaries |

---

## 8. Future work — Voice recitation (separate spec, NOT in v1)

Voice counting was requested but is **not** part of this spec, and one part of
the request was factually incorrect and must not be built as described.

**Verified against Deepgram's official documentation:**

| Claim | Verified reality |
|---|---|
| Telugu speech-to-text | **Supported.** Nova-3 ships improved models for Telugu (`te`); Whisper also supports `te` |
| "Pronunciation assessment" | **Does NOT exist in Deepgram.** There is no phoneme scoring or pronunciation-grading API. The only "pronunciation" docs concern *TTS* IPA input — the opposite direction |
| What Deepgram does provide | Per-word `confidence` (0–1) and `utterances` segmentation |

**Therefore:** a future spec may implement a **recitation check** — store the
expected mantra text per counter, transcribe the user's chant in Telugu
(`model=nova-3&language=te`), compare transcript to expected, and flag
low-confidence words as "unclear". That **may auto-increment the count**.

It must **not** be labelled "pronunciation assessment", because word confidence
means "the model is unsure it heard this word", not "you pronounced it
correctly".

**Two constraints for that future spec:**

1. **The API key cannot ship in the app.** It must be proxied through the Render
   server with rate limiting and a Vault-stored credential.
2. **Cost and connectivity.** Japa is high-repetition; per-recitation cloud calls
   scale as `recitations × users × days` (one user at 1,008/day is ~1,000 calls
   daily) and fail on poor connectivity — exactly when someone is chanting. An
   on-device option should be evaluated before committing to cloud.
