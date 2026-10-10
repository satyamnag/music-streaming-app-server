import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/models/metadata/metadata.dart';

/// One GRID CELL of the Artists analytics screen.
///
/// ## Why not the list row
/// `StatsArtistItem` renders a `ButtonTile` - a small round avatar with the name
/// (hidden app-wide) and the stat trailing it. In a grid that shape leaves most
/// of the tile empty: the avatar is a fixed small size and a trailing stat has
/// nowhere to go, which is the blank space this screen showed.
///
/// This cell instead uses the SAME [TrackCard] every other card surface uses, in
/// its album anatomy, with a CIRCULAR cover - an artist is a face, not artwork,
/// so a round crop is what reads correctly at grid size. The stat sits under it
/// exactly as it does on the other analytics grids, so the five screens are
/// visually consistent with each other and with home.
class StatsArtistGridItem extends StatelessWidget {
  final SangeetSimpleArtistObject artist;

  /// The stat line shown under the card, e.g. "12 plays".
  final Widget info;

  const StatsArtistGridItem({
    super.key,
    required this.artist,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final imageUrl = artist.images.asUrlString(
      placeholder: ImagePlaceholder.artist,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The shared card, so tile width, corner radius, typography and the tile
        // footprint match every other surface exactly.
        //
        // Artist names are hidden app-wide, so the title is empty and the stat is
        // the only line - matching the list row this replaces. The empty title
        // still occupies its reserved line, which is what keeps this tile the
        // same height as a track or album tile in the same grid.
        TrackCard(
          imageUrl: imageUrl,
          title: '',
          onTap: () {},
        ),
        const Gap(4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: DefaultTextStyle.merge(
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: info,
          ),
        ),
      ],
    );
  }
}
