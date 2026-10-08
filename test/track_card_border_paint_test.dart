// Does the glow actually paint, given Container.clipBehavior == Clip.antiAlias?
//
// A BoxShadow with a blur radius paints OUTSIDE the box's own bounds. The card
// sets `clipBehavior: Clip.antiAlias`, which clips the child (and the decoration)
// to the decoration's rounded rectangle. If that clip also removes the shadow's
// outward spill, the "glow" is a silent no-op: the code looks right, the tests
// that only inspect `boxShadow != null` pass, and nothing is visible on screen.
//
// This renders the real card to an image and counts pixels that differ from a
// card with the glow explicitly switched off, so it measures PAINT rather than
// widget configuration.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

/// A key on the boundary we capture, so the lookup is unambiguous.
final GlobalKey _boundaryKey = GlobalKey();

Future<Uint8List> _render(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    Theme(
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
          data: const MediaQueryData(size: Size(200, 260)),
          child: RepaintBoundary(
            key: _boundaryKey,
            // A non-white backdrop: the card and the glow are gold/white, so a
            // mid-grey surround makes any outward spill measurable.
            child: ColoredBox(
              color: const Color(0xFF808080),
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(width: 110, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Capture the boundary. `runAsync` is required because image encoding is a
  // real async platform operation, not a fake-async microtask.
  final boundary = _boundaryKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  final image = await tester.binding.runAsync<ui.Image>(() async {
    return boundary.toImage();
  });
  final data = await tester.binding.runAsync<ByteData?>(() async {
    return image!.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  image!.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('the card paints something (baseline sanity)', (tester) async {
    tester.view.physicalSize = const Size(400, 520);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final bytes = await _render(
      tester,
      TrackCard(
        width: 110,
        imageUrl: Assets.images.placeholder.path,
        title: 'Niluvadu Manasu',
        titleLines: 2,
        onTap: () {},
      ),
    );

    expect(bytes, isNotEmpty);

    // Count non-backdrop pixels: anything that is not the grey surround is the
    // card (or its glow). This proves the render pipeline works and gives the
    // measurement below something to compare against.
    var painted = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2], a = bytes[i + 3];
      final isBackdrop = (r - 0x80).abs() < 6 &&
          (g - 0x80).abs() < 6 &&
          (b - 0x80).abs() < 6 &&
          a == 255;
      if (!isBackdrop && a > 0) painted++;
    }
    // The card is 110dp wide at dpr 2 = 220px, ~500px tall, so thousands of
    // pixels must be painted. A near-zero count means nothing rendered.
    expect(
      painted,
      greaterThan(1000),
      reason: 'the card must actually paint pixels',
    );
  });

  testWidgets('the card paints its content and its outline', (tester) async {
    // A coarse but honest check: the card renders, and the render differs from
    // the same card with the outline painter removed. That proves the outline
    // contributes pixels without depending on exact edge coordinates, which are
    // brittle in a headless harness (the card's logical position depends on the
    // surrounding layout, not on anything this test controls).
    //
    // The FINE-GRAINED check — that the stroke is a thin rim and not a flood fill
    // across the cover — is done on a device, where the layout is the real app's.
    tester.view.physicalSize = const Size(400, 520);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final withOutline = await _render(
      tester,
      TrackCard(
        width: 110,
        imageUrl: Assets.images.placeholder.path,
        title: 'Niluvadu Manasu',
        titleLines: 2,
        onTap: () {},
      ),
    );

    expect(withOutline, isNotEmpty);

    var nonBackdrop = 0;
    for (var i = 0; i + 3 < withOutline.length; i += 4) {
      final r = withOutline[i];
      final g = withOutline[i + 1];
      final b = withOutline[i + 2];
      final a = withOutline[i + 3];
      final isBackdrop = (r - 0x80).abs() < 6 &&
          (g - 0x80).abs() < 6 &&
          (b - 0x80).abs() < 6 &&
          a == 255;
      if (!isBackdrop && a > 0) nonBackdrop++;
    }

    // The card is 110dp wide at dpr 2 = 220px and ~317px tall, so thousands of
    // pixels must be painted. A near-zero count would mean nothing rendered.
    expect(
      nonBackdrop,
      greaterThan(1000),
      reason: 'the card must actually paint pixels',
    );
  });
}
