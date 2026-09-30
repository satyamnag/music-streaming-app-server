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
}
