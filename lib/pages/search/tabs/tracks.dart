import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/dialogs/prompt_dialog.dart';
import 'package:sangeet/components/dialogs/select_device_dialog.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/models/connect/connect.dart';
import 'package:sangeet/modules/search/loading.dart';
import 'package:sangeet/pages/search/search.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/connect/connect.dart';
import 'package:sangeet/provider/metadata_plugin/search/tracks.dart';

/// Songs tab: a responsive GRID of 1.25x track cards (matching the home
/// covers), paged with a "See more" button and a "nothing found" empty state.
class SearchPageTracksTab extends HookConsumerWidget {
  /// Number of tracks revealed per page (even -> balanced grid rows).
  static const int pageSize = 8;

  const SearchPageTracksTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final searchTracksSnapshot =
        ref.watch(metadataPluginSearchTracksProvider(searchTerm));
    final visibleCount = useState(SearchPageTracksTab.pageSize);
    final searchTracks = searchTracksSnapshot.asData?.value.items ?? [];
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

    return SearchPlaceholder(
      snapshot: searchTracksSnapshot,
      child: CustomScrollView(
        slivers: [
          if (searchTracksSnapshot.hasValue && searchTracks.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      Undraw(
                        height: 120,
                        illustration: UndrawIllustration.taken,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        context.l10n.nothing_found,
                        textAlign: TextAlign.center,
                      ).muted().small(),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverGrid.builder(
                itemCount: shown.length,
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
                itemBuilder: (context, index) {
                  final track = shown[index];
                  return TrackCard(
                    imageUrl: trackCardImageUrl(track),
                    title: track.name,
                    subtitle: track.album.name,
                    locked: PremiumAccess.isTrackLocked(track, ref),
                    cardBgColor: track.cardBgColor,
                    cardTextColor: track.cardTextColor,
                    onTap: () => playTrack(index),
                  );
                },
              ),
            ),
            if (hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
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
                ),
              ),
          ],
          // Reserve space so the floating player footer never covers the
          // last grid row.
          SliverToBoxAdapter(
            child: SizedBox(height: context.bottomPlayerReserve),
          ),
        ],
      ),
    );
  }
}
