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
}
