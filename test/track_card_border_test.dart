// Regression tests for the album/track card border effect.
//
// The border is a VISUAL change with a GEOMETRIC contract, and the geometric
// half is the half that can break silently. Every card height, every grid tile
// extent and every horizontal row height in the app is computed by
// `HomeSectionLayout` from arithmetic that assumes the card occupies exactly the
// box it was handed. If the border moved the card's content even one pixel,
// every card on every screen would be wrong at once — and the failure would be
// invisible in a screenshot review.
//
// So these tests pin the property that makes the change safe alongside the
// visual properties that make it the effect that was asked for.
//
// Two real defects were caught while building this, and both are pinned below so
// they cannot come back:
//
//   1. A border on `Container.decoration` INSETS the child by the border width
//      (Flutter inflates the child padding by the decoration's borders). It moved
//      the play control 1dp up off the text block it is pinned to. The outline is
//      therefore a `foregroundDecoration`, which contributes no layout padding.
//   2. An outer `BoxShadow` glow measured as painting ZERO pixels — it never
//      reached the screen at all, even without a clip. It was replaced by an
//      inset gradient stroke, which is measured to paint.
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

/// A 110dp tile at the density the grids actually use.
const double _tile = 110;

Widget _harness(Widget child, {ColorScheme? scheme, double textScale = 1.0}) {
  return Theme(
    data: ThemeData(
      radius: .5,
      iconTheme: const IconThemeProperties(),
      colorScheme: scheme ?? BhaktiColorSchemes.lightMaroon(),
      surfaceOpacity: .8,
      surfaceBlur: 10,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: _tile, child: child),
        ),
      ),
    ),
  );
}

Widget _card({int titleLines = 2, String? bg}) {
  return TrackCard(
    width: _tile,
    imageUrl: Assets.images.placeholder.path,
    title: 'Niluvadu Manasu',
    titleLines: titleLines,
    locked: false,
    cardBgColor: bg,
    onTap: () {},
    onPlay: () {},
  );
}

/// The card's Container, which holds the background and the outline.
Container _containerOf(WidgetTester tester) {
  return tester.widget<Container>(
    find.descendant(
      of: find.byType(TrackCard),
      matching: find.byType(Container),
    ).first,
  );
}

/// The background decoration: fill and gradient. Carries NO border.
BoxDecoration _decorationOf(WidgetTester tester) =>
    _containerOf(tester).decoration! as BoxDecoration;

/// The outline widget: the final child of the card's Stack.
Widget _outlineRoot(WidgetTester tester) {
  final stack = tester.widget<Stack>(
    find.descendant(
      of: find.byType(TrackCard),
      matching: find.byType(Stack),
    ).first,
  );
  expect(
    stack.children.length,
    2,
    reason: 'the card is a Stack of [content, outline]',
  );
  return stack.children.last;
}

/// The outline's painter, which strokes the gradient edge.
CustomPaint _outlinePaint(WidgetTester tester) {
  return tester.widget<CustomPaint>(
    find.descendant(
      of: find.byWidget(_outlineRoot(tester)),
      matching: find.byType(CustomPaint),
    ).first,
  );
}

