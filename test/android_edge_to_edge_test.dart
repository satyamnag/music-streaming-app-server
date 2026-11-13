// Guards the Play Console requirements for apps targeting SDK 35+:
//
//   1. "Edge-to-edge may not display for all users … call enableEdgeToEdge() …
//      for backward compatibility"
//   2. "Your app uses deprecated APIs or parameters for edge-to-edge …
//      android.view.Window.setStatusBarColor,
//      android.view.Window.setNavigationBarColor,
//      LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES"
//
//   https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge
//
// The two advisories pull in opposite directions: `enableEdgeToEdge()` satisfies
// the first and is itself built out of the APIs the second reports (it calls both
// colour setters and sets SHORT_EDGES on API 28-29). The resolution recorded here
// is to keep the *effect* of edge-to-edge and drop every deprecated call:
//
//   * `WindowCompat.setDecorFitsSystemWindows(window, false)` — one call, not
//     deprecated, and the actual switch that makes the app own the insets;
//   * no `setStatusBarColor` / `setNavigationBarColor` — from Kotlin or from
//     Flutter's `setSystemChromeSystemUIOverlayStyle` (the engine forwards Dart's
//     `SystemUiOverlayStyle.statusBarColor` straight to them);
//   * transparent bars come from the theme
//     (`android:windowDrawsSystemBarBackgrounds=false`) instead;
//   * the cutout mode is `always` (what Android 15 requires of non-floating
//     windows) instead of the deprecated `shortEdges`;
//   * the Flutter root consumes both insets, so nothing hides under the bars.
//
// Source probes, matching `bottom_nav_and_header_test.dart`: the failure mode is
// silent (correct on Android 13, broken on 15, or older warnings returning).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _themeFiles = [
  'android/app/src/main/res/values/styles.xml',
  'android/app/src/main/res/values-night/styles.xml',
  'android/app/src/main/res/values-v31/styles.xml',
  'android/app/src/main/res/values-night-v31/styles.xml',
];

/// Removes Kotlin comments before asserting that an API is NOT used.
///
/// The KDoc above `onCreate` has to *name* the deprecated calls to explain why
/// they are avoided, so a raw substring search would match the explanation
/// instead of the code.
String _codeOnly(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i >= 0 ? line.substring(0, i) : line;
      })
      .join('\n');
}

void main() {
  group('the Activity opts into edge-to-edge without deprecated APIs', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/sangeet/app/MainActivity.kt',
    ).readAsStringSync();

    test('the WindowCompat import is the edge-to-edge entry point', () {
      expect(
        mainActivity.contains('import androidx.core.view.WindowCompat'),
        isTrue,
      );
      expect(
        mainActivity.contains('import android.os.Build'),
        isTrue,
        reason: 'the version guard needs Build.VERSION.SDK_INT',
      );
    });

    test('it does NOT call the deprecated bar-colour setters itself', () {
      final code = _codeOnly(mainActivity);
      for (final api in ['setStatusBarColor', 'setNavigationBarColor']) {
        expect(
          code.contains(api),
          isFalse,
          reason: '$api is deprecated for targetSdk 35+ and was reported by '
              'Play Console; the helper applies the bars for us',
        );
      }
    });

    test('enableEdgeToEdge is guarded to API < 35, where it is not deprecated',
        () {
      final code = _codeOnly(mainActivity);
      expect(
        code.contains('WindowCompat.enableEdgeToEdge(window)'),
        isTrue,
        reason: 'below Android 15 it is the documented way to get transparent '
            'bars; from 15 the platform enforces edge-to-edge and the call would '
            'be dead code',
      );
      final guardAt = code.indexOf('Build.VERSION.SDK_INT <');
      final callAt = code.indexOf('WindowCompat.enableEdgeToEdge(window)');
      expect(guardAt, greaterThan(-1));
      expect(callAt, greaterThan(guardAt),
          reason: 'the call must sit inside the version guard');
      expect(code.contains('VANILLA_ICE_CREAM'), isTrue,
          reason: 'API 35 / Android 15 is the boundary the deprecation starts at');
    });

    test('the window setup runs before super.onCreate', () {
      final callAt = mainActivity.indexOf(
        'WindowCompat.enableEdgeToEdge(window)',
      );
      final superAt = mainActivity.indexOf('super.onCreate(savedInstanceState)');
      expect(callAt, greaterThan(-1));
      expect(superAt, greaterThan(-1));
      expect(callAt, lessThan(superAt));
    });

    test('MainActivity keeps its audio_service base class', () {
      expect(
        mainActivity.contains('class MainActivity: AudioServiceActivity()'),
        isTrue,
      );
    });
  });

  group('the theme provides transparent bars and the mandated cutout mode', () {
    for (final path in _themeFiles) {
      test('$path', () {
        final xml = File(path).readAsStringSync();

        expect(
          xml.contains('>always<'),
          isTrue,
          reason: 'Android 15 requires LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS for '
              'non-floating windows',
        );
        expect(
          xml.contains('shortEdges'),
          isFalse,
          reason: 'shortEdges is the deprecated value Play Console reported',
        );

        final normalTheme = xml.split('name="NormalTheme"').last;
        expect(
          normalTheme.contains('windowDrawsSystemBarBackgrounds'),
          isFalse,
          reason: 'on a MIUI device this flag produced a BLACK status bar with '
              'dark icons (measured: rows 0-47 pure #000000, no icon pixels). '
              'The bars stay transparent through enableEdgeToEdge below API 35 '
              'and through the platform from 35 up',
        );
      });
    }
  });

  group('Flutter no longer sets bar colours and still consumes both insets', () {
    final root = File('lib/pages/root/root_app.dart').readAsStringSync();

    test('no statusBarColor / systemNavigationBarColor is passed', () {
      for (final key in ['statusBarColor:', 'systemNavigationBarColor:']) {
        expect(
          root.contains(key),
          isFalse,
          reason: '$key reaches Window#setStatusBarColor / setNavigationBarColor '
              'through PlatformPlugin, which Play flagged',
        );
      }
      expect(
        root.contains('statusBarIconBrightness'),
        isTrue,
        reason: 'icon contrast must still follow the app theme',
      );
    });

    test('the root SafeArea still handles both insets', () {
      expect(root.contains('SafeArea(') && root.contains('top: true'), isTrue);
      final hasTopFalseArg = root
          .split('\n')
          .any((line) => line.trim() == 'top: false,' && !line.contains('//'));
      expect(hasTopFalseArg, isFalse);
      expect(root.contains('removeViewInsets'), isTrue);
    });
  });
}
