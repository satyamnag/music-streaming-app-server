import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The border effect every album/track card wears.
///
/// ## Why this file exists
/// The border is ONE decision — how thick, in what colours, at what angle — and
/// it is worn by every card. Keeping the decision in a pure function means the
/// cards cannot drift apart, and means the numbers can be asserted in a plain
/// unit test instead of only being visible on a device.
///
/// ## The one hard rule: the border must not touch the layout
/// Every card height, every grid tile extent and every horizontal row height is
/// derived by `HomeSectionLayout` from arithmetic that assumes the card occupies
/// exactly the box it was handed. A border that moved the card's content by even
/// one logical pixel would shift the play control off the text block it is
/// pinned to, on every screen at once.
///
/// A border on a `BoxDecoration` DOES move the content: Flutter's `Container`
/// inflates its child padding by any border in the decoration, which insets the
/// child by the border width on every side. So the outline is applied as the
/// card's `foregroundDecoration` instead, which is painted over the child and
/// contributes no layout padding at all. See [outline] for the full account —
/// this was found by a failing regression test, not by reading the docs first.
///
/// The glow below is deliberately a *box shadow drawn with zero offset and zero
/// spread*, not an outset stroke. A shadow is painted by the decoration inside
/// the widget's own paint bounds and is clipped by the card's own
/// `Clip.antiAlias`, so it cannot bleed into the 6dp gutter and land on the
/// neighbouring card either.
///
/// ## The colours
/// Taken from the theme's own palette rather than invented: the app's `accent`
/// (the gold of the logo) and `primary` (the deep maroon). Both light and dark
/// schemes define them, so the border is correct in either mode without a
/// branch here.
///
/// The gradient runs top-left to bottom-right. On a card whose cover sits at the
/// top, that reads as light catching the top-left corner and the maroon
/// grounding the bottom-right, which is the direction the app's own artwork
/// already shades in.
class CardBorder {
  const CardBorder._();

  /// Thickness of the outline at scale == 1, in logical pixels.
  ///
  /// 1.5dp, and it was 1dp. Raised after a device check: this phone reports
  /// `density 320` (2 physical pixels per logical pixel), so a 1dp stroke is a
  /// 2px line on a 125dp card — and against dark, detailed album artwork even a
  /// correctly-coloured 2px line reads as a faint edge rather than a border. At
  /// 1.5dp the stroke is 3px, which is the thinnest line that still reads as a
  /// deliberate rim at this density while staying far short of a picture frame
  /// on a 125dp card.
  static const double width = 1.5;

  /// Opacity of the soft inner halo at scale == 1.
  ///
  /// Deliberately low. The halo's job is to lift the card off the page — which
  /// matters most in LIGHT mode, where the card and the background are both pure
  /// white and the cards currently have no separation at all — not to announce
  /// itself.
  static const double haloOpacity = 0.22;

  /// Width of that inner halo at scale == 1, in logical pixels.
  ///
  /// Two pixels, sitting immediately inside the outline stroke.
  static const double haloWidth = 2;

  // ---------------------------------------------------------------------------
  // Why there is no outer glow, and why the halo is drawn INSIDE the card.
  //
  // The first version of this file painted the glow the obvious way: a
  // `BoxShadow` on the card's `BoxDecoration`, with a blur radius, expecting a
  // soft halo to spill past the card's edge.
  //
  // It rendered NOTHING. A probe that measured the actual pixels in a band just
  // outside the card returned a total brightness of exactly 0 — with the card's
  // `Clip.antiAlias`, and again with `Clip.none`, so this was not the clip
  // either. The shadow never reached the screen at all.
  //
  // That is the worst kind of failure: the code reads as a working glow, a
  // configuration-level test asserting `boxShadow != null` passes, and the
  // feature is invisible on the device. So the shadow is gone, and the luminous
  // edge is instead painted as an INSET gradient stroke, inside the card's own
  // bounds, where paint is verifiable and cannot be clipped away.
  //
  // The lesson is recorded here rather than in a commit message because the next
  // person to want a glow on these cards will otherwise reach for `BoxShadow`
  // again and hit exactly the same silent nothing.
  // ---------------------------------------------------------------------------

