# Jaap Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bottom-nav Jaap Counter that lets a devotee count mantra repetitions across multiple named counters — each with its own daily target — showing today's progress, a streak, and a 7-day discipline strip, entirely on-device.

**Architecture:** Two new Drift tables (`jaap_counters`, `jaap_daily_counts`) at schema 12 → 14, mirroring the existing `LocalLikedSongsTable` local-only pattern. (v13 adds the Jaap tables; v14 repairs a pre-existing invalid foreign key on the local playlists — see the implementation note.) A repository/provider layer wraps `databaseProvider` so the UI never touches Drift directly and streak/history logic is unit-testable. One distraction-free screen holds a counter selector, a progress ring, one large tap target, the discipline strip, and a lifetime total.

**Tech Stack:** Flutter 3.35.2 / Dart 3.9.0, Drift (`drift`, `drift_dev`), hooks_riverpod, Shadcn Flutter UI, auto_route, `build_runner` for codegen. Release builds go through GitHub Actions.

**Spec:** `docs/superpowers/specs/2025-09-20-jaap-counter-design.md`

## Global Constraints

- **Local-only storage.** No Supabase table, no server endpoint, no cloud sync in v1.
- **Schema version 12 → 14.** The Jaap tables are created in a `to >= 13 && from < 13` block. A separate `to >= 14 && from < 14` block repairs a **pre-existing** bug exposed by enabling foreign keys: `LocalPlaylistsTable` had no primary key, so `local_playlist_songs.playlist_id` was an invalid foreign key. See the implementation note below.
- **`day` is a local calendar date string (`YYYY-MM-DD`)**, never a `DateTime` and never UTC. Streaks are calendar-day questions.
- **Unique `(counterId, day)`** on `jaap_daily_counts` so every write is an idempotent upsert.
- **`dailyTarget` lives on the counter**, not the daily row; changing it must not alter past days.
- **Deleting a counter cascades** its daily rows.
- **The tap must never block on disk.** Increment in memory first; persist debounced (~400 ms) with a forced flush on screen exit and app background.
- **No error dialog may ever appear while counting.** A failed write is retried on the next tap.
- **Nav order:** the Jaap entry goes **immediately after `home`** in both `getNavbarTileList` and `getSidebarTileList`.
- **Never build a release locally** — use `.github/workflows/android-release.yml`.
- **Do not modify `spotube-release-binary.yml`.**
- **Flutter pinned at 3.35.2** (`.fvmrc`). Local path in this environment: `D:\flutter-sdk\flutter\bin`.
- **Do not hand-patch `test/drift/app_db/generated/schema_v*.dart`** — a known pre-existing defect (they reference enums that no longer exist). The v13 snapshot is generated fresh.

---

## Implementation note — the pre-existing foreign-key bug (discovered during Task 1)

Task 1 was implemented and reviewed, and the review surfaced a genuine pre-existing defect
that this work had to repair. Recording it here so the plan matches reality.

**What was wrong.** `lib/models/database/tables/local_playlists.dart` declared
`TextColumn get id => text()();` with **no `primaryKey` override**. Its child table declared
`playlistId => text().references(LocalPlaylistsTable, #id)()`. SQLite only accepts a foreign
key whose parent column is a primary key or has a unique index, so that reference was
**invalid** — it simply never fired, because SQLite leaves foreign-key enforcement off by
default.

**Why this work exposed it.** `onDelete: KeyAction.cascade` on the new Jaap table is
worthless unless foreign keys are actually enforced, so the implementation added the
documented `beforeOpen` callback:

```dart
beforeOpen: (details) async {
  await customStatement('PRAGMA foreign_keys = ON');
},
```

Turning enforcement on immediately activated the broken playlist reference, and every write
to `local_playlist_songs_table` failed with `foreign key mismatch`. It also broke the
account-deletion cleanup in `lib/provider/auth/clerk_auth_provider.dart`, which deleted
`localPlaylistsTable` **before** `localPlaylistSongsTable` — the resulting exception was
swallowed by a `catch (_)`, so local cleanup silently no-oped.

**The repair (parts of Task 1, as implemented).**

1. `LocalPlaylistsTable` now declares `Set<Column> get primaryKey => {id};`
2. `local_playlist_songs.playlistId` now specifies `onDelete: KeyAction.cascade`
3. `clerk_auth_provider.dart` deletes children before parents, so cleanup is correct
   whether or not cascade applies
4. Schema bumped **13 → 14**, with a dedicated `to >= 14 && from < 14` block running
   `m.alterTable(TableMigration(...))` for both tables. A separate step was required
   because folding the repair into the v13 block would leave any database already at v13
   silently broken.

**Verification:** `test/models/database/foreign_keys_test.dart` — 7 tests, all passing:
FK enforcement is on at open; counter delete cascades; an orphan daily row is rejected;
playlist delete cascades; an orphan song is rejected; the account-deletion cleanup order
empties both tables; and a **v13 → v14 migration test that seeds a real v13 schema and
migrates it with data**, proving existing installs are repaired rather than reset.

**Consequence for the rest of this plan:** the schema version is **14**, not 13. Task 2 must
not re-bump it.

---

**Create:**

| Path | Responsibility |
|---|---|
| `lib/models/database/tables/jaap_counters.dart` | Drift table: a named counter with a daily target |
| `lib/models/database/tables/jaap_daily_counts.dart` | Drift table: one row per counter per day |
| `lib/provider/jaap/jaap_provider.dart` | Repository + providers: CRUD, increment, streak, 7-day strip |
| `lib/pages/jaap/jaap_counter.dart` | The single screen (`@RoutePage()`) |
| `lib/modules/jaap/jaap_tap_target.dart` | The large tap button |
| `lib/modules/jaap/jaap_progress_ring.dart` | count/target ring |
| `lib/modules/jaap/jaap_streak_strip.dart` | Streak number + 7-day dots |
| `lib/modules/jaap/jaap_counter_chips.dart` | Counter selector chips |
| `lib/modules/jaap/jaap_new_counter_dialog.dart` | Create/rename + target dialog |
| `test/provider/jaap/jaap_provider_test.dart` | Repository unit tests |
| `test/modules/jaap/jaap_widgets_test.dart` | Widget tests |

