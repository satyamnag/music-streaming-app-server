import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/provider/history/top.dart';

/// One calendar day of listening, as the Analytics screen charts it.
class ListeningDay {
  /// Local midnight of the day.
  final DateTime day;

  /// Track plays scrobbled that day.
  final int plays;

  /// NOMINAL minutes: the sum of the full lengths of the tracks played that
  /// day, not the seconds actually spent with the app open. This is the same
  /// basis `playbackHistorySummaryProvider` uses for "minutes listened", so the
  /// two can never disagree about what a minute means.
  final int minutes;

  const ListeningDay({
    required this.day,
    required this.plays,
    required this.minutes,
  });

  bool get hasPlay => plays > 0;
}

/// Everything the Analytics screen shows about the selected period.
///
/// Pure value object: [computeListeningActivity] builds it from the database
/// rows, so all of the arithmetic below is unit-tested without a database, an
/// engine or a network.
class ListeningActivity {
  /// The period these numbers describe.
  final HistoryDuration range;

  /// Track plays inside the period.
  final int plays;

  /// Track plays inside the equally long period immediately before it, used as
  /// the trend's baseline. Zero when there is no such period (all time).
  final int previousPlays;

  /// Nominal minutes listened inside the period.
  final int totalMinutes;

  /// Nominal minutes listened in the baseline period.
  final int previousMinutes;

  /// Consecutive days with at least one play, ending today — or yesterday when
  /// today has none yet, because today is not over.
  final int currentStreakDays;

  /// The longest run of consecutive days with at least one play, ever.
  final int bestStreakDays;

  /// Days of the period that had at least one play.
  final int devotionalDays;

  /// Days the period covers, for "You listened on X out of Y days".
  final int rangeDays;

  /// The current week, Monday first, exactly seven entries with the days that
  /// have no plays zero-filled. This is what the chart draws, and what its
  /// "Total this week" sums, so the bars always add up to the printed total.
  final List<ListeningDay> weekDays;

  const ListeningActivity({
    required this.range,
    required this.plays,
    required this.previousPlays,
    required this.totalMinutes,
    required this.previousMinutes,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.devotionalDays,
    required this.rangeDays,
    required this.weekDays,
  });

  /// Minutes across [weekDays], i.e. the chart's own total.
  int get weekMinutes =>
      weekDays.fold(0, (sum, day) => sum + day.minutes);

  /// How many days the trend compares against, or null when there is nothing to
  /// compare with (all time, which has no previous period).
  int? get comparisonDays => switch (range) {
        HistoryDuration.days7 => 7,
        HistoryDuration.days30 => 30,
        _ => null,
      };

  /// Signed percent change in plays against the previous period, or null when
  /// there is no baseline to compare against.
  double? get playsTrendPercent => percentChange(plays, previousPlays);

  /// Signed percent change in minutes against the previous period, or null when
  /// there is no baseline to compare against.
  double? get minutesTrendPercent =>
      percentChange(totalMinutes, previousMinutes);
}

/// Signed percent change from [previous] to [current], or null when [previous]
/// is not a usable baseline (a jump from nothing has no meaningful percentage,
/// so it is reported as "no trend" rather than as +100% or infinity).
double? percentChange(num current, num previous) {
  if (previous <= 0) return null;
  return ((current - previous) / previous) * 100;
}

/// A deity shelf: one admin-authored Featured Playlist chip, which is how this
/// app already groups tracks by deity (`featured_playlists`, migrations 028/029,
/// shown on the home screen as the round chips under the carousel).
class DeityShelf {
  final String id;
  final String title;

  /// Admin-uploaded deity artwork, drawn in the card's circle. Null falls back
  /// to the theme's glyph, so the circle is never blank.
  final String? iconUrl;

  final Set<String> trackIds;

  const DeityShelf({
    required this.id,
    required this.title,
    required this.trackIds,
    this.iconUrl,
  });
}

/// The deity the user listened to most in a period, and how big a share of that
/// period's listening it was.
class FavouriteDeity {
  final String id;
  final String title;
  final String? iconUrl;
  final int minutes;

  /// Nominal minutes listened in the period across ALL tracks, i.e. the
  /// denominator of [sharePercent].
  final int totalMinutes;

  const FavouriteDeity({
    required this.id,
    required this.title,
    required this.minutes,
    required this.totalMinutes,
    this.iconUrl,
  });

  /// The deity's share of the period's listening, 0..100, rounded for display.
  int get sharePercent =>
      totalMinutes <= 0 ? 0 : ((minutes * 100) / totalMinutes).round();
}

/// Start of the window a [range] describes, as local midnight.
///
/// These boundaries are deliberately the SAME ones `historyTopTracksProvider`
/// uses (Monday for the week, the 1st for the month, the epoch for all time), so
/// every number on one Analytics screen describes one period. A screen whose
/// cards said "this week" while its Top Tracks list said "this month" would be
/// worse than either alone.
DateTime historyWindowStart(HistoryDuration range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (range) {
    HistoryDuration.days7 =>
      DateTime(today.year, today.month, today.day - (today.weekday - 1)),
    HistoryDuration.days30 => DateTime(today.year, today.month, 1),
    _ => DateTime(1970),
  };
}

