// Does the card outline actually put a rim on screen, ALL THE WAY ROUND?
//
// Why this exists
// ---------------
// `track_card_border_paint_test.dart` claims to prove the outline paints, but it
// only counts "pixels that differ from the grey backdrop". The card's COVER
// already differs from the backdrop, so that assertion passes whether the
// outline paints or not — it cannot fail for the reason it claims to test.
//
// The card's border shipped invisible on a real phone for exactly that reason.
// Two defects, both invisible to a configuration-level test:
//
//   1. The outline's `CustomPaint` was a bare `Stack` child. Under the Stack's
//      default loose constraints a child with no intrinsic size collapses to
//      0x0, so the painter was handed `Size.zero` and drew nothing at all.
//      Asserting "a painter exists" passed the whole time.
//   2. The rim stroked the gold-to-maroon FILL ramp. Its maroon end is nearly
//      identical to the dark album artwork, so even once it painted, it read as
//      no border over most of the card.
//
// This test measures PAINT, not configuration: it renders the real card and
// requires accent-gold pixels along the top, bottom, left AND right edges of the
// card's own rect. A rim that only paints a corner, or paints nothing, fails.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

final GlobalKey _key = GlobalKey();

/// The captured raster's width in pixels, and the pixel-per-logical-pixel ratio
/// it was rendered at.
///
/// `RenderRepaintBoundary.toImage()` defaults to `pixelRatio: 1.0`, and the view's
/// `devicePixelRatio` does NOT change that, so the captured raster is exactly the
/// surface's logical size. The capture surface is 200x400 logical, so the raster
/// is 200x400 pixels and one logical pixel is one raster pixel. Deriving the
/// ratio from the byte length rather than assuming it keeps this correct if the
/// surface size changes.
const int _captureWidth = 200;
const int _captureHeight = 400;

/// The ratio the boundary is captured at. Kept in one place so the render and
/// the coordinate mapping can never disagree.
const double _devicePixelRatio = 2.0;

