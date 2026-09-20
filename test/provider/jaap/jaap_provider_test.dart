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
    expect((await repo.counters()).single.dailyTarget, 10);
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

  test('dayKey zero-pads single-digit months and days', () {
    expect(JaapRepository.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(JaapRepository.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('createCounter rejects an empty name and a non-positive target', () async {
    expect(
      () => repo.createCounter(name: '   ', dailyTarget: 108),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repo.createCounter(name: 'Gayatri', dailyTarget: 0),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('setDailyTarget rejects a non-positive target', () async {
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 108);
    expect(() => repo.setDailyTarget(id, 0), throwsA(isA<ArgumentError>()));
  });
}