**Modify:**

| Path | Change |
|---|---|
| `lib/models/database/database.dart` | Add 2 `part` lines, 2 tables to `@DriftDatabase`, `schemaVersion => 14`, the v13 (Jaap tables) and v14 (playlist FK repair) migration blocks, and `beforeOpen` enabling `PRAGMA foreign_keys = ON` |
| `lib/collections/side_bar_tiles.dart` | Add the Jaap entry after `home` in both lists |
| `lib/collections/routes.dart` | Add `AutoRoute(path: "jaap", page: JaapCounterRoute.page)` |
| `lib/collections/spotube_icons.dart` | Add `SangeetIcons.jaap` |
| `lib/l10n/app_en.arb` | Add Jaap strings |

**Generated (never hand-edited):** `database.g.dart`, `routes.gr.dart`, `app_localizations*.dart`

---

### Task 1: Drift tables + schema 13 migration

**Files:**
- Create: `lib/models/database/tables/jaap_counters.dart`
- Create: `lib/models/database/tables/jaap_daily_counts.dart`
- Modify: `lib/models/database/database.dart` (parts ~32-40, `@DriftDatabase` ~50, `schemaVersion` 68, migration block 253-256)
- Test: `test/drift/app_db/migration_test.dart` (add a v13 case)

**Interfaces:**
- Produces: `JaapCountersTable` (columns `id`, `name`, `dailyTarget`, `sortOrder`, `createdAt`) and `JaapDailyCountsTable` (columns `id`, `counterId`, `day`, `count`, `updatedAt`), both usable as `jaapCountersTable` / `jaapDailyCountsTable` inside `database.dart`, and as `db.jaapCountersTable` / `db.jaapDailyCountsTable` from generated code.

- [ ] **Step 1: Create the counters table**

Create `lib/models/database/tables/jaap_counters.dart`:

```dart
part of '../database.dart';

/// A named japa practice, e.g. "Gayatri" or "Nama".
///
/// The daily target (vow / sankalpa) lives here rather than on the daily row so
/// that changing the target does not rewrite history.
class JaapCountersTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  IntColumn get dailyTarget => integer().withDefault(const Constant(108))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 2: Create the daily counts table**

Create `lib/models/database/tables/jaap_daily_counts.dart`:

```dart
part of '../database.dart';

/// One row per counter per calendar day.
///
/// `day` is a local `YYYY-MM-DD` string, not a DateTime: streaks and the 7-day
/// strip are calendar-day questions, and a text day avoids timezone bugs where
/// a late-evening tap would land on the wrong date.
///
/// The unique (counterId, day) constraint makes every write an idempotent
/// upsert. Deleting a counter removes its rows via the cascade.
class JaapDailyCountsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get counterId => integer().references(
        JaapCountersTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get day => text().withLength(min: 10, max: 10)();
  IntColumn get count => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {counterId, day},
      ];
}
```

- [ ] **Step 3: Register the tables and bump the version**

In `lib/models/database/database.dart`:

1. Add the part directives after `part 'tables/local_liked_songs.dart';` (line ~40):

```dart
part 'tables/jaap_counters.dart';
part 'tables/jaap_daily_counts.dart';
```

2. Add the tables to `@DriftDatabase(tables: [...])` after `LocalLikedSongsTable,`:

```dart
    JaapCountersTable,
    JaapDailyCountsTable,
```

3. Change the version (line ~68):

```dart
  int get schemaVersion => 14;
```

- [ ] **Step 4: Add the v13 migration block**

In `database.dart`, immediately after the existing v11 → v12 block (lines ~253-256) and before the closing `},` of `onUpgrade`:

```dart
        // v12 -> v13: local Jaap Counter (counters + per-day counts).
        if (to >= 13 && from < 13) {
          await m.createTable(jaapCountersTable);
          await m.createTable(jaapDailyCountsTable);
        }
```

- [ ] **Step 5: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` regenerates with `$JaapCountersTableTable` and `$JaapDailyCountsTableTable`; no errors.

- [ ] **Step 6: Verify the generated accessors exist**

Run: `flutter analyze lib/models/database/database.dart`
Expected: `No issues found!`

- [ ] **Step 7: Write the migration test**

Add to `test/drift/app_db/migration_test.dart` inside the existing migration group, following the file's existing pattern for a schema-version test (`verifier.migrateAndValidate(db, 13)` then assert the new tables exist). If the existing test style uses `SchemaVerifier`, mirror the nearest existing case exactly and target version `13`.

- [ ] **Step 8: Run the migration test**

Run: `flutter test test/drift/app_db/migration_test.dart`
Expected: PASS for the v13 case. (Other pre-existing cases in this file may still fail on the known snapshot defect — that defect is out of scope and must not be "fixed" by hand-editing generated files. If unrelated cases fail, note them and continue; the v13 assertion is what this task must prove.)

- [ ] **Step 9: Commit**

```bash
git add lib/models/database/ test/drift/app_db/migration_test.dart
git commit -m "feat(jaap): add counters and daily-counts tables at schema 13"
```

---

### Task 2: Repository + providers

**Files:**
- Create: `lib/provider/jaap/jaap_provider.dart`
- Test: `test/provider/jaap/jaap_provider_test.dart`

