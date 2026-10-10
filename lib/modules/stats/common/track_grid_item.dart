import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// One GRID CELL of a stats screen: the shared home track card with the row's
/// own stat (play count, minutes listened, …) beneath it.
///
/// ## Why this exists alongside [StatsTrackItem]
/// `StatsTrackItem` lays the card and the stat out in a `Row`, which is the
/// right shape for a LIST and the wrong one for a GRID. In a grid the card fills
/// its tile, so a trailing `Expanded` stat would be squeezed into whatever width
/// the card left - and the card is the full tile - producing either an overflow
/// or a wide dead column beside every tile. That dead space is exactly the
/// "blank space" these screens were showing.
///
/// Here the stat sits UNDER the card and the cell is the card plus that line, so
/// the tile is filled edge to edge and the grid reads like the home screen's.
///
/// The card itself is unchanged ([HomeTrackCard]), so cover, corner radius,
/// typography, play control and premium gating all match the home screen by
/// construction - which is the requirement for every album/track surface.
class StatsTrackGridItem extends HookConsumerWidget {
  final SangeetTrackObject track;

  /// The stat line shown under the card, e.g. "12 plays".
  final Widget info;

  const StatsTrackGridItem({
    super.key,
    required this.track,
    required this.info,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final locked = PremiumAccess.isTrackLocked(track, ref);

    void open() => context.navigateTo(TrackRoute(trackId: track.id));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (locked) {
          PremiumAccess.gateTrackPlay(
            context: context,
            ref: ref,
            track: track,
            feature: () async => open(),
          );
          return;
        }
        open();
      },
      child: Column(
        // Stretch, not centre: the card must fill the tile's width exactly as it
        // does on the home screen, and the stat line starts at the same left
        // edge as the title under the cover.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeTrackCard(
            track: track,
            imageUrl: trackCardImageUrl(track),
            onTap: open,
            // The tile's tap opens the track, so the play control plays it - the
            // app's usual single-track play. The card gates both itself.
            onPlay: () => ref
                .read(audioPlayerProvider.notifier)
                .load([track], autoPlay: true),
          ),
          const Gap(4),
          // Aligned with the card's text block rather than the tile's edge, so
          // the stat sits under the title rather than under the artwork's
          // border.
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
