import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/modules/home/sections/home_wallpaper.dart';

/// The wallpaper is the home screen's backdrop, so two properties matter: it
/// never swallows input, and it is drawn at FULL brightness.
///
/// The second one is a deliberate reversal. The wallpaper used to carry a
/// three-stop black scrim so the header text stayed legible over a bright photo;
/// on screen that read as a grey wash across the top of the home page and was
/// reported as ugly. The header now carries its own text shadows instead, so the
/// artwork is the only thing painted over the page background. These tests exist
/// to stop the dimming layer from quietly returning.
void main() {
  Widget harness(Widget child) => ProviderScope(
        child: material.MaterialApp(
          home: material.Scaffold(body: child),
        ),
      );

  testWidgets('the wallpaper ignores pointers and paints no overlay',
      (tester) async {
    tester.view.physicalSize = const material.Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(const HomeWallpaper(url: 'https://example.com/wall.webp')),
    );
    await tester.pump();

    // Every tap that reaches the background would otherwise be eaten by an
    // image sitting over the cards. Scoped to HomeWallpaper's own subtree: the
    // Material framework inserts IgnorePointers of its own.
    final ignore = tester.widget<IgnorePointer>(
      find
          .descendant(
            of: find.byType(HomeWallpaper),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue,
        reason: 'the wallpaper must not intercept taps');

    // No scrim. The dimming layer was a DecoratedBox holding a black gradient;
    // `Container(decoration: ...)` also builds one, so this covers both spellings
    // of the regression. It deliberately does NOT assert on the absence of a
    // Stack: FadeInImage (inside UniversalImage) may build one of its own for the
    // placeholder cross-fade, and a test that fails on the framework's internals
    // would be worse than no test.
    expect(
      find.descendant(
        of: find.byType(HomeWallpaper),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
      reason: 'the wallpaper must not dim its own artwork',
    );
  });

  test('the band keeps its aspect ratio, capped by the viewport', () {
    // A 400x800 viewport: 400/2 = 200 by ratio, 800 * 0.34 = 272 cap, so the
    // ratio wins.
    expect(HomeWallpaper.heightFor(const material.Size(400, 800)), 200);

    // A short/landscape viewport: 900/2 = 450 by ratio would eat the screen, so
    // the 34% cap wins instead.
    expect(
      HomeWallpaper.heightFor(const material.Size(900, 400)),
      closeTo(400 * HomeWallpaper.maxHeightFraction, 0.001),
    );
  });

  testWidgets('an empty url still renders without throwing', (tester) async {
    // Defence in depth: the caller only mounts this widget when a wallpaper is
    // configured, but a bad value must never crash the home screen.
    await tester.pumpWidget(harness(const HomeWallpaper(url: '')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
