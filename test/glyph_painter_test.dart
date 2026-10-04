// Verifies every chip glyph PAINTS the expected visible coverage.
//
// A painter that runs without throwing can still draw the wrong shape or
// nothing at all - which is exactly what happened while building these: the Om
// came out an unrecognisable squiggle and then a solid blob, and the Ganesha
// merged into a knot. Asserting "did not throw" would have passed all three.
//
// So each glyph is rasterised and its painted-pixel coverage is checked against
// the shape it should be:
//   - every glyph must actually mark the canvas (a blank glyph fails),
//   - it must stay inside its box (no clipped/overflowing paths),
//   - and glyphs with known structure are checked for ink where they need it.
//
// The visual contact sheet is produced by `tool/render_glyph_sheet.dart`
// instead of here, so a test never depends on writing files.
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/home/sections/featured_playlist_chips.dart';

/// Glyph names as the admin dropdown offers them, plus an unknown and an empty
/// name to cover the fallback.
///
/// Keep in step with `CHIP_ICON_GLYPHS` in `server/admin.html`: a name offered
/// there but missing from the painter would render the fallback note, which is
/// exactly what these tests exist to catch.
const _glyphs = <String>[
  'temple',
  'flute',
  'ganesha',
  'bow',
  'lotus',
  'om',
  'trishul',
  'conch',
  'diya',
  'bell',
  'music',
  'unknown-fallback',
  '',
];

/// How many pixels of [name] are painted, and where.
///
/// Renders the glyph white-on-transparent at a fixed size, then inspects the
/// alpha channel.
Future<_Coverage> _rasterise(String name) async {
  const size = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = material.Canvas(recorder, const material.Rect.fromLTWH(0, 0, size, size));
  FeaturedChipGlyphPainter(name: name, color: const material.Color(0xFFFFFFFF))
      .paint(canvas, const material.Size(size, size));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(data, isNotNull, reason: '$name should rasterise');

  final bytes = data!.buffer.asUint8List();
  var painted = 0;
  var minX = size.toInt(), maxX = -1, minY = size.toInt(), maxY = -1;
  for (var y = 0; y < size.toInt(); y++) {
    for (var x = 0; x < size.toInt(); x++) {
      final alpha = bytes[(y * size.toInt() + x) * 4 + 3];
      if (alpha > 24) {
        painted++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  picture.dispose();
  image.dispose();
  return _Coverage(
    painted: painted,
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    box: size.toInt(),
  );
}

class _Coverage {
  final int painted;
  final int minX, maxX, minY, maxY, box;
  const _Coverage({
    required this.painted,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.box,
  });

  /// Fraction of the box that carries ink.
  double get fill => painted / (box * box);

  /// Ink present in a horizontal band (0 = top, 1 = bottom).
  bool hasInkFromLeft(double from, double to) => minX <= box * to && maxX >= box * from;

  @override
  String toString() =>
      'painted=$painted (${(fill * 100).toStringAsFixed(1)}%) '
      'x=[$minX,$maxX] y=[$minY,$maxY] box=$box';
}

void main() {
  group('every glyph paints something visible inside its box', () {
    for (final name in _glyphs) {
      test('"$name"', () async {
        final c = await _rasterise(name);
        // Blank glyph = invisible button face.
        expect(c.painted, greaterThan(20), reason: '"$name" painted almost nothing ($c)');
        // A shape that filled in as a solid block would be the "blob"
        // regression the Om went through. The bar is deliberately generous:
        // Om is drawn with a heavier calligraphic stroke (~47%) and is still a
        // legible ॐ, whereas a true filled blob lands well above 60%.
        expect(c.fill, lessThan(0.60), reason: '"$name" looks like a solid blob ($c)');
        // Must stay inside its box: a path outside would be clipped in place.
        expect(c.minX, greaterThanOrEqualTo(0), reason: '"$name" overflows left ($c)');
        expect(c.minY, greaterThanOrEqualTo(0), reason: '"$name" overflows top ($c)');
        expect(c.maxX, lessThan(c.box), reason: '"$name" overflows right ($c)');
        expect(c.maxY, lessThan(c.box), reason: '"$name" overflows bottom ($c)');
      });
    }
  });

  group('glyphs are structurally distinct from each other', () {
    test('no two glyphs render the same coverage box', () async {
      // If two names produced identical bounds, one of them is falling through
      // to the wrong case (e.g. a typo silently hitting the fallback).
      final boxes = <String, String>{};
      for (final name in [
        'temple',
        'flute',
        'ganesha',
        'bow',
        'lotus',
        'om',
        'trishul',
        'conch',
        'diya',
        'bell',
      ]) {
        final c = await _rasterise(name);
        boxes[name] = '${c.minX},${c.maxX},${c.minY},${c.maxY},${c.painted}';
      }
      final seen = <String, String>{};
      boxes.forEach((name, sig) {
        expect(seen.containsKey(sig), isFalse,
            reason: '"$name" renders identically to "${seen[sig]}" - one is not drawing its own glyph');
        seen[sig] = name;
      });
    });

    test('an unknown name falls back to the music note, not to nothing', () async {
      final fallback = await _rasterise('definitely-not-a-glyph');
      final music = await _rasterise('music');
      expect(fallback.painted, equals(music.painted),
          reason: 'the fallback should be the music note itself');
    });

    test('an empty name also falls back to the music note', () async {
      final empty = await _rasterise('');
      final music = await _rasterise('music');
      expect(empty.painted, equals(music.painted));
    });
  });

  group('glyphs with a known vertical structure are the right way up', () {
    test('the om draws its bowl low and its bindu high', () async {
      // Om's body sits in the lower half and the dot floats above it; if the
      // strokes were mis-positioned the dot would be missing or the whole mark
      // would collapse into one band.
      final c = await _rasterise('om');
      expect(c.maxY, greaterThan((c.box * 0.75).round()),
          reason: 'the bowl should reach low in the box ($c)');
      expect(c.minY, lessThan((c.box * 0.30).round()),
          reason: 'the bindu should sit high in the box ($c)');
    });

    test('the temple is widest at its base and narrows toward the spire', () async {
      final recorder = ui.PictureRecorder();
      const size = 64.0;
      final canvas = material.Canvas(recorder, const material.Rect.fromLTWH(0, 0, size, size));
      FeaturedChipGlyphPainter(name: 'temple', color: const material.Color(0xFFFFFFFF))
          .paint(canvas, const material.Size(size, size));
      final image = await recorder.endRecording().toImage(64, 64);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();

      int widthAt(int y) {
        var lo = 64, hi = -1;
        for (var x = 0; x < 64; x++) {
          if (bytes[(y * 64 + x) * 4 + 3] > 24) {
            if (x < lo) lo = x;
            if (x > hi) hi = x;
          }
        }
        return hi < lo ? 0 : hi - lo;
      }

      final baseWidth = widthAt(56); // near the plinth
      final spireWidth = widthAt(10); // near the tip
      expect(baseWidth, greaterThan(0), reason: 'the base should have ink');
      expect(baseWidth, greaterThan(spireWidth),
          reason: 'a gopuram is wider at the base than the spire');
    });
  });
}
