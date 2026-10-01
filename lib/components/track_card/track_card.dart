import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/models/metadata/metadata.dart';

/// Responsive count of grid columns for the 1.25x track/album cards: each
/// column is at least a card (175 * scaling) plus one 6px gutter wide, so the
/// fixed-size artwork never overflows its tile on any phone/tablet.
int trackGridCrossAxisCount(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final perColumn = (175 * Theme.of(context).scaling) + 6;
  return math.max(2, (width / perColumn).floor());
}

/// A shared 1.25x track/album card for GRID surfaces (see-all screens, search
/// tabs). Provider-free: the caller resolves artwork, handles taps and any
/// premium gating, so search and see-all screens keep their own play logic.
///
/// The card fills its grid tile horizontally (artwork stays 150 * scaling,
/// centered) and its exact height is provided by the grid's `mainAxisExtent`
/// via HomeSectionLayout.rowHeight — never hard-code a grid extent.
class TrackCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;

  const TrackCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * scale),
          color: theme.colorScheme.card,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withValues(alpha: 0.12)
                  : theme.colorScheme.primary.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(10 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8 * scale),
                  child: Stack(
                    children: [
                      UniversalImage(
                        path: imageUrl,
                        height: 150 * scale,
                        width: 150 * scale,
                        fit: BoxFit.cover,
                      ),
                      LockedBadge(locked: locked, borderRadius: 0),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4 * scale),
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