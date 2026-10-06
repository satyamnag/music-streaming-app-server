import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';

/// The row of round "Featured Playlist" chips shown under the home carousel,
/// matching the reference design: a colored circle with the admin's icon inside
/// and the name underneath. Tapping a chip opens that deity's playlist screen —
/// its tracks in the same cards the home shelves use — instead of starting
/// playback immediately; playing is one tap further, on a card.
///
/// Every chip is admin-defined. Its icon is the image the admin uploaded
/// (`icon_url`); if there is none, or it fails to load, the chip falls back to
/// one of the glyphs the painter below knows. The glyphs are drawn with a
/// [CustomPainter] rather than pulled from an icon font, because the design uses
/// devotional symbols (a temple gopuram, a flute, a lotus, an Om, a trishul, a
/// conch, a diya, a bell) that no bundled icon set provides — and drawing them
/// means the row renders identically offline with no extra asset weight. An
/// unknown `icon` name falls back to a music glyph, so the circle is never
/// empty.
class FeaturedPlaylistChips extends HookConsumerWidget {
  const FeaturedPlaylistChips({super.key});

  /// Diameter of the colored circle.
  ///
  /// Sized so six chips fit a 360dp phone screen with the name underneath,
  /// matching the reference design's row (which shows six). A larger circle
  /// pushed the row to four visible chips and made the row feel oversized next
  /// to the album cards below it.
  static const double chipDiameter = 52;

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
        padding: EdgeInsets.only(top: 2 * scale, bottom: 4 * scale),
        child: SizedBox(
          height: (chipDiameter + 30) * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            itemCount: chips.length,
            separatorBuilder: (_, __) => Gap(10 * scale),
            itemBuilder: (context, index) {
              final chip = chips[index];
              return _FeaturedChip(
                chip: chip,
                onTap: () {
                  // A chip is the door to that deity's playlist: tapping it
                  // opens the full-screen playlist (its tracks rendered with
                  // the same cards the home shelves use) rather than starting
                  // playback on the spot.
                  context.navigateTo(
                    FeaturedPlaylistRoute(id: chip.id),
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
      label: 'Open ${chip.title} playlist',
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
                  child: _circleArtwork(diameter, glyphColor),
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

  /// The circle's inner artwork.
  ///
  /// An admin-uploaded [FeaturedPlaylist.iconUrl] is drawn instead of the glyph,
  /// so the admin can put any devotional image on a chip. The image is clipped
  /// to the circle (the same circle the admin previews) and a load failure —
  /// offline, or the object since deleted — falls back to the glyph rather than
  /// the shared placeholder, so the chip keeps its meaning instead of turning
  /// into a generic image box.
  Widget _circleArtwork(double diameter, Color glyphColor) {
    final url = chip.iconUrl?.trim() ?? '';
    if (url.isEmpty) return _glyph(diameter, glyphColor);

    return ClipOval(
      child: Image(
        image: CachedNetworkImageProvider(url, cacheKey: url),
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _glyph(diameter, glyphColor),
      ),
    );
  }

  /// The painted devotional glyph, used directly or as the icon's fallback.
  Widget _glyph(double diameter, Color glyphColor) => CustomPaint(
        size: Size(diameter * 0.5, diameter * 0.5),
        painter: FeaturedChipGlyphPainter(
          name: chip.icon ?? '',
          color: glyphColor,
        ),
      );
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
///
/// This is the FALLBACK vocabulary, not a menu: an icon is now an image the
/// admin uploads in the panel (`featured_playlists.icon_url`), and the glyph is
/// only drawn when a playlist has no uploaded icon or that icon fails to load.
/// The admin panel deliberately offers no glyph picker, so this set exists to
/// keep the already-stored `icon` values working — including the glyphs the
/// migration seeded onto the six original playlists.
///
/// Public (not private) so the glyph sheet can be rendered to an image in a
/// test and actually looked at, rather than only asserted not to throw.
class FeaturedChipGlyphPainter extends CustomPainter {
  final String name;
  final Color color;

  const FeaturedChipGlyphPainter({required this.name, required this.color});

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
      case 'trishul':
        _trishul(canvas, s, paint);
        break;
      case 'conch':
        _conch(canvas, s, paint);
        break;
      case 'diya':
        _diya(canvas, s, paint);
        break;
      case 'bell':
        _bell(canvas, s, paint);
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

  /// Krishna's bansuri: a long diagonal flute with a peacock-feather eye.
  ///
  /// The first attempt drew a short shaft with a large oval at the end, which
  /// read as a lollipop/magnifying glass at chip size. The flute is now a long
  /// shaft across the full box with the feather as a small teardrop, so the
  /// two parts stay distinct.
  void _flute(Canvas canvas, double s, Paint p) {
    // Flute shaft: a long diagonal across the box.
    final flute = Path()
      ..moveTo(s * 0.08, s * 0.86)
      ..lineTo(s * 0.80, s * 0.34);
    canvas.drawPath(flute, p);

    // Finger holes along the shaft.
    canvas.drawCircle(Offset(s * 0.36, s * 0.66), s * 0.04, p);
    canvas.drawCircle(Offset(s * 0.54, s * 0.54), s * 0.04, p);

    // Peacock-feather eye: a small teardrop at the top end, plus a short stem
    // linking it to the shaft so it reads as a feather rather than a ball.
    final feather = Path()
      ..moveTo(s * 0.80, s * 0.34)
      ..cubicTo(s * 0.84, s * 0.16, s * 0.96, s * 0.14, s * 0.94, s * 0.28)
      ..cubicTo(s * 0.92, s * 0.40, s * 0.86, s * 0.40, s * 0.80, s * 0.34);
    canvas.drawPath(feather, p);
    canvas.drawCircle(Offset(s * 0.89, s * 0.26), s * 0.035, p);
  }

  /// A Ganesha head, built around the two features that make an elephant
  /// readable at a glance: the big side ears and the curling trunk.
  ///
  /// Earlier attempts (a face oval with overlapping arcs, then a dome with a
  /// separate crown triangle) both read as abstract shapes. Here the ears are
  /// wide open curves that clearly flank the head, and the trunk is a thick
  /// hanging curl - so the silhouette says "elephant" even without the crown.
  void _ganesha(Canvas canvas, double s, Paint p) {
    // Head: a rounded dome, sized to leave room for the ears on both sides.
    final head = Path()
      ..moveTo(s * 0.34, s * 0.56)
      ..cubicTo(s * 0.34, s * 0.26, s * 0.66, s * 0.26, s * 0.66, s * 0.56);
    canvas.drawPath(head, p);

    // Ears: wide open curves flanking the head - the strongest elephant cue.
    for (final sign in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(s * 0.50 + s * 0.16 * sign, s * 0.34)
        ..cubicTo(
          s * (0.50 + 0.48 * sign),
          s * 0.34,
          s * (0.50 + 0.48 * sign),
          s * 0.68,
          s * 0.50 + s * 0.16 * sign,
          s * 0.62,
        );
      canvas.drawPath(ear, p);
    }

    // Trunk: hangs from the head and curls left, clearly separate from the ears.
    final trunk = Path()
      ..moveTo(s * 0.50, s * 0.54)
      ..cubicTo(s * 0.46, s * 0.76, s * 0.34, s * 0.92, s * 0.24, s * 0.80);
    canvas.drawPath(trunk, p);

    // Crown: a small pointed tier on top, the last Ganesha-specific cue.
    final crown = Path()
      ..moveTo(s * 0.40, s * 0.30)
      ..lineTo(s * 0.50, s * 0.10)
      ..lineTo(s * 0.60, s * 0.30);
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

  /// The Om symbol (ॐ), drawn as thick strokes in the symbol's real form.
  ///
  /// Two earlier attempts failed for opposite reasons: thin arcs came out as an
  /// unreadable squiggle, and a single filled outline came out as a solid blob.
  /// The form that reads is the middle path - a heavy stroke weight (roughly
  /// double the other glyphs') tracing the recognised parts: the big lower
  /// bowl, the hood curving over it, the crescent and tail to the right, and
  /// the bindu dot.
  void _om(Canvas canvas, double s, Paint p) {
    // Heavier than the shared stroke: Om's calligraphic weight is what makes it
    // recognisable, and a hairline loses the shape entirely at chip size.
    final heavy = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Lower bowl: a big open circle occupying the left two-thirds.
    canvas.drawArc(
      Rect.fromLTRB(s * 0.10, s * 0.40, s * 0.66, s * 0.94),
      math.pi * 0.50,
      math.pi * 1.45,
      false,
      heavy,
    );

    // Hood: sweeps from the left, over the top, hooking down to the right.
    final hood = Path()
      ..moveTo(s * 0.16, s * 0.44)
      ..cubicTo(s * 0.24, s * 0.14, s * 0.62, s * 0.16, s * 0.58, s * 0.42);
    canvas.drawPath(hood, heavy);

    // Crescent: opens to the left, sitting above the bowl's right shoulder.
    final crescent = Path()
      ..moveTo(s * 0.62, s * 0.50)
      ..cubicTo(s * 0.82, s * 0.44, s * 0.86, s * 0.62, s * 0.70, s * 0.62);
    canvas.drawPath(crescent, heavy);

    // Tail: drops from the crescent and flicks left under it.
    final tail = Path()
      ..moveTo(s * 0.70, s * 0.62)
      ..cubicTo(s * 0.72, s * 0.78, s * 0.54, s * 0.80, s * 0.50, s * 0.68);
    canvas.drawPath(tail, heavy);

    // Bindu: the dot above the crescent.
    canvas.drawCircle(Offset(s * 0.70, s * 0.18), s * 0.075, heavy);
  }

  /// Shiva's trishul: three prongs on a shaft, rising from a crossbar.
  void _trishul(Canvas canvas, double s, Paint p) {
    // Shaft. Stops at 0.92 like the temple's plinth: the round cap adds half a
    // stroke width past the end point, and 0.98 would clip at the box edge.
    final shaft = Path()
      ..moveTo(s * 0.50, s * 0.92)
      ..lineTo(s * 0.50, s * 0.26);
    canvas.drawPath(shaft, p);

    // Crossbar the prongs rise from.
    final bar = Path()
      ..moveTo(s * 0.24, s * 0.62)
      ..lineTo(s * 0.76, s * 0.62);
    canvas.drawPath(bar, p);

    // Centre prong: a spearhead.
    final centre = Path()
      ..moveTo(s * 0.42, s * 0.26)
      ..lineTo(s * 0.50, s * 0.05)
      ..lineTo(s * 0.58, s * 0.26);
    canvas.drawPath(centre, p);

    // Outer prongs: they bow outward, then hook inward at the top - the shape
    // that separates a trishul from a plain three-tined fork.
    for (final sign in [-1.0, 1.0]) {
      final prong = Path()
        ..moveTo(s * (0.50 + 0.26 * sign), s * 0.62)
        ..cubicTo(
          s * (0.50 + 0.31 * sign),
          s * 0.44,
          s * (0.50 + 0.31 * sign),
          s * 0.28,
          s * (0.50 + 0.19 * sign),
          s * 0.20,
        );
      canvas.drawPath(prong, p);
    }
  }

  /// Vishnu's shankha: a conch whose whorl is what makes it readable.
  void _conch(Canvas canvas, double s, Paint p) {
    // Body: a bulb at the top tapering into the tail at the lower left.
    final body = Path()
      ..moveTo(s * 0.46, s * 0.14)
      ..cubicTo(s * 0.80, s * 0.16, s * 0.86, s * 0.52, s * 0.62, s * 0.68)
      ..cubicTo(s * 0.46, s * 0.78, s * 0.32, s * 0.84, s * 0.20, s * 0.90)
      ..cubicTo(s * 0.22, s * 0.66, s * 0.26, s * 0.30, s * 0.46, s * 0.14);
    canvas.drawPath(body, p);

    // The whorl: an open spiral in the middle of the bulb.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.44),
        width: s * 0.34,
        height: s * 0.34,
      ),
      -math.pi * 0.20,
      math.pi * 1.55,
      false,
      p,
    );

    // A second, tighter curl inside it, so the spiral reads as a spiral.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.44),
        width: s * 0.13,
        height: s * 0.13,
      ),
      math.pi * 0.30,
      math.pi * 1.30,
      false,
      p,
    );
  }

  /// A diya: the lamp cup with its flame, for aarti-style playlists.
  void _diya(Canvas canvas, double s, Paint p) {
    // Flame: a teardrop floating above the cup.
    final flame = Path()
      ..moveTo(s * 0.50, s * 0.06)
      ..cubicTo(s * 0.66, s * 0.22, s * 0.64, s * 0.36, s * 0.50, s * 0.42)
      ..cubicTo(s * 0.36, s * 0.36, s * 0.34, s * 0.22, s * 0.50, s * 0.06);
    canvas.drawPath(flame, p);

    // Rim: the lip the wick sits on.
    final rim = Path()
      ..moveTo(s * 0.10, s * 0.58)
      ..lineTo(s * 0.90, s * 0.58);
    canvas.drawPath(rim, p);

    // Cup: a shallow bowl under the rim.
    final cup = Path()
      ..moveTo(s * 0.14, s * 0.58)
      ..cubicTo(s * 0.22, s * 0.86, s * 0.78, s * 0.86, s * 0.86, s * 0.58);
    canvas.drawPath(cup, p);
  }

  /// A temple bell: dome, rim, crown loop and clapper.
  void _bell(Canvas canvas, double s, Paint p) {
    // Dome.
    final dome = Path()
      ..moveTo(s * 0.26, s * 0.72)
      ..cubicTo(s * 0.26, s * 0.30, s * 0.74, s * 0.30, s * 0.74, s * 0.72);
    canvas.drawPath(dome, p);

    // Rim.
    final rim = Path()
      ..moveTo(s * 0.16, s * 0.72)
      ..lineTo(s * 0.84, s * 0.72);
    canvas.drawPath(rim, p);

    // Crown loop: the handle the bell hangs from.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.24),
        width: s * 0.18,
        height: s * 0.18,
      ),
      math.pi,
      math.pi,
      false,
      p,
    );

    // Clapper, hanging below the rim.
    canvas.drawCircle(Offset(s * 0.50, s * 0.86), s * 0.075, p);
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
  bool shouldRepaint(covariant FeaturedChipGlyphPainter old) =>
      old.name != name || old.color != color;
}
