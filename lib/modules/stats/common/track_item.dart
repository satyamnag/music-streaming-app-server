import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/components/ui/button_tile.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

class StatsTrackItem extends HookConsumerWidget {
  final SangeetTrackObject track;
  final Widget info;
  const StatsTrackItem({
    super.key,
    required this.track,
    required this.info,
  });

  @override
  Widget build(BuildContext context, ref) {
    final locked = PremiumAccess.isTrackLocked(track, ref);
    return ButtonTile(
      style: ButtonVariance.ghost,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            UniversalImage(
              path: (track.album.images).asUrlString(
                placeholder: ImagePlaceholder.albumArt,
              ),
              width: 40,
              height: 40,
            ),
            LockedBadge(locked: locked),
          ],
        ),
      ),
      title: Text(track.name),
      subtitle: const SizedBox.shrink(),
      trailing: info,
      onPressed: () {
        void open() => context.navigateTo(TrackRoute(trackId: track.id));
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
    );
  }
}
