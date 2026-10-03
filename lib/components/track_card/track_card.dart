import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
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

/// A shared track/album card for GRID surfaces (see-all screens, search tabs)
/// and horizontal home rows. Provider-free: the caller resolves artwork,
/// handles taps and any premium gating, so search and see-all screens keep
/// their own play logic.
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
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;

  /// Optional override for the card's own width. Grid surfaces pass nothing
  /// (the card fills its tile); horizontal rows pass their fixed card width.
  final double? width;

  const TrackCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        color: theme.colorScheme.card,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.12)
                : theme.colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(
            HomeSectionLayout.cardPadding * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      UniversalImage(path: imageUrl, fit: BoxFit.cover),
                      LockedBadge(locked: locked, borderRadius: 0),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6 * scale),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              SizedBox(height: 2 * scale),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
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