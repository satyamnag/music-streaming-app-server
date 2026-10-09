import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/components/track_card/card_border.dart';
import 'package:sangeet/components/track_card/card_colors.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';

/// Responsive count of grid columns for the track/album cards: each column is
/// at least a card ([minCardWidth] * scaling) plus one [cardGap] gutter wide.
///
/// The card itself is fluid (see [TrackCard]), so this only decides how many
/// columns fit comfortably — it can never cause artwork to overflow its tile.
int trackGridCrossAxisCount(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final perColumn = (minCardWidth * Theme.of(context).scaling) + cardGap;
  return math.max(2, (width / perColumn).floor());
}

/// Minimum comfortable width of one track/album card at scale == 1. The card
/// is fluid and expands to fill its grid tile, so this is only the width at
/// which we decide a column is still readable (and thus how many columns fit).
///
/// Derived from the shared [HomeSectionLayout.cardScale] so the smaller cards
/// also fit more columns per row, which is what makes the library read as a
/// large collection.
const double minCardWidth = HomeSectionLayout.imageSize +
    (HomeSectionLayout.cardPadding * 2);

/// Gap between cards inside a row/grid, at scale == 1.
const double cardGap = 6;

/// Cards per row in every non-home track/album grid (home "see all", the
/// search tabs/sections and the library). The home rows keep their own card
/// width and are not affected by anything below.
const int trackGridColumns = 3;

/// Screen width the three grid numbers below are derived from, in logical
/// pixels: the app's reference phone.
const double trackGridReferenceWidth = 360;

/// Side padding of those grids, in logical pixels: the inset that keeps the
/// outermost cards clear of the screen edge without wasting the width the cards
/// could use. 9dp is visibly separate from the edge while still leaving the
/// three columns 110dp each.
const double trackGridPadding = 9;

/// Gutter between the columns of those grids, in logical pixels: exactly the
/// house [cardGap], which is also what [trackGridDelegate] already uses for its
/// `mainAxisSpacing`. Horizontal and vertical rhythm therefore finally match
/// instead of the gutter being 2.5dp tighter than the rows below it.
const double trackGridGutter = cardGap;

/// Card width those three numbers produce on the [trackGridReferenceWidth]
/// reference phone, where the arithmetic closes exactly:
///
///   3 * 110 (cards) + 2 * 9 (side padding) + 2 * 6 (gutters) = 330 + 18 + 12
///   = 360
///   => (360 - 18 - 12) / 3 = 110dp per card
///
/// The cards FILL their grid tile (no fixed-width wrapper), so the card width IS
/// the tile width, and this number is a result of the three above rather than an
/// input — the assert in [trackGridDelegate] fails loudly if they stop agreeing.
///
/// History, so the numbers are not mysterious later: the user asked for three per
/// row, then for 120dp (which needs 3 * 120 = 360dp of cards alone, i.e. zero
/// padding and zero gutters — impossible), then 117.5dp, then 115dp for more
/// space between the cards, and finally 110dp for a 6dp gutter on both axes with
/// a 9dp side inset. Every pixel of card width given up here is what pays for
/// the grid's own spacing.
const double trackGridTileWidth = 110;

/// The grid delegate every NON-HOME track/album grid renders with.
///
/// One place decides how many columns there are, how wide the gutters are and
/// how tall a tile is, so the four grids can never disagree about the cards
/// they show. Callers apply [trackGridPadding] themselves (as their
/// `SliverPadding`/`GridView` padding) — the padding is part of the geometry
/// [HomeSectionLayout.trackGridCardExtent] measures the tile width from, so a
/// grid that pads differently would clip its cards.
///
/// `mainAxisSpacing` is the house [HomeSectionLayout.cardGap] and, since
/// [trackGridGutter] is now the same number, the grid's vertical and horizontal
/// spacing match.
SliverGridDelegate trackGridDelegate(BuildContext context) {
  // The four numbers are one system: three cards plus the padding and the
  // gutters have to fill the reference width, or the cards stop being the size
  // the tile height (and therefore the card height) was derived from.
  assert(
    (trackGridColumns * trackGridTileWidth) +
            (2 * trackGridPadding) +
            ((trackGridColumns - 1) * trackGridGutter) ==
        trackGridReferenceWidth,
    'the track grid constants no longer fill the reference width',
  );

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: trackGridColumns,
    crossAxisSpacing: trackGridGutter,
    mainAxisSpacing: HomeSectionLayout.cardGap,
    // The card fills the tile, so the tile width IS the card width and this
    // extent is the card's exact height — derived from the tile width the grid
    // really produces rather than from an assumed one. These grids show the
    // two-line track card AND the one-line title + subtitle album/playlist card,
    // so the extent is the taller of the two (see
    // [HomeSectionLayout.trackGridCardExtent]).
    mainAxisExtent: HomeSectionLayout.trackGridCardExtent(
      context,
      crossAxisCount: trackGridColumns,
      horizontalPadding: trackGridPadding,
      gutter: trackGridGutter,
    ),
  );
}

