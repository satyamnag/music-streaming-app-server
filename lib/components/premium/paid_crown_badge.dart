import 'package:flutter/material.dart' as material;

/// A golden crown marker for paid tracks, replacing the earlier centred lock.
///
/// The crown is drawn with a [material.CustomPainter] (matching the app's other
/// painted glyphs in `featured_playlist_chips.dart`) rather than an icon-font
/// glyph, so its silhouette stays exact across platforms. It sits at the
/// TOP-RIGHT corner of a cover.
///
/// **Why the dark disc exists.** The first version was a gold [#E0A000] crown
/// with a 1.2dp 40%-black halo, drawn straight onto the cover. Almost every cover
/// in this catalogue is itself gold — temple gopurams, sunset skies, marigold
/// garlands — so the crown dissolved into the artwork and readers could not tell a
/// paid track from a free one. The badge is now a dark, gold-rimmed disc that the
/// crown is cut out of: the crown keeps its exact shape and gold, and the disc
/// guarantees contrast on light, dark, gold and photographic artwork alike.
class PaidCrown extends material.StatelessWidget {
  final double size;

  const PaidCrown({super.key, this.size = 20});

  @override
  material.Widget build(material.BuildContext context) {
    final scale = size / 20.0;
    return material.SizedBox(
      width: size,
      height: size,
      child: material.DecoratedBox(
        decoration: material.BoxDecoration(
          shape: material.BoxShape.circle,
          // Near-black, warm, and nearly opaque: 90% is enough to hide the
          // artwork's texture without turning the badge into a hole in the cover.
          color: const material.Color(0xE6140E05),
          border: material.Border.all(
            color: const material.Color(0x99FFD977),
            width: 1 * scale,
          ),
          // A soft drop shadow lifts the disc off a same-tone cover.
          boxShadow: [
            material.BoxShadow(
              color: const material.Color(0x73000000),
              blurRadius: 3 * scale,
              offset: material.Offset(0, 1 * scale),
            ),
          ],
        ),
        child: material.Padding(
          padding: material.EdgeInsets.all(3 * scale),
          child: const material.CustomPaint(
            painter: _CrownPainter(),
          ),
        ),
      ),
    );
  }
}

/// Positions a [PaidCrown] at the top-right corner of the enclosing
/// [material.Stack]. Use inside a cover's `Stack(fit: StackFit.expand, ...)`
/// (the track card) or the cover `Stack` of a track row.
class PaidCrownBadge extends material.StatelessWidget {
  final bool paid;
  final double size;
  final material.EdgeInsets inset;

  const PaidCrownBadge({
    super.key,
    required this.paid,
    this.size = 20,
    this.inset = const material.EdgeInsets.all(4),
  });

  @override
  material.Widget build(material.BuildContext context) {
    if (!paid) return const material.SizedBox.shrink();
    return material.Positioned(
      top: inset.top,
      right: inset.right,
      child: PaidCrown(size: size),
    );
  }
}

/// The crown painter exposed for tests: rasterises the real glyph so a test
/// can assert it is not blank, not a blob, and the right way up.
const material.CustomPainter paidCrownPainter = _CrownPainter();

/// Paints the crown itself: a light-to-deep gold gradient, a cream keyline so the
/// silhouette survives on a dark or gold backdrop, and a thin dark outer halo so
/// it survives on a light one. Designed in a 24x24 canvas and scaled to the
/// requested size.
///
/// The disc behind it lives in [PaidCrown], deliberately NOT here: the painter
/// stays a pure glyph, which is what the raster test measures.
class _CrownPainter extends material.CustomPainter {
  const _CrownPainter();

  static const material.Color goldLight = material.Color(0xFFFFE082);
  static const material.Color goldDeep = material.Color(0xFFE0A000);
  static const material.Color keyline = material.Color(0xCCFFF6DC);
  static const material.Color outline = material.Color(0x8A000000);

  @override
  void paint(material.Canvas canvas, material.Size size) {
    final s = size.width / 24.0; // design-space scale

    // A three-spike crown: centre spike tallest, two side spikes, then a band.
    final path = material.Path()
      ..moveTo(3.0 * s, 18.5 * s)
      ..lineTo(3.0 * s, 8.0 * s)
      ..lineTo(7.0 * s, 12.0 * s)
      ..lineTo(12.0 * s, 4.5 * s)
      ..lineTo(17.0 * s, 12.0 * s)
      ..lineTo(21.0 * s, 8.0 * s)
      ..lineTo(21.0 * s, 18.5 * s)
      ..close();

    final bounds = path.getBounds();
    final fill = material.Paint()
      ..style = material.PaintingStyle.fill
      ..shader = const material.LinearGradient(
        begin: material.Alignment.topCenter,
        end: material.Alignment.bottomCenter,
        colors: [goldLight, goldDeep],
        stops: [0.0, 0.85],
      ).createShader(bounds);

    // Cream keyline INSIDE the glyph, so the outline is gold-on-cream-on-dark
    // rather than a single colour that matches the artwork behind it.
    final inner = material.Paint()
      ..style = material.PaintingStyle.stroke
      ..strokeWidth = 0.9 * s
      ..strokeJoin = material.StrokeJoin.round
      ..color = keyline;

    final halo = material.Paint()
      ..style = material.PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeJoin = material.StrokeJoin.round
      ..color = outline;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, halo);
    canvas.drawPath(path, inner);

    // Three small jewels on the spike tips.
    final jewel = material.Paint()
      ..style = material.PaintingStyle.fill
      ..color = goldLight;
    final jewelRim = material.Paint()
      ..style = material.PaintingStyle.stroke
      ..strokeWidth = 0.6 * s
      ..color = keyline;

    for (final (centre, radius) in [
      (const material.Offset(12.0, 4.5), 1.7),
      (const material.Offset(7.0, 12.0), 1.5),
      (const material.Offset(17.0, 12.0), 1.5),
    ]) {
      final c = material.Offset(centre.dx * s, centre.dy * s);
      canvas.drawCircle(c, radius * s, jewel);
      canvas.drawCircle(c, radius * s, jewelRim);
    }
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}
