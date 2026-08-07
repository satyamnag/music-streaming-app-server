import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/dialogs/playlist_add_track_dialog.dart';
import 'package:sangeet/components/dialogs/prompt_dialog.dart';
import 'package:sangeet/components/dialogs/track_details_dialog.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/local_tracks/local_tracks_provider.dart';
import 'package:sangeet/provider/metadata_plugin/core/auth.dart';
import 'package:sangeet/provider/metadata_plugin/library/playlists.dart';
import 'package:sangeet/provider/metadata_plugin/library/tracks.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/services/metadata/errors/exceptions.dart';

enum TrackOptionValue {
  share,
  addToPlaylist,
  addToQueue,
  removeFromPlaylist,
removeFromQueue,
    delete,
  playNext,
  favorite,
  details,
  startRadio,
}

class TrackOptionsActions {
  final Ref ref;
  final SangeetTrackObject track;

  TrackOptionsActions(this.ref, this.track);

  AudioPlayerNotifier get playback => ref.read(audioPlayerProvider.notifier);
  MetadataPluginSavedTracksNotifier get favoriteTracks =>
      ref.read(metadataPluginSavedTracksProvider.notifier);
  MetadataPluginSavedPlaylistsNotifier get favoritePlaylistsNotifier =>
      ref.read(metadataPluginSavedPlaylistsProvider.notifier);

  void actionShare(BuildContext context) {
    // Share the song via the platform's native share sheet (ACTION_SEND on
    // Android), so the user can send it to WhatsApp, Facebook, SMS, etc.
    final shareText = track.name.isNotEmpty
        ? track.name
        : (track.externalUri.isNotEmpty ? track.externalUri : 'Soulful Bhakti');
    SharePlus.instance.share(ShareParams(text: shareText));
  }

  Future<void> actionAddToPlaylist(
    BuildContext context,
    String? playlistId,
  ) async {
    /// showDialog doesn't work for some reason. So we have to
    /// manually push a Dialog Route in the Navigator to get it working
    await showDialog(
      context: context,
      builder: (context) {
        return PlaylistAddTrackDialog(
          tracks: [track],
          openFromPlaylist: playlistId,
        );
      },
    );
  }

  Future<void> actionStartRadio(BuildContext context) async {
    final playback = ref.read(audioPlayerProvider.notifier);
    final playlist = ref.read(audioPlayerProvider);
    final metadataPlugin = await ref.read(metadataPluginProvider.future);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    final tracks = await metadataPlugin.track.radio(track.id);

    bool replaceQueue = false;

    if (context.mounted && playlist.tracks.isNotEmpty) {
      replaceQueue = await showPromptDialog(
        context: context,
        title: context.l10n.how_to_start_radio,
        message: context.l10n.replace_queue_question,
        okText: context.l10n.replace,
        cancelText: context.l10n.add_to_queue,
      );
    }

    if (replaceQueue || playlist.tracks.isEmpty) {
      await playback.stop();
      await playback.load([track], autoPlay: true);

      // we don't have to add those tracks as useEndlessPlayback will do it for us
      return;
    } else {
      await playback.addTrack(track);
    }

    await playback.addTracks(
      tracks.toList()
        ..removeWhere((e) {
          final isDuplicate = playlist.tracks.any((t) => t.id == e.id);
          return e.id == track.id || isDuplicate;
        }),
    );
  }

  Future<void> action(
    BuildContext context,
    TrackOptionValue value,
    String? playlistId,
  ) async {
    switch (value) {
      case TrackOptionValue.delete:
        await File((track as SangeetLocalTrackObject).path).delete();
        ref.invalidate(localTracksProvider);
        break;
      case TrackOptionValue.addToQueue:
        await playback.addTrack(track);
        if (context.mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) {
              return SurfaceCard(
                child: Text(
                  context.l10n.added_track_to_queue(track.name),
                  textAlign: TextAlign.center,
                ),
              );
            },
          );
        }
        break;
      case TrackOptionValue.playNext:
        await playback.addTracksAtFirst([track]);

        if (context.mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) {
              return SurfaceCard(
                child: Text(
                  context.l10n.track_will_play_next(track.name),
                  textAlign: TextAlign.center,
                ),
              );
            },
          );
        }
        break;
      case TrackOptionValue.removeFromQueue:
        playback.removeTrack(track.id);

        if (context.mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) {
              return SurfaceCard(
                child: Text(
                  context.l10n.removed_track_from_queue(
                    track.name,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          );
        }
        break;
      case TrackOptionValue.favorite:
        final isLikedTrack = await ref.read(
          isLikedSongProvider(track.id).future,
        );

        if (isLikedTrack) {
          await unlikeTrack(track.id);
        } else {
          await likeTrack(track.id);
        }
        ref.invalidate(likedSongsProvider);
        break;
      case TrackOptionValue.addToPlaylist:
        actionAddToPlaylist(context, playlistId);
        break;
      case TrackOptionValue.removeFromPlaylist:
        favoritePlaylistsNotifier.removeTracks(playlistId ?? "", [track.id]);
        break;
      case TrackOptionValue.share:
        actionShare(context);
        break;
      case TrackOptionValue.details:
        if (track is! SangeetFullTrackObject) break;
        showDialog(
          context: context,
          builder: (context) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TrackDetailsDialog(track: track as SangeetFullTrackObject),
          ),
        );
        break;
      case TrackOptionValue.startRadio:
        actionStartRadio(context);
        break;
    }
  }
}

typedef TrackOptionFlags = ({
  bool isInQueue,
  bool isActiveTrack,
  bool isAuthenticated,
  bool isLiked,
});

final trackOptionActionsProvider =
    Provider.family<TrackOptionsActions, SangeetTrackObject>(
  (ref, track) => TrackOptionsActions(ref, track),
);

final trackOptionsStateProvider =
    Provider.family<TrackOptionFlags, SangeetTrackObject>((ref, track) {
  final playlist = ref.watch(audioPlayerProvider);
  final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
  final isSavedTrack = ref.watch(isLikedSongProvider(track.id));

  return (
    isInQueue: playlist.containsTrack(track),
    isActiveTrack: playlist.activeTrack?.id == track.id,
    isAuthenticated: authenticated.asData?.value ?? false,
    isLiked: isSavedTrack.asData?.value ?? false,
  );
});