/// Local midnight [days] after [day]. Day arithmetic goes through the calendar
/// fields rather than `Duration(days: n)` so a DST change can never shift a
/// bucket by an hour into the neighbouring day.
DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Builds the Analytics screen's numbers from per-day totals.
///
/// [perDay] is keyed by local midnight and holds that day's plays and nominal
/// minutes; days with no listening are simply absent.
ListeningActivity computeListeningActivity({
  required Map<DateTime, ({int plays, int minutes})> perDay,
  required DateTime now,
  required HistoryDuration range,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = _addDays(today, 1);
  final windowStart = historyWindowStart(range, today);

  int playsIn(DateTime from, DateTime toExclusive) {
    var total = 0;
    for (final entry in perDay.entries) {
      if (entry.key.isBefore(from) || !entry.key.isBefore(toExclusive)) {
        continue;
      }
      total += entry.value.plays;
    }
    return total;
  }

  int minutesIn(DateTime from, DateTime toExclusive) {
    var total = 0;
    for (final entry in perDay.entries) {
      if (entry.key.isBefore(from) || !entry.key.isBefore(toExclusive)) {
        continue;
      }
      total += entry.value.minutes;
    }
    return total;
  }

  // The baseline is the equally long window immediately before the current one:
  // the previous seven days for the week, the previous thirty for the month, and
  // nothing at all for all time.
  final (previousStart, previousEnd) = switch (range) {
    HistoryDuration.days7 => (_addDays(windowStart, -7), windowStart),
    HistoryDuration.days30 => (_addDays(windowStart, -30), windowStart),
    _ => (windowStart, windowStart),
  };

  // A streak ends today, or yesterday when today has no play yet.
  var currentStreak = 0;
  var cursor =
      (perDay[today]?.plays ?? 0) > 0 ? today : _addDays(today, -1);
  while ((perDay[cursor]?.plays ?? 0) > 0) {
    currentStreak++;
    cursor = _addDays(cursor, -1);
  }

  // The best streak is the longest run anywhere in the history, so it is
  // computed from every day that has a play rather than from a window.
  var bestStreak = 0;
  var run = 0;
  DateTime? previousDay;
  final playedDays = perDay.entries
      .where((e) => e.value.plays > 0)
      .map((e) => e.key)
      .toList()
    ..sort();
  for (final day in playedDays) {
    final previous = previousDay;
    if (previous != null && _addDays(previous, 1) == day) {
      run++;
    } else {
      run = 1;
    }
    if (run > bestStreak) bestStreak = run;
    previousDay = day;
  }

  // The chart is always the current week (the mock's "Total this week"), with
  // Monday first, so it reads the same whatever range the cards describe.
  final weekStart = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  final weekDays = [
    for (var i = 0; i < 7; i++)
      ListeningDay(
        day: _addDays(weekStart, i),
        plays: perDay[_addDays(weekStart, i)]?.plays ?? 0,
        minutes: perDay[_addDays(weekStart, i)]?.minutes ?? 0,
      ),
  ];

  final devotionalDays = playedDays
      .where((day) => !day.isBefore(windowStart) && day.isBefore(tomorrow))
      .length;

  // All time has no fixed length, so "out of N days" counts from the first day
  // the user ever listened. A history with no plays is "0 out of 1" rather than
  // a division by zero.
  final rangeDays = switch (range) {
    HistoryDuration.days7 => 7,
    HistoryDuration.days30 => 30,
    _ => playedDays.isEmpty
        ? 1
        : tomorrow.difference(playedDays.first).inDays.clamp(1, 100000),
  };

  return ListeningActivity(
    range: range,
    plays: playsIn(windowStart, tomorrow),
    previousPlays: playsIn(previousStart, previousEnd),
    totalMinutes: minutesIn(windowStart, tomorrow),
    previousMinutes: minutesIn(previousStart, previousEnd),
    currentStreakDays: currentStreak,
    bestStreakDays: bestStreak,
    devotionalDays: devotionalDays,
    rangeDays: rangeDays,
    weekDays: weekDays,
  );
}

/// Picks the deity whose shelves hold the largest share of the period's
/// listening.
///
/// [minutesByTrackId] is the period's nominal minutes per track. A track the
/// admin has not filed under any deity contributes to [FavouriteDeity.
/// totalMinutes] (the denominator) but to no shelf, so the share is always "of
/// your listening time" exactly as the card says, never "of what we could
/// classify".
///
/// Returns null when nothing was played, or when no played track belongs to any
/// deity shelf — in which case the card is not shown at all rather than
/// inventing a favourite.
FavouriteDeity? computeFavouriteDeity({
  required Map<String, int> minutesByTrackId,
  required List<DeityShelf> shelves,
}) {
  var totalMinutes = 0;
  for (final minutes in minutesByTrackId.values) {
    totalMinutes += minutes;
  }
  if (totalMinutes <= 0) return null;

  FavouriteDeity? best;
  for (final shelf in shelves) {
    var minutes = 0;
    for (final id in shelf.trackIds) {
      minutes += minutesByTrackId[id] ?? 0;
    }
    if (minutes <= 0) continue;
    // Ties go to the earlier chip in the admin's order, which is the order the
    // home screen shows, so the same win cannot flip between builds.
    if (best == null || minutes > best.minutes) {
      best = FavouriteDeity(
        id: shelf.id,
        title: shelf.title,
        iconUrl: shelf.iconUrl,
        minutes: minutes,
        totalMinutes: totalMinutes,
      );
    }
  }
  return best;
}

/// Per-day plays and nominal minutes for every day that has a track play.
///
/// `created_at` is a `DateTimeColumn`, which drift stores as unix seconds (this
/// app never sets `storeDateTimeAsText`), so `'unixepoch'` reads it back and
/// `'localtime'` puts it on the USER's calendar day. Without `'localtime'` an
/// early-morning bhajan — the normal case here — would fall on the previous day.
/// Days are bucketed in SQL so the watch stream carries one row per day instead
/// of re-reading the whole history on every play.
final listeningActivityProvider =
    StreamProvider.family<ListeningActivity, HistoryDuration>((ref, range) {
  final database = ref.watch(databaseProvider);

  final query = database.customSelect(
    r'''
    SELECT date(created_at, 'unixepoch', 'localtime') AS day,
           count(*) AS plays,
           sum(CASE WHEN json_valid(data)
                    THEN coalesce(json_extract(data, '$.durationMs'), 0)
                    ELSE 0 END) AS milliseconds
    FROM history_table
    WHERE type = 'track'
    GROUP BY day
    ORDER BY day
    ''',
  );

  return query.watch().map((rows) {
    final perDay = <DateTime, ({int plays, int minutes})>{};
    for (final row in rows) {
      final rawDay = row.data['day']?.toString();
      if (rawDay == null) continue;
      final parsed = DateTime.tryParse(rawDay);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      final plays = (row.data['plays'] as num?)?.toInt() ?? 0;
      final milliseconds = (row.data['milliseconds'] as num?)?.toInt() ?? 0;
      perDay[day] = (plays: plays, minutes: (milliseconds / 60000).round());
    }
    return computeListeningActivity(
      perDay: perDay,
      now: DateTime.now(),
      range: range,
    );
  });
});

/// Nominal minutes per track id for the selected period, which is what the
/// favourite-deity attribution divides up.
final historyMinutesByTrackProvider =
    StreamProvider.family<Map<String, int>, HistoryDuration>((ref, range) {
  final database = ref.watch(databaseProvider);
  final now = DateTime.now();
  final windowStart = historyWindowStart(range, now);

  final query = database.customSelect(
    r'''
    SELECT item_id AS track_id,
           sum(CASE WHEN json_valid(data)
                    THEN coalesce(json_extract(data, '$.durationMs'), 0)
                    ELSE 0 END) AS milliseconds
    FROM history_table
    WHERE type = 'track' AND created_at >= ?
    GROUP BY item_id
    ''',
    variables: [
      Variable<int>(windowStart.millisecondsSinceEpoch ~/ 1000),
    ],
  );

  return query.watch().map((rows) {
    final minutesByTrack = <String, int>{};
    for (final row in rows) {
      final trackId = row.data['track_id']?.toString();
      if (trackId == null || trackId.isEmpty) continue;
      final milliseconds = (row.data['milliseconds'] as num?)?.toInt() ?? 0;
      minutesByTrack[trackId] = (milliseconds / 60000).round();
    }
    return minutesByTrack;
  });
});

/// The user's favourite deity for the period, derived from the admin's own
/// Featured Playlist chips — the same shelves the home screen shows.
///
/// It resolves to null (and the card is hidden) when the chips are unavailable,
/// when nothing was played, or when none of the played tracks is filed under a
/// deity. There is deliberately no fallback: a made-up deity would be worse than
/// no card.
final favouriteDeityProvider =
    FutureProvider.family<FavouriteDeity?, HistoryDuration>((ref, range) async {
  final playlists = await ref.watch(featuredPlaylistsProvider.future);
  if (playlists.isEmpty) return null;

  final minutesByTrack =
      await ref.watch(historyMinutesByTrackProvider(range).future);

  return computeFavouriteDeity(
    minutesByTrackId: minutesByTrack,
    shelves: [
      for (final playlist in playlists)
        DeityShelf(
          id: playlist.id,
          title: playlist.title,
          iconUrl: playlist.iconUrl,
          trackIds: {for (final track in playlist.tracks) track.id},
        ),
    ],
  );
});
