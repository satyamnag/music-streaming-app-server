import 'dart:async';

import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/provider/database/database.dart';

/// Per-day listening insights derived from the local history table
/// (one `type='track'` row per scrobbled play, `created_at` second precision).
///
/// All values are computed with SQL GROUP BY over the single local table —
/// bounded rows out, no schema changes, no network.
class PlaybackInsights {
  /// Scrobbled track plays since the start of the current week (Monday).
  final int playsThisWeek;

  /// Scrobbled track plays in the 7 days before the current week.
  final int playsPreviousWeek;

  /// Calendar day with the most scrobbled plays (most recent on ties).
  final DateTime bestDay;

  /// Consecutive days with at least one play, ending today or yesterday
  /// (today is not yet complete, so it may be excluded).
  final int currentStreakDays;

  const PlaybackInsights({
    required this.playsThisWeek,
    required this.playsPreviousWeek,
    required this.bestDay,
    required this.currentStreakDays,
  });

  /// Signed percent change of plays this week vs the previous week, or null
  /// when there is no baseline week to compare against.
  double? get weekTrendPercent {
    if (playsPreviousWeek <= 0) return null;
    return ((playsThisWeek - playsPreviousWeek) / playsPreviousWeek) * 100;
  }
}

class PlaybackInsightsNotifier extends AsyncNotifier<PlaybackInsights> {
  @override
  Future<PlaybackInsights> build() async {
    final database = ref.watch(databaseProvider);
    final byDay = database.customSelect(
      "SELECT date(created_at) AS day, count(*) AS plays "
      "FROM history_table WHERE type = 'track' GROUP BY day",
    );

    final subscription = byDay.watch().listen((rows) {
      state = AsyncData(_compute(rows));
    });
    ref.onDispose(subscription.cancel);

    return _compute(await byDay.get());
  }

  PlaybackInsights _compute(List<QueryRow> rows) {
    final perDay = <DateTime, int>{
      for (final row in rows)
        DateTime.parse(row.read<String>('day')): row.read<int>('plays'),
    };
    if (perDay.isEmpty) {
      return PlaybackInsights(
        playsThisWeek: 0,
        playsPreviousWeek: 0,
        bestDay: DateTime.now(),
        currentStreakDays: 0,
      );
    }

    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    // Current week starts on Monday (matches the Top Tracks convention).
    final weekStart = midnight.subtract(Duration(days: midnight.weekday - 1));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));

    int playsIn(DateTime from, DateTime toExclusive) => perDay.entries
        .where((e) => !e.key.isBefore(from) && e.key.isBefore(toExclusive))
        .fold(0, (sum, e) => sum + e.value);

    final bestDay = perDay.entries.reduce((a, b) =>
        (b.value > a.value) ||
            (b.value == a.value && b.key.isAfter(a.key))
            ? b
            : a).key;

    // Current streak: consecutive days with at least one play, ending today
    // (or yesterday when today has none yet).
    var streak = 0;
    var cursor = perDay.containsKey(midnight)
        ? midnight
        : midnight.subtract(const Duration(days: 1));
    while (perDay.containsKey(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return PlaybackInsights(
      playsThisWeek: playsIn(weekStart, previousWeekStart.add(const Duration(days: 14))),
      playsPreviousWeek: playsIn(previousWeekStart, weekStart),
      bestDay: bestDay,
      currentStreakDays: streak,
    );
  }
}

final playbackInsightsProvider =
    AsyncNotifierProvider<PlaybackInsightsNotifier, PlaybackInsights>(
  PlaybackInsightsNotifier.new,
);