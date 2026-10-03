import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/dialogs/prompt_dialog.dart';
import 'package:sangeet/components/dialogs/select_device_dialog.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/models/connect/connect.dart';
import 'package:sangeet/pages/search/search.dart';
import 'package:sangeet/provider/connect/connect.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/metadata_plugin/search/all.dart';

class SearchTracksSection extends HookConsumerWidget {
  /// Number of tracks revealed per page (even -> balanced grid rows).
  static const int pageSize = 8;

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

    // Preserves the original single-track tap flow (device dialog + queue
    // prompt when the queue is long).
    Future<void> loadOnDeviceOrRemote(int index) async {
      final track = shown[index];
      final isRemoteDevice = await showSelectDeviceDialog(context, ref);
      if (isRemoteDevice == null) return;

      if (isRemoteDevice) {
        final remotePlayback = ref.read(connectProvider.notifier);
        final remotePlaylist = ref.read(queueProvider);
        final isTrackPlaying = remotePlaylist.activeTrack?.id == track.id;
        if (!isTrackPlaying && context.mounted) {
          final shouldPlay = (playlist.tracks.length) > 20
              ? await showPromptDialog(
                  context: context,
                  title: context.l10n.playing_track(track.name),
                  message: context.l10n.queue_clear_alert(
                    playlist.tracks.length,
                  ),
                )
              : true;
          if (shouldPlay) {
            await remotePlayback.load(
              WebSocketLoadEventData.playlist(tracks: [track]),
            );
          }
        }
      } else {
        final isTrackPlaying = playlist.activeTrack?.id == track.id;
        if (!isTrackPlaying && context.mounted) {
          final shouldPlay = (playlist.tracks.length) > 20
              ? await showPromptDialog(
                  context: context,
                  title: context.l10n.playing_track(track.name),
                  message:
                      context.l10n.queue_clear_alert(playlist.tracks.length),
                )
              : true;
          if (shouldPlay) {
            await playlistNotifier.load([track], autoPlay: true);
          }
        }
      }
    }

    Future<void> playTrack(int index) async {
      final track = shown[index];
      if (PremiumAccess.isTrackLocked(track, ref)) {
        await PremiumAccess.gateTrackPlay(
          context: context,
          ref: ref,
          track: track,
          feature: () async => loadOnDeviceOrRemote(index),
        );
        return;
      }
      await loadOnDeviceOrRemote(index);
    }

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
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: trackGridCrossAxisCount(context),
                  mainAxisExtent: HomeSectionLayout.trackCardGridExtent(
                    context,
                    crossAxisCount: trackGridCrossAxisCount(context),
                    horizontalPadding: 8,
                  ),
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                children: const [
                  _SkeletonCell(),
                  _SkeletonCell(),
                ],
              ),
            ),
          )
        else if (shown.isNotEmpty)
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: trackGridCrossAxisCount(context),
              mainAxisExtent: HomeSectionLayout.trackCardGridExtent(
                context,
                crossAxisCount: trackGridCrossAxisCount(context),
                horizontalPadding: 8,
              ),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            children: [
              for (final (index, track) in shown.indexed)
                TrackCard(
                  imageUrl: trackCardImageUrl(track),
                  title: track.name,
                  subtitle: track.album.name,
                  locked: PremiumAccess.isTrackLocked(track, ref),
                  cardBgColor: track.cardBgColor,
                  cardTextColor: track.cardTextColor,
                  onTap: () => playTrack(index),
                ),
            ],
          ),
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

class _SkeletonCell extends StatelessWidget {
  const _SkeletonCell();

  @override
  Widget build(BuildContext context) {
    return TrackCard(
      imageUrl: '',
      title: 'Loading',
      subtitle: 'Loading',
      onTap: () {},
    );
  }
}
