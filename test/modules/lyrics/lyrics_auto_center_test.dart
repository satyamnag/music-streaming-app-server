// Guards the Synced Lyrics auto-scroll contract.
//
// The behaviour the screens must have, in order:
//  1. nothing playing / before the first cue: the lyrics begin at the TOP of the
//     view, not in the middle under an empty half-screen;
//  2. as the track plays, the singing line travels DOWN towards the anchor - it
//     cannot reach it while it still sits near the top, so the scroll clamps at
//     the top and the line simply sits lower with each cue;
//  3. once it can reach the anchor (30% from the top), it STAYS there for the rest
//     of the track;
//  4. when the track starts again - a repeat, a loop, a new play - the lyrics go
//     back to the top and the whole descent happens again.
//
// Tested here against a synthetic list rather than only on a device: this is pure
// scroll geometry, and a device check cannot be repeated cheaply for the first
// line, the last line, a far seek, or the loop.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sangeet/modules/lyrics/lyrics_auto_center.dart';

const Size _windowSize = Size(300, 400);

/// Height of one lyric line in the synthetic list.
const double _rowHeight = 40;

/// A list shaped like the lyrics view: the lines as [AutoScrollTag]s (so `tagMap`
/// is populated the way the screens' is), then the trailing space the screens
/// reserve so the final line can still reach the anchor. No spacer on top.
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
            SliverList.builder(
              itemCount: count,
              itemBuilder: (context, index) => AutoScrollTag(
                key: ValueKey(index),
                index: index,
                controller: controller,
                child: SizedBox(
                  height: _rowHeight,
                  child: Center(child: Text('line $index')),
                ),
              ),
            ),
            SliverToBoxAdapter(
              // The real helper, so the test breaks if the reservation stops
              // matching the anchor.
              child: SizedBox(
                height: LyricsAutoCenter.trailingSpace(_windowSize.height),
              ),
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

  /// The fixed vertical point the singing line locks onto: the anchor fraction
  /// of the viewport, measured from its top.
  double anchorY(WidgetTester tester) {
    final viewport = tester.getRect(find.byType(CustomScrollView));
    return viewport.top + LyricsAutoCenter.alignment * viewport.height;
  }

  /// The vertical top of the scroll viewport.
  double viewportTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(CustomScrollView)).dy;

  /// How far the given line's centre is from the anchor.
  double offBy(WidgetTester tester, int index) =>
      (tester.getCenter(find.byKey(ValueKey(index))).dy - anchorY(tester)).abs();

  group('LyricsAutoCenter', () {
    test('the anchor sits just under a third of the way down', () {
      expect(LyricsAutoCenter.alignment, 0.3);
      // The trailing reservation is the mirror of the anchor: whatever is NOT
      // above the anchor has to be reachable below the last line.
      expect(
        LyricsAutoCenter.trailingSpace(400),
        closeTo(400 * 0.7, 0.001),
      );
    });

    testWidgets('the FIRST line starts at the TOP, not at the anchor',
        (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      LyricsAutoCenter.centerOnLine(controller, 0);
      await tester.pumpAndSettle();

      // Its centre is above the anchor, so the offset clamps to 0 and the line
      // sits flush with the top - the lyrics read from the top down instead of
      // starting under an empty half-screen.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(0))).dy -
            viewportTop(tester),
        closeTo(0, 1),
      );
      expect(controller.offset, 0);
    });

    testWidgets('the singing line descends to the anchor, then stays there',
        (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      // (2) Lines too close to the top cannot reach the anchor yet: the list
      // stays at the top and each cue simply sits one row lower than the last.
      for (final index in const [0, 1, 2]) {
        LyricsAutoCenter.centerOnLine(controller, index);
        await tester.pumpAndSettle();
        expect(controller.offset, 0);
        expect(
          tester.getTopLeft(find.byKey(ValueKey(index))).dy -
              viewportTop(tester),
          closeTo(index * _rowHeight, 1),
          reason: 'line $index should sit $index rows below the top',
        );
      }

      // (3) From the point where the anchor is reachable, every line lands on the
      // same fixed point and the list moves up behind it.
      for (final index in const [5, 6, 9, 20]) {
        LyricsAutoCenter.centerOnLine(controller, index);
        await tester.pumpAndSettle();
        expect(offBy(tester, index), lessThan(1.0),
            reason: 'line $index must lock onto the anchor');
      }
    });

    testWidgets(
        'the LAST line still reaches the anchor - the lock survives to the end '
        'of the track', (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      // This is what the trailing reservation is for: without it the final lines
      // could not rise as far as the anchor and the lock would silently break.
      LyricsAutoCenter.centerOnLine(controller, 29);
      await tester.pumpAndSettle();

      expect(offBy(tester, 29), lessThan(1.0));
    });

    testWidgets('a line that is NOT built yet still ends up on the anchor',
        (tester) async {
      // The real case: the screen opens mid-song, so the list has only built the
      // top while the singing line is far down. Jumping to an estimate alone
      // would leave it near - but not at - the anchor.
      await tester.pumpWidget(_harness(controller, count: 200));
      await tester.pumpAndSettle();

      LyricsAutoCenter.centerOnLine(controller, 150);
      await tester.pumpAndSettle();

      expect(offBy(tester, 150), lessThan(1.0));
    });

    testWidgets('a restart sends the lyrics back to the top, so the descent '
        'happens again', (tester) async {
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      LyricsAutoCenter.centerOnLine(controller, 12);
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));

      // Track repeats / loops: the singing line is the first one again.
      LyricsAutoCenter.scrollToStart(controller);
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(0))).dy -
            viewportTop(tester),
        closeTo(0, 1),
      );
    });

    testWidgets('scrollToStart is a no-op at the top and safe before layout',
        (tester) async {
      // Before any list exists the controller has no clients. Neither call may
      // throw (both are invoked from post-frame callbacks on the real screens).
      LyricsAutoCenter.scrollToStart(controller);
      LyricsAutoCenter.centerOnLine(controller, 3);

      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      // And at the top it does nothing rather than animating a no-op.
      LyricsAutoCenter.scrollToStart(controller);
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
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
    // The behaviour above is useless if a screen stops using it, goes back to
    // scrolling from itemBuilder (during build, against an estimated row height),
    // or stops reserving the space the anchor needs. Cheap guards on BOTH sync
    // surfaces: the full lyrics page and the player's lyrics page.
    void expectAnchored(String path) {
      final source = File(path).readAsStringSync();
      final name = path.split('/').last;

      expect(source.contains('LyricsAutoCenter.centerOnLine'), isTrue,
          reason: '$name must position through LyricsAutoCenter');
      expect(source.contains('scrollToIndex'), isFalse,
          reason: '$name: scrolling from itemBuilder runs during build and '
              'uses an estimated row height; the post-frame effect replaces it');
      expect(
        source.contains('LyricsAutoCenter.trailingSpace'),
        isTrue,
        reason: '$name: the space below the last line must come from the same '
            'fraction as the anchor, or the final lines cannot reach it',
      );
      expect(
        'trailingSpace'.allMatches(source).length,
        1,
        reason: '$name: exactly one trailing reservation - a second one would be '
            'a spacer above the list, which puts the first line mid-screen',
      );
    }

    test('the full lyrics page starts at the top and locks to the anchor', () {
      expectAnchored('lib/pages/lyrics/synced_lyrics.dart');
    });

    test('the player lyrics page starts at the top and locks to the anchor', () {
      final path = 'lib/pages/player/lyrics.dart';
      expectAnchored(path);

      final source = File(path).readAsStringSync();
      expect(source.contains('top: windowHeight'), isFalse,
          reason: 'no padding above the first line: the lyrics must begin at '
              'the top of the view');
      // The specific wrong answer that used to be there: a proportional jump that
      // put the current line wherever a fraction of the scroll extent landed.
      // Matched as code (`position.maxScrollExtent`), not as the phrase, because
      // the file's own comment quotes the expression it replaced.
      expect(source.contains('position.maxScrollExtent'), isFalse,
          reason: 'the player page must not position lines by scroll fraction - '
              'that is what left the singing line away from the anchor');
    });
  });
}