  /// The gold-to-maroon outline gradient for [context]'s theme.
  ///
  /// This is what strokes the card's edge. Both stops come from the theme, so a
  /// theme change moves the border with it rather than leaving a hard-coded
  /// colour behind.
  ///
  /// ## This gradient is NOT used for the outline stroke
  /// It is kept because it is the card's FILL gradient (see [decoration]), where
  /// a wide gold-to-maroon wash reads as intended. It must never stroke the rim —
  /// see [rimColors] for the measurement that rules it out.
  static Gradient gradient(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[scheme.accent, scheme.primary],
    );
  }

  /// The two colours the rim stroke interpolates between, light to dark.
  ///
  /// ## Why the rim is GOLD, not the gold-to-maroon fill gradient
  /// The first version stroked the rim with [gradient] — the same gold→maroon
  /// ramp the card's box is filled with. On a device it was INVISIBLE over
  /// 95% of the rim, and the pixels say exactly why:
  ///
  ///   * the ramp's dark end is `primary` = `#520101` (RGB 82,1,1), which is
  ///     near-identical to the dark album artwork sitting against it. On the
  ///     phone the card's left edge went `(255,255,255)` → `(34,4,2)` and its
  ///     bottom edge `(72,5,0)` → `(255,255,255)`: page to artwork with no rim
  ///     line in between;
  ///   * a pixel probe of the rendered card found accent-gold pixels confined to
  ///     rows 0..19 of a ~634px-tall raster — the top-left corner only. The rest
  ///     of the stroke was maroon on maroon.
  ///
  /// A rim's whole job is to separate the card from what is behind it, so its
  /// colour must contrast with BOTH the page and the artwork. Gold does; the
  /// theme's maroon does not, because the app's own cover art is shaded in the
  /// same maroon.
  ///
  /// So the stroke stays inside one hue and varies only its LIGHTNESS: a lighter
  /// gold at the top-left falling to a deeper gold at the bottom-right. That
  /// keeps the top-left-to-bottom-right shading the fill gradient establishes,
  /// while keeping every point on the rim a gold that reads against dark
  /// artwork. Both ends are derived from `scheme.accent`, so a theme change moves
  /// the rim with it and neither end is a hard-coded colour.
  ///
  /// The lightness shift is a fixed factor rather than a second theme colour so
  /// it cannot collapse to the background in either light or dark mode.
  static List<Color> rimColors(BuildContext context) {
    final accent = Theme.of(context).colorScheme.accent;
    final hsl = HSLColor.fromColor(accent);
    // Deepen toward the bottom-right by lightness only, clamped so the dark end
    // can never approach black (which would reintroduce the invisibility above).
    final deep = hsl.withLightness((hsl.lightness * 0.72).clamp(0.30, 1.0));
    return <Color>[accent, deep.toColor()];
  }

  /// The card's background box: the theme fill and the themed gradient.
  ///
  /// [background] is the card's resolved fill colour (the admin-configured
  /// colour when set, otherwise the theme card colour), and [radius] is the same
  /// corner radius the card already used — passed in rather than recomputed so
  /// the decoration cannot round its corners differently from the box that clips
  /// the cover.
  ///
  /// The gradient is applied only when the card is NOT using an
  /// admin-configured background. An admin colour is an explicit instruction
  /// about what that card's box should look like, and overpainting it with a
  /// gradient would silently ignore the setting the admin panel exists to
  /// provide.
  ///
  /// This decoration deliberately carries NO border — see [outline] for why the
  /// outline is a separate, foreground decoration.
  static BoxDecoration decoration({
    required BuildContext context,
    required Color background,
    required double radius,
    bool usesConfiguredBackground = false,
  }) {
    return BoxDecoration(
      color: background,
      gradient: usesConfiguredBackground ? null : gradient(context),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// The card's OUTLINE stroke and inner halo, painted over the card's content.
  ///
  /// Returned as a widget and placed as the LAST child of the card's `Stack`, so
  /// it draws over the cover and the text.
  ///
  /// ## Why the outline is a foreground decoration and not a `decoration` border
  /// This is the most important decision in the file, and it was found by a
  /// failing test rather than by reasoning alone.
  ///
  /// A `BoxDecoration`'s border is not free: Flutter documents that a `Container`
  /// "surrounds the child with padding (inflated by any borders present in the
  /// decoration)", and that `BoxDecoration` reports those insets through
  /// `Decoration.padding`. So a border on `decoration` INSETS THE CHILD by the
  /// border width on every side. The card's outer height stayed correct — which
  /// is what the first design predicted and tested — but the CONTENT inside it
  /// was squeezed 1dp inward, and the play control, which is pinned flush to the
  /// text block's bottom edge, moved up by exactly the border width.
  ///
  /// `foregroundDecoration` is painted over the child and contributes NO layout
  /// padding, so the border cannot move a single child pixel, by construction
  /// rather than by compensating arithmetic.
  ///
  /// It is also drawn over the cover rather than under it, which is what makes it
  /// visible at all: the cover bleeds to the card's edges, so an outline painted
  /// underneath would be completely hidden behind it.
  ///
  /// ## Why a CustomPainter
  /// A `BoxDecoration` can either FILL with a gradient or STROKE a single colour
  /// through `Border.all`; `BorderSide` takes one `Color`, so a gradient edge
  /// cannot be expressed as a `BoxDecoration` at all. Three constructions were
  /// tried and only this one works:
  ///
  ///   1. `boxShadow` glow — measured as painting ZERO pixels. Invisible.
  ///   2. Border on `decoration` — insets the child, moving the play control.
  ///   3. Two stacked rounded rectangles (outer gradient, inner fill) — the inner
  ///      shapes had no child and therefore no size, so they collapsed and the
  ///      gradient painted across the WHOLE card instead of as a rim. Measured
  ///      with a pixel probe: gradient values spanned the full card width.
  ///
  /// A `CustomPainter` strokes the path directly with a gradient shader. There is
  /// no occluding shape to collapse and no layout interaction at all — the
  /// painter only draws, so it cannot move the card's content by construction.
  static Widget outline({
    required BuildContext context,
    required double radius,
  }) {
    final scale = Theme.of(context).scaling;
    // The rim varies in LIGHTNESS only, never in hue — see [rimColors] for the
    // device measurement that rules the gold-to-maroon fill ramp out here.
    final rim = rimColors(context);

    // ## Why this is a Positioned.fill, and not a bare Stack child
    // This is THE defect that made the outline invisible on the device, and it
    // is subtle because every unit test still passed.
    //
    // The card is a `Stack` whose FIRST child is the content `Column`. A `Stack`
    // with the default `StackFit.loose` sizes itself from its largest
    // non-positioned child, and lays out every other non-positioned child with
    // LOOSE constraints. A `CustomPaint` with no `child` and no explicit `size`
    // has no intrinsic size, so under loose constraints it collapses to 0x0 —
    // and `_CardOutlinePainter.paint` is then handed `Size.zero`, where
    // `outer.isEmpty` is true and it returns immediately having drawn NOTHING.
    //
    // Measured on this very card: the outline's `CustomPaint` reported
    // `Rect.fromLTRB(0.0, 0.0, 0.0, 0.0)` while the card was
    // `Rect.fromLTRB(0.0, 0.0, 110.0, 172.3)`. The painter was correct and was
    // simply never given a rectangle to draw into.
    //
    // `Positioned.fill` is the fix: it forces the child to the Stack's full size
    // (tight constraints), so the painter always receives the card's real rect.
    // It contributes no layout padding and cannot move the card's content, so
    // the geometry contract in this file's header still holds.
    //
    // The old unit tests could not catch this: they asserted that a painter
    // EXISTS and that the Stack's last child is a widget, both of which were true
    // of a zero-sized, painting-nothing CustomPaint. The gold-pixel probe in
    // `test/track_card_border_visibility_probe_test.dart` is what catches it, by
    // measuring paint instead of configuration.
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _CardOutlinePainter(
            radius: radius,
            stroke: width * scale,
            haloWidth: haloWidth * scale,
            haloOpacity: haloOpacity,
            // The rim is handed over as its two stops rather than as a
            // `Gradient` object, because the painter needs a `Shader` sized to
            // the card's own rect, which only exists at paint time.
            from: rim.first,
            to: rim.last,
          ),
        ),
      ),
    );
  }
}

