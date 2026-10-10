import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/track_card/home_album_card.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

/// One GRID CELL of a stats screen: the shared home album card with the row's
/// own stat beneath it.
///
/// ## Why this exists alongside [StatsAlbumItem]
/// `StatsAlbumItem` lays the card and the stat out in a `Row`, which suits a
/// list and not a grid: in a grid the card fills its tile, so a trailing
/// `Expanded` stat has no width left and the tile shows a blank column beside
/// the artwork. That is the empty space these screens were reported to have.
///
/// Here the stat sits UNDER the card, so the tile is filled edge to edge.
///
/// The card is the unchanged [HomeAlbumCard], so cover, corner radius,
/// typography and premium gating match the home screen by construction.
class StatsAlbumGridItem extends HookConsumerWidget {
  final SangeetSimpleAlbumObject album;

  /// The stat line shown under the card, e.g. "12 plays".
  final Widget info;

  const StatsAlbumGridItem({
    super.key,
    required this.album,
    required this.info,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final locked = PremiumAccess.isAlbumLocked(album, ref);

    // A stats album tile only opens the payment gate for a locked album; it does
    // not navigate, matching the row it replaces.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (locked) {
          PremiumAccess.gateAlbumPlay(
            context: context,
            ref: ref,
            album: album,
            feature: () async {},
          );
        }
      },
      child: Column(
        // Stretch so the card fills the tile's width exactly as on the home
        // screen.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeAlbumCard(
            album: album,
            imageUrl: album.images.smallest(ImagePlaceholder.albumArt),
            subtitle: '${album.albumType.formatted} • ',
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
      ),
    );
  }
}