void main() {
  group('the border does not change the card geometry', () {
    testWidgets('a bordered card is EXACTLY the reserved height',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(_card()));
      expect(tester.takeException(), isNull);

      final context = tester.element(find.byType(TrackCard));
      expect(
        tester.getSize(find.byType(TrackCard)).height,
        closeTo(HomeSectionLayout.twoLineTrackCardHeight(context, _tile), 0.01),
        reason: 'the border must not add a single pixel to the card',
      );
    });

    testWidgets('a bordered album card is EXACTLY the reserved height',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(_card(titleLines: 1)));
      expect(tester.takeException(), isNull);

      final context = tester.element(find.byType(TrackCard));
      expect(
        tester.getSize(find.byType(TrackCard)).height,
        closeTo(HomeSectionLayout.trackCardHeightFor(context, _tile), 0.01),
      );
    });

    testWidgets('the card never overflows at any text scale', (tester) async {
      for (final scale in <double>[0.8, 1.0, 1.3, 2.0]) {
        await tester.pumpWidget(_harness(_card(), textScale: scale));
        expect(
          tester.takeException(),
          isNull,
          reason: 'text scale $scale must not overflow',
        );
      }
    });
  });

  group('the card paints NO outline', () {
    // The card used to wear a gold rim over its content. It was removed by
    // request: the gold edge read as a yellow frame around every album and
    // track tile rather than as subtle separation.
    //
    // These assertions are the inverse of the ones that guarded the rim, and
    // they are kept here - rather than the file being deleted - because the
    // geometry guarantees below them still matter and still have to hold.
    testWidgets('the card carries no outline over its content', (tester) async {
      await tester.pumpWidget(_harness(_card()));
      expect(
        find.descendant(
          of: find.byType(TrackCard),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
        reason: 'an outline CustomPaint over the card is what drew the gold rim',
      );
    });

    testWidgets('the background decoration carries NO border', (tester) async {
      // Still asserted: a border on `decoration` inflates the Container's child
      // padding by its width, which insets the content and shifts the play
      // control off the text block's bottom edge. Nothing in HomeSectionLayout
      // accounts for that inset. Removing the outline must not be "fixed" by
      // adding a border here instead.
      await tester.pumpWidget(_harness(_card()));
      expect(
        _decorationOf(tester).border,
        isNull,
        reason: 'a border here would inset the card content by its own width',
      );
    });

    testWidgets('the card is not wrapped in an overlay Stack', (tester) async {
      // The Stack existed ONLY to paint the outline over the content as its last
      // child. With no outline there is nothing to overlay, and the card is a
      // plain child again. Asserting that keeps the structure honest: if a Stack
      // reappears, so has an overlay.
      await tester.pumpWidget(_harness(_card()));
      expect(
        find.descendant(
          of: find.byType(TrackCard),
          matching: find.byType(Stack),
        ),
        // One Stack remains - the cover's, which layers the LockedBadge over the
        // artwork. A second would be the removed outline layer.
        findsOneWidget,
        reason: 'only the cover keeps a Stack; an extra one is an overlay',
      );
    });

    testWidgets('the play control stays pinned WITHOUT a border',
        (tester) async {
      // The exact assertion the suite caught the original defect with, kept so
      // the geometry guarantee survives the outline's removal.
      await tester.pumpWidget(_harness(_card()));
      final context = tester.element(find.byType(TrackCard));
      final scale = Theme.of(context).scaling;

      final card = tester.getRect(find.byType(TrackCard));
      final control = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Play Niluvadu Manasu',
        ),
      );

      final blockBottom = card.top +
          _tile +
          (HomeSectionLayout.cardTextGap * scale) +
          HomeSectionLayout.trackTitleBlockHeight(context);
      expect(
        control.bottom,
        closeTo(blockBottom, 0.5),
        reason: 'the border must not push the control off the block bottom',
      );

      // And the card is still exactly as wide as its tile.
      expect(card.width, closeTo(_tile, 0.01));
    });
  });

  group('the border follows the theme', () {
    testWidgets('the dark scheme renders without throwing', (tester) async {
      await tester.pumpWidget(
        _harness(_card(), scheme: BhaktiColorSchemes.darkMaroon()),
      );
      expect(tester.takeException(), isNull);
      expect(_outlineRoot(tester), isA<Widget>());
    });

    testWidgets('an admin background suppresses the themed gradient',
        (tester) async {
      // An admin colour is an explicit instruction about that card's box; the
      // gradient must step aside rather than silently overpaint it.
      await tester.pumpWidget(_harness(_card(bg: '#ff0000')));
      expect(_decorationOf(tester).gradient, isNull);
      // The outline is still drawn — only the fill changes.
      expect(_outlineRoot(tester), isA<Widget>());
    });

    testWidgets('an admin background is used as the card fill', (tester) async {
      await tester.pumpWidget(_harness(_card(bg: '#ff0000')));
      // The fill still honours the admin colour; only the gradient steps aside.
      expect(_decorationOf(tester).color, const Color(0xFFFF0000));
    });
  });
}
