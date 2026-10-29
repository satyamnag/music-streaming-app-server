// Regression tests for the mini player's VISIBILITY rule.
//
// The mini player must always be on screen unless the full-screen player is
// open — that is the whole point of it, and the rule was broken by an equality
// against a literal 50 (the navigation bar's height before it became 64).
// `SlidingUpPanel` publishes exactly `kNavigationBarHeight` when it closes, so
// `64.ceil() == 50` was never true again: after the full-screen player had been
// opened once, the mini player stayed hidden for good, and a listener had no
// player on screen at all until they dragged the panel through the 49..50 band a
// second time.
//
// The rule lives in `miniPlayerVisibleAt` precisely so this can be tested
// without standing up the player's providers, streams and panel controller.
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/player/player_overlay_collapsed.dart';
import 'package:sangeet/modules/root/spotube_navigation_bar.dart';

void main() {
  group('the mini player is visible while the full player is closed', () {
    test('at the bar height the panel publishes when it is fully collapsed', () {
      expect(
        miniPlayerVisibleAt(kNavigationBarHeight),
        isTrue,
        reason: 'this is the value SlidingUpPanel writes on close; the old '
            'rule compared it to 50 and therefore hid the player forever',
      );
    });

    test('the published collapsed height is the one the bar renders', () {
      // The regression was a stale constant, so pin the constant's own value.
      expect(kNavigationBarHeight, 64);
    });
  });

  group('the mini player is hidden while the full player is open', () {
    test('fully open', () {
      expect(miniPlayerVisibleAt(0), isFalse);
    });

    test('part way open, whatever the fraction', () {
      // The rule rounds UP (`ceil`), so the last fraction of a logical pixel
      // counts as collapsed - that difference cannot be seen, and treating it as
      // collapsed is what makes the player reappear the instant the panel lands.
      for (final h in <double>[1, 8, 30, 49, 49.5, 50, 55, 63, 63.0]) {
        expect(
          miniPlayerVisibleAt(h),
          isFalse,
          reason: 'a panel at $h of $kNavigationBarHeight is opening, so the '
              'mini player must not be drawn behind it',
        );
      }
    });
  });

  test('closing the panel brings the mini player straight back', () {
    // Open, then closed again: the same value the panel reports in both cases
    // must give hidden -> visible, which is the exact sequence that used to end
    // with a permanently missing player.
    expect(miniPlayerVisibleAt(0), isFalse);
    expect(miniPlayerVisibleAt(kNavigationBarHeight), isTrue);
  });
}
