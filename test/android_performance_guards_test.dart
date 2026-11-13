// Guards two Play Console performance advisories:
//
//   1. "Improve your app's performance with bitmap downsampling" —
//      BitmapFactory used without BitmapFactory.Options.inSampleSize.
//      https://developer.android.com/develop/ui/compose/graphics/images/optimization
//   2. "Improve your app's memory and performance with R8 optimization" —
//      release builds without code/resource shrinking.
//      https://developer.android.com/google/play/vitals/code-optimization
//
// Both are silent regressions if they come back: a full-size cover decodes fine
// on a fast phone (it just costs ~4 MB per bitmap in a 50dp widget), and a
// release build still works without R8 - it is only larger and slower. Source
// probes are the cheapest reliable tripwire, matching the rest of this suite.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _decodingHelper =
    'android/app/src/main/kotlin/com/sangeet/app/glance/BitmapDecoding.kt';
const _trackDetailsView =
    'android/app/src/main/kotlin/com/sangeet/app/glance/widgets/TrackDetailsView.kt';
const _buildGradle = 'android/app/build.gradle';
const _proguard = 'android/app/proguard-rules.pro';

/// Strips Kotlin line comments, so an explanatory comment that *names* an API
/// cannot be mistaken for a call to it.
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i >= 0 ? line.substring(0, i) : line;
    })
    .join('\n');

void main() {
  group('bitmap downsampling', () {
    test('the shared helper decodes in two passes with inSampleSize', () {
      final src = File(_decodingHelper).readAsStringSync();

      expect(
        src.contains('inJustDecodeBounds = true'),
        isTrue,
        reason: 'the bounds must be read before allocating the bitmap',
      );
      expect(
        src.contains('inSampleSize'),
        isTrue,
        reason: 'inSampleSize is the parameter Play asks for',
      );
      expect(
        src.contains('calculateInSampleSize'),
        isTrue,
        reason: 'the power-of-two calculation lives in one place',
      );
      expect(
        src.contains('inPreferredConfig'),
        isTrue,
        reason: 'the decoding format is pinned rather than left implicit',
      );
    });

    test('the widget no longer calls BitmapFactory directly', () {
      final src = _codeOnly(File(_trackDetailsView).readAsStringSync());

      expect(
        src.contains('BitmapFactory'),
        isFalse,
        reason: 'every decode must go through decodeSampledBitmap / '
            'decodeSampledResource, which pass Options',
      );
      expect(src.contains('decodeSampledBitmap'), isTrue);
      expect(src.contains('decodeSampledResource'), isTrue);
      expect(
        src.contains('targetPx'),
        isTrue,
        reason: 'the decode target is the widget size in pixels, not a guess',
      );
    });

    test('the decoded size follows the widget size (50dp / 100dp)', () {
      final src = File(_trackDetailsView).readAsStringSync();
      expect(
        src.contains('50.dp') && src.contains('100.dp'),
        isTrue,
        reason: 'the 50/100dp breakpoint is what the target is derived from',
      );
      expect(
        src.contains('displayMetrics.density'),
        isTrue,
        reason: 'dp -> px conversion is required for a correct target',
      );
    });
  });

  group('R8 optimization', () {
    final gradle = File(_buildGradle).readAsStringSync();

    test('release enables code shrinking and resource shrinking', () {
      final release = gradle.substring(gradle.indexOf('buildTypes {'));
      final releaseBlock = release.substring(0, release.indexOf('debug {'));

      expect(
        releaseBlock.contains('minifyEnabled true'),
        isTrue,
        reason: 'without it R8 never runs, so no dead code is removed',
      );
      expect(
        releaseBlock.contains('shrinkResources true'),
        isTrue,
        reason: 'Play reports "optimized resource shrinking isn\'t enabled"',
      );
      expect(
        releaseBlock.contains('proguard-android-optimize.txt'),
        isTrue,
        reason: 'the optimising rules file is what enables the optimisation '
            'passes; the legacy default does not',
      );
    });

    test('the reflection-heavy SDKs are kept', () {
      final rules = File(_proguard).readAsStringSync();
      for (final pkg in [
        'com.clerk',
        'com.superwall',
        'com.onesignal',
        'com.posthog',
        'com.ryanheise',
        'com.sangeet.app',
      ]) {
        expect(
          rules.contains('-keep class $pkg.**'),
          isTrue,
          reason: '$pkg resolves its own classes by name; shrinking it breaks '
              'sign-in / purchases / push at runtime',
        );
      }
    });

    test('workers and widget receivers survive shrinking', () {
      final rules = File(_proguard).readAsStringSync();
      expect(rules.contains('extends androidx.work.ListenableWorker'), isTrue);
      expect(
        rules.contains('extends androidx.glance.appwidget.GlanceAppWidgetReceiver'),
        isTrue,
        reason: 'the launcher constructs these by class name',
      );
    });
  });
}
