import 'dart:math';

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A lightweight donut / ring chart rendered with [CustomPainter].
///
/// Slices are sized proportionally to [segments]. The center shows a
/// [centerLabel] / [centerValue] pair, making it ideal for "share of
/// listening" visualizations without pulling in a heavy charting dependency.
class DonutChart extends StatelessWidget {
  /// Ordered segments; the largest renders first and each gets a distinct
  /// color derived from the theme's primary palette.
  final List<({String label, double value})> segments;

  final String? centerValue;
  final String? centerLabel;

  /// Space (in logical pixels) between the outer edge and the inner hole.
  final double thickness;

  const DonutChart({
    super.key,
    required this.segments,
    this.centerValue,
    this.centerLabel,
    this.thickness = 14,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = _resolvedSegments(scheme);

    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _DonutPainter(
          segments: resolved,
          thickness: thickness,
          baseColor: scheme.muted,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerValue != null)
                Text(
                  centerValue!,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: scheme.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (centerLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    centerLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<({String label, double value, Color color})> _resolvedSegments(
    ColorScheme scheme,
  ) {
    if (segments.isEmpty) return const [];

    final palette = <Color>[
      scheme.chart1,
      scheme.chart2,
      scheme.chart3,
      scheme.chart4,
      scheme.chart5,
      scheme.primary,
      scheme.secondary,
    ];

    // Sort descending so the biggest slice starts at the top.
    final sorted = [...segments]..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (var i = 0; i < sorted.length; i++)
        (
          label: sorted[i].label,
          value: sorted[i].value,
          color: palette[i % palette.length],
        ),
    ];
  }
}

class _DonutPainter extends CustomPainter {
  final List<({String label, double value, Color color})> segments;
  final double thickness;
  final Color baseColor;

  _DonutPainter({
    required this.segments,
    required this.thickness,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - thickness / 2;

    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = baseColor.withValues(alpha: 0.35);

    canvas.drawCircle(center, radius, background);

    const startAngle = -pi / 2;
    var sweepStart = startAngle;

    for (final segment in segments) {
      final sweep = (segment.value / total) * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt
        ..color = segment.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        sweepStart,
        sweep - (segments.length > 1 ? 0.02 : 0),
        false,
        paint,
      );

      sweepStart += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.thickness != thickness ||
        oldDelegate.baseColor != baseColor;
  }
}
