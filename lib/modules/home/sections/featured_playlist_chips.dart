import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// The row of round "Featured Playlist" chips shown under the home carousel,
/// matching the reference design: a colored circle with a white glyph inside
/// and the name underneath. Tapping a chip plays that chip's tracks.
///
/// The glyphs are drawn with a [CustomPainter] rather than pulled from an icon
/// font. The design uses devotional symbols (a temple gopuram, a flute, a
/// lotus, an Om) that no bundled icon set provides, and drawing them means the
/// row renders identically offline with no extra asset weight. An unknown
/// `icon` name falls back to a music glyph, so an admin typo can never produce
/// an empty circle.
class FeaturedPlaylistChips extends HookConsumerWidget {
  const FeaturedPlaylistChips({super.key});

  /// Diameter of the colored circle.
  static const double chipDiameter = 62;

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    // The provider is a FutureProvider: an unresolved or failed load yields no
    // chips, which renders nothing rather than blocking the whole home screen.
    final chips = ref.watch(featuredPlaylistsProvider).valueOrNull ?? const [];

    // Nothing to show until the catalogue resolves, or when no chip matched.
    if (chips.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: 10 * scale, bottom: 4 * scale),
        child: SizedBox(
          height: (chipDiameter + 30) * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            itemCount: chips.length,
            separatorBuilder: (_, __) => Gap(14 * scale),
            itemBuilder: (context, index) {
              final chip = chips[index];
              return _FeaturedChip(
                chip: chip,
                onTap: () async {
                  await ref.read(audioPlayerProvider.notifier).load(
                        chip.tracks,
                        initialIndex: 0,
                        autoPlay: true,
                      );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One round chip: the gradient circle with its glyph, and the name below.
class _FeaturedChip extends StatelessWidget {
  final FeaturedPlaylist chip;
  final VoidCallback onTap;

  const _FeaturedChip({required this.chip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final diameter = FeaturedPlaylistChips.chipDiameter * scale;

    // A chip with no configured colors uses the theme primary for both stops,
    // which renders as a flat circle in the app's own accent color.
    final from = chip.colorFromOr(theme.colorScheme.primary);
    final to = chip.colorToOr(theme.colorScheme.primary);

    // White glyphs read on the design's saturated chips. When an admin picks a
    // pale gradient that would hide white, fall back to a dark glyph — the same
    // WCAG-ratio approach the card colors use, so the choice is measured rather
    // than assumed.
    final glyphColor = _contrastRatio(from, Colors.white) >= 2.2
        ? Colors.white
        : const Color(0xDD000000);

    return Semantics(
      button: true,
      label: 'Play ${chip.title}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: diameter + 12 * scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: diameter,
                width: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [from, to],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: to.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: Size(diameter * 0.5, diameter * 0.5),
                    painter: _GlyphPainter(
                      name: chip.icon ?? '',
                      color: glyphColor,
                    ),
                  ),
                ),
              ),
              Gap(6 * scale),
              Text(
                chip.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.typography.xSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WCAG relative luminance of [c].
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colors (1..21).
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Draws the devotional glyph for a chip inside a normalized 0..1 box.
///
/// Every glyph is stroke-based line art so a single painter covers all of them
/// and each stays crisp at any size. Unknown names draw the fallback music
/// note, which is also what an admin typo lands on.
class _GlyphPainter extends CustomPainter {
  final String name;
  final Color color;

  const _GlyphPainter({required this.name, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Work in a unit square so each glyph is authored in easy coordinates.
    final s = size.width;
    switch (name) {
      case 'temple':
        _temple(canvas, s, paint);
        break;
      case 'flute':
        _flute(canvas, s, paint);
        break;
      case 'ganesha':
        _ganesha(canvas, s, paint);
        break;
      case 'bow':
        _bow(canvas, s, paint);
        break;
      case 'lotus':
        _lotus(canvas, s, paint);
        break;
      case 'om':
        _om(canvas, s, paint);
        break;
      default:
        _musicNote(canvas, s, paint);
    }
  }

  /// A gopuram: a tiered temple tower on a base.
  void _temple(Canvas canvas, double s, Paint p) {
    final path = Path();
    // Base plinth.
    path.moveTo(s * 0.10, s * 0.92);
    path.lineTo(s * 0.90, s * 0.92);
    // Left side, stepping up to the spire.
    path.moveTo(s * 0.10, s * 0.92);
    path.lineTo(s * 0.16, s * 0.70);
    path.lineTo(s * 0.26, s * 0.70);
    path.lineTo(s * 0.30, s * 0.50);
    path.lineTo(s * 0.38, s * 0.50);
    path.lineTo(s * 0.41, s * 0.30);
    path.lineTo(s * 0.50, s * 0.30);
    // Right side, mirrored.
    path.moveTo(s * 0.90, s * 0.92);
    path.lineTo(s * 0.84, s * 0.70);
    path.lineTo(s * 0.74, s * 0.70);
    path.lineTo(s * 0.70, s * 0.50);
    path.lineTo(s * 0.62, s * 0.50);
    path.lineTo(s * 0.59, s * 0.30);
    path.lineTo(s * 0.50, s * 0.30);
    // Spire.
    path.moveTo(s * 0.50, s * 0.30);
    path.lineTo(s * 0.50, s * 0.10);
    // Doorway.
    path.moveTo(s * 0.42, s * 0.92);
    path.lineTo(s * 0.42, s * 0.78);
    path.lineTo(s * 0.58, s * 0.78);
    path.lineTo(s * 0.58, s * 0.92);
    canvas.drawPath(path, p);
  }

  /// Krishna's bansuri: a diagonal flute with a peacock feather.
  void _flute(Canvas canvas, double s, Paint p) {
    // Flute body.
    final flute = Path()
      ..moveTo(s * 0.16, s * 0.80)
      ..lineTo(s * 0.84, s * 0.28);
    canvas.drawPath(flute, p);

    // Two finger holes.
    canvas.drawCircle(Offset(s * 0.44, s * 0.60), s * 0.045, p);
    canvas.drawCircle(Offset(s * 0.60, s * 0.48), s * 0.045, p);

    // Peacock feather eye at the top end.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.80, s * 0.20),
        width: s * 0.26,
        height: s * 0.34,
      ),
      p,
    );
    canvas.drawCircle(Offset(s * 0.80, s * 0.20), s * 0.055, p);
  }

  /// A Ganesha head: ears, trunk and crown, read as a silhouette.
  void _ganesha(Canvas canvas, double s, Paint p) {
    // Head.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.42),
        width: s * 0.44,
        height: s * 0.46,
      ),
      p,
    );
    // Left ear, right ear.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.20, s * 0.42),
        width: s * 0.26,
        height: s * 0.40,
      ),
      -math.pi / 2,
      math.pi,
      false,
      p,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.80, s * 0.42),
        width: s * 0.26,
        height: s * 0.40,
      ),
      math.pi / 2,
      math.pi,
      false,
      p,
    );
    // Trunk curling to the left.
    final trunk = Path()
      ..moveTo(s * 0.50, s * 0.58)
      ..cubicTo(s * 0.50, s * 0.80, s * 0.34, s * 0.86, s * 0.34, s * 0.70);
    canvas.drawPath(trunk, p);
    // Crown.
    final crown = Path()
      ..moveTo(s * 0.34, s * 0.24)
      ..lineTo(s * 0.50, s * 0.06)
      ..lineTo(s * 0.66, s * 0.24);
    canvas.drawPath(crown, p);
  }

