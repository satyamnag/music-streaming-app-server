// The first-run analytics disclosure — the piece Play's Prominent Disclosure &
// Consent requirement actually asks for.
//
// Policy basis (verified, not assumed):
//   support.google.com/googleplay/android-developer/answer/10144311
//     * disclosure "must be displayed in the normal usage of the app and not
//       require the user to navigate into a menu or settings";
//     * consent "must require affirmative user action";
//     * "must be granted by the user before your app can begin to collect";
//     * navigating away (back, tapping outside) must NOT count as consent.
//
// So the guards below are the policy, expressed as tests: the dialog exists, it
// lives on the home screen (normal usage), it cannot be dismissed by accident, it
// offers an explicit decline, and the two answers drive the real consent gates.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/modules/analytics/analytics_consent.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

Widget _harness(Widget child) => Theme(
      data: ThemeData(
        radius: .5,
        iconTheme: const IconThemeProperties(),
        colorScheme: BhaktiColorSchemes.lightMaroon(),
        surfaceOpacity: .8,
        surfaceBlur: 10,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 900)),
          child: child,
        ),
      ),
    );

void main() {
  group('the disclosure is shown in normal usage, once', () {
    final home =
        File('lib/pages/home/home.dart').readAsStringSync();

    test('the home screen asks on first run', () {
      expect(
        home.contains('AnalyticsConsent.promptIfNeeded'),
        isTrue,
        reason: 'Play: the disclosure must appear in normal app usage, so it is '
            'asked from Home, not from Settings',
      );
      expect(
        home.contains('addPostFrameCallback'),
        isTrue,
        reason: 'asked after the first frame so it cannot interleave with the '
            'first build',
      );
      expect(
        home.contains('consentAsked'),
        isTrue,
        reason: 'a rebuild must not stack a second copy of the dialog',
      );
    });

    test('it is asked only when the decision is unknown', () {
      final consent =
          File('lib/modules/analytics/analytics_consent.dart').readAsStringSync();
      expect(
        consent.contains('if (hasDecided) return;'),
        isTrue,
        reason: 'a listener who already answered is never asked again',
      );
      expect(consent.contains('analyticsConsentDecided'), isTrue);
    });

    test('answering in Settings counts as answering', () {
      final privacy =
          File('lib/pages/settings/sections/privacy.dart').readAsStringSync();
      expect(
        privacy.contains('AnalyticsConsent.markDecided()'),
        isTrue,
        reason: 'otherwise the Settings user is asked again on the next launch',
      );
    });
  });

  group('the dialog cannot be dismissed into consent', () {
    final source =
        File('lib/modules/analytics/analytics_consent.dart').readAsStringSync();

    test('tapping outside does not close it', () {
      expect(
        source.contains('barrierDismissible: false'),
        isTrue,
        reason: 'Play: tapping away must not be interpreted as consent',
      );
    });

    test('the back gesture does not close it', () {
      expect(
        source.contains('PopScope(') && source.contains('canPop: false'),
        isTrue,
      );
    });

    test('declining is an explicit, labelled answer', () {
      expect(source.contains("const Text('Not now')"), isTrue);
      expect(source.contains("const Text('Allow analytics')"), isTrue);
    });
  });

  group('the disclosure says what a listener cannot otherwise know', () {
    final source =
        File('lib/modules/analytics/analytics_consent.dart').readAsStringSync();

    test('it names the data, the purpose and the account link', () {
      expect(source.contains('account ID'), isTrue,
          reason: 'events carry the Clerk id, which is why this is personal '
              'data needing consent');
      expect(source.contains('advertising ID'), isTrue,
          reason: 'GA4 reads the AD_ID, which the manifest declares');
      expect(source.contains('never sold'), isTrue);
      expect(source.contains('Settings → Privacy'), isTrue,
          reason: 'withdrawal path must be stated in the disclosure');
    });
  });

  group('the dialog widget', () {
    testWidgets('shows both answers and reports the choice', (tester) async {
      var allowed = 0;
      var declined = 0;

      await tester.pumpWidget(_harness(
        AnalyticsConsentDialog(
          onAllow: () async => allowed++,
          onDecline: () async => declined++,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(AnalyticsConsentDialog.title), findsOneWidget);
      expect(find.byKey(const Key('analytics_consent_allow')), findsOneWidget);
      expect(find.byKey(const Key('analytics_consent_decline')), findsOneWidget);

      await tester.tap(find.byKey(const Key('analytics_consent_decline')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(declined, 1);
      expect(allowed, 0,
          reason: 'declining must never grant consent as a side effect');
    });

    testWidgets('allow reports a grant', (tester) async {
      var allowed = 0;
      await tester.pumpWidget(_harness(
        AnalyticsConsentDialog(
          onAllow: () async => allowed++,
          onDecline: () async {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('analytics_consent_allow')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(allowed, 1);
    });
  });
}
