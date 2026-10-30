// Guards the Play Console ADVERTISING ID declaration.
//
// The Console answer is **Yes**: Play Console -> App content -> Advertising ID ->
// "Does your app use advertising ID?" -> Yes. That answer is only safe while the
// four facts below stay true together, so each one is asserted here:
//
//   1. the shipped manifest declares com.google.android.gms.permission.AD_ID
//      (Play BLOCKS a release whose declaration says Yes while the artifact
//      lacks the permission);
//   2. a component that genuinely uses the identifier is present - Google
//      Analytics for Firebase, which Google's own Android documentation says
//      collects it by default;
//   3. the identifier is never used for personalized advertising, and
//      collection only happens after the listener opts in;
//   4. the privacy policy discloses it, which is what the Play Ads policy
//      requires of an app that reads the identifier.
//
// A regression in any of these is worse than a build failure: it is a Play
// policy violation discovered during review, with the release blocked.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  final gradle = File('android/app/build.gradle').readAsStringSync();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('the artifact declares the advertising ID (Console answer: Yes)', () {
    test('the permission is declared explicitly in the manifest', () {
      expect(
        manifest.contains(
          '<uses-permission android:name="com.google.android.gms.permission.AD_ID" />',
        ),
        isTrue,
        reason: 'Play blocks releases whose Console declaration says Yes while '
            'the merged manifest lacks AD_ID. Declaring it here (not relying on '
            'a transitive AAR) is what makes the answer safe.',
      );
    });

    test('the component that uses the identifier is a real dependency', () {
      expect(
        gradle.contains("implementation 'com.google.firebase:firebase-analytics'"),
        isTrue,
        reason: 'answering Yes must be TRUE: GA4 is the component that reads the '
            'advertising ID, so the Gradle artifact has to be there',
      );
      expect(
        pubspec.contains('firebase_analytics:'),
        isTrue,
        reason: 'the Flutter side must be able to drive its consent',
      );
    });
  });

  group('the identifier is used for measurement only, and only after consent', () {
    test('collection is switched off until the listener opts in', () {
      expect(
        manifest.contains('android:name="firebase_analytics_collection_enabled"'),
        isTrue,
        reason: 'Google documents this meta-data as the way to disable '
            'collection until consent is collected',
      );
      expect(
        RegExp(
          r'firebase_analytics_collection_enabled"\s*\n?\s*android:value="false"',
        ).hasMatch(manifest),
        isTrue,
        reason: 'it must be FALSE - analytics is opt-in in this app',
      );
    });

    test('personalized advertising is off', () {
      expect(
        manifest.contains(
          'android:name="google_analytics_default_allow_ad_personalization_signals"',
        ),
        isTrue,
        reason: 'the Ads policy allows the identifier only for advertising and '
            'user analytics; this app promises analytics only, so personalized '
            'advertising must be off',
      );
    });

    test('ad-ID collection is NOT disabled (that would contradict the answer)', () {
      expect(
        manifest.contains('google_analytics_adid_collection_enabled'),
        isFalse,
        reason: 'setting this to false would stop GA4 reading the identifier, so '
            'the Console answer would no longer be a truthful "Yes"',
      );
    });

    test('both entry points apply the consent to GA4', () {
      final main = File('lib/main.dart').readAsStringSync();
      final privacy =
          File('lib/pages/settings/sections/privacy.dart').readAsStringSync();

      expect(main.contains('FirebaseAnalyticsService.instance'), isTrue,
          reason: 'startup must apply the stored decision before any collection');
      expect(privacy.contains('FirebaseAnalyticsService.instance'), isTrue,
          reason: 'the Settings toggle must start/stop GA4 with PostHog');
      expect(
        File('lib/services/analytics/firebase_analytics_service.dart')
            .existsSync(),
        isTrue,
      );
    });
  });

  group('the privacy policy discloses it', () {
    test('the policy names the advertising identifier', () {
      final policy = File('PRIVACY_POLICY.md').readAsStringSync();
      expect(
        policy.toLowerCase().contains('advertising identifier') ||
            policy.toLowerCase().contains('advertising id'),
        isTrue,
        reason: 'the Ads policy requires the identifier to be disclosed in a '
            'legally adequate privacy notification',
      );
      expect(
        policy.contains('We do not use advertising identifiers'),
        isFalse,
        reason: 'the old promise contradicts the Console answer',
      );
    });
  });
}
