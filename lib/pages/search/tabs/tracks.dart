import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/dialogs/prompt_dialog.dart';
import 'package:sangeet/components/dialogs/select_device_dialog.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/track_tile/track_tile.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/models/connect/connect.dart';
import 'package:sangeet/modules/search/loading.dart';
import 'package:sangeet/pages/search/search.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/connect/connect.dart';
import 'package:sangeet/provider/metadata_plugin/search/tracks.dart';

class SearchPageTracksTab extends HookConsumerWidget {
  /// Number of tracks revealed per page.
  static const int pageSize = 5;

  const SearchPageTracksTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final searchTracksSnapshot =
        ref.watch(metadataPluginSearchTracksProvider(searchTerm));
    final visibleCount = useState(SearchPageTracksTab.pageSize);
    final searchTracks =
        searchTracksSnapshot.asData?.value.items ?? [FakeData.track];
    final shown = searchTracks.take(visibleCount.value).toList();
    final hasMore = searchTracks.length > visibleCount.value;

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);

    if (searchTracksSnapshot.hasError) {
      return ErrorBox(
        error: searchTracksSnapshot.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSearchTracksProvider(searchTerm));
        },
      );
    }

    return SearchPlaceholder(
      snapshot: searchTracksSnapshot,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(shown.length, (index) {
              final track = shown[index];

              return TrackTile(
                track: track,
                playlist: playlist,
                index: index,
                onTap: () async {
                  if (PremiumAccess.isTrackLocked(track, ref)) {
                    await PremiumAccess.gateTrackPlay(
                      context: context,
                      ref: ref,
                      track: track,
                      feature: () async {
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
                          final isTrackPlaying =
                              playlist.activeTrack?.id == track.id;
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
                    return;
                  }

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
                    visibleCount.value += SearchPageTracksTab.pageSize;
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
        ),
      ),
    );
  }
}
