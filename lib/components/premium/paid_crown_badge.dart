import 'package:flutter/material.dart' as material;

/// A golden crown marker for paid tracks, replacing the earlier centred lock.
///
/// The crown is drawn with a [material.CustomPainter] (matching the app's other
/// painted glyphs in `featured_playlist_chips.dart`) rather than an icon-font
/// glyph, so its silhouette and its gold fill `#E0A000` stay exact across
/// platforms. It sits at the TOP-RIGHT corner of a cover.
///
/// Two widgets are provided:
///   * [PaidCrown] — the bare crown, sized to [size] (in logical pixels).
///   * [PaidCrownBadge] — a [material.Positioned] overlay that pins the crown to
///     the top-right corner of a cover [material.Stack], with an optional inset.
class PaidCrown extends material.StatelessWidget {
  final double size;

  const PaidCrown({super.key, this.size = 20});

  @override
  material.Widget build(material.BuildContext context) {
    return material.SizedBox(
      width: size,
      height: size,
      child: material.CustomPaint(
        painter: _CrownPainter(),
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
final material.CustomPainter paidCrownPainter = _CrownPainter();

/// Paints the crown in the app's brand gold with a thin dark halo so it stays
/// legible on light artwork. Designed in a 24x24 canvas and scaled to the
/// requested size.
class _CrownPainter extends material.CustomPainter {
  static const material.Color gold = material.Color(0xFFE0A000);
  static const material.Color outline = material.Color(0x66000000);

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

    final fill = material.Paint()
      ..style = material.PaintingStyle.fill
      ..color = gold;
    final halo = material.Paint()
      ..style = material.PaintingStyle.stroke
      ..strokeWidth = 1.2 * s
      ..strokeJoin = material.StrokeJoin.round
      ..color = outline;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, halo);

    // Three small jewels on the spike tips.
    final jewel = material.Paint()
      ..style = material.PaintingStyle.fill
      ..color = gold;
    canvas.drawCircle(
      material.Offset(12.0 * s, 4.5 * s),
      1.6 * s,
      jewel,
    );
    canvas.drawCircle(
      material.Offset(7.0 * s, 12.0 * s),
      1.4 * s,
      jewel,
    );
    canvas.drawCircle(
      material.Offset(17.0 * s, 12.0 * s),
      1.4 * s,
      jewel,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}
