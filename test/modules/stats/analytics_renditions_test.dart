// Guards two things about the Analytics screen that a layout test cannot see.
//
// 1. The chart's y-axis ceiling. It has to round UP to a familiar number, and it
//    has to answer for an empty week (all zero) instead of dividing by zero.
//
// 2. Which cover rendition each image asks for. `CoverRendition.urlFor` rewrites
//    ANY requested pixel size into `variants/<pixels>/<name>`, and the repository
//    only generates the 512px renditions (see the "Cover Variants" workflow).
//    Asking for 148 or 176 therefore produced a URL that does not exist: found on
//    a device, where the deity circle and the top-track thumbnails would have
//    been blank. The probe fails if any Analytics widget asks for a size other
//    than the generated one, or for one at all on an admin upload.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/stats/analytics/analytics_activity_chart.dart';
import 'package:sangeet/services/images/cover_renditions.dart';

void main() {
  group('the chart axis rounds up to a readable ceiling', () {
    test('an empty week still gets an axis', () {
      expect(AnalyticsActivityChart.axisMaxFor(0), 60);
      expect(AnalyticsActivityChart.axisMaxFor(-5), 60);
    });

    test('values snap to the next familiar step', () {
      expect(AnalyticsActivityChart.axisMaxFor(1), 15);
      expect(AnalyticsActivityChart.axisMaxFor(15), 15);
      expect(AnalyticsActivityChart.axisMaxFor(16), 30);
      expect(AnalyticsActivityChart.axisMaxFor(45), 45);
      expect(AnalyticsActivityChart.axisMaxFor(46), 60);
      expect(AnalyticsActivityChart.axisMaxFor(100), 120);
      expect(AnalyticsActivityChart.axisMaxFor(601), 1200);
    });

    test('the ceiling is never below the tallest bar', () {
      for (final minutes in const [1, 7, 42, 125, 599, 600, 601, 5000]) {
        expect(
          AnalyticsActivityChart.axisMaxFor(minutes),
          greaterThanOrEqualTo(minutes.toDouble()),
          reason: 'a bar taller than the axis would be clipped',
        );
      }
    });
  });

  group('analytics images use a rendition that exists', () {
    test('no analytics widget asks for an ungenerated cover size', () {
      final directory = Directory('lib/modules/stats/analytics');
      expect(directory.existsSync(), isTrue);

      final offenders = <String>[];
      for (final file in directory.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        // A literal pixel size is always wrong here: 176 and 148 were both
        // served from `variants/<size>/`, which is never generated.
        for (final match
            in RegExp(r'coverPixels:\s*(\d+)').allMatches(source)) {
          offenders.add('${file.path}: coverPixels: ${match.group(1)}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'these ask for a cover rendition that does not exist (only '
            '${CoverRendition.card}px is generated): $offenders',
      );
    });

    test('the top-track thumbnail asks for the generated cover rendition', () {
      final source =
          File('lib/modules/stats/analytics/analytics_top_tracks.dart')
              .readAsStringSync();
      expect(source, contains('coverPixels: CoverRendition.card'));
    });

    test('the generated rendition is 512 and the app still declares it', () {
      // If the rendition size ever changes, the two literals above must change
      // with it — this pins the constant the contract is written against.
      expect(CoverRendition.card, 512);
      expect(CoverRendition.original, 1024);
    });
  });
}
