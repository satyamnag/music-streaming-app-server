import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/routes.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/ui/button_tile.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/track_options/track_options_provider.dart';

/// [track] must be a [SangeetFullTrackObject] or [SangeetLocalTrackObject]
class TrackOptions extends HookConsumerWidget {
  final SangeetTrackObject track;
  final bool userPlaylist;
  final String? playlistId;
  final Widget? icon;
  final VoidCallback? onTapItem;

  const TrackOptions({
    super.key,
    required this.track,
    this.userPlaylist = false,
    this.playlistId,
    this.icon,
    this.onTapItem,
  }) : assert(
          track is SangeetFullTrackObject || track is SangeetLocalTrackObject,
          "Track must be a SangeetFullTrackObject, SangeetLocalTrackObject",
        );

  @override
  Widget build(BuildContext context, ref) {
    final trackOptionActions = ref.watch(trackOptionActionsProvider(track));
    final (
      :isInQueue,
      :isActiveTrack,
      :isAuthenticated,
      :isLiked,
    ) = ref.watch(trackOptionsStateProvider(track));
    final isLocalTrack = track is SangeetLocalTrackObject;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.delete,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.trash),
            title: Text(context.l10n.delete),
          ),
        if (!isInQueue) ...[
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.addToQueue,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.queueAdd),
            title: Text(context.l10n.add_to_queue),
          ),
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.playNext,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.lightning),
            title: Text(context.l10n.play_next),
          ),
        ] else
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.removeFromQueue,
                playlistId,
              );
              onTapItem?.call();
            },
            enabled: !isActiveTrack,
            leading: const Icon(SangeetIcons.queueRemove),
            title: Text(context.l10n.remove_from_queue),
          ),
        if (isAuthenticated && !isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.favorite,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: isLiked
                ? const Icon(
                    SangeetIcons.heartFilled,
                    color: Colors.pink,
                  )
                : const Icon(SangeetIcons.heart),
            title: Text(
              isLiked
                  ? context.l10n.remove_from_favorites
                  : context.l10n.save_as_favorite,
            ),
          ),
        if (isAuthenticated && !isLocalTrack) ...[
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.startRadio,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.radio),
            title: Text(context.l10n.start_a_radio),
          ),
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.addToPlaylist,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.playlistAdd),
            title: Text(context.l10n.add_to_playlist),
          ),
        ],
        if (userPlaylist && isAuthenticated && !isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.removeFromPlaylist,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.removeFilled),
            title: Text(context.l10n.remove_from_playlist),
          ),
        if (!isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.share,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.share),
            title: Text(context.l10n.share),
          ),
        if (!isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.details,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SangeetIcons.info),
            title: Text(context.l10n.details),
          ),
      ],
    );
  }
}
