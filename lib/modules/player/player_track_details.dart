import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/links/link_text.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

class PlayerTrackDetails extends HookConsumerWidget {
  final Color? color;
  final SangeetTrackObject? track;

  /// Optional widget rendered directly BENEATH the track name, inside the same
  /// column as it.
  ///
  /// Because that column already sits to the right of the artwork and to the
  /// left of whatever follows the details, a footer here spans exactly the gap
  /// between them. The collapsed mini player passes its [TimelineBar] this way,
  /// which is what puts the playback timeline under the track name instead of
  /// in a full-width band below both the artwork and the controls.
  final Widget? footer;

  const PlayerTrackDetails({
    super.key,
    this.color,
    this.track,
    this.footer,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final playback = ref.watch(audioPlayerProvider);

    return Row(
      children: [
        if (playback.activeTrack != null)
          Container(
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(
              maxWidth: 80,
              maxHeight: 80,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: UniversalImage(
                path: (track?.album.images)
                    .asUrlString(placeholder: ImagePlaceholder.albumArt),
                placeholder: Assets.images.albumPlaceholder.path,
              ),
            ),
          ),
        if (mediaQuery.mdAndDown)
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  playback.activeTrack?.name ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.normal.copyWith(
                    color: color,
                  ),
                ),
                if (footer != null) footer!,
              ],
            ),
          ),
        if (mediaQuery.lgAndUp)
          Flexible(
            flex: 1,
            child: Column(
              children: [
                LinkText(
                  playback.activeTrack?.name ?? "",
                  TrackRoute(trackId: playback.activeTrack?.id ?? ""),
                  push: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                if (footer != null) footer!,
              ],
            ),
          ),
      ],
    );
  }
}