  /// Rama's bow with an arrow.
  void _bow(Canvas canvas, double s, Paint p) {
    // Bow arc.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.38, s * 0.50),
        width: s * 0.60,
        height: s * 0.92,
      ),
      -math.pi / 2,
      math.pi,
      false,
      p,
    );
    // Bowstring.
    final string = Path()
      ..moveTo(s * 0.38, s * 0.04)
      ..lineTo(s * 0.38, s * 0.96);
    canvas.drawPath(string, p);
    // Arrow shaft with a head and fletching.
    final arrow = Path()
      ..moveTo(s * 0.10, s * 0.74)
      ..lineTo(s * 0.88, s * 0.26);
    canvas.drawPath(arrow, p);
    final head = Path()
      ..moveTo(s * 0.88, s * 0.26)
      ..lineTo(s * 0.70, s * 0.26)
      ..moveTo(s * 0.88, s * 0.26)
      ..lineTo(s * 0.84, s * 0.44);
    canvas.drawPath(head, p);
  }

  /// A lotus: Devi's flower.
  void _lotus(Canvas canvas, double s, Paint p) {
    // Centre petal.
    final centre = Path()
      ..moveTo(s * 0.50, s * 0.18)
      ..cubicTo(s * 0.66, s * 0.40, s * 0.66, s * 0.62, s * 0.50, s * 0.78)
      ..cubicTo(s * 0.34, s * 0.62, s * 0.34, s * 0.40, s * 0.50, s * 0.18);
    canvas.drawPath(centre, p);

    // Side petals.
    for (final sign in [-1.0, 1.0]) {
      final petal = Path()
        ..moveTo(s * 0.50, s * 0.62)
        ..cubicTo(
          s * (0.50 + 0.44 * sign),
          s * 0.42,
          s * (0.50 + 0.40 * sign),
          s * 0.66,
          s * 0.50,
          s * 0.80,
        );
      canvas.drawPath(petal, p);
    }

    // Base line.
    final base = Path()
      ..moveTo(s * 0.16, s * 0.84)
      ..lineTo(s * 0.84, s * 0.84);
    canvas.drawPath(base, p);
  }

  /// The Om symbol, drawn as a stylised glyph.
  void _om(Canvas canvas, double s, Paint p) {
    // The lower loop.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.42, s * 0.62),
        width: s * 0.62,
        height: s * 0.50,
      ),
      0,
      math.pi * 1.55,
      false,
      p,
    );
    // The upper curve.
    final upper = Path()
      ..moveTo(s * 0.16, s * 0.40)
      ..cubicTo(s * 0.34, s * 0.18, s * 0.62, s * 0.20, s * 0.60, s * 0.40);
    canvas.drawPath(upper, p);
    // The tail sweeping right.
    final tail = Path()
      ..moveTo(s * 0.66, s * 0.50)
      ..cubicTo(s * 0.80, s * 0.60, s * 0.70, s * 0.80, s * 0.56, s * 0.80);
    canvas.drawPath(tail, p);
    // The dot.
    canvas.drawCircle(Offset(s * 0.82, s * 0.22), s * 0.07, p);
  }

  /// Fallback glyph: a quaver, used for an unknown `icon` name.
  void _musicNote(Canvas canvas, double s, Paint p) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.34, s * 0.76),
        width: s * 0.34,
        height: s * 0.26,
      ),
      p,
    );
    final stem = Path()
      ..moveTo(s * 0.50, s * 0.76)
      ..lineTo(s * 0.50, s * 0.18)
      ..lineTo(s * 0.82, s * 0.30);
    canvas.drawPath(stem, p);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.name != name || old.color != color;
}