**Interfaces:**
- Consumes: `databaseProvider` from `lib/provider/database/database.dart`; `JaapCountersTable` / `JaapDailyCountsTable` from Task 1.
- Produces (exact names later tasks use):

```dart
class JaapCounter { final int id; final String name; final int dailyTarget; final int sortOrder; }
class JaapDayStatus { final DateTime day; final int count; final bool targetMet; }

class JaapRepository {
  Future<List<JaapCounter>> counters();
  Future<int> createCounter({required String name, required int dailyTarget});
  Future<void> renameCounter(int id, String name);
  Future<void> setDailyTarget(int id, int target);
  Future<void> deleteCounter(int id);
  Future<void> resetToday(int counterId);
  Future<int> increment(int counterId, DateTime today);
  Future<int> todayCount(int counterId, DateTime today);
  Future<int> lifetimeTotal(int counterId);
  Future<int> currentStreak(int counterId, DateTime today);
  Future<List<JaapDayStatus>> last7Days(int counterId, DateTime today);
}

final jaapRepositoryProvider = Provider<JaapRepository>((ref) => JaapRepository(ref.read(databaseProvider)));
final jaapCountersProvider = FutureProvider<List<JaapCounter>>((ref) => ref.watch(jaapRepositoryProvider).counters());
final selectedJaapCounterProvider = StateProvider<int?>((ref) => null);
```

- [ ] **Step 1: Write the failing test**

Create `test/provider/jaap/jaap_provider_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/provider/jaap/jaap_provider.dart';

void main() {
  late AppDatabase db;
  late JaapRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = JaapRepository(db);
  });

  tearDown(() async => db.close());

  test('createCounter then counters returns it', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 108);
    final all = await repo.counters();
    expect(all.length, 1);
    expect(all.single.id, id);
    expect(all.single.name, 'Gayatri');
    expect(all.single.dailyTarget, 108);
  });

  test('increment accumulates within the same day', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 108);
    final today = DateTime(2026, 9, 20);
    expect(await repo.increment(id, today), 1);
    expect(await repo.increment(id, today), 2);
    expect(await repo.todayCount(id, today), 2);
  });

  test('increment starts a fresh row on a new day', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 108);
    await repo.increment(id, DateTime(2026, 9, 20));
    await repo.increment(id, DateTime(2026, 9, 20));
    expect(await repo.increment(id, DateTime(2026, 9, 21)), 1);
    expect(await repo.todayCount(id, DateTime(2026, 9, 20)), 2);
    expect(await repo.todayCount(id, DateTime(2026, 9, 21)), 1);
  });

  test('lifetimeTotal sums every day', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 108);
    await repo.increment(id, DateTime(2026, 9, 20));
    await repo.increment(id, DateTime(2026, 9, 20));
    await repo.increment(id, DateTime(2026, 9, 21));
    expect(await repo.lifetimeTotal(id), 3);
  });

  test('currentStreak counts consecutive days meeting the target', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 2);
    final today = DateTime(2026, 9, 22);
    for (final d in [20, 21, 22]) {
      await repo.increment(id, DateTime(2026, 9, d));
      await repo.increment(id, DateTime(2026, 9, d));
    }
    expect(await repo.currentStreak(id, today), 3);
  });

  test('currentStreak stops at a missed day', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 2);
    final today = DateTime(2026, 9, 22);
    // 22 and 20 meet the target; 21 is missing.
    for (final d in [20, 22]) {
      await repo.increment(id, DateTime(2026, 9, d));
      await repo.increment(id, DateTime(2026, 9, d));
    }
    expect(await repo.currentStreak(id, today), 1);
  });

  test('currentStreak is 0 when today has not met the target', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 5);
    await repo.increment(id, DateTime(2026, 9, 22)); // only 1 of 5
    expect(await repo.currentStreak(id, DateTime(2026, 9, 22)), 0);
  });

  test('last7Days returns exactly 7 days, oldest first', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 1);
    final today = DateTime(2026, 9, 22);
    await repo.increment(id, today);
    final week = await repo.last7Days(id, today);
    expect(week.length, 7);
    expect(week.first.day, DateTime(2026, 9, 16));
    expect(week.last.day, today);
    expect(week.last.targetMet, isTrue);
    expect(week.first.targetMet, isFalse);
  });

  test('setDailyTarget does not alter existing days', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 2);
    final today = DateTime(2026, 9, 22);
    await repo.increment(id, today);
    await repo.increment(id, today);
    await repo.setDailyTarget(id, 10);
    expect(await repo.todayCount(id, today), 2);
  });

  test('resetToday zeroes only today', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 108);
    await repo.increment(id, DateTime(2026, 9, 20));
    await repo.increment(id, DateTime(2026, 9, 21));
    await repo.resetToday(id, DateTime(2026, 9, 21));
    expect(await repo.todayCount(id, DateTime(2026, 9, 20)), 1);
    expect(await repo.todayCount(id, DateTime(2026, 9, 21)), 0);
  });

  test('deleteCounter cascades its daily rows', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 108);
    await repo.increment(id, DateTime(2026, 9, 20));
    await repo.deleteCounter(id);
    expect(await repo.counters(), isEmpty);
    expect(await repo.lifetimeTotal(id), 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/provider/jaap/jaap_provider_test.dart`
Expected: FAIL — `jaap_provider.dart` not found.

- [ ] **Step 3: Add the testing constructor to `AppDatabase`**

The tests need an in-memory database. In `lib/models/database/database.dart`, add a named constructor next to the existing one:

```dart
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);
```

- [ ] **Step 4: Implement the repository**

