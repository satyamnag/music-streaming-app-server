/// The capsule drawn around the lyric line that is currently being sung.
///
/// This is the app's existing devotional vocabulary applied to the reference
/// design, rather than a second visual language:
///
///  * the cream pill fill (`#FAF3E0`) and the hairline gold (`#C9A227`) are the
///    exact colours [LyricsOrnamentDivider] and [LyricsMusicBanner] already use
///    for the `{Heading}` divider and the `♪ Music ♪` banner, so a marked heading
///    and the playing line read as one family;
///  * the ink is the Bhakti colour scheme's documented deep-maroon primary
///    (`#520101`), which is what the reference sets the singing line in;
///  * the gold sunburst at each end is the ornament the reference brackets the
///    capsule with, painted with paths so it adds no asset and stays crisp at
///    every text-zoom level the page offers.
///
/// Deliberately NOT included: the reference's full-width gold rules reaching the
/// screen edges. They are drawn beside a capsule that spans almost the whole
/// width there, but here the capsule hugs the line, and a lyric line needs every
/// horizontal pixel it can get - spending ~24dp per side on rules would push a
/// long line onto an extra row every time it became current, making the text
/// jump as it is highlighted. The ornaments alone carry the same signal.
library;

import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

class LyricsActiveLineCapsule extends StatelessWidget {
  /// The line, and any translation sub-lines, to draw inside the capsule.
  final Widget child;

  const LyricsActiveLineCapsule({super.key, required this.child});

  /// Cream pill fill, top to bottom. Slightly warmed at the bottom so the pill
  /// reads as a lit surface rather than a flat block.
  static const Color creamTop = Color(0xFFFDF7E7);
  static const Color creamBottom = Color(0xFFF3E6C8);

  /// Hairline gold shared with the ornament divider.
  static const Color gold = Color(0xFFC9A227);

  /// The ink for the singing line. `#520101` is the deep maroon primary of the
  /// Bhakti colour scheme (documented at the top of bhakti_color_scheme.dart).
  ///
  /// It is a fixed colour rather than `colorScheme.primary` because this text is
  /// painted on the CREAM pill, not on the themed surface: the light theme's
  /// primary is the near-black maroon below, which is what 12:1 against this
  /// cream needs, while the dark theme's primary is a brighter red that would sit
  /// at roughly 4:1 here. The capsule owns its own surface, so it owns its ink.
  static const Color ink = Color(0xFF520101);

  /// Ornament diameter at 100% text zoom.
  static const double ornamentSize = 18;

  @override
  Widget build(BuildContext context) {
    final scale = Theme.of(context).scaling;

    // `mainAxisSize.max` + `center`: the capsule centres ITSELF in whatever width
    // it is given. As a min-width row dropped into a full-width list item it sat
    // against the left edge, because those items only centre their TEXT
    // (`textAlign`) - which is why the singing line was the one line that was not
    // horizontally aligned with the rest. The pill is still the only flexible
    // child, so a long line wraps inside the space the ornaments leave and
    // nothing can overflow.
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Sunburst(size: ornamentSize * scale),
        Gap(6 * scale),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 7 * scale,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [creamTop, creamBottom],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: gold.withValues(alpha: 0.55),
                width: 1.2,
              ),
              // A soft gold halo, so the capsule lifts off the artwork the page
              // is drawn on the way the reference's does off its sheet.
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.28),
                  blurRadius: 14 * scale,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        ),
        Gap(6 * scale),
        _Sunburst(size: ornamentSize * scale),
      ],
    );
  }
}

/// A small gold sunburst: eight tapered rays around a solid core.
///
/// Painted rather than composed from rotated boxes so the rays stay symmetric
/// and hairline-thin at every size, and so nothing is clipped at the corners.
class _Sunburst extends StatelessWidget {
  final double size;

  const _Sunburst({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SunburstPainter(LyricsActiveLineCapsule.gold),
      ),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  final Color color;

  const _SunburstPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.46;

    final ray = Paint()
      ..color = color
      ..strokeWidth = math.max(1, outer * 0.14)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + direction * inner, center + direction * outer, ray);
    }

    canvas.drawCircle(center, outer * 0.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter oldDelegate) =>
      oldDelegate.color != color;
}
