// Unit tests for the Analytics screen's arithmetic.
//
// The screen's numbers are all derived, so the derivations are the thing worth
// testing: the week window, the streaks, the "out of N days" denominator, the
// period trend and the deity attribution. They are pure functions over a
// per-day map, which is why they can be checked here without a database, an
// audio engine or a network.
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/provider/history/listening_activity.dart';
import 'package:sangeet/provider/history/top.dart';

/// A fixed "now" so every window is deterministic.
///
/// 2026-10-28 is a Wednesday — asserted below, because the week-window
/// assertions depend on it and a silently different weekday would make them
/// pass for the wrong reason.
final DateTime _now = DateTime(2026, 10, 28);

Map<DateTime, ({int plays, int minutes})> _days(
  Map<int, int> offsetToMinutes, {
  int playsPerDay = 1,
}) {
  return {
    for (final entry in offsetToMinutes.entries)
      DateTime(_now.year, _now.month, _now.day + entry.key): (
        plays: playsPerDay,
        minutes: entry.value,
      ),
  };
}

void main() {
  setUpAll(() {
    expect(_now.weekday, DateTime.wednesday);
  });

  group('percentChange', () {
    test('is the signed change against the previous period', () {
      expect(percentChange(120, 100), closeTo(20, 0.0001));
      expect(percentChange(80, 100), closeTo(-20, 0.0001));
      expect(percentChange(0, 100), closeTo(-100, 0.0001));
    });

    test('has no answer when there is no baseline', () {
      expect(percentChange(10, 0), isNull);
      expect(percentChange(0, 0), isNull);
    });
  });

  group('historyWindowStart', () {
    test('the week starts on Monday', () {
      expect(historyWindowStart(HistoryDuration.days7, _now).weekday,
          DateTime.monday);
      expect(historyWindowStart(HistoryDuration.days7, _now), DateTime(2026, 10, 26));
    });

    test('the month starts on the 1st', () {
      expect(historyWindowStart(HistoryDuration.days30, _now), DateTime(2026, 10, 1));
    });

    test('all time starts at the epoch', () {
      expect(historyWindowStart(HistoryDuration.allTime, _now), DateTime(1970));
    });
  });

  group('computeListeningActivity', () {
    test('an empty history is zeros, not an error', () {
      final activity = computeListeningActivity(
        perDay: const {},
        now: _now,
        range: HistoryDuration.days7,
      );

      expect(activity.plays, 0);
      expect(activity.totalMinutes, 0);
      expect(activity.currentStreakDays, 0);
      expect(activity.bestStreakDays, 0);
      expect(activity.devotionalDays, 0);
      expect(activity.playsTrendPercent, isNull);
      expect(activity.minutesTrendPercent, isNull);
      // Seven bars, all zero, Monday first.
      expect(activity.weekDays.length, 7);
      expect(activity.weekDays.first.day.weekday, DateTime.monday);
      expect(activity.weekMinutes, 0);
    });

    test('the week window covers Monday through today', () {
      final activity = computeListeningActivity(
        perDay: _days({-2: 10, 0: 5}),
        now: _now,
        range: HistoryDuration.days7,
      );

      // Monday (offset -2) and today (Wednesday) are inside; nothing else is
      // present, so the totals are exactly those two days.
      expect(activity.totalMinutes, 15);
      expect(activity.plays, 2);
      expect(activity.devotionalDays, 2);
      expect(activity.rangeDays, 7);
      expect(activity.weekMinutes, activity.totalMinutes);
    });

    test('the month window covers the 1st through today', () {
      final activity = computeListeningActivity(
        perDay: _days({-27: 30, -3: 7, 0: 3}),
        now: _now,
        range: HistoryDuration.days30,
      );

      // October 1st is offset -27 from October 28th, so all three days are in.
      expect(activity.totalMinutes, 40);
      expect(activity.rangeDays, 30);
      expect(activity.devotionalDays, 3);
    });

    test('all time covers everything and spans from the first played day', () {
      final activity = computeListeningActivity(
        perDay: _days({-40: 12, -1: 8, 0: 4}),
        now: _now,
        range: HistoryDuration.allTime,
      );

      expect(activity.totalMinutes, 24);
      // 40 days back .. today inclusive = 41 days.
      expect(activity.rangeDays, 41);
      expect(activity.devotionalDays, 3);
      // There is no period before "all time", so there is no trend.
      expect(activity.playsTrendPercent, isNull);
      expect(activity.comparisonDays, isNull);
    });

    test('the trend compares against the previous equally long window', () {
      final activity = computeListeningActivity(
        // Current week (Mon..today): 20 minutes over two days.
        // Previous week: 10 minutes.
        perDay: _days({-2: 12, 0: 8, -9: 6, -7: 4}),
        now: _now,
        range: HistoryDuration.days7,
      );

      expect(activity.totalMinutes, 20);
      expect(activity.previousMinutes, 10);
      expect(activity.minutesTrendPercent, closeTo(100, 0.0001));
      expect(activity.comparisonDays, 7);
    });

    test('the current streak ends today when today has a play', () {
      final activity = computeListeningActivity(
        perDay: _days({0: 5, -1: 5, -2: 5}),
        now: _now,
        range: HistoryDuration.days7,
      );
      expect(activity.currentStreakDays, 3);
    });

    test('the current streak still counts when today has no play yet', () {
      final activity = computeListeningActivity(
        perDay: _days({-1: 5, -2: 5}),
        now: _now,
        range: HistoryDuration.days7,
      );
      expect(activity.currentStreakDays, 2);
    });

    test('a missed day ends the current streak', () {
      final activity = computeListeningActivity(
        perDay: _days({-2: 5, -3: 5}),
        now: _now,
        range: HistoryDuration.days7,
      );
      expect(activity.currentStreakDays, 0);
    });

    test('the best streak is the longest run anywhere in the history', () {
      final activity = computeListeningActivity(
        // Runs: [today, -1] = 2, and [-5, -6, -7] = 3.
        perDay: _days({0: 1, -1: 1, -5: 1, -6: 1, -7: 1}),
        now: _now,
        range: HistoryDuration.days7,
      );
      expect(activity.currentStreakDays, 2);
      expect(activity.bestStreakDays, 3);
    });

    test('the chart sums to the week total', () {
      final activity = computeListeningActivity(
        perDay: _days({-2: 12, -1: 25, 0: 18}),
        now: _now,
        range: HistoryDuration.days7,
      );
      var sum = 0;
      for (final day in activity.weekDays) {
        sum += day.minutes;
      }
      expect(sum, activity.weekMinutes);
      expect(activity.weekMinutes, 55);
      // Each bar sits on its own weekday, in order.
      expect(activity.weekDays[0].minutes, 12);
      expect(activity.weekDays[1].minutes, 25);
      expect(activity.weekDays[2].minutes, 18);
      expect(activity.weekDays[6].day.weekday, DateTime.sunday);
    });
  });

  group('computeFavouriteDeity', () {
    const krishna = DeityShelf(
      id: 'krishna',
      title: 'Krishna',
      iconUrl: 'https://cdn.example/krishna.png',
      trackIds: {'k1', 'k2'},
    );
    const ganesha = DeityShelf(
      id: 'ganesha',
      title: 'Ganesha',
      trackIds: {'g1'},
    );

    test('is null when nothing was played', () {
      expect(
        computeFavouriteDeity(minutesByTrackId: const {}, shelves: const [krishna]),
        isNull,
      );
    });

    test('is null when no played track belongs to a deity', () {
      expect(
        computeFavouriteDeity(
          minutesByTrackId: const {'unknown-track': 30},
          shelves: const [krishna, ganesha],
        ),
        isNull,
      );
    });

    test('picks the deity with the most minutes', () {
      final favourite = computeFavouriteDeity(
        minutesByTrackId: const {'k1': 20, 'k2': 10, 'g1': 12, 'other': 18},
        shelves: const [krishna, ganesha],
      );

      expect(favourite, isNotNull);
      expect(favourite!.id, 'krishna');
      // 30 of the 60 listened minutes, and the tracks no deity owns are still
      // part of the denominator — the card says "of your listening time".
      expect(favourite.minutes, 30);
      expect(favourite.totalMinutes, 60);
      expect(favourite.sharePercent, 50);
      expect(favourite.iconUrl, 'https://cdn.example/krishna.png');
    });

    test('a tie keeps the first shelf, so it cannot flip between builds', () {
      final favourite = computeFavouriteDeity(
        minutesByTrackId: const {'k1': 10, 'g1': 10},
        shelves: const [krishna, ganesha],
      );
      expect(favourite?.id, 'krishna');
    });

    test('a shelf with no played tracks is never chosen', () {
      final favourite = computeFavouriteDeity(
        minutesByTrackId: const {'g1': 4},
        shelves: const [krishna, ganesha],
      );
      expect(favourite?.id, 'ganesha');
      expect(favourite?.sharePercent, 100);
    });
  });
}