Create `lib/provider/jaap/jaap_provider.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/provider/database/database.dart';

/// A named japa practice with its daily vow (target).
class JaapCounter {
  final int id;
  final String name;
  final int dailyTarget;
  final int sortOrder;

  const JaapCounter({
    required this.id,
    required this.name,
    required this.dailyTarget,
    required this.sortOrder,
  });
}

/// One day's standing for one counter.
class JaapDayStatus {
  final DateTime day;
  final int count;
  final bool targetMet;

  const JaapDayStatus({
    required this.day,
    required this.count,
    required this.targetMet,
  });
}

/// Local-only japa storage. No Supabase, no server: japa is personal practice
/// and must work offline.
class JaapRepository {
  final AppDatabase db;
  JaapRepository(this.db);

  /// Local calendar date as `YYYY-MM-DD`. Deliberately not UTC: a 23:30 tap
  /// belongs to that local day, and streaks are calendar-day questions.
  static String dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<List<JaapCounter>> counters() async {
    final rows = await (db.select(db.jaapCountersTable)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows
        .map((r) => JaapCounter(
              id: r.id,
              name: r.name,
              dailyTarget: r.dailyTarget,
              sortOrder: r.sortOrder,
            ))
        .toList();
  }

  Future<int> createCounter({required String name, required int dailyTarget}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('name is required');
    if (dailyTarget <= 0) throw ArgumentError('dailyTarget must be > 0');
    final existing = await counters();
    return db.into(db.jaapCountersTable).insert(
          JaapCountersTableCompanion.insert(
            name: trimmed,
            dailyTarget: Value(dailyTarget),
            sortOrder: Value(existing.length),
          ),
        );
  }

  Future<void> renameCounter(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('name is required');
    await (db.update(db.jaapCountersTable)..where((t) => t.id.equals(id)))
        .write(JaapCountersTableCompanion(name: Value(trimmed)));
  }

  /// Changing the vow must not rewrite history, so only the counter row changes.
  Future<void> setDailyTarget(int id, int target) async {
    if (target <= 0) throw ArgumentError('dailyTarget must be > 0');
    await (db.update(db.jaapCountersTable)..where((t) => t.id.equals(id)))
        .write(JaapCountersTableCompanion(dailyTarget: Value(target)));
  }

  /// Cascades to jaap_daily_counts via the FK's ON DELETE CASCADE.
  Future<void> deleteCounter(int id) async {
    await (db.delete(db.jaapCountersTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> resetToday(int counterId, DateTime today) async {
    await (db.delete(db.jaapDailyCountsTable)
          ..where((t) => t.counterId.equals(counterId) & t.day.equals(dayKey(today))))
        .go();
  }

  /// Increments and returns the new value for `today`. Upsert on (counterId, day).
  Future<int> increment(int counterId, DateTime today) async {
    final key = dayKey(today);
    final row = await (db.select(db.jaapDailyCountsTable)
          ..where((t) => t.counterId.equals(counterId) & t.day.equals(key)))
        .getSingleOrNull();
    if (row == null) {
      await db.into(db.jaapDailyCountsTable).insert(
            JaapDailyCountsTableCompanion.insert(
              counterId: counterId,
              day: key,
              count: const Value(1),
            ),
          );
      return 1;
    }
    final next = row.count + 1;
    await (db.update(db.jaapDailyCountsTable)..where((t) => t.id.equals(row.id)))
        .write(JaapDailyCountsTableCompanion(
      count: Value(next),
      updatedAt: Value(DateTime.now()),
    ));
    return next;
  }

  Future<int> todayCount(int counterId, DateTime today) async {
    final row = await (db.select(db.jaapDailyCountsTable)
          ..where((t) => t.counterId.equals(counterId) & t.day.equals(dayKey(today))))
        .getSingleOrNull();
    return row?.count ?? 0;
  }

  Future<int> lifetimeTotal(int counterId) async {
    final sum = db.jaapDailyCountsTable.count.sum();
    final q = db.selectOnly(db.jaapDailyCountsTable)
      ..addColumns([sum])
      ..where(db.jaapDailyCountsTable.counterId.equals(counterId));
    final row = await q.getSingle();
    return row.read(sum) ?? 0;
  }

  /// Consecutive days up to and including [today] where the target was met.
  /// Today only counts as part of the streak once its target is met.
  Future<int> currentStreak(int counterId, DateTime today) async {
    final counter = await (db.select(db.jaapCountersTable)
          ..where((t) => t.id.equals(counterId)))
        .getSingleOrNull();
    if (counter == null) return 0;
    final target = counter.dailyTarget;
    final rows = await (db.select(db.jaapDailyCountsTable)
          ..where((t) => t.counterId.equals(counterId)))
        .get();
    final byDay = {for (final r in rows) r.day: r.count};
    var streak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    while (true) {
      final c = byDay[dayKey(cursor)] ?? 0;
      if (c >= target) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// The last 7 local days ending at [today], oldest first.
  Future<List<JaapDayStatus>> last7Days(int counterId, DateTime today) async {
    final counter = await (db.select(db.jaapCountersTable)
          ..where((t) => t.id.equals(counterId)))
        .getSingleOrNull();
    final target = counter?.dailyTarget ?? 108;
    final rows = await (db.select(db.jaapDailyCountsTable)
          ..where((t) => t.counterId.equals(counterId)))
        .get();
    final byDay = {for (final r in rows) r.day: r.count};
    final base = DateTime(today.year, today.month, today.day);
    return List.generate(7, (i) {
      final d = base.subtract(Duration(days: 6 - i));
      final c = byDay[dayKey(d)] ?? 0;
      return JaapDayStatus(day: d, count: c, targetMet: c >= target);
    });
  }
}

final jaapRepositoryProvider = Provider<JaapRepository>(
  (ref) => JaapRepository(ref.read(databaseProvider)),
);

final jaapCountersProvider = FutureProvider<List<JaapCounter>>(
  (ref) => ref.watch(jaapRepositoryProvider).counters(),
);

/// Which counter the screen is showing. Null means "not chosen yet"; the screen
/// falls back to the first counter.
final selectedJaapCounterProvider = StateProvider<int?>((ref) => null);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/provider/jaap/jaap_provider_test.dart`
Expected: PASS — all 11 tests.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/provider/jaap/jaap_provider.dart test/provider/jaap/jaap_provider_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/provider/jaap/ lib/models/database/database.dart test/provider/jaap/
git commit -m "feat(jaap): local repository for counters, daily counts, streaks"
```

---

### Task 3: Icon, route, and nav entry

**Files:**
- Modify: `lib/collections/spotube_icons.dart` (near line 91-95)
- Modify: `lib/collections/routes.dart` (in the `RootAppRoute` children, after the `home` routes)
- Modify: `lib/collections/side_bar_tiles.dart` (both `getSidebarTileList` ~25 and `getNavbarTileList` ~66)
- Create: `lib/pages/jaap/jaap_counter.dart` (minimal placeholder page, filled in Task 4)

**Interfaces:**
- Produces: `SangeetIcons.jaap`; `JaapCounterRoute` (generated); a `/jaap` path reachable from the nav bar at index 1.

- [ ] **Step 1: Add the icon**

In `lib/collections/spotube_icons.dart`, beside the other action icons (e.g. after `volumeMute`):

```dart
  static const jaap = FeatherIcons.circle;
