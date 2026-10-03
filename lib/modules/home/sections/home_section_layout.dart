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
  /// The cards were reduced to ~75% of their original footprint so a row shows
  /// noticeably more artwork (the home rows and grids now read as a full,
  /// deep library rather than a handful of oversized tiles). Everything that
  /// defines the card — artwork, padding, internal gaps — is derived from
  /// [imageSize] and [cardPadding] through this factor, so the card geometry
  /// stays exact and self-consistent at any value.
  static const double cardScale = 0.75;

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
        subtitleLine;
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
