import 'package:collection/collection.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/dialogs/prompt_dialog.dart';
import 'package:sangeet/components/dialogs/select_device_dialog.dart';
import 'package:sangeet/components/track_tile/track_tile.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/connect/connect.dart';
import 'package:sangeet/pages/search/search.dart';
import 'package:sangeet/provider/connect/connect.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/metadata_plugin/search/all.dart';

class SearchTracksSection extends HookConsumerWidget {
  /// Number of tracks revealed per page.
  static const int pageSize = 5;

  const SearchTracksSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final search = ref.watch(metadataPluginSearchAllProvider(searchTerm));
    final tracks = search.asData?.value.tracks ?? [];
    final visibleCount = useState(SearchTracksSection.pageSize);
    final shown = tracks.take(visibleCount.value).toList();
    final hasMore = tracks.length > visibleCount.value;
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final playlist = ref.watch(audioPlayerProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tracks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.songs,
              style: theme.typography.h4,
            ),
          ),
        if (search.isLoading)
          Skeletonizer(
            enabled: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TrackTile(
                track: FakeData.track,
                playlist: playlist,
              ),
            ),
          )
        else
          ...shown.mapIndexed((i, track) {
            return TrackTile(
              index: i,
              track: track,
              playlist: playlist,
              onTap: () async {
                final isRemoteDevice =
                    await showSelectDeviceDialog(context, ref);

                if (isRemoteDevice == null) return;

                if (isRemoteDevice) {
                  final remotePlayback = ref.read(connectProvider.notifier);
                  final remotePlaylist = ref.read(queueProvider);

                  final isTrackPlaying =
                      remotePlaylist.activeTrack?.id == track.id;

                  if (!isTrackPlaying && context.mounted) {
                    final shouldPlay = (playlist.tracks.length) > 20
                        ? await showPromptDialog(
                            context: context,
                            title: context.l10n.playing_track(
                              track.name,
                            ),
                            message: context.l10n.queue_clear_alert(
                              playlist.tracks.length,
                            ),
                          )
                        : true;

                    if (shouldPlay) {
                      await remotePlayback.load(
                        WebSocketLoadEventData.playlist(
                          tracks: [track],
                        ),
                      );
                    }
                  }
                } else {
                  final isTrackPlaying = playlist.activeTrack?.id == track.id;
                  if (!isTrackPlaying && context.mounted) {
                    final shouldPlay = (playlist.tracks.length) > 20
                        ? await showPromptDialog(
                            context: context,
                            title: context.l10n.playing_track(
                              track.name,
                            ),
                            message: context.l10n.queue_clear_alert(
                              playlist.tracks.length,
                            ),
                          )
                        : true;

                    if (shouldPlay) {
                      await playlistNotifier.load(
                        [track],
                        autoPlay: true,
                      );
                    }
                  }
                }
              },
            );
          }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Button.text(
              onPressed: () {
                visibleCount.value += SearchTracksSection.pageSize;
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(SangeetIcons.angleDown, size: 16),
                  const Gap(6),
                  Text(context.l10n.see_more),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