/// The captured raster's width in pixels.
int get _rasterWidth => (_captureWidth * _devicePixelRatio).round();

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
          data: const MediaQueryData(size: Size(220, 400)),
          child: RepaintBoundary(
            key: _key,
            // An explicit, generously sized surface. The card is ~110dp wide but
            // 172dp tall (cover + two title lines + subtitle), so a 200x400
            // surface leaves room for the whole card plus a backdrop band on
            // every side — the backdrop is what makes an outward-painting rim
            // distinguishable from the card itself.
            child: SizedBox(
              width: 200,
              height: 400,
              child: ColoredBox(
                color: const Color(0xFF808080),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // Render at pixelRatio 2 so the raster is fine enough to resolve a 1.5dp rim,
  // and so the coordinate mapping is explicit rather than inherited from the view.
  final image = await tester.binding.runAsync<ui.Image>(
    () async => boundary.toImage(pixelRatio: _devicePixelRatio),
  );
  final data = await tester.binding.runAsync<ByteData?>(
    () async => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  image!.dispose();
  return data!.buffer.asUint8List();
}

/// True when [r,g,b] is close to the light scheme's accent gold (HSL 43, 1, .44),
/// which is what BOTH ends of the rim are derived from.
bool _isRimGold(int r, int g, int b) {
  // Generous enough to accept the rim's darker bottom-right end (the ramp
  // deepens lightness to 72%, clamped at 0.30) while still rejecting the album
  // artwork's near-black maroons and the page's white.
  return r >= 110 && r <= 255 && g >= 45 && g <= 200 && b <= 90 && r > g;
}

void main() {
  testWidgets('the outline paints a gold rim on all four card edges',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final bytes = await _render(
      tester,
      TrackCard(
        width: 110,
        imageUrl: Assets.images.placeholder.path,
        title: 'Ganesha Lahari',
        subtitle: '8 songs',
        titleLines: 1,
        onTap: () {},
        onPlay: () {},
      ),
    );
    expect(bytes, isNotEmpty);

    // The card's own rect, in logical pixels, mapped into raster pixels.
    final card = tester.getRect(find.byType(TrackCard));
    final left = (card.left * _devicePixelRatio).round();
    final right = (card.right * _devicePixelRatio).round();
    final top = (card.top * _devicePixelRatio).round();
    final bottom = (card.bottom * _devicePixelRatio).round();

    final totalPixels = bytes.length ~/ 4;
    // ignore: avoid_print
    print('RIM CAPTURE: $totalPixels px, raster ${_rasterWidth}x'
        '${_captureHeight * _devicePixelRatio ~/ 1}');
    // ignore: avoid_print
    print('RIM CARD RECT(px): l=$left r=$right t=$top b=$bottom  '
        '(card ${card.width}x${card.height} dp)');

    bool goldAt(int x, int y) {
      if (x < 0 || y < 0 || x >= _rasterWidth) return false;
      final i = ((y * _rasterWidth) + x) * 4;
      if (i + 3 >= bytes.length) return false;
      if (bytes[i + 3] == 0) return false;
      return _isRimGold(bytes[i], bytes[i + 1], bytes[i + 2]);
    }

    // Walk just INSIDE each edge. The stroke is centred on the rect inset by half
    // its width, so the rim's pixels sit within a few raster pixels of the edge;
    // scanning a small band inward finds it without depending on the exact pixel.
    const int band = 7;
    const int cornerSkip = 30;

    int goldAlong(bool horizontal, int fixed, int from, int to) {
      var n = 0;
      for (var v = from; v <= to; v++) {
        for (var d = 0; d <= band; d++) {
          final hit = horizontal
              ? (goldAt(v, fixed + d) || goldAt(v, fixed - d))
              : (goldAt(fixed + d, v) || goldAt(fixed - d, v));
          if (hit) {
            n++;
            break;
          }
        }
      }
      return n;
    }

    final topGold =
        goldAlong(true, top, left + cornerSkip, right - cornerSkip);
    final bottomGold =
        goldAlong(true, bottom, left + cornerSkip, right - cornerSkip);
    final leftGold =
        goldAlong(false, left, top + cornerSkip, bottom - cornerSkip);
    final rightGold =
        goldAlong(false, right, top + cornerSkip, bottom - cornerSkip);

    // ignore: avoid_print
    print('RIM PROBE: top=$topGold bottom=$bottomGold '
        'left=$leftGold right=$rightGold');

    // Dump the actual colours found just inside each edge, so a failure says
    // WHICH colour the rim has rather than only that the predicate missed.
    void dumpEdge(String name, int x, int y, {required bool horizontal}) {
      final b = <String>[];
      for (var d = 0; d <= band; d++) {
        final px = horizontal ? x : x + d;
        final py = horizontal ? y + d : y;
        final i = ((py * _rasterWidth) + px) * 4;
        if (i + 3 < bytes.length) {
          b.add('d$d=(${bytes[i]},${bytes[i + 1]},${bytes[i + 2]})');
        }
      }
      // ignore: avoid_print
      print('RIM EDGE $name @($x,$y): ${b.join(" ")}');
    }

    final midX = (left + right) ~/ 2;
    final midY = (top + bottom) ~/ 2;
    dumpEdge('top(mid)', midX, top, horizontal: true);
    dumpEdge('bottom(mid)', midX, bottom, horizontal: true);
    dumpEdge('left(mid)', left, midY, horizontal: false);
    dumpEdge('right(mid)', right, midY, horizontal: false);

    final spanX = (right - cornerSkip) - (left + cornerSkip);
    final spanY = (bottom - cornerSkip) - (top + cornerSkip);

    // Antialiasing and artwork that itself contains warm tones mean a perfect
    // clean sweep is not a fair bar; "a clear majority of sampled positions"
    // is, and it still fails loudly when an edge paints no rim at all (the
    // bottom edge measured 0 before this fix).
    expect(topGold, greaterThan(spanX * 0.7),
        reason: 'the top rim must be gold along its length');
    expect(bottomGold, greaterThan(spanX * 0.7),
        reason: 'the BOTTOM rim must be gold too — the old maroon end '
            'disappeared into the dark cover here');
    expect(leftGold, greaterThan(spanY * 0.7),
        reason: 'the left rim must be gold along its length');
    expect(rightGold, greaterThan(spanY * 0.7),
        reason: 'the right rim must be gold along its length');
  });

  testWidgets('the outline CustomPaint is given the card\'s full rect',
      (tester) async {
    // The zero-size defect, pinned directly. A bare Stack child with no intrinsic
    // size collapses to 0x0 under loose constraints, and the painter then returns
    // early having drawn nothing — while every "a painter exists" assertion still
    // passes.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

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
          child: Align(
            alignment: Alignment.topLeft,
            child: TrackCard(
              width: 110,
              imageUrl: Assets.images.placeholder.path,
              title: 'Ganesha Lahari',
              subtitle: '8 songs',
              titleLines: 1,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(TrackCard));
    final outlinePaint = find.descendant(
      of: find.byType(TrackCard),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null,
      ),
    );
    expect(outlinePaint, findsWidgets,
        reason: 'the outline painter must be in the tree');

    final paintRect = tester.getRect(outlinePaint.first);
    expect(
      paintRect.size,
      card.size,
      reason: 'the outline painter must receive the card\'s full rect; a '
          'zero-sized CustomPaint draws nothing and the border vanishes',
    );
  });
}
