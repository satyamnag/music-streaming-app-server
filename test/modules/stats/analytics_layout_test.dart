// Layout guard for the Analytics screen's new cards.
//
// The two tightest pieces of the design are the four accent cards (two per row
// on a phone) and the streak / favourite-deity pair, which share one row and
// both carry a lot of text. Flutter turns any RenderFlex overflow into a test
// failure in debug mode, so pumping them at the narrowest supported width is a
// direct reproduction: if a card overflows, this test fails and names it.
//
// The header and the Top Tracks card are left out on purpose: the first needs a
// wallpaper URL and the second needs the playback database, neither of which a
// widget test has. Their layouts are single-column and cannot overflow
// horizontally.
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:sangeet/modules/stats/analytics/analytics_activity_chart.dart';
import 'package:sangeet/modules/stats/analytics/analytics_header.dart';
import 'package:sangeet/modules/stats/analytics/analytics_stats.dart';
import 'package:sangeet/modules/stats/analytics/analytics_streak_deity.dart';
import 'package:sangeet/provider/history/listening_activity.dart';
import 'package:sangeet/provider/history/top.dart';

final DateTime _now = DateTime(2026, 10, 28);

Widget _harness(Widget child, {required bool dark}) {
  return ProviderScope(
    child: material.MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: L10n.all,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Theme(
          data: ThemeData(
            radius: .5,
            iconTheme: const IconThemeProperties(),
            colorScheme: dark
                ? BhaktiColorSchemes.darkMaroon()
                : BhaktiColorSchemes.lightMaroon(),
            surfaceOpacity: .8,
            surfaceBlur: 10,
          ),
          child: child,
        ),
      ),
    ),
  );
}

ListeningActivity _busyWeek() => computeListeningActivity(
      perDay: {
        for (final offset in const [0, -1, -2, -3, -5, -6])
          DateTime(_now.year, _now.month, _now.day + offset): (
            plays: 9,
            minutes: 128,
          ),
      },
      now: _now,
      range: HistoryDuration.days7,
    );

Widget _screen(ListeningActivity activity) {
  return SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stands in for AnalyticsHeader, which needs a wallpaper URL.
        const SizedBox(height: AnalyticsHeader.height),
        const AnalyticsRangeTabs(),
        AnalyticsStatGrid(activity: activity),
        AnalyticsActivityChart(activity: activity),
        AnalyticsStreakAndDeity(
          activity: activity,
          // Deliberately the longest deity name the admin's shelves use, so the
          // tightest realistic case is the one being measured.
          deity: const FavouriteDeity(
            id: 'venkateswara',
            title: 'Venkateswara',
            minutes: 84,
            totalMinutes: 130,
          ),
        ),
      ],
    ),
  );
}

void main() {
  for (final width in const [320.0, 360.0, 412.0]) {
    for (final dark in const [false, true]) {
      testWidgets(
        'the analytics cards fit a ${width.toInt()}dp '
        '${dark ? 'dark' : 'light'} phone',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_harness(_screen(_busyWeek()), dark: dark));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'the Analytics cards must not overflow at ${width}dp',
          );
        },
      );
    }
  }

  testWidgets('an empty history still lays out', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final activity = computeListeningActivity(
      perDay: const {},
      now: _now,
      range: HistoryDuration.allTime,
    );

    await tester.pumpWidget(_harness(_screen(activity), dark: false));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
