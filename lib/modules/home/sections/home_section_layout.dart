import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shared geometry for the home-screen horizontal card rows ("Recently
/// played", "Albums", "<Language> Songs", "Newest Arrivals", "Top Trending").
///
/// Every one of those rows renders the same card anatomy — artwork square,
/// title line and (optionally) a subtitle line inside a padded, rounded card —
/// inside a horizontal `ListView`. A horizontal `ListView` stretches its
/// children to the viewport's cross-axis extent, so a hard-coded row height
/// larger than the card content paints a dead empty band below every card.
/// This helper returns the exact height the cards need, measured from the same
/// typography they render with, so rows fit their cards perfectly at any theme
/// scale or font.
abstract final class HomeSectionLayout {
  /// Global size multiplier for every home/grid track+album card.
  ///
  /// 5/6 of the original 150px footprint, which is *exactly* a 125px square
  /// cover — raised from the 112.5px (0.75) the cards had been reduced to, so
  /// the artwork reads larger on the home rows and in the grids. 5/6 is exact
  /// in IEEE754 here, so `150 * cardScale` lands on 125.0 and not
  /// 125.00000000000001. Everything that defines the card — artwork, padding,
  /// internal gaps — is derived from [imageSize] and [cardPadding] through this
  /// factor, so the card geometry stays exact and self-consistent at any value.
  ///
  /// Raising it also raises `minCardWidth` in
  /// `components/track_card/track_card.dart`, which `trackGridCrossAxisCount`
  /// divides the screen width by — so the track grids (search, home see-all)
  /// fit fewer, larger columns. That is the intended consequence of bigger
  /// cards, not a side effect to chase: the 411–447dp phones move from 3
  /// columns to 2, and 540/720/840/960/1024dp each lose one column.
  static const double cardScale = 5 / 6;

  /// The square artwork width/height of every home card, in logical pixels at
  /// scale == 1 (cards multiply by `theme.scaling` themselves).
  ///
  /// This is the *nominal* inner width used to size horizontal rows; the
  /// card's artwork is fluid (see `TrackCard`) and always matches whatever
  /// width the card actually receives, so rows stay exact at any theme scale.
  static const double imageSize = 150 * cardScale;

  /// Horizontal/vertical padding inside each card, at scale == 1.
  static const double cardPadding = 10 * cardScale;

  /// Gap between the artwork and the title, at scale == 1.
  static const double imageTitleGap = 6;

  /// Gap between the cover (which now bleeds to the card's top/left/right
  /// edges) and the title text block below it, at scale == 1.
  static const double cardTextGap = imageTitleGap;

  /// Gap between the title and the subtitle, at scale == 1.
  static const double titleSubtitleGap = 2;

  /// Gap between cards inside a row, at scale == 1.
  static const double cardGap = 6;

  /// Total width of one card box, at scale == 1.
  ///
  /// The cover bleeds to the card's left and right edges, so the box width IS
  /// the cover width — the horizontal [cardPadding] applies only to the title
  /// block below the cover, never to the cover itself.
  static const double cardWidth = imageSize;

  /// Extra row height reserved for SKELETON rows only. The measured
  /// [rowHeight] is razor-exact against the loaded card, but Skeletonizer's
  /// bone glyphs render a couple of pixels taller under real (non-test) font
  /// metrics, which intermittently overflowed the tight row
  /// ("A RenderFlex overflowed by 4.0 pixels", track_section.dart card
  /// Column, observed on the emulator). Skeleton rows reserve this headroom;
  /// loaded rows stay exact.
  static const double skeletonHeadroom = 4;

  /// Measured height of one line rendered with [style].
  static double _lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.height;
  }

  /// Height of one home card whose square cover is [coverWidth] wide.
  ///
  /// The cover bleeds to the card's top/left/right edges, so the card height
  /// is the cover plus a padded text block underneath — there is no padding
  /// above the cover or beside it. [coverWidth] is therefore both the card's
  /// width and the cover's height.
  ///
  /// The text block is padded on ALL four sides (see `TrackCard`'s
  /// `EdgeInsets.fromLTRB`), so [cardPadding] is added twice: once as the gap
  /// between the cover and the title, and once as the bottom padding. Omitting
  /// the bottom padding made every card one [cardPadding] taller than the height
  /// computed here, which overflowed the card's own Column by exactly that much.
  static double _cardHeightFor(
    BuildContext context,
    double coverWidth, {
    required bool withSubtitle,
  }) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final titleLine = _lineHeight(
      theme.typography.small.copyWith(fontWeight: FontWeight.w600),
    );
    final subtitleLine =
        withSubtitle ? _lineHeight(theme.typography.xSmall) : 0.0;
    final subtitleGap = withSubtitle ? titleSubtitleGap : 0.0;
    return coverWidth +
        (cardTextGap * scale) +
        titleLine +
        (subtitleGap * scale) +
        subtitleLine +
        (cardPadding * scale);
  }

  /// The exact height a home card row needs so cards are never stretched
  /// taller than their content. Derived from the same geometry the cards
  /// render with, so the row stays perfectly tight regardless of fonts, theme
  /// scaling or platform text metrics.
  ///
  /// Horizontal rows give their cards a fixed [cardWidth]-wide box whose cover
  /// bleeds to the edges, so the cover is exactly [cardWidth] tall.
  ///
  /// [withSubtitle] must be false for the card variant that omits the
  /// subtitle line ("Recently played" cards, whose second line is empty).
  static double rowHeight(BuildContext context, {bool withSubtitle = true}) {
    final scale = Theme.of(context).scaling;
    return _cardHeightFor(
      context,
      cardWidth * scale,
      withSubtitle: withSubtitle,
    );
  }

  /// Exact tile height for a [TrackCard] grid whose tiles are [tileWidth] wide
  /// (in logical pixels, already scaled).
  ///
  /// The card's cover bleeds to the tile's full width, so the cover is exactly
  /// [tileWidth] tall and the tile height is derived from that.
  static double trackCardHeightFor(
    BuildContext context,
    double tileWidth, {
    bool withSubtitle = true,
  }) {
    return _cardHeightFor(
      context,
      tileWidth,
      withSubtitle: withSubtitle,
    );
  }

  /// Width of one tile in a [crossAxisCount]-column [TrackCard] grid that has
  /// [horizontalPadding] on each side and [gutter] between its columns.
  static double trackCardTileWidth(
    BuildContext context, {
    required int crossAxisCount,
    required double horizontalPadding,
    double gutter = cardGap,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final usable = width - (horizontalPadding * 2) -
        (gutter * (crossAxisCount - 1));
    return usable / crossAxisCount;
  }

  /// Convenience: exact tile height for a [crossAxisCount]-column [TrackCard]
  /// grid, derived from the tile width that grid will actually produce.
  static double trackCardGridExtent(
    BuildContext context, {
    required int crossAxisCount,
    required double horizontalPadding,
    bool withSubtitle = true,
    double gutter = cardGap,
  }) {
    return trackCardHeightFor(
      context,
      trackCardTileWidth(
        context,
        crossAxisCount: crossAxisCount,
        horizontalPadding: horizontalPadding,
        gutter: gutter,
      ),
      withSubtitle: withSubtitle,
    );
  }

  // ---------------------------------------------------------------------------
  // The two-line TRACK card variant.
  //
  // The album/playlist cards keep the anatomy every helper above describes: one
  // ellipsized title line, the 2dp gap, one subtitle line and the play control
  // inside that row. The TRACK card drops the subtitle entirely, reserves two
  // whole lines for the title (so a one-line and a two-line name produce exactly
  // the same card) and moves the control onto its own line at the card's
  // bottom-right corner, which is what gives the title the card's full width.
  //
  // Everything below is derived from the same typography and the same constants
  // the card itself renders with, so the card and this helper can never drift.
  // ---------------------------------------------------------------------------

  /// Explicit line-height multiplier of the two-line track title: one rendered
  /// line box is exactly `fontSize * this` logical pixels tall.
  ///
  /// ## Why the track title pins its own line height
  /// The card reserves a FIXED two-line box for its title — that is the whole
  /// reason a one-line and a two-line card measure the same — so the reserve has
  /// to agree with what the [Text] inside it really renders. Measuring a line
  /// with a [TextPainter] (what every other helper here does) does NOT agree:
  /// [Text] merges its style over the ambient `DefaultTextStyle`, so the card
  /// inherits Material's `height: 1.43` and whatever font family the platform
  /// hands us, while a bare `TextStyle` measures with the font's own metrics
  /// (~1.17em). On the device that difference is ~3.5px per line, which is
  /// exactly how a "reserved" two-line title ends up overflowing the box it was
  /// reserved in.
  ///
  /// `TextStyle.height` removes the guesswork by contract: Flutter renders such
  /// a line exactly `fontSize * height` tall whatever the font's metrics are, so
  /// the card reserves `2 *` that number and the text fits BY CONSTRUCTION — at
  /// any font family, any platform metrics and any system text scale.
  static const double trackTitleLineHeight = 1.2;

  /// Horizontal padding of the two-line track title block, at scale == 1: half
  /// the album card's [cardPadding].
  ///
  /// The track title has to show the full track name on at most two lines, and
  /// in a 110dp grid tile every pixel of width counts. Measured at the title's
  /// own style (14px/w600, no tracking, real Roboto metrics) over this
  /// catalogue's names: "Sri Rama Nama Sudha Lahala" needs 97.5dp of width to
  /// break over two lines and "Niluvadu Manasu" 55.5dp. This padding leaves the
  /// title 110 - 2 * 4.17 = 101.7dp in a 110dp tile — ~4dp of slack on the
  /// longest one — where the full [cardPadding] would leave 93.3dp and ellipsize
  /// it. The card's cover bleeds to its edges, so the tighter inset also keeps
  /// the title closer to the artwork it belongs to.
  static const double trackCardTextPadding = cardPadding / 2;

  /// Target diameter of the track card's play control at scale == 1: 0.75 x the
  /// 30dp control the album/playlist cards still render
  /// (`TrackCard.playButtonSize`).
  ///
  /// The control sits at the card's BOTTOM-RIGHT, in the same row as the title
  /// block and bottom-aligned with it — exactly how the album card arranges its
  /// own control. That row is why [trackPlayButtonClearance] exists: the control
  /// must never be the taller child, or it would add its own height to the card
  /// and break the "every card is the same height" guarantee.
  static const double trackPlayButtonSize = 22.5;

  /// Gap between the title block and the play control beside it, at scale == 1.
  /// The same number as `TrackCard.playButtonGap`, which the album card uses
  /// inside its own row — these two files both name the gap they render with, so
  /// neither card's geometry has to reach into the other's.
  static const double trackPlayButtonGap = 4;

  /// How much shorter than the title block the track control is kept, at scale
  /// == 1. Same role as `TrackCard.playButtonClearance`: the control can never be
  /// the taller child of the card's row, so it can never add a pixel to the
  /// height derived in [twoLineTrackCardHeight].
  static const double trackPlayButtonClearance = 4;

  /// One rendered line box of the two-line track title, in logical pixels.
  ///
  /// `fontSize * height` is what Flutter renders such a line as (see
  /// [trackTitleLineHeight]). The [TextScaler] is applied to the font size
  /// first, because that is the order Flutter's own line-height calculation uses
  /// — so a system text scale enlarges the reserve exactly as much as it
  /// enlarges the text.
  static double trackTitleLineBox(BuildContext context) {
    final fontSize = Theme.of(context).typography.small.fontSize ?? 0;
    return MediaQuery.textScalerOf(context).scale(fontSize) *
        trackTitleLineHeight;
  }

  /// The height of the box the track title renders in — the SAME number the card
  /// gives it, because both call this.
  ///
  /// Two whole line boxes, each rounded UP. The engine rounds a rendered line box
  /// to whole logical pixels, so a fractional line (14 * 1.2 = 16.8) would
  /// otherwise leave a reserve up to a pixel short of the text it holds. Rounding
  /// keeps `reserve >= rendered text` at every text scale, so the title can never
  /// be clipped for lack of room; the cost is at most one pixel per line, and every
  /// card pays it identically, which is what keeps all the cards the same height.
  ///
  /// The play control does NOT live in this box: it sits beside the block, in the
  /// card's row, so the block is purely the two title lines.
  static double trackTitleBlockHeight(BuildContext context) {
    return 2 * trackTitleLineBox(context).ceilToDouble();
  }

  /// Diameter of the track card's play control, derived so it can never be the
  /// taller child of the card's row:
  ///
  ///   control <= block - clearance < block
  ///
  /// where the block is the fixed two-line title box above. The `min` with
  /// [trackPlayButtonSize] means the ordinary case renders exactly 0.75 x the
  /// album card's control; the clearance only bites at a text scale so small — or a
  /// theme so tight — that the title block is shorter than the control.
  static double trackPlayButtonDiameter(BuildContext context) {
    final scale = Theme.of(context).scaling;
    final block = trackTitleBlockHeight(context);
    return math.max(
      0,
      math.min(
        trackPlayButtonSize * scale,
        block - (trackPlayButtonClearance * scale),
      ),
    );
  }

  /// Exact height of the TRACK card whose square cover is [coverWidth] wide: the
  /// cover, the padded title/control row and the card's bottom padding.
  ///
  /// Every term is either a constant or a value the card itself computes through
  /// the helpers above, so a one-word title, a one-line title and a two-line title
  /// produce exactly the same card: the title's box is a fixed
  /// [trackTitleBlockHeight] whichever way the text wraps, and the control beside
  /// it is clamped by [trackPlayButtonDiameter] to be shorter than that block, so
  /// the row is always the block. The `max` is written out anyway rather than
  /// assumed, so the derivation stays correct even if those constants are ever
  /// retuned to make the control the taller child.
  static double twoLineTrackCardHeight(
    BuildContext context,
    double coverWidth,
  ) {
    final scale = Theme.of(context).scaling;
    return coverWidth +
        (cardTextGap * scale) +
        math.max(
          trackTitleBlockHeight(context),
          trackPlayButtonDiameter(context),
        ) +
        (cardPadding * scale);
  }

  /// Exact height of one card in a home TRACK row: the same two-line card at the
  /// rows' fixed [cardWidth] box, which is also the card's cover width.
  static double twoLineTrackRowHeight(BuildContext context) {
    final scale = Theme.of(context).scaling;
    return twoLineTrackCardHeight(context, cardWidth * scale);
  }

  /// Exact tile height for the shared track/album grids.
  ///
  /// Those grids have ONE tile extent but render two card anatomies: the
  /// two-line, no-subtitle track card on their track surfaces and the one-line
  /// title + subtitle album/playlist card on the others. Taking the taller of the
  /// two derived heights is what keeps either one from overflowing its tile.
  ///
  /// At scale 1 and a 110dp tile the two-line track card is the taller one —
  /// 110 + 6 + 34 + 4 + 22.5 + 8.33 = 184.83dp against the album card's
  /// 110 + 6 + 16.41 + 2 + 14.06 + 8.33 = 156.80dp — so the album and playlist
  /// cards simply have room to spare at the bottom of their own background
  /// instead of a clipped text block. Both cards FILL the tile either way.
  static double trackGridCardExtent(
    BuildContext context, {
    required int crossAxisCount,
    required double horizontalPadding,
    double gutter = cardGap,
  }) {
    final tileWidth = trackCardTileWidth(
      context,
      crossAxisCount: crossAxisCount,
      horizontalPadding: horizontalPadding,
      gutter: gutter,
    );
    return math.max(
      twoLineTrackCardHeight(context, tileWidth),
      trackCardHeightFor(context, tileWidth),
    );
  }

  /// Exact tile height for the shared 150px-art `PlaybuttonCard` grids
  /// (playlists/albums grids). The card renders a 150px artwork, a 12px
  /// content gap and a title + up-to-two-line subtitle, so the tile is sized
  /// to that with zero dead band and no clipping of two-line descriptions.
  static double playbuttonCardHeight(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final titleLine = _lineHeight(theme.typography.small);
    final subtitleLine = _lineHeight(theme.typography.xSmall);
    // 150 artwork + 12 CardImage gap + title + 2 title/subtitle gap +
    // subtitle (reserve two lines so long playlist descriptions never clip).
    return (150 + 12 + titleLine + 2 + subtitleLine * 2) * scale;
  }

  /// Exact row height for horizontal rows of `PlaybuttonCard`s. The rows add
  /// 8px of top and bottom list padding around the cards.
  static double playbuttonRowHeight(BuildContext context) =>
      playbuttonCardHeight(context) + 16;

  /// Exact tile height for `ArtistCard` grids. The card is a padded `Button`
  /// (16px padding at scale 1) holding a 130px avatar, a 10px gap and the
  /// song-count badge, with no fixed middle filler, so tiles fit ~198px
  /// instead of the previous fixed 225/250 that left a dead band in every
  /// tile (absorbed by the card's internal [Spacer]).
  static double artistCardHeight(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    // Badge line + SecondaryBadge's internal padding (~8px).
    final badgeLine = _lineHeight(theme.typography.small) + 8;
    return (16 + 130 + 10 + badgeLine + 16) * scale;
  }

  /// Exact row height for horizontal rows of `ArtistCard`s (row adds 8px of
  /// top/bottom list padding around the cards).
  static double artistRowHeight(BuildContext context) =>
      artistCardHeight(context) + 16;
}