/// Strokes the card's rounded-rectangle edge with a gradient, plus a soft gold
/// halo just inside it.
///
/// Drawn in `paint` only; it reports no size, so it never affects layout.
class _CardOutlinePainter extends CustomPainter {
  final double radius;
  final double stroke;
  final double haloWidth;
  final double haloOpacity;
  final Color from;
  final Color to;

  const _CardOutlinePainter({
    required this.radius,
    required this.stroke,
    required this.haloWidth,
    required this.haloOpacity,
    required this.from,
    required this.to,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The stroke is drawn centred on the path, so the path is inset by half the
    // stroke to keep the whole line inside the card's bounds. Drawing it outside
    // would be clipped by the card's own `Clip.antiAlias` and half the line
    // would vanish.
    final inset = stroke / 2;
    final outer = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(inset);
    if (outer.isEmpty) return;

    final outerRRect = RRect.fromRectAndRadius(
      outer,
      Radius.circular(math.max(0, radius - inset)),
    );

    // 1. The gradient stroke, following the card's own corner radius.
    //
    //    Drawn at FULL opacity: this is the rim the card is identified by, and
    //    the earlier failure was precisely that it did not read against dark
    //    artwork. Both stops are gold (see [rimColors]), so the stroke stays
    //    visible all the way round rather than fading into the cover.
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        // Antialiasing matters here: the line is only `stroke` wide against a
        // rounded corner, and an aliased edge on a curve reads as a chipped rim.
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[from, to],
        ).createShader(outer),
    );