```

- [ ] **Step 2: Create a minimal page so the route can generate**

Create `lib/pages/jaap/jaap_counter.dart`:

```dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class JaapCounterPage extends StatelessWidget {
  const JaapCounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Jaap')),
    );
  }
}
```

- [ ] **Step 3: Register the route**

In `lib/collections/routes.dart`, inside the `RootAppRoute` children, after the `home/see-all` route entry:

```dart
            AutoRoute(
              path: "jaap",
              page: JaapCounterRoute.page,
            ),
```

- [ ] **Step 4: Add the nav entry (after home, in BOTH lists)**

In `lib/collections/side_bar_tiles.dart`, in `getNavbarTileList`, insert immediately after the `home` entry and before `search`:

```dart
      SideBarTiles(
        id: "jaap",
        pathPrefix: "/jaap",
        route: const JaapCounterRoute(),
        icon: SangeetIcons.jaap,
        title: l10n.jaap_counter,
      ),
```

Make the identical insertion in `getSidebarTileList` (the desktop sidebar), also after its `home` entry.

- [ ] **Step 5: Add the l10n string**

In `lib/l10n/app_en.arb` add (keeping valid JSON — add a comma to the previous last entry):

```json
  "jaap_counter": "Jaap"
```

- [ ] **Step 6: Regenerate**

Run: `flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs`
Expected: `routes.gr.dart` gains `JaapCounterRoute`; no errors.

- [ ] **Step 7: Verify**

Run: `flutter analyze lib/collections/ lib/pages/jaap/`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/collections/ lib/pages/jaap/ lib/l10n/
git commit -m "feat(jaap): bottom-nav entry directly after Home, plus its route"
```

---

### Task 4: The counting screen

**Files:**
- Modify: `lib/pages/jaap/jaap_counter.dart` (replace the placeholder)
- Create: `lib/modules/jaap/jaap_tap_target.dart`
- Create: `lib/modules/jaap/jaap_progress_ring.dart`
- Create: `lib/modules/jaap/jaap_streak_strip.dart`
- Create: `lib/modules/jaap/jaap_counter_chips.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `JaapRepository`, `JaapCounter`, `JaapDayStatus`, `jaapRepositoryProvider`, `jaapCountersProvider`, `selectedJaapCounterProvider` (Task 2).
- Produces: the assembled `JaapCounterPage`; each widget is a standalone `HookConsumerWidget` so Task 5's tests can pump them individually.

- [ ] **Step 1: Add the remaining strings**

In `lib/l10n/app_en.arb`:

```json
  "jaap_today": "Today",
  "jaap_streak": "Streak",
  "jaap_days": "days",
  "jaap_lifetime": "Lifetime",
  "jaap_new_counter": "New counter",
  "jaap_name": "Name",
  "jaap_daily_target": "Daily target",
  "jaap_rename": "Rename",
  "jaap_delete": "Delete",
  "jaap_delete_confirm": "Delete this counter and its history?",
  "jaap_reset_today": "Reset today",
  "jaap_target_reached": "Target reached"
```

- [ ] **Step 2: Write the progress ring**

Create `lib/modules/jaap/jaap_progress_ring.dart`:

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// count / target with a ring that fills as the count approaches the vow.
/// Deliberately shows the raw numbers large: "complete a chosen number" is a
/// stated goal, so the number must be readable at a glance.
class JaapProgressRing extends HookWidget {
  final int count;
  final int target;

  const JaapProgressRing({required this.count, required this.target, super.key});

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '/ $target',
                style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.mutedForeground),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Write the tap target**

Create `lib/modules/jaap/jaap_tap_target.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/extensions/context.dart';

/// The single large counting button. One press = one repetition.
///
/// Feedback is haptic and immediate; the caller updates its in-memory count
/// synchronously, so a tap never waits on disk. There is deliberately no
/// confirmation dialog and no error surface here - interrupting japa is the one
/// thing this screen must never do.
class JaapTapTarget extends HookWidget {
  final VoidCallback onTap;
  final bool targetReached;

  const JaapTapTarget({required this.onTap, this.targetReached = false, super.key});

