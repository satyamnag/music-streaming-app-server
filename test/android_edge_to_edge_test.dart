// Guards the Play Console requirement for apps targeting SDK 35+:
//
//   "Edge-to-edge may not display for all users … Apps targeting SDK 35 should
//    handle insets … Alternatively, call enableEdgeToEdge() for Kotlin … for
//    backward compatibility."
//   https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge
//
// Three things must stay true together, which is why they are asserted in one
// place:
//
//   1. the Activity opts in explicitly (the API Google names), so the app is
//      edge-to-edge on EVERY Android version instead of only from 15 up;
//   2. the androidx.core version that actually ships that API is pinned
//      (`WindowCompat.enableEdgeToEdge` landed in 1.17.0, whose AAR metadata
//      requires compileSdk 36 — 1.19.x would require 37);
//   3. the Flutter side consumes BOTH insets at the root, because once the
//      window spans the whole screen the status bar no longer insets the view.
//
// Source probes, matching the style of `bottom_nav_and_header_test.dart`: the
// failure mode here is a silent regression (the app still looks right on an
// Android 13 phone and breaks on Android 15), so a source-level tripwire is the
// cheapest reliable guard.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the Activity opts into edge-to-edge', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/sangeet/app/MainActivity.kt',
    ).readAsStringSync();

    test('it calls WindowCompat.enableEdgeToEdge(window)', () {
      expect(
        mainActivity.contains('WindowCompat.enableEdgeToEdge(window)'),
        isTrue,
        reason: 'Play asks for enableEdgeToEdge(); the Window-level API is the '
            'non-deprecated form and the only one available to a '
            'FlutterActivity (ComponentActivity.enableEdgeToEdge() is not)',
      );
      expect(
        mainActivity.contains('import androidx.core.view.WindowCompat'),
        isTrue,
      );
    });

    test('the call runs BEFORE super.onCreate, as the AndroidX KDoc requires',
        () {
      final callAt = mainActivity.indexOf('WindowCompat.enableEdgeToEdge(window)');
      final superAt = mainActivity.indexOf('super.onCreate(savedInstanceState)');

      expect(callAt, greaterThan(-1));
      expect(superAt, greaterThan(-1));
      expect(
        callAt,
        lessThan(superAt),
        reason: 'enableEdgeToEdge() initialises the decor view so the later '
            'window setup cannot overwrite the attributes',
      );
    });

    test('MainActivity keeps its audio_service base class', () {
      expect(
        mainActivity.contains('class MainActivity: AudioServiceActivity()'),
        isTrue,
        reason: 'switching to a ComponentActivity would only be needed for the '
            'deprecated ComponentActivity extension, and it would change '
            'audio_service lifecycle behaviour',
      );
    });
  });

  group('the dependency that provides the API is pinned, not incidental', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();

    test('androidx.core:core-ktx 1.17.0 is declared explicitly', () {
      expect(
        gradle.contains("implementation 'androidx.core:core-ktx:1.17.0'"),
        isTrue,
        reason: '1.17.0 is the first release with WindowCompat.enableEdgeToEdge '
            'and its minCompileSdk is 36, which this module uses',
      );
    });

    test('the module still compiles against SDK 36', () {
      expect(gradle.contains('compileSdkVersion 36'), isTrue);
    });
  });

  group('Flutter consumes both insets at the root', () {
    final root = File('lib/pages/root/root_app.dart').readAsStringSync();

    test('the root SafeArea is not limited to the bottom', () {
      expect(
        root.contains('SafeArea(') && root.contains('top: true'),
        isTrue,
        reason: 'with decorFitsSystemWindows=false the status bar no longer '
            'insets the view; the root must apply the top inset or every '
            'header slides under the clock',
      );
      // Only an actual argument counts — the explanatory comment above quotes
      // the old value, so a naive substring search would match that instead.
      final hasTopFalseArg = root
          .split('\n')
          .any((line) => line.trim() == 'top: false,' && !line.contains('//'));
      expect(
        hasTopFalseArg,
        isFalse,
        reason: 'top: false was correct only while the window was not '
            'edge-to-edge',
      );
    });

    test('the bottom inset is still handled (navigation bar, mini player)', () {
      expect(root.contains('removeViewInsets'), isTrue);
      expect(root.contains('footers:'), isTrue);
    });
  });
}