    // 2. The halo: a faint gold line immediately inside the stroke, which is what
    //    softens the edge into the card. Drawn only when it has a positive width,
    //    since a zero-width stroke with a visible colour would paint a hairline
    //    at the wrong radius.
    //
    //    [from] is the rim's LIGHT gold end (see [CardBorder.rimColors]), so the
    //    halo always picks up the brighter of the two rim colours regardless of
    //    where on the card it sits — a halo tinted with the darker end would
    //    disappear against dark artwork, which is the exact failure this whole
    //    file exists to avoid.
    if (haloWidth <= 0) return;
    final haloInset = inset + stroke / 2 + haloWidth / 2;
    final haloRect =
        Rect.fromLTWH(0, 0, size.width, size.height).deflate(haloInset);
    if (haloRect.isEmpty) return;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        haloRect,
        Radius.circular(math.max(0, radius - haloInset)),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = haloWidth
        ..isAntiAlias = true
        ..color = from.withValues(alpha: haloOpacity),
    );
  }

  /// Repaints only when an input actually changes, so a rebuild that changes
  /// nothing does not force a repaint of every card on screen.
  @override
  bool shouldRepaint(_CardOutlinePainter old) {
    return old.radius != radius ||
        old.stroke != stroke ||
        old.haloWidth != haloWidth ||
        old.haloOpacity != haloOpacity ||
        old.from != from ||
        old.to != to;
  }
}
