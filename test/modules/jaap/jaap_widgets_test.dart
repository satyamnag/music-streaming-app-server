import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/l10n/generated/app_localizations.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/modules/jaap/jaap_counter_chips.dart';
import 'package:sangeet/modules/jaap/jaap_progress_ring.dart';
import 'package:sangeet/modules/jaap/jaap_streak_strip.dart';
import 'package:sangeet/modules/jaap/jaap_tap_target.dart';
import 'package:sangeet/pages/jaap/jaap_counter.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/provider/jaap/jaap_provider.dart';

/// Wraps a widget with the two things these tests cannot work without:
///
/// 1. `AppLocalizations` delegates. `context.l10n` is
///    `AppLocalizations.of(this)!`, so without them a widget throws a
///    null-check error and renders nothing.
/// 2. A `ProviderScope`, for the widgets that read providers.
Widget _wrap(Widget child, {ProviderScope? scope}) {
  final app = ShadcnApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: m.Material(child: child),
  );
  return scope ?? ProviderScope(child: app);
}

/// A database with the preferences row already present.
///
/// The root shell's bottom nav watches `userPreferencesProvider`, whose
/// `build()` inserts a row via `getDownloadsDirectory()` when none exists.
/// That path_provider call has no Windows implementation and throws, so the
/// row is seeded here instead; the notifier then finds it and never reaches
/// the filesystem.
Future<AppDatabase> _seededDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.into(db.preferencesTable).insert(
        PreferencesTableCompanion.insert(id: const Value(0)),
      );
  return db;
}

Widget _wrapPage(AppDatabase db) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: ShadcnApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const m.Material(child: JaapCounterPage()),
      ),
    );

void main() {
  // ---------------------------------------------------------------- widgets

  testWidgets('progress ring shows the count and the target', (tester) async {
    await tester.pumpWidget(_wrap(const JaapProgressRing(count: 73, target: 108)));
    await tester.pumpAndSettle();

    expect(find.text('73'), findsOneWidget);
    expect(find.text('/ 108'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress ring clamps above the target', (tester) async {
    await tester.pumpWidget(_wrap(const JaapProgressRing(count: 200, target: 108)));
    await tester.pumpAndSettle();

    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress ring renders nothing weird for a zero target', (tester) async {
    await tester.pumpWidget(_wrap(const JaapProgressRing(count: 5, target: 0)));
    await tester.pumpAndSettle();

    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    // A zero target must not divide by zero.
    expect(ring.value, 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap target calls onTap exactly once per press', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(JaapTapTarget(onTap: () => taps++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(JaapTapTarget));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await tester.tap(find.byType(JaapTapTarget));
    await tester.pumpAndSettle();
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak strip shows the streak number and a dot per day', (tester) async {
    final week = List.generate(
      7,
      (i) => JaapDayStatus(
        day: DateTime(2026, 9, 16).add(Duration(days: i)),
        count: i * 10,
        targetMet: i.isEven,
      ),
    );
    await tester.pumpWidget(_wrap(JaapStreakStrip(streak: 12, week: week)));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    // exactly one filled dot per targetMet day
    expect(week.where((d) => d.targetMet).length, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counter chips render each counter and emit selection', (tester) async {
    int? selected;
    var created = false;
    await tester.pumpWidget(
      _wrap(JaapCounterChips(
        counters: const [
          JaapCounter(id: 1, name: 'Gayatri', dailyTarget: 108, sortOrder: 0),
          JaapCounter(id: 2, name: 'Nama', dailyTarget: 1008, sortOrder: 1),
        ],
        selectedId: 1,
        onSelect: (id) => selected = id,
        onCreate: () => created = true,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gayatri'), findsOneWidget);
    expect(find.text('Nama'), findsOneWidget);

    await tester.tap(find.text('Nama'));
    await tester.pumpAndSettle();
    expect(selected, 2);

    await tester.tap(find.byIcon(FeatherIcons.plus));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------------- page

  testWidgets('page shows a create affordance when there are no counters', (tester) async {
    final db = await _seededDb();
    await tester.pumpWidget(_wrapPage(db));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(m.Icons.add), findsOneWidget);

    await db.close();
  });

  testWidgets('page shows the tap target once a counter exists', (tester) async {
    final db = await _seededDb();
    await JaapRepository(db).createCounter(name: 'Gayatri', dailyTarget: 108);

    await tester.pumpWidget(_wrapPage(db));
    await tester.pumpAndSettle();

    expect(find.byType(JaapTapTarget), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
  });

  testWidgets('tapping the target persists through the debounce', (tester) async {
    final db = await _seededDb();
    final repo = JaapRepository(db);
    final id = await repo.createCounter(name: 'Gayatri', dailyTarget: 3);

    await tester.pumpWidget(_wrapPage(db));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(JaapTapTarget));
      await tester.pump();
    }
    // let the 400 ms debounce fire, then let the write settle
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(await repo.todayCount(id, DateTime.now()), 3);
    expect(tester.takeException(), isNull);

    await db.close();
  });

  testWidgets('page seeds an existing count from the database', (tester) async {
    final db = await _seededDb();
    final repo = JaapRepository(db);
    final id = await repo.createCounter(name: 'Nama', dailyTarget: 108);
    await repo.increment(id, DateTime.now());
    await repo.increment(id, DateTime.now());

    await tester.pumpWidget(_wrapPage(db));
    await tester.pumpAndSettle();

    // The seeded tally must be visible, not zero.
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
  });
}
