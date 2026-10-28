// Verifies the paid-track crown badge paints correctly and that the lock glyph
// is gone from the surfaces the requirement covers.
//
// The change: paid tracks previously showed a centred dark-scrim lock icon on
// their cover art (LockedBadge) and a padlock in the album-row play slot. Both
// are now a golden crown at the TOP-RIGHT corner. This test guards two things:
//
//   1. THE GLYPH — the crown painter rasterises to a recognisable crown: ink
//      that is neither blank nor a solid blob, with a tall centre spike high
//      and a wide base low.
//
//   2. THE SWAP — the centred lock must no longer be referenced by the track
//      cover or the album row; the crown badge must be wired in its place.
//      Album covers (album_card.dart) intentionally keep their lock, so that
//      file is out of scope here (asserted to remain unchanged).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/components/premium/paid_crown_badge.dart';

/// Rasterises the real crown painter (public `paidCrownPainter`) at [size] and
/// returns its painted-pixel bounds, mirroring the coverage probes in
/// `test/glyph_painter_test.dart`.
Future<_Coverage> _rasterise(double size) async {
  final recorder = ui.PictureRecorder();
  final canvas = material.Canvas(
    recorder,
    material.Rect.fromLTWH(0, 0, size, size),
  );
  paidCrownPainter.paint(canvas, material.Size(size, size));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(data, isNotNull, reason: 'the crown should rasterise');

  final bytes = data!.buffer.asUint8List();
  var painted = 0;
  var minX = size.toInt(), maxX = -1, minY = size.toInt(), maxY = -1;
  for (var y = 0; y < size.toInt(); y++) {
    for (var x = 0; x < size.toInt(); x++) {
      if (bytes[(y * size.toInt() + x) * 4 + 3] > 24) {
        painted++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
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

  double get fill => painted / (box * box);
}

void main() {
  group('the crown paints a recognisable paid marker', () {
    test('the crown is not blank', () async {
      final c = await _rasterise(64);
      expect(c.painted, greaterThan(20),
          reason: 'a blank crown is an invisible badge (painted=${c.painted})');
    });

    test('the crown is not a solid blob', () async {
      final c = await _rasterise(64);
      expect(c.fill, lessThan(0.60),
          reason: 'a filled blob is not a crown (fill=${c.fill.toStringAsFixed(3)})');
    });

    test('the crown is the right way up (spike high, band low)', () async {
      final c = await _rasterise(64);
      expect(c.minY, lessThan((c.box * 0.35).round()),
          reason: 'the centre spike should reach high (minY=${c.minY})');
      expect(c.maxY, greaterThan((c.box * 0.70).round()),
          reason: 'the band should sit low (maxY=${c.maxY})');
    });

    test('the crown stays inside its canvas', () async {
      final c = await _rasterise(64);
      expect(c.minX, greaterThanOrEqualTo(0));
      expect(c.minY, greaterThanOrEqualTo(0));
      expect(c.maxX, lessThan(c.box));
      expect(c.maxY, lessThan(c.box));
    });
  });

  group('the centred lock is gone wherever a paid track renders', () {
    test('track cover uses the crown badge, not the lock badge', () {
      final src = File('lib/components/track_card/track_card.dart')
          .readAsStringSync();
      expect(src.contains('PaidCrownBadge'), isTrue);
      expect(src.contains('LockedBadge'), isFalse,
          reason: 'the track cover must no longer reference the centred lock');
    });

    test('album row uses the crown, not the padlock glyph', () {
      final src =
          File('lib/components/track_tile/track_tile.dart').readAsStringSync();
      expect(src.contains('PaidCrownBadge'), isTrue);
      expect(src.contains('Icons.lock'), isFalse,
          reason: 'the album row play slot must no longer draw a padlock');
    });

    test('album COVERS keep their lock (out of scope)', () {
      final src =
          File('lib/modules/album/album_card.dart').readAsStringSync();
      expect(src.contains('LockedBadge'), isTrue,
          reason: 'album covers were not part of the crown change and must keep '
              'their lock badge');
    });
  });
}
