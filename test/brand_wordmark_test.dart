// Guards the brand wordmark: it must render, keep both words, and never depend
// on a custom font family.
//
// ## Why this file replaced `brand_font_test.dart`
// The old suite proved a custom face (Dancing Script) was declared, bundled and
// measured differently from the fallback. All of that passed while the brand
// name rendered in the platform sans-serif on every real device tested, because
// the suite loaded the font itself through `FontLoader` and so never exercised
// the engine's bundled-font lookup - the path that was failing.
//
// A custom face has been dropped entirely. These assertions cover what the
// wordmark now IS: a typographic lockup on the DEFAULT face, which cannot fall
// back because there is nothing to load.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as sh;
import 'package:sangeet/components/branding/brand_wordmark.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 360,
  }) async {
    await tester.pumpWidget(
      sh.Theme(
        data: sh.ThemeData(
          radius: .5,
          iconTheme: const sh.IconThemeProperties(),
          surfaceOpacity: .8,
          surfaceBlur: 10,
        ),
        child: sh.Directionality(
          textDirection: TextDirection.ltr,
          child: MaterialApp(
            home: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      ),
    );
  }

  test('Dancing Script is gone from the project entirely', () {
    // The removal must be complete: a leftover asset, a stale constant or a
    // dangling import would keep shipping a font that never renders.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('family: DancingScript'),
      isFalse,
      reason: 'the Dancing Script family must not be declared; it never '
          'rendered on device and is no longer used',
    );
    expect(
      File('assets/fonts/DancingScript-Regular.ttf').existsSync(),
      isFalse,
      reason: 'the font files must be deleted, not merely unreferenced',
    );

    for (final path in [
      'lib/pages/home/home.dart',
      'lib/modules/splash/splash_screen.dart',
      'lib/modules/root/sidebar/sidebar.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(
        src.contains('dancingScript') || src.contains('DancingScript'),
        isFalse,
        reason: '$path must not reference the removed font',
      );
    }
  });

  testWidgets('the wordmark renders both words', (tester) async {
    await pump(tester,
      const BrandWordmark(fontSize: 24, color: Colors.black),
    );
    await tester.pumpAndSettle();

    expect(find.text('Soulful'), findsOneWidget);
    expect(find.text('Bhakti'), findsOneWidget);
  });

  testWidgets('the two words carry DIFFERENT weights', (tester) async {
    // The weight contrast is the entire design of the lockup. If the two halves
    // ever share a weight the treatment silently becomes plain text.
    await pump(tester,
      const BrandWordmark(fontSize: 24, color: Colors.black, gradient: false),
    );
    await tester.pumpAndSettle();

    final light = tester.widget<Text>(find.text('Soulful')).style!;
    final heavy = tester.widget<Text>(find.text('Bhakti')).style!;

    expect(light.fontWeight, FontWeight.w300);
    expect(heavy.fontWeight, FontWeight.w900);
    expect(
      light.fontWeight == heavy.fontWeight,
      isFalse,
      reason: 'the lockup depends on the two words differing in weight',
    );
  });

  testWidgets('no font family is requested, so nothing can fall back',
      (tester) async {
    await pump(tester,
      const BrandWordmark(fontSize: 24, color: Colors.black),
    );
    await tester.pumpAndSettle();

    for (final word in ['Soulful', 'Bhakti']) {
      final style = tester.widget<Text>(find.text(word)).style!;
      expect(
        style.fontFamily,
        isNull,
        reason: '"$word" must use the default face; naming a custom family is '
            'what silently fell back on device',
      );
    }
  });

  testWidgets('the wordmark does not overflow a narrow phone', (tester) async {
    // 320dp is the narrowest supported width, and the header row also holds the
    // logo and three icons, so a lockup that cannot shrink would overflow.
    for (final size in [20.0, 24.0, 30.0]) {
      await pump(tester,
        BrandWordmark(fontSize: size, color: Colors.black),
        width: 320,
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'the wordmark overflowed at fontSize $size on a 320dp phone',
      );
    }
  });

  testWidgets('the gold gradient is applied to the heavy word by default',
      (tester) async {
    await pump(tester,
      const BrandWordmark(fontSize: 24, color: Colors.black),
    );
    await tester.pumpAndSettle();

    // A ShaderMask is what paints the gradient through the glyphs.
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('gradient: false renders flat with no shader', (tester) async {
    await pump(tester,
      const BrandWordmark(
        fontSize: 24,
        color: Colors.black,
        gradient: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShaderMask), findsNothing);
    final heavy = tester.widget<Text>(find.text('Bhakti')).style!;
    expect(heavy.color, Colors.black);
  });

  group('the styling that lifts the mark from plain text', () {
    /// Any gradient-filled box inside the wordmark: the underline flourish.
    Finder flourish() => find.descendant(
          of: find.byType(BrandWordmark),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).gradient != null,
          ),
        );

    testWidgets('the heavy word uses a THREE-stop gold ramp', (tester) async {
      // The flat two-stop ramp read as dull at small sizes because the eye
      // averages it. A bright highlight at the top-left is what makes the gold
      // read as metal - light catching the lettering's edge - so the highlight
      // is the styling, not decoration.
      await pump(tester, const BrandWordmark(fontSize: 24, color: Colors.black));
      await tester.pumpAndSettle();

      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      expect(mask.shaderCallback(const Rect.fromLTWH(0, 0, 100, 30)),
          isA<Shader>(),
          reason: 'the gradient must resolve to a real shader');

      // A shader cannot be read back into its stops, so the palette is asserted
      // directly: a highlight equal to the base gold would collapse the ramp
      // back to two stops and lose the effect.
      expect(BrandWordmark.goldHighlight, isNot(BrandWordmark.goldLight));
      expect(BrandWordmark.goldHighlight, isNot(BrandWordmark.goldDeep));
    });

    testWidgets('the mark carries a fading underline flourish', (tester) async {
      await pump(tester, const BrandWordmark(fontSize: 24, color: Colors.black));
      await tester.pumpAndSettle();

      expect(flourish(), findsWidgets,
          reason: 'the fading gold rule is what makes it read as a designed '
              'mark rather than as two words');
    });

    testWidgets('gradient: false omits the flourish as well', (tester) async {
      // A caller that opted out of gold must not get a gold rule underneath.
      await pump(
        tester,
        const BrandWordmark(fontSize: 24, color: Colors.black, gradient: false),
      );
      await tester.pumpAndSettle();

      expect(flourish(), findsNothing);
    });

    testWidgets('the flourish does not overflow a narrow phone', (tester) async {
      // The rule is laid under an `IntrinsicWidth` lockup, which is a layout
      // shape that can overflow where a plain Text did not.
      for (final size in [20.0, 24.0, 30.0]) {
        await pump(
          tester,
          BrandWordmark(fontSize: size, color: Colors.black),
          width: 320,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'the mark overflowed at fontSize $size on a 320dp phone');
      }
    });
  });
}