/// A shared track/album card for GRID surfaces (see-all screens, search tabs)
/// and horizontal home rows. Provider-free: the caller resolves artwork,
/// handles taps and any premium gating, so search and see-all screens keep
/// their own play logic.
///
/// ## The two anatomies
/// The card renders one of two layouts, chosen by [titleLines]:
///
///  * [titleLines] == 1 (the default, and every album/playlist card): the card
///    this widget has always rendered — one ellipsized title line, the 2dp gap,
///    one subtitle line, and the play control inside that same row.
///  * [titleLines] == 2 (the TRACK card): no subtitle line at all, the title in
///    a FIXED two-line box that fills the card's width, and the play control on
///    its own line at the card's bottom-right corner. The fixed box is what
///    makes a one-line and a two-line track card exactly the same height; the
///    explicit line height the title style pins (see
///    [HomeSectionLayout.trackTitleLineHeight]) is what makes the text agree
///    with that box at any font and any system text scale.
///
/// ## Why the artwork is fluid
/// This card used to lay out a hard-coded 150px artwork inside a fixed 175px
/// box with 10px padding (170px of content in a 175px box), while the grid tile
/// and the home row both size themselves independently of the card. Any
/// mismatch between those independent numbers — a narrower phone, a different
/// theme scale, or different font metrics — made the artwork touch the card's
/// top/bottom edges, so the card read as a clipped, incomplete box.
///
/// The artwork now fills whatever width the card actually receives via
/// [LayoutBuilder] + [AspectRatio], so the 10px inset on every side is
/// guaranteed at any size and the box always renders complete.
class TrackCard extends StatelessWidget {
  final String imageUrl;
  final String title;

  /// The card's second line. The track variant ([titleLines] == 2) renders no
  /// subtitle at all — the album name it used to show under the track name is
  /// gone — so this is empty there.
  final String subtitle;
  final VoidCallback onTap;

  /// How many lines the title is allowed to occupy, and which anatomy the card
  /// renders: 1 (the default) for the one-line title + subtitle album/playlist
  /// card, 2 for the two-line, no-subtitle TRACK card. Only those two values are
  /// meaningful — the track variant reserves exactly two line boxes — and the
  /// constructor asserts it.
  final int titleLines;

  /// What the card's own play control does, or null to render no control at
  /// all (the card then looks exactly as it did before the control existed).
  ///
  /// The control is a separate tap target, so it must be a DIFFERENT action
  /// from [onTap] wherever the card's tap already means something else — on the
  /// see-all albums grid the card opens the album and this plays it, while on a
  /// track card both start the same track.
  final VoidCallback? onPlay;

  final bool locked;

  /// Optional override for the card's own width. Grid surfaces pass nothing
  /// (the card fills its tile); horizontal rows pass their fixed card width.
  final double? width;

  /// Admin-configured card box background (`#rrggbb`), or null for the theme's
  /// card color. Set from the admin panel and stored per track/album.
  final String? cardBgColor;

  /// Admin-configured card text color (`#rrggbb`), or null for the theme's
  /// default foreground/muted colors.
  final String? cardTextColor;

  /// Target diameter of the ALBUM/playlist card's play control at scale == 1.
  /// It is only a ceiling: [_playButtonDiameter] shrinks it to fit the text block
  /// it sits beside, which is what keeps the card exactly as tall as
  /// [HomeSectionLayout] computes.
  ///
  /// The track variant uses 0.75 x this — [HomeSectionLayout.trackPlayButtonSize]
  /// — because its control sits on its own line rather than beside the title.
  static const double playButtonSize = 30;

  /// How much shorter than the text block the play control is kept, at scale
  /// == 1. A positive clearance rather than "trust the two sizes": it makes the
  /// control strictly shorter than the block by arithmetic instead of by
  /// assumption. See [_playButtonDiameter].
  static const double playButtonClearance = 4;

  /// Gap between the title/subtitle block and the play control, at scale == 1.
  /// The track variant names the same number separately as
  /// [HomeSectionLayout.trackPlayButtonGap], the way [cardGap] is named in both
  /// files, so neither card's geometry has to reach into the other's.
  static const double playButtonGap = 4;

