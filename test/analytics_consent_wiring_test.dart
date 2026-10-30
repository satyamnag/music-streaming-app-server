// Proves the Settings → Privacy switch really drives Google Analytics.
//
// The Play Console declares that this app uses the advertising ID, and the
// permission is shipped. What must ALSO stay true is that the identifier is only
// read once the listener has opted in: the manifest switches GA4 off
// (firebase_analytics_collection_enabled=false) and the only thing that can turn
// it back on is FirebaseAnalyticsService.applyConsent — called from the startup
// path and from this switch.
//
// Asserting that against the REAL widget (not the source text) is what this file
// is for: the seam in FirebaseAnalyticsService records every enable/disable GA4
// would have received.
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:sangeet/pages/settings/sections/privacy.dart';
import 'package:sangeet/services/analytics/firebase_analytics_service.dart';
import 'package:sangeet/services/analytics/posthog_service.dart';

Widget _harness() {
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
            colorScheme: BhaktiColorSchemes.lightMaroon(),
            surfaceOpacity: .8,
            surfaceBlur: 10,
          ),
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 900)),
            child: const material.Material(
              child: SettingsPrivacySection(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late List<bool> ga4Calls;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // PostHogService is a process-wide singleton, so its consent survives from
    // one test to the next; start every test from the shipping default (off).
    await PostHogService.instance.setConsent(false);

    ga4Calls = <bool>[];
    FirebaseAnalyticsService.instance.debugSetCollectionOverride =
        (granted) async => ga4Calls.add(granted);
  });

  tearDown(() {
    FirebaseAnalyticsService.instance.debugSetCollectionOverride = null;
  });

  testWidgets('turning analytics ON enables Google Analytics', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(PostHogService.instance.hasConsent, isFalse,
        reason: 'a fresh install starts opted out');

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(ga4Calls, <bool>[true],
        reason: 'the same switch that opts in to PostHog must enable GA4, or the '
            'advertising-ID declaration would describe collection that never '
            'starts - and the listener would be told analytics is on while '
            'Google Analytics stayed dark');
    expect(FirebaseAnalyticsService.instance.lastApplied, isTrue);
    expect(PostHogService.instance.hasConsent, isTrue);
  });

  testWidgets('turning analytics OFF disables Google Analytics', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch)); // on
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch)); // off
    await tester.pumpAndSettle();

    expect(ga4Calls, <bool>[true, false],
        reason: 'withdrawing consent must stop GA4 collection immediately, which '
            'is also when the app stops reading the advertising identifier');
    expect(PostHogService.instance.hasConsent, isFalse);
  });
}
