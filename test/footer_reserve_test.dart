// Guards the footer reserve: the space every screen leaves at the bottom so the
// floating mini player and navigation bar never cover the page's last row.
//
// ## The bug this replaces
// `root_app.dart` set the body's bottom padding to a hard-coded
// `100 * scaling`, which DISCARDED the value the scaffold had already computed.
// With `floatingFooter: true`, shadcn adds the measured `footerHeight` to
// `MediaQuery.padding.bottom` (see `Scaffold.build`), and that is the number the
// app then overwrote.
//
// The real footer is the mini player (86) plus the navigation bar (50) - about
// 136 at scale 1 - so a fixed 100 was roughly 36 short, and the last row of
// every screen sat under the player. It was also wrong in the other direction
// whenever the nav bar animated away, because a constant cannot follow a widget
// that changes height.
//
// `context.bottomPlayerReserve` (used by 19 call sites) is derived from this
// same padding, so the fix corrects every screen at once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as sh;
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/player/player_overlay_collapsed.dart';

void main() {
  /// Reads `context.bottomPlayerReserve` under a given bottom padding.
  ///
  /// The ancestor must be shadcn's OWN `Theme`: the reserve scales by
  /// `Theme.of(this).scaling`, and that resolves to `shadcn_flutter`'s Theme.
  /// A plain `MaterialApp` provides Material's theme instead, so the getter
  /// throws "No Theme found in context" and never returns a number.
  Future<double> reserveFor(WidgetTester tester, double padding) async {
    double? reserve;
    await tester.pumpWidget(
      sh.MediaQuery(
        data: sh.MediaQueryData(
          size: const Size(360, 800),
          padding: EdgeInsets.only(bottom: padding),
        ),
        child: sh.Theme(
          data: const sh.ThemeData(
            radius: .5,
            iconTheme: sh.IconThemeProperties(),
          ),
          child: sh.Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                reserve = context.bottomPlayerReserve;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(reserve, isNotNull,
        reason: 'the reserve must compute; a throw here means a required '
            'ancestor (shadcn Theme or MediaQuery) is missing');
    return reserve!;
  }

  test('the footer is taller than the padding the app hard-coded', () {
    // This is WHY the overlap happened: the constant was smaller than the thing
    // it was reserving room for.
    const navBarHeight = 50.0; // navigationPanelHeight provider's default
    const miniPlayerHeight = PlayerOverlayCollapsedSection.collapsedHeight;
    const footerHeight = navBarHeight + miniPlayerHeight;

    expect(
      miniPlayerHeight,
      86,
      reason: 'the mini player height is the basis of the reserve; if this '
          'changed, the overlap arithmetic below changed too',
    );
    expect(
      footerHeight,
      greaterThan(100),
      reason: 'the real footer (nav bar + mini player) exceeds the 100 that was '
          'hard-coded, which is the overlap bug',
    );
  });

  testWidgets('the reserve follows the padding it is given', (tester) async {
    // The reserve must TRACK the padding. A constant could not, and that is the
    // whole point of the fix.
    final small = await reserveFor(tester, 40);
    final large = await reserveFor(tester, 150);

    expect(small, lessThan(large),
        reason: 'the reserve must grow with the padding it is given; a fixed '
            'constant would not');
  });

  testWidgets('the reserve exceeds the footer and adds only a small margin',
      (tester) async {
    const scaffoldPadding = 136.0; // the real footer: 86 + 50
    final reserve = await reserveFor(tester, scaffoldPadding);

    expect(
      reserve,
      greaterThan(scaffoldPadding),
      reason: 'the reserve must exceed the footer height, or the last row still '
          'touches the player',
    );
    expect(
      reserve - scaffoldPadding,
      lessThanOrEqualTo(20),
      reason: 'the margin is breathing room, not a second footer of dead space',
    );
  });

  testWidgets('it does not come from a hard-coded 100', (tester) async {
    // The specific regression: a reserve of exactly 100 (at scale 1) would mean
    // the constant came back.
    final reserve = await reserveFor(tester, 200);

    expect(
      reserve,
      isNot(closeTo(100, 1)),
      reason: 'the reserve must come from the inherited padding, not a constant',
    );
    expect(reserve, greaterThan(200));
  });

  testWidgets('a zero footer padding yields only the margin', (tester) async {
    // With no player and no nav bar the reserve must collapse, so a screen is
    // not left with a band of dead space.
    final reserve = await reserveFor(tester, 0);
    expect(reserve, lessThan(30),
        reason: 'with no footer the reserve should be just the small margin');
  });
}
