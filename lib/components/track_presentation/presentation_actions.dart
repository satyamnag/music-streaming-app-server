import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sangeet/components/dialogs/playlist_add_track_dialog.dart';
import 'package:sangeet/components/track_presentation/presentation_props.dart';
import 'package:sangeet/components/track_presentation/presentation_state.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/history/history.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

ToastOverlay showToastForAction(
  BuildContext context,
  String action,
  int count,
) {
  final message = switch (action) {
    "add-to-playlist" => (
        context.l10n.add_count_to_playlist(count),
        SangeetIcons.playlistAdd
      ),
    "add-to-queue" => (
        context.l10n.add_count_to_queue(count),
        SangeetIcons.queueAdd
      ),
    "play-next" => (
        context.l10n.play_count_next(count),
        SangeetIcons.lightning
      ),
    _ => ("", SangeetIcons.error),
  };

  return showToast(
    context: context,
    location: ToastLocation.topRight,
    builder: (context, overlay) {
      return SurfaceCard(
        child: Basic(
          leading: Icon(message.$2),
          title: Text(message.$1),
          leadingAlignment: Alignment.center,
          trailing: IconButton.ghost(
            size: ButtonSize.small,
            icon: const Icon(SangeetIcons.close),
            onPressed: () {
              overlay.close();
            },
          ),
        ),
      );
    },
  );
}

class TrackPresentationActionsSection extends HookConsumerWidget {
  const TrackPresentationActionsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final options = TrackPresentationOptions.of(context);

    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final historyNotifier = ref.watch(playbackHistoryActionsProvider);

    final state = ref.watch(presentationStateProvider(options.collection));
    final notifier =
        ref.watch(presentationStateProvider(options.collection).notifier);
    final selectedTracks = state.selectedTracks;

    return AdaptivePopSheetList(
      tooltip: context.l10n.more_actions,
      headings: [
        Text(
          context.l10n.more_actions,
          style: context.theme.typography.large,
        ),
      ],
      onSelected: (action) async {
        var tracks = selectedTracks;

        if (selectedTracks.isEmpty) {
          tracks = await options.pagination.onFetchAll();

          notifier.selectAllTracks();
        }

        if (!context.mounted) return;

        switch (action) {
          case "add-to-playlist":
            {
              if (context.mounted) {
                final worked = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return PlaylistAddTrackDialog(
                      openFromPlaylist: options.collectionId,
                      tracks: tracks.toList(),
                    );
                  },
                );

                if (!context.mounted || worked != true) return;
                showToastForAction(context, action, tracks.length);
              }
              break;
            }
          case "play-next":
            {
              playlistNotifier.addTracksAtFirst(tracks);
              playlistNotifier.addCollection(options.collectionId);
              if (options.collection is SangeetSimpleAlbumObject) {
                historyNotifier.addAlbums(
                    [options.collection as SangeetSimpleAlbumObject]);
              } else {
                historyNotifier.addPlaylists(
                    [options.collection as SangeetSimplePlaylistObject]);
              }
              notifier.deselectAllTracks();
              if (!context.mounted) return;
              showToastForAction(context, action, tracks.length);
              break;
            }
          case "add-to-queue":
            {
              playlistNotifier.addTracks(tracks);
              playlistNotifier.addCollection(options.collectionId);
              if (options.collection is SangeetSimpleAlbumObject) {
                historyNotifier.addAlbums(
                    [options.collection as SangeetSimpleAlbumObject]);
              } else {
                historyNotifier.addPlaylists(
                    [options.collection as SangeetSimplePlaylistObject]);
              }
              notifier.deselectAllTracks();
              if (!context.mounted) return;
              showToastForAction(context, action, tracks.length);
              break;
            }
          default:
        }

        if (!context.mounted) return;
      },
      icon: const Icon(SangeetIcons.moreVertical),
      variance: ButtonVariance.outline,
      items: (context) => [
        AdaptiveMenuButton(
          value: "add-to-playlist",
          leading: const Icon(SangeetIcons.playlistAdd),
          child: selectedTracks.isEmpty ||
                  selectedTracks.length == options.tracks.length
              ? Text(
                  context.l10n.add_all_to_playlist,
                )
              : Text(
                  context.l10n.add_count_to_playlist(selectedTracks.length),
                ),
        ),
        AdaptiveMenuButton(
          value: "add-to-queue",
          leading: const Icon(SangeetIcons.queueAdd),
          child: selectedTracks.isEmpty ||
                  selectedTracks.length == options.tracks.length
              ? Text(
                  context.l10n.add_all_to_queue,
                )
              : Text(
                  context.l10n.add_count_to_queue(selectedTracks.length),
                ),
        ),
        AdaptiveMenuButton(
          value: "play-next",
          leading: const Icon(SangeetIcons.lightning),
          child: selectedTracks.isEmpty ||
                  selectedTracks.length == options.tracks.length
              ? Text(
                  context.l10n.play_all_next,
                )
              : Text(
                  context.l10n.play_count_next(selectedTracks.length),
                ),
        ),
      ],
    );
  }
}