  @override
  Widget build(BuildContext context) {
    final scale = useAnimationController(
      duration: const Duration(milliseconds: 90),
      lowerBound: 1.0,
      upperBound: 0.97,
      value: 1.0,
    );

    return GestureDetector(
      onTapDown: (_) => scale.reverse(),
      onTapUp: (_) => scale.forward(),
      onTapCancel: () => scale.forward(),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ScaleTransition(
        scale: scale,
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: targetReached
                ? context.theme.colorScheme.primary.withValues(alpha: 0.18)
                : context.theme.colorScheme.primary,
          ),
          alignment: Alignment.center,
          child: Text(
            context.l10n.jaap_tap_to_count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: targetReached
                  ? context.theme.colorScheme.primary
                  : context.theme.colorScheme.primaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}
```

Add the string used above to `app_en.arb`:

```json
  "jaap_tap_to_count": "Tap to count"
```

- [ ] **Step 4: Write the streak strip**

Create `lib/modules/jaap/jaap_streak_strip.dart`:

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/jaap/jaap_provider.dart';

/// Current streak plus a 7-day dot strip: filled = that day met the target.
/// This is the "regularity over days and weeks" goal made visible at a glance.
class JaapStreakStrip extends HookWidget {
  final int streak;
  final List<JaapDayStatus> week;

  const JaapStreakStrip({required this.streak, required this.week, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$streak', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const Gap(6),
            Text(context.l10n.jaap_days, style: TextStyle(color: context.theme.colorScheme.mutedForeground)),
          ],
        ),
        const Gap(10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in week)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: d.targetMet ? context.theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(color: context.theme.colorScheme.primary, width: 2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Write the counter chips**

Create `lib/modules/jaap/jaap_counter_chips.dart`:

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/provider/jaap/jaap_provider.dart';

/// Horizontal selector for the user's counters. Tap to switch, "+" to create.
class JaapCounterChips extends HookWidget {
  final List<JaapCounter> counters;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  const JaapCounterChips({
    required this.counters,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final c in counters) ...[
            Button(
              style: c.id == selectedId
                  ? const ButtonStyle.primary()
                  : const ButtonStyle.outline(),
              onPressed: () => onSelect(c.id),
              child: Text(c.name),
            ),
            const Gap(8),
          ],
          Button(
            style: const ButtonStyle.outline(),
            onPressed: onCreate,
            child: const Icon(FeatherIcons.plus),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Assemble the page**

Replace `lib/pages/jaap/jaap_counter.dart`:

```dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/jaap/jaap_counter_chips.dart';
import 'package:sangeet/modules/jaap/jaap_progress_ring.dart';
import 'package:sangeet/modules/jaap/jaap_streak_strip.dart';
import 'package:sangeet/modules/jaap/jaap_tap_target.dart';
import 'package:sangeet/provider/jaap/jaap_provider.dart';

@RoutePage()
class JaapCounterPage extends HookConsumerWidget {
  const JaapCounterPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final countersAsync = ref.watch(jaapCountersProvider);
    final selectedId = ref.watch(selectedJaapCounterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.jaap_counter)),
      body: countersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (counters) {
          if (counters.isEmpty) {
            return _EmptyState(onCreate: () => _createCounter(context, ref));
          }
          final active = counters.firstWhere(
            (c) => c.id == selectedId,
            orElse: () => counters.first,
          );
          return _CounterView(counter: active, counters: counters);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.jaap_new_counter),
          const Gap(12),
          Button.primary(onPressed: onCreate, child: const Icon(FeatherIcons.plus)),
        ],
      ),
    );
  }
}

Future<void> _createCounter(BuildContext context, WidgetRef ref) async {
  // Implemented in Task 6; for now this is a no-op placeholder that keeps the
  // empty state tappable so the screen is exercisable.
}

class _CounterView extends HookConsumerWidget {
  final JaapCounter counter;
  final List<JaapCounter> counters;

  const _CounterView({required this.counter, required this.counters});

  @override
  Widget build(BuildContext context, ref) {
    final repo = ref.read(jaapRepositoryProvider);
    final today = DateTime.now();

    // Today's count is held in memory so a tap paints immediately and never
    // waits on SQLite. It is seeded from the DB once, then written back
    // debounced (see _persist).
    final count = useState(0);
    final seeded = useRef(false);
    final pending = useRef(0);
    final debounce = useRef<Timer?>(null);

    final streak = useState(0);
    final lifetime = useState(0);
    final week = useState<List<JaapDayStatus>>(const []);

    Future<void> refreshDerived() async {
      streak.value = await repo.currentStreak(counter.id, today);
      lifetime.value = await repo.lifetimeTotal(counter.id);
      week.value = await repo.last7Days(counter.id, today);
    }

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final c = await repo.todayCount(counter.id, today);
        if (cancelled) return;
        count.value = c;
        seeded.value = true;
        await refreshDerived();
      }

      load();
      return () {
        cancelled = true;
        // Forced flush: never lose the last taps on screen exit.
        debounce.value?.cancel();
        _flush(repo, counter.id, today, pending);
      };
    }, [counter.id]);

    void flushSoon() {
      debounce.value?.cancel();
      debounce.value = Timer(const Duration(milliseconds: 400), () {
        _flush(repo, counter.id, today, pending);
      });
    }

    final targetReached = count.value >= counter.dailyTarget;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          JaapCounterChips(
            counters: counters,
            selectedId: counter.id,
            onSelect: (id) => ref.read(selectedJaapCounterProvider.notifier).state = id,
            onCreate: () => _createCounter(context, ref),
          ),
          const Gap(24),
          JaapProgressRing(count: count.value, target: counter.dailyTarget),
          const Gap(24),
          JaapTapTarget(
            targetReached: targetReached,
            onTap: () {
              if (!seeded.value) return;
              count.value += 1;
              pending.value += 1;
              flushSoon();
              // Refresh derived stats once the target is first reached, so the
              // strip and streak update without a manual pull.
              if (count.value == counter.dailyTarget) {
                refreshDerived();
              }
            },
          ),
          const Gap(24),
          JaapStreakStrip(streak: streak.value, week: week.value),
          const Gap(16),
          Text('${context.l10n.jaap_lifetime}: ${lifetime.value}'),
        ],
      ),
    );
  }
}

