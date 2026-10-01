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
  /// The square artwork width/height of every home card, in logical pixels at
  /// scale == 1 (cards multiply by `theme.scaling` themselves).
  static const double imageSize = 120;

  /// Horizontal/vertical padding inside each card, at scale == 1.
  static const double cardPadding = 10;

  /// Gap between the artwork and the title, at scale == 1.
  static const double imageTitleGap = 8;

  /// Gap between the title and the subtitle, at scale == 1.
  static const double titleSubtitleGap = 2;

  /// Gap between cards inside a row, at scale == 1.
  static const double cardGap = 12;

  /// Measured height of one line rendered with [style].
  static double _lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.height;
  }

  /// The exact height a home card row needs so cards are never stretched
  /// taller than their content. The title/subtitle line heights are measured
  /// from the actual styles the cards use, so the row stays perfectly tight
  /// regardless of fonts, theme scaling or platform text metrics.
  ///
  /// [withSubtitle] must be false for the card variant that omits the
  /// subtitle line ("Recently played" cards, whose second line is empty).
  static double rowHeight(BuildContext context, {bool withSubtitle = true}) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final titleLine = _lineHeight(
      theme.typography.small.copyWith(fontWeight: FontWeight.w600),
    );
    final subtitleLine =
        withSubtitle ? _lineHeight(theme.typography.xSmall) : 0.0;
    final subtitleGap = withSubtitle ? titleSubtitleGap : 0.0;
    return (cardPadding +
            imageSize +
            imageTitleGap +
            titleLine +
            subtitleGap +
            subtitleLine +
            cardPadding) *
        scale;
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
