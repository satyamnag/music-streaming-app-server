import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/modules/home/sections/home_wallpaper.dart';

/// The wallpaper renders behind every home widget, so the two properties that
/// matter are: it never swallows input, and it always lays a scrim over the
/// artwork so the header and mini player stay legible on a bright image.
void main() {
  Widget harness(Widget child) => ProviderScope(
        child: material.MaterialApp(
          home: material.Scaffold(body: child),
        ),
      );

  testWidgets('the wallpaper ignores pointers and paints a scrim above the art',
      (tester) async {
    tester.view.physicalSize = const material.Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(const HomeWallpaper(url: 'https://example.com/wall.webp')),
    );
    await tester.pump();

    // Every tap that reaches the background would otherwise be eaten by a
    // full-screen image sitting over the cards. Scoped to HomeWallpaper's own
    // subtree: the Material framework inserts IgnorePointers of its own.
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

    // Order matters: the scrim must be painted AFTER the image, i.e. it is the
    // later child of the Stack.
    final stack = tester.widget<Stack>(
      find
          .descendant(of: find.byType(HomeWallpaper), matching: find.byType(Stack))
          .first,
    );
    expect(stack.children.length, 2,
        reason: 'expect the image plus exactly one scrim layer');
    expect(stack.children.last, isA<DecoratedBox>(),
        reason: 'the scrim should be the top layer');
  });

  testWidgets('an empty url still renders without throwing', (tester) async {
    // Defence in depth: the caller only mounts this widget when a wallpaper is
    // configured, but a bad value must never crash the home screen.
    await tester.pumpWidget(harness(const HomeWallpaper(url: '')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