/// Applies the buffered increments. Failures are swallowed on purpose: a
/// transient write error must never interrupt counting, and the next tap
/// retries.
Future<void> _flush(JaapRepository repo, int counterId, DateTime today, ObjectRef<int> pending) async {
  final n = pending.value;
  if (n <= 0) return;
  pending.value = 0;
  try {
    for (var i = 0; i < n; i++) {
      await repo.increment(counterId, today);
    }
  } catch (_) {
    pending.value += n;
  }
}
```

- [ ] **Step 7: Add the missing imports**

Add to `jaap_counter.dart`:

```dart
import 'dart:async';
```

and to `jaap_streak_strip.dart` / `jaap_counter_chips.dart` whichever of `FlutterIcons`/`FeatherIcons` the analyzer reports as missing (the codebase consistently uses `FeatherIcons` from `flutter_feather_icons`).

- [ ] **Step 8: Regenerate and analyze**

Run: `flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/pages/jaap/ lib/modules/jaap/`
Expected: `No issues found!` (fix any import the analyzer names, then re-run)

- [ ] **Step 9: Commit**

```bash
git add lib/pages/jaap/ lib/modules/jaap/ lib/l10n/
git commit -m "feat(jaap): counting screen with tap target, ring, streak strip and chips"
```

---

### Task 5: Widget tests

**Files:**
- Create: `test/modules/jaap/jaap_widgets_test.dart`

**Interfaces:**
- Consumes: `JaapProgressRing`, `JaapStreakStrip`, `JaapTapTarget` (Task 4); `JaapDayStatus` (Task 2).

- [ ] **Step 1: Write the failing tests**

Create `test/modules/jaap/jaap_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/modules/jaap/jaap_progress_ring.dart';
import 'package:sangeet/modules/jaap/jaap_streak_strip.dart';
import 'package:sangeet/modules/jaap/jaap_tap_target.dart';
import 'package:sangeet/provider/jaap/jaap_provider.dart';

Widget wrap(Widget child) => ShadcnApp(home: Scaffold(body: child));

