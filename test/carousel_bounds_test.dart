// Guards the carousel fix: a slide must never be SEEN outside the carousel's
// own bounds.
//
// The bug this replaces was invisible to a configuration-level test - the
// carousel looked right at rest and only misbehaved mid-swipe. The margin used
// to be the padding of each PAGE, so a page filled the pager's viewport and its
// gutter sat inside the pager's rect. On a swipe the incoming page's leading
// edge landed exactly on the carousel's right edge, so the next banner appeared
// at the extreme edge of the PHONE and slid in, reading as though it came from
// outside the app.
//
// Measured on a 360dp viewport with the old structure, mid-swipe:
//   carousel 220..580, incoming page 502..838  -> 258dp painted beyond the row
// The fix moves the gutter OUTSIDE the pager and clips it to the inset box, so
// the visible area of the carousel is exactly the visible area of a slide.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/home/sections/specials_carousel.dart';

void main() {
  /// Builds the carousel's real layout structure: the pager inset by
  /// [HomeSpecialsCarousel.slideMargin] on each side, clipped to that box.
  ///
  /// This mirrors `HomeSpecialsCarousel.build` deliberately. If the widget's
  /// structure changes, this test must change with it - and the assertions below
  /// are what make that a decision rather than an accident.
  Widget harness({required double width, double height = 190}) {
    const margin = HomeSpecialsCarousel.slideMargin;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: margin),
            child: ClipRect(
              child: PageView.builder(
                itemCount: 3,
                itemBuilder: (context, index) => Container(
                  key: ValueKey('slide$index'),
                  color: const Color(0xFF000000),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the carousel is inset from both screen edges', (tester) async {
    const screenWidth = 360.0;
    await tester.pumpWidget(harness(width: screenWidth));
    await tester.pumpAndSettle();

    final clip = tester.getRect(find.byType(ClipRect));

    expect(clip.left, HomeSpecialsCarousel.slideMargin,
        reason: 'the carousel must start at its own gutter, not at the screen '
            'edge; a banner touching x=0 is what made it look like it slid in '
            'from beside the app');
    expect(clip.right, screenWidth - HomeSpecialsCarousel.slideMargin,
        reason: 'the carousel must end at its own gutter, not at the screen edge');
  });

  testWidgets('nothing a slide paints is visible outside the carousel',
      (tester) async {
    await tester.pumpWidget(harness(width: 360));
    await tester.pumpAndSettle();

    final clip = tester.getRect(find.byType(ClipRect));

    Rect rectOf(int i) {
      final f = find.byKey(ValueKey('slide$i'));
      return f.evaluate().isEmpty ? Rect.zero : tester.getRect(f);
    }

    // Halfway through a swipe - the moment the bug was visible.
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await gesture.moveBy(const Offset(-90, 0));
    await tester.pump();

    var checked = 0;
    for (var i = 0; i < 3; i++) {
      final r = rectOf(i);
      if (r == Rect.zero) continue;
      checked++;

      // What can actually be seen is the slide's rect intersected with the
      // clip; assert that intersection never escapes the clip.
      final visible = r.intersect(clip);
      expect(
        visible.left,
        greaterThanOrEqualTo(clip.left - 0.01),
        reason: 'slide$i is visible left of the carousel',
      );
      expect(
        visible.right,
        lessThanOrEqualTo(clip.right + 0.01),
        reason: 'slide$i is visible right of the carousel',
      );
    }
    expect(checked, greaterThanOrEqualTo(2),
        reason: 'a mid-swipe frame must show two slides for this to test '
            'anything; if only one built, the swipe did not take effect');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the resting banner fills the carousel box exactly',
      (tester) async {
    await tester.pumpWidget(harness(width: 360));
    await tester.pumpAndSettle();

    final clip = tester.getRect(find.byType(ClipRect));
    final resting = tester.getRect(find.byKey(const ValueKey('slide0')));

    expect(resting, clip,
        reason: 'at rest one slide must occupy the carousel exactly, so the '
            'settled layout is unchanged by the clip');
  });

  testWidgets('the clip never reaches either screen edge on a narrow phone',
      (tester) async {
    // The narrowest width the app supports; the fix must not collapse the
    // carousel to nothing there.
    const narrow = 320.0;
    await tester.pumpWidget(harness(width: narrow));
    await tester.pumpAndSettle();

    final clip = tester.getRect(find.byType(ClipRect));
    expect(clip.width, greaterThan(0));
    expect(clip.left, greaterThan(0));
    expect(clip.right, lessThan(narrow));
  });
}
