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
  /// Historical days are evaluated against the counter's *current* target.
  Future<int> currentStreak(int counterId, DateTime today) async {
    final counter = await (db.select(db.jaapCountersTable)
          ..where((t) => t.id.equals(counterId)))
        .getSingleOrNull();
    if (counter == null) return 0;
    final target = counter.dailyTarget;
    // Defensive: a non-positive target would make the loop below run forever,
    // because `0 >= 0` is always true. The public API rejects such values, but
    // the column has no CHECK constraint, so guard here too.
    if (target <= 0) return 0;
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
        // Step by calendar day, not by 24h: DST transitions can make a local
        // day 23 or 25 hours long, and the DateTime constructor normalises
        // out-of-range day values.
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      } else {
        break;
      }
    }
    return streak;
  }

  /// The last 7 local days ending at [today], oldest first.
  /// `targetMet` is evaluated against the counter's *current* target.
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
      final d = DateTime(base.year, base.month, base.day - (6 - i));
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
