// Guards the Synced Lyrics auto-scroll contract: the line being sung is pinned
// to a FIXED point in the middle of the view, so the lines above it travel
// upward as the track plays.
//
// This is tested here, against a synthetic list, rather than only on a device:
// the rule is pure scroll geometry, and a device check cannot be repeated
// cheaply for the first line, the last line and a far seek (which is exactly
// where a "centre it" implementation usually breaks).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sangeet/modules/lyrics/lyrics_auto_center.dart';

const Size _windowSize = Size(300, 400);

/// Half the viewport height - the spacer the page puts above the first line and
/// below the last so both ends can reach the centre. A literal because a property
/// access (`_windowSize.height`) is not a constant expression in Dart.
const double _halfWindow = 200; // == _windowSize.height / 2

/// A list shaped like the lyrics view: a half-viewport spacer, the lines as
/// [AutoScrollTag]s (so `tagMap` is populated the way the page's is), then the
/// matching spacer. Uniform 40dp rows keep the arithmetic checkable.
Widget _harness(AutoScrollController controller, {int count = 30}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _windowSize.width,
        height: _windowSize.height,
        child: CustomScrollView(
          controller: controller,
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: _halfWindow),
            ),
            SliverList.builder(
              itemCount: count,
              itemBuilder: (context, index) => AutoScrollTag(
                key: ValueKey(index),
                index: index,
                controller: controller,
                child: SizedBox(
                  height: 40,
                  child: Center(child: Text('line $index')),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: _halfWindow),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  late AutoScrollController controller;

  setUp(() {
    controller = AutoScrollController();
  });

  tearDown(() {
    controller.dispose();
  });

  /// The vertical centre of the scroll viewport - the fixed point the singing
  /// line must sit on.
  double viewportCentre(WidgetTester tester) =>
      tester.getCenter(find.byType(CustomScrollView)).dy;

  /// How far the given line's centre is from the viewport's centre.
  double offBy(WidgetTester tester, int index) =>
      (tester.getCenter(find.byKey(ValueKey(index))).dy -
              viewportCentre(tester))
          .abs();

  group('LyricsAutoCenter', () {
    testWidgets('centres the FIRST line, not just the middle of the song',
        (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      LyricsAutoCenter.centerOnLine(controller, 0);
      await tester.pumpAndSettle();

      expect(offBy(tester, 0), lessThan(1.0));
    });

    testWidgets('centres a line in the middle of the list', (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      LyricsAutoCenter.centerOnLine(controller, 15);
      await tester.pumpAndSettle();

      expect(offBy(tester, 15), lessThan(1.0));
    });

    testWidgets('centres the LAST line', (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      LyricsAutoCenter.centerOnLine(controller, 29);
      await tester.pumpAndSettle();

      expect(offBy(tester, 29), lessThan(1.0));
    });

    testWidgets('a line that is NOT built yet still ends up centred',
        (tester) async {
      // The real case: the screen opens mid-song, so the list has only built the
      // top while the singing line is far down. Jumping to an estimate alone
      // would leave it near - but not at - the centre.
      await tester.pumpWidget(_harness(controller, count: 200));
      await tester.pumpAndSettle();

      LyricsAutoCenter.centerOnLine(controller, 150);
      await tester.pumpAndSettle();

      expect(offBy(tester, 150), lessThan(1.0));
    });

    testWidgets('every new line lands on the SAME centre point, so the text '
        'travels upward instead of drifting', (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      // A run of consecutive cues, in playing order.
      for (final index in const [4, 5, 6, 7]) {
        LyricsAutoCenter.centerOnLine(controller, index);
        await tester.pumpAndSettle();
        expect(
          offBy(tester, index),
          lessThan(1.0),
          reason: 'line $index must sit on the same fixed centre as the others',
        );
      }

      // And the list really did move up: the offset grew.
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('does nothing when no line is active or the list is empty',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 100, height: 100),
        ),
      );
      await tester.pumpAndSettle();

      // -1 is what the page passes when nothing is playing; a detached
      // controller has no clients. Neither may throw.
      LyricsAutoCenter.centerOnLine(controller, -1);
      LyricsAutoCenter.centerOnLine(controller, 3);
      await tester.pumpAndSettle();
    });
  });

  group('Synced Lyrics screens wiring', () {
    // The behaviour above is useless if a screen stops using it or goes back to
    // scrolling from inside itemBuilder (during build, against an estimated row
    // height). These are cheap guards against that regression, on BOTH sync
    // surfaces: the full lyrics page and the player's lyrics page.
    void expectCentred(String path) {
      final source = File(path).readAsStringSync();
      final name = path.split('/').last;

      expect(source.contains('LyricsAutoCenter.centerOnLine'), isTrue,
          reason: '$name must centre through LyricsAutoCenter');
      expect(source.contains('scrollToIndex'), isFalse,
          reason: '$name: scrolling from itemBuilder runs during build and '
              'uses an estimated row height; the post-frame effect replaces it');
      expect(
        source.contains('mediaQuery.height / 2') ||
            source.contains('windowHeight / 2'),
        isTrue,
        reason: '$name: without half a viewport above and below, the first and '
            'last lines can never reach the centre',
      );
    }

    test('the full lyrics page centres its lines', () {
      expectCentred('lib/pages/lyrics/synced_lyrics.dart');
    });

    test('the player lyrics page centres its lines too', () {
      expectCentred('lib/pages/player/lyrics.dart');

      // The specific wrong answer that used to be there: a proportional jump that
      // put the current line wherever a fraction of the scroll extent landed.
      final source = File('lib/pages/player/lyrics.dart').readAsStringSync();
      expect(
        source.contains('maxScrollExtent *'),
        isFalse,
        reason: 'the player page must not position lines by scroll fraction - '
            'that is what left the singing line away from the centre',
      );
    });
  });
}