void main() {
  testWidgets('progress ring shows count and target', (tester) async {
    await tester.pumpWidget(wrap(const JaapProgressRing(count: 73, target: 108)));
    expect(find.text('73'), findsOneWidget);
    expect(find.text('/ 108'), findsOneWidget);
  });

  testWidgets('progress ring clamps when over target', (tester) async {
    await tester.pumpWidget(wrap(const JaapProgressRing(count: 200, target: 108)));
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });

  testWidgets('tap target invokes onTap once per press', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(JaapTapTarget(onTap: () => taps++)));
    await tester.tap(find.byType(JaapTapTarget));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('streak strip shows the streak number', (tester) async {
    final week = [
      JaapDayStatus(day: DateTime(2026, 9, 16), count: 0, targetMet: false),
      JaapDayStatus(day: DateTime(2026, 9, 17), count: 108, targetMet: true),
    ];
    await tester.pumpWidget(wrap(JaapStreakStrip(streak: 12, week: week)));
    expect(find.text('12'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify they fail or pass meaningfully**

Run: `flutter test test/modules/jaap/jaap_widgets_test.dart`
Expected: if Task 4 is complete, these should PASS. If any widget name is wrong, fix the widget (not the test) and re-run.

- [ ] **Step 3: Full suite**

Run: `flutter test`
Expected: the Jaap tests pass. Note any pre-existing failures separately — do not fix unrelated generated-file defects.

- [ ] **Step 4: Commit**

```bash
git add test/modules/jaap/
git commit -m "test(jaap): widget tests for ring, tap target and streak strip"
```

---

### Task 6: Manage counters (create, rename, target, reset, delete)

**Files:**
- Create: `lib/modules/jaap/jaap_new_counter_dialog.dart`
- Modify: `lib/pages/jaap/jaap_counter.dart` (`_createCounter`, plus an overflow menu)
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `JaapRepository` methods from Task 2.
- Produces: a working create/rename/target/reset/delete flow, invalidating `jaapCountersProvider` after each mutation.

- [ ] **Step 1: Write the dialog**

Create `lib/modules/jaap/jaap_new_counter_dialog.dart`:

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/extensions/context.dart';

/// Returns the entered (name, target) or null when cancelled.
class JaapNewCounterDialog extends HookWidget {
  final String? initialName;
  final int? initialTarget;

  const JaapNewCounterDialog({this.initialName, this.initialTarget, super.key});

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: initialName ?? '');
    final target = useTextEditingController(text: (initialTarget ?? 108).toString());
    final error = useState<String?>(null);

    void submit() {
      final n = name.text.trim();
      final t = int.tryParse(target.text.trim());
      if (n.isEmpty) {
        error.value = 'Name is required';
        return;
      }
      if (t == null || t <= 0) {
        error.value = 'Target must be greater than 0';
        return;
      }
      Navigator.of(context).pop((name: n, target: t));
    }

    return AlertDialog(
      title: Text(context.l10n.jaap_new_counter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: name, placeholder: Text(context.l10n.jaap_name)),
          const Gap(12),
          TextField(
            controller: target,
            placeholder: Text(context.l10n.jaap_daily_target),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
          ),
          if (error.value != null) ...[
            const Gap(8),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        Button.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        Button.primary(onPressed: submit, child: Text(context.l10n.save)),
      ],
    );
  }
}
```

- [ ] **Step 2: Wire create, rename, target, reset and delete into the page**

Replace the placeholder `_createCounter` in `lib/pages/jaap/jaap_counter.dart`:

```dart
Future<void> _createCounter(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<({String name, int target})>(
    context: context,
    builder: (_) => const JaapNewCounterDialog(),
  );
  if (result == null) return;
  final id = await ref
      .read(jaapRepositoryProvider)
      .createCounter(name: result.name, dailyTarget: result.target);
  ref.invalidate(jaapCountersProvider);
  ref.read(selectedJaapCounterProvider.notifier).state = id;
}
```

Add an overflow menu to `_CounterView`'s `AppBar`-less layout — simplest correct home is a `Button.outline` row under the strip:

```dart
          const Gap(12),
          Wrap(
            spacing: 8,
            children: [
              Button.outline(
                onPressed: () async {
                  final r = await showDialog<({String name, int target})>(
                    context: context,
                    builder: (_) => JaapNewCounterDialog(
                      initialName: counter.name,
                      initialTarget: counter.dailyTarget,
                    ),
                  );
                  if (r == null) return;
                  await repo.renameCounter(counter.id, r.name);
                  await repo.setDailyTarget(counter.id, r.target);
                  ref.invalidate(jaapCountersProvider);
                  await refreshDerived();
                },
                child: Text(context.l10n.jaap_rename),
              ),
              Button.outline(
                onPressed: () async {
                  await repo.resetToday(counter.id, today);
                  count.value = 0;
                  pending.value = 0;
                  await refreshDerived();
                },
                child: Text(context.l10n.jaap_reset_today),
              ),
              Button.destructive(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(context.l10n.jaap_delete),
                      content: Text(context.l10n.jaap_delete_confirm),
                      actions: [
                        Button.outline(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(context.l10n.cancel),
                        ),
                        Button.destructive(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(context.l10n.jaap_delete),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await repo.deleteCounter(counter.id);
                  ref.read(selectedJaapCounterProvider.notifier).state = null;
                  ref.invalidate(jaapCountersProvider);
                },
                child: Text(context.l10n.jaap_delete),
              ),
            ],
          ),
```

- [ ] **Step 3: Regenerate and analyze**

Run: `flutter gen-l10n && dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/pages/jaap/ lib/modules/jaap/`
Expected: `No issues found!`

- [ ] **Step 4: Run the tests**

Run: `flutter test`
Expected: Jaap tests still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/jaap/ lib/modules/jaap/ lib/l10n/
git commit -m "feat(jaap): create, rename, retarget, reset and delete counters"
```

---

### Task 7: Release build via GitHub Actions

**Files:**
- No source changes.

**Interfaces:**
- Consumes: all prior tasks committed and pushed.

- [ ] **Step 1: Push**

```bash
git push origin main
```

- [ ] **Step 2: Trigger the release build**

```bash
gh workflow run android-release.yml -f channel=stable -f format=apk -f split_per_abi=false
```

- [ ] **Step 3: Watch it**

```bash
gh run watch --exit-status
```
Expected: all steps green. Dart/Kotlin compile errors surface here.

- [ ] **Step 4: Report the artifact**

```bash
gh run view <run-id> --json jobs
```
Report the artifact name and size. **Do not attempt a local release build.**

- [ ] **Step 5: Manual verification checklist (report honestly)**

On a device with the built APK:
1. The nav bar shows **Jaap directly after Home** — confirm it is not cramped at 5 items
2. Tapping through to Jaap shows the empty state, then the create dialog works
3. Creating a counter shows the ring at `0 / 108`
4. Tapping the target increments immediately and the ring fills
5. Reaching 108 fires one haptic and the dot strip fills today
6. Killing and reopening the app preserves today's count
7. Changing the target does not alter the displayed history

If any item fails, report which one — do not claim success without the observation.

---

## Self-Review

**Spec coverage**

| Spec section | Task |
|---|---|
| §3 two tables, schema 13, unique (counterId, day), cascade, target on counter | Task 1 |
| §3 local `YYYY-MM-DD` day rationale | Task 2 (`JaapRepository.dayKey`) |
| §4 nav after home, both lists, route, icon | Task 3 |
| §4 one screen: chips, ring, tap target, strip, lifetime | Task 4 |
| §4 tap behaviour: in-memory, debounced, forced flush, no modal, continue past target | Task 4 (Steps 3, 6) |
| §4 error handling: never block a tap, no error dialog | Task 4 (`_flush` swallows and re-buffers) |
| §4 new counter dialog validation | Task 6 |
| §6 unit tests | Task 2 |
| §6 widget tests | Task 5 |
| §6 migration test | Task 1 |
| §6 CI release build | Task 7 |
| §7 5-item nav risk | Task 7 Step 5 checklist |
| §8 voice — out of scope | Not planned (correct) |

**Placeholder scan:** no TBD/TODO. The one intentional placeholder is `_createCounter` in Task 4 Step 6, which is explicitly labelled as implemented in Task 6 — Task 4 remains independently testable without it (empty state is tappable, and widget tests in Task 5 do not exercise creation).

**Type consistency:** `JaapCounter`, `JaapDayStatus`, `JaapRepository.dayKey`, `increment`, `todayCount`, `lifetimeTotal`, `currentStreak`, `last7Days`, `jaapCountersProvider`, `selectedJaapCounterProvider`, `jaapRepositoryProvider` are used with identical signatures in Tasks 2, 4, 5 and 6. Widget names `JaapProgressRing`, `JaapTapTarget`, `JaapStreakStrip`, `JaapCounterChips`, `JaapNewCounterDialog` are consistent across Tasks 4, 5 and 6.

**Known risk carried honestly:** the repo's pre-existing drift snapshot defect means `flutter test` may report unrelated failures in `test/drift/app_db/`. Task 1 Step 8 states this explicitly and forbids hand-patching generated files.