  const TrackCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle = '',
    this.titleLines = 1,
    required this.onTap,
    this.onPlay,
    this.locked = false,
    this.width,
    this.cardBgColor,
    this.cardTextColor,
  }) : assert(
          titleLines == 1 || titleLines == 2,
          'the track card renders either one title line or the reserved '
          'two-line track title, nothing else',
        );

  /// Diameter of this card's play control.
  ///
  /// The two-line track variant takes its control's diameter from
  /// [HomeSectionLayout.trackPlayButtonDiameter] instead — the same derivation
  /// against the block the card reserves, so the control still can never be the
  /// taller child.
  ///
  /// ## Why it is measured and not just "30dp"
  /// The card's height is decided by the text block, and every grid tile and
  /// home row takes that height from [HomeSectionLayout], which measures the
  /// title line, the 2dp gap and the subtitle line. The play control is a
  /// second child of the same [Row] as that block, so a control TALLER than the
  /// block would become the row's height and push the card past the height its
  /// tile was sized for — a card that overflows its row.
  ///
  /// Keeping the control [playButtonClearance] shorter than the block gives:
  ///
  ///   rowHeight = max(block, control) <= max(block, block - clearance)
  ///             = block
  ///
  /// so the control can never add a single pixel to the card, whatever font
  /// metrics or text scale the platform hands us — including metrics tighter
  /// than the ones [HomeSectionLayout] measured, where a fixed 30dp control
  /// would have been the taller child.
  ///
  /// The block is measured here rather than through [HomeSectionLayout]
  /// because the house helper deliberately measures the bare styles, while the
  /// card's [Text] widgets also apply the ambient text scale. At a system font
  /// scale below 1 the text really is shorter than the house number, and a
  /// control sized from that number would be the taller child — exactly the
  /// case this measurement exists to keep out.
  double _playButtonDiameter(BuildContext context) {
    if (titleLines > 1) {
      return HomeSectionLayout.trackPlayButtonDiameter(context);
    }

    final theme = Theme.of(context);
    final scale = theme.scaling;
    final textScaler = MediaQuery.textScalerOf(context);
    // The styles the card's Texts render with: `Text` merges its own style over
    // the ambient default (which is where the font family comes from), so
    // measuring the same merge avoids sizing the control against a different
    // font than the text beside it.
    final defaultStyle = DefaultTextStyle.of(context).style;

    // One rendered line, measured with the scaler the Text widgets use, the
    // same way [HomeSectionLayout] measures its lines.
    double lineHeight(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag', style: defaultStyle.merge(style)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final block = lineHeight(
          theme.typography.small.copyWith(fontWeight: FontWeight.w600),
        ) +
        (HomeSectionLayout.titleSubtitleGap * scale) +
        lineHeight(theme.typography.xSmall);

    // The block always holds at least one title line, so this cannot go
    // negative; the clamp only stops an exotic metric from handing a negative
    // size to the control's box.
    return math.max(
      0,
      math.min(playButtonSize * scale, block - (playButtonClearance * scale)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    // The admin color wins when set; otherwise the card keeps the theme look.
    final bg = cardBackgroundColor(cardBgColor, theme.colorScheme.card);
    final configuredText = parseCardColor(cardTextColor);
    // When a custom background is set but no text color, pick black/white so
    // the text stays readable instead of vanishing into the new background.
    final titleColor = configuredText ??
        (cardBgColor != null
            ? readableTextOn(bg)
            : theme.colorScheme.foreground);
    final subtitleColor = configuredText ??
        (cardBgColor != null
            ? readableTextOn(bg).withValues(alpha: 0.75)
            : theme.colorScheme.mutedForeground);

    // Bound to a local because Dart only promotes local variables, not fields.
    final play = onPlay;

    // TRACK card (titleLines == 2): no album line, and the name gets at most two
    // lines — never a third.
    //
    // Line one holds the first word and line two holds every remaining word, and
    // if the name still does not fit, line two ellipsizes. A name short enough to
    // fit beside the control keeps its single line instead of being split for the
    // sake of the rule.
    //
    // The play control shares line one, right aligned, which is what places it at
    // the right of the first word. Sharing the line costs line one the control's
    // width, so the card MEASURES each name before choosing a shape.
    //
    // Both lines live in a FIXED [HomeSectionLayout.trackTitleBlockHeight], so a
    // one-line name and a two-line name produce cards of exactly the same height,
    // and the block is tall enough for the control whichever line it lands on.
    // The explicit `height` multiplier is what makes that reserve exact: it makes
    // a line box `fontSize * height` by contract, so the reserve cannot come up
    // short of the text whatever font or text scale the platform supplies.
    //
    // The shape is decided by measuring the name with the very style it renders
    // in, at the very width this card will give it — a [TextPainter] with the same
    // style, the same text scaler and the same maxWidth the [Text] below is laid
    // out with. No rule of thumb can do this job: the catalogue's first words
    // alone span 25dp to 93dp, and the line they share with the control is only
    // 75.2dp wide in a 110dp tile.
    final cardTitleStyle = theme.typography.small.copyWith(
      fontWeight: FontWeight.w600,
      color: titleColor,
      height: HomeSectionLayout.trackTitleLineHeight,
    );
    final titleScaler = MediaQuery.textScalerOf(context);

    final controlDiameter = HomeSectionLayout.trackPlayButtonDiameter(context);

    /// One title line. The play control does NOT share a text line any more — it
    /// sits at the card's bottom-right in the row beside this block — so each line
    /// gets the block's full width, which is what lets long names use the space the
    /// control used to take.
    Widget titleLine(String text) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cardTitleStyle,
        );

    /// The fixed two-line title block, split for the width it is ACTUALLY handed.
    ///
    /// [LayoutBuilder] reports the padded text column — the padding around the
    /// block sits outside it — so this needs no arithmetic about the card's outer
    /// width or its insets, and cannot drift from the width the [Text] widgets are
    /// really laid out with.
    Widget trackTitleBlock() {
      return LayoutBuilder(
        builder: (context, constraints) {
          /// True when [text] paints on ONE line inside [maxWidth] with the
          /// card's own title style — the same measurement the [Text] widgets
          /// below perform, because it is the same engine call.
          bool fitsOneLine(String text, double maxWidth) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: cardTitleStyle),
              maxLines: 1,
              textDirection: TextDirection.ltr,
              textScaler: titleScaler,
            )..layout(maxWidth: maxWidth);
            final fits = !painter.didExceedMaxLines;
            painter.dispose();
            return fits;
          }

          final words = title.trim().split(RegExp(r'\s+'));
          // A name that fits on one line keeps it; otherwise the first word takes
          // line one and every remaining word takes line two, ellipsized if even
          // that is not enough. Never a third line.
          final onOneLine = fitsOneLine(title, constraints.maxWidth);
          final splits = !onOneLine && words.length > 1;
          final secondLine = splits ? words.skip(1).join(' ') : null;

          return SizedBox(
            height: HomeSectionLayout.trackTitleBlockHeight(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleLine(onOneLine ? title : words.first),
                if (secondLine != null) titleLine(secondLine),
              ],
            ),
          );
        },
      );
    }

    /// The ALBUM/playlist title: the same two-line block the track card uses,
    /// with the subtitle kept underneath it.
    ///
    /// ## Why this is no longer a single ellipsized line
    /// A device screenshot of the home Albums row showed three consecutive cards
    /// reading "Ganesha …", "Ganapati …" and "Venkates…". The album card was a
    /// fixed 125dp box whose title got ONE line at the body size, so the catalogue's
    /// real names — "Ganesha Lahari", "Ganapati Vaibhavam", "Venkatesa Mahima" —
    /// were all cut off mid-word even though the card had an empty second line's
    /// worth of room beneath it. Truncating the artist's own album name on the
    /// main browse surface is a content failure, not a layout preference, so the
    /// title now gets the same measured two-line treatment as a track name.
    ///
    /// Reuses [trackTitleBlock] rather than re-deriving the split: that function
    /// already measures the name with the very style and scaler the [Text]
    /// widgets render with, and already guarantees the first word takes line one
    /// and the remainder line two, never a third. One implementation means the
    /// album and track cards cannot drift apart.
    Widget albumTitleBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The title block is a FIXED two-line box, so a one-line name and a
          // two-line name produce cards of exactly the same height — the same
          // contract the track card's block keeps, and the number
          // [HomeSectionLayout] reserves the tile from.
          trackTitleBlock(),
          // From the shared layout constant, not a literal 2, so the gap the
          // card renders is the same number the tile height is computed from.
          SizedBox(height: HomeSectionLayout.titleSubtitleGap * scale),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.xSmall.copyWith(
              color: subtitleColor,
            ),
          ),
        ],
      );
    }

    final titleBox = titleLines > 1
        ? trackTitleBlock()
        // ALBUM/playlist card: two title lines over the subtitle.
        : albumTitleBlock();

    // The track card's control now lives INSIDE [titleBox], sharing one of its
    // two lines, so the card's column is the block alone. The album card keeps
    // its control beside its block.
    // The play control sits at the card's BOTTOM-RIGHT for the track card and the
    // album card alike — beside the text block, bottom aligned, so it reads as part
    // of the block rather than as a floating badge. The track card used to place it
    // at the end of the title's first line; sharing a text line cost that line the
    // control's width, which is exactly what pushed long first words onto a second
    // fallback line. Beside the block it costs the title nothing it cannot spare.
    //
    // The room is reserved even when the card has NO control (`play == null`), so
    // cards with and without one stay exactly the same height.
    final content =
        play == null && titleLines == 1
            ? titleBox
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: titleBox),
                  Gap(
                    (titleLines > 1
                            ? HomeSectionLayout.trackPlayButtonGap
                            : playButtonGap) *
                        scale,
                  ),
                  if (play == null)
                    SizedBox(
                      height: controlDiameter,
                      width: controlDiameter,
                    )
                  else
                    _CardPlayButton(
                      diameter: titleLines > 1
                          ? controlDiameter
                          : _playButtonDiameter(context),
                      title: title,
                      onPlay: play,
                    ),
                ],
              );

    return Container(
      width: width,
      // The card's background box — fill and themed gradient — is built by
      // [CardBorder], which owns the fill shared by every card.
      //
      // The card deliberately carries NO outline. It previously wore a gold rim
      // (`CardBorder.outline`), which is no longer wanted: the gold edge read as
      // a yellow frame around every album and track tile rather than as a subtle
      // separation, and the app's own artwork is already framed in gold. The
      // cards are separated from the page by the themed fill and by the artwork
      // itself, with nothing stroking the card's edge.
      //
      // `CardBorder.outline` and the rim helpers it needs are kept in
      // `card_border.dart` — they are still exercised by the border test suite
      // and remain the documented way to reinstate a rim — but nothing in the
      // app calls them, so no card paints an outline.
      decoration: CardBorder.decoration(
        context: context,
        background: bg,
        radius: 12 * scale,
        // An admin-configured background is an explicit instruction, so the
        // themed gradient steps aside for it.
        usesConfiguredBackground: cardBgColor != null,
      ),
      clipBehavior: Clip.antiAlias,
      // A plain child again, not a Stack. The Stack existed ONLY so the outline
      // could be painted over the content as its last child; with no outline
      // there is nothing to overlay, and a single child keeps the paint order
      // obvious. The geometry is unchanged: the Stack was a plain `Stack`, whose
      // first child is laid out against the same constraints the Container would
      // have handed it directly, so removing it cannot move a single pixel. (It
      // matters that it was NOT `StackFit.expand` or a `Positioned.fill` - either
      // of those would have changed the child's constraints.)
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The cover bleeds to the card's top, left and right edges. The
            // card itself clips with `Clip.antiAlias`, so the artwork takes
            // the card's outer rounded corners at the top while its bottom
            // corners stay square where it meets the text area.
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  UniversalImage(path: imageUrl, fit: BoxFit.cover),
                  LockedBadge(locked: locked, borderRadius: 0),
                ],
              ),
            ),
            // Only the text block is padded, so the cover stays flush. The
            // track card insets its text more tightly than the album card
            // ([HomeSectionLayout.trackCardTextPadding]) because the
            // two-line name needs every pixel of a 110dp tile to fit in full.
            Padding(
              padding: EdgeInsets.fromLTRB(
                (titleLines > 1
                        ? HomeSectionLayout.trackCardTextPadding
                        : HomeSectionLayout.cardPadding) *
                    scale,
                HomeSectionLayout.cardTextGap * scale,
                (titleLines > 1
                        ? HomeSectionLayout.trackCardTextPadding
                        : HomeSectionLayout.cardPadding) *
                    scale,
                HomeSectionLayout.cardPadding * scale,
              ),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's play control: a filled circle in the theme's primary color with
/// the shared play glyph, sitting at the bottom-right of the card's text block.
///
/// It carries its own tap target, so tapping the circle runs the card's play
/// action while tapping anywhere else on the card keeps doing what the card
/// already did.
class _CardPlayButton extends StatelessWidget {
  final double diameter;
  final String title;
  final VoidCallback onPlay;

  const _CardPlayButton({
    required this.diameter,
    required this.title,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Play $title',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPlay,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          // The glyph is sized from the circle (55% of it) so the control stays
          // legible at the small widths a three-column grid produces.
          child: Center(
            child: Icon(
              SangeetIcons.play,
              size: diameter * 0.55,
              color: theme.colorScheme.primaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cover/artwork resolution shared by grid cards, matching the home cards'
/// placeholder behavior.
String trackCardImageUrl(SangeetTrackObject track) =>
    track.album.images.smallest(ImagePlaceholder.albumArt);