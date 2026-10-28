// Proves WHERE the paid-track badge is drawn, which the requirement states
// precisely: the golden crown must sit at the TOP-RIGHT corner of the paid
// track's cover, replacing the lock that used to sit in the CENTRE.
//
// `test/paid_crown_badge_test.dart` proves the glyph itself paints; this test
// proves its position, by measuring the real `TrackCard`'s render boxes rather
// than trusting the widget tree:
//
//   * the crown is pinned to the cover's top-right corner (badge inset 4dp);
//   * its centre is in the top-right quadrant, well away from the middle;
//   * the card no longer contains the `LockedBadge` that used to cover the
//     centre; and
//   * a free (unlocked) track draws no crown at all.
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/components/premium/paid_crown_badge.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

/// A 110dp tile, the width the home rows and grids actually use.
const double _tile = 110;

/// The default inset `PaidCrownBadge` applies inside the cover [Stack].
const double _inset = 4;

Widget _harness(Widget child) {
  return Theme(
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
        data: const MediaQueryData(size: Size(360, 800)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: _tile, child: child),
        ),
      ),
    ),
  );
}

Widget _card({required bool locked}) {
  return TrackCard(
    width: _tile,
    // An asset path (not a URL) keeps the cover synchronous and offline.
    imageUrl: Assets.images.placeholder.path,
    title: 'Niluvadu Manasu',
    titleLines: 2,
    locked: locked,
    onTap: () {},
    onPlay: () {},
  );
}

void main() {
  testWidgets('the paid crown is pinned to the cover top-right corner',
      (tester) async {
    await tester.pumpWidget(_harness(_card(locked: true)));
    await tester.pumpAndSettle();

    // The cover bleeds to the card's top, left and right edges and is square
    // (see TrackCard's cover comment), so the cover IS this band.
    final card = tester.getRect(find.byType(TrackCard));
    final cover = Rect.fromLTWH(card.left, card.top, _tile, _tile);

    final crown = tester.getRect(find.byType(PaidCrown));

    expect(
      crown.right,
      closeTo(cover.right - _inset, 0.5),
      reason: 'the crown must be flush with the cover RIGHT edge (minus the '
          'badge inset)',
    );
    expect(
      crown.top,
      closeTo(cover.top + _inset, 0.5),
      reason: 'the crown must be flush with the cover TOP edge (minus the badge '
          'inset)',
    );
    expect(crown.width, closeTo(20, 0.5));
    expect(crown.height, closeTo(20, 0.5));
  });

  testWidgets('the crown is in the top-right quadrant, not the centre',
      (tester) async {
    await tester.pumpWidget(_harness(_card(locked: true)));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(TrackCard));
    final cover = Rect.fromLTWH(card.left, card.top, _tile, _tile);
    final crown = tester.getRect(find.byType(PaidCrown));

    expect(
      crown.center.dx,
      greaterThan(cover.left + cover.width * 0.7),
      reason: 'the badge must sit on the RIGHT, where the requirement puts it',
    );
    expect(
      crown.center.dy,
      lessThan(cover.top + cover.height * 0.3),
      reason: 'the badge must sit at the TOP, where the requirement puts it',
    );
  });

  testWidgets('the centred lock badge is gone from the track cover',
      (tester) async {
    await tester.pumpWidget(_harness(_card(locked: true)));
    await tester.pumpAndSettle();

    expect(
      find.byType(LockedBadge),
      findsNothing,
      reason: 'the old centre-of-cover lock must no longer be rendered for a '
          'paid track; the crown replaces it',
    );
  });

  testWidgets('a free track draws no crown', (tester) async {
    await tester.pumpWidget(_harness(_card(locked: false)));
    await tester.pumpAndSettle();

    expect(
      find.byType(PaidCrown),
      findsNothing,
      reason: 'only PAID tracks are marked - a free track must be unmarked so it '
          'plays with no blocker',
    );
  });
}
