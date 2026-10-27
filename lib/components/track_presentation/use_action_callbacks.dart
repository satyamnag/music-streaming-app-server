import 'dart:math';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/components/dialogs/select_device_dialog.dart';
import 'package:sangeet/components/track_presentation/presentation_actions.dart';
import 'package:sangeet/components/track_presentation/presentation_props.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

import 'package:sangeet/models/connect/connect.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/connect/connect.dart';
import 'package:sangeet/provider/history/history.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/logger/logger.dart';

typedef UseActionCallbacks = ({
  bool isActive,
  bool isLoading,
  Future<void> Function() onShuffle,
  Future<void> Function() onPlay,
  Future<void> Function() onAddToQueue,
});

UseActionCallbacks useActionCallbacks(WidgetRef ref) {
  final isLoading = useState(false);
  final context = useContext();
  final options = TrackPresentationOptions.of(context);
  final playlist = ref.watch(audioPlayerProvider);
  final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
  final historyNotifier = ref.watch(playbackHistoryActionsProvider);

  final isActive = useMemoized(
    () => playlist.collections.contains(options.collectionId),
    [playlist.collections, options.collectionId],
  );

  // One gate for the whole collection. Every track — free or paid — now needs a
  // signed-in user before it can be listened to, so the gate runs for EVERY
  // collection and not only for a locked (paid) one; PremiumAccess presents the
  // sign-in dialog and, when the collection is paid, the paywall on top.
  // [feature] is a no-op here: access is granted by the sign-in/purchase itself,
  // not by playing something.
  Future<bool> ensureCollectionUnlocked() async {
    return PremiumAccess.gateAlbumPlay(
      context: context,
      ref: ref,
      album: options.collection,
      feature: () async {},
    );
  }

  final onShuffle = useCallback(() async {
    try {
      isLoading.value = true;

      if (!await ensureCollectionUnlocked()) return;

      final initialTracks = options.tracks;
      if (!context.mounted) return;

      final isRemoteDevice = await showSelectDeviceDialog(context, ref);
      if (isRemoteDevice == null) return;
      if (isRemoteDevice) {
        final allTracks = await options.pagination.onFetchAll();
        final remotePlayback = ref.read(connectProvider.notifier);
        await remotePlayback.load(
          options.collection is SangeetSimpleAlbumObject
              ? WebSocketLoadEventData.album(
                  tracks: allTracks,
                  collection: options.collection as SangeetSimpleAlbumObject,
                  initialIndex: Random().nextInt(allTracks.length))
              : WebSocketLoadEventData.playlist(
                  tracks: allTracks,
                  collection: options.collection as SangeetSimplePlaylistObject,
                  initialIndex: Random().nextInt(allTracks.length),
                ),
        );
        await remotePlayback.setShuffle(true);
      } else {
        await playlistNotifier.load(
          initialTracks,
          autoPlay: true,
          initialIndex: Random().nextInt(initialTracks.length),
        );
        await audioPlayer.setShuffle(true);
        playlistNotifier.addCollection(options.collectionId);
        if (options.collection is SangeetSimpleAlbumObject) {
          historyNotifier
              .addAlbums([options.collection as SangeetSimpleAlbumObject]);
        } else {
          historyNotifier.addPlaylists(
              [options.collection as SangeetSimplePlaylistObject]);
        }

        final allTracks = await options.pagination.onFetchAll();

        await playlistNotifier.addTracks(
          allTracks.sublist(initialTracks.length),
        );
      }
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }, [options, playlistNotifier, historyNotifier]);

  final onPlay = useCallback(() async {
    try {
      isLoading.value = true;

      if (!await ensureCollectionUnlocked()) return;

      final initialTracks = options.tracks;

      if (!context.mounted) return;

      final isRemoteDevice = await showSelectDeviceDialog(context, ref);
      if (isRemoteDevice == null) return;
      if (isRemoteDevice) {
        final allTracks = await options.pagination.onFetchAll();

        final remotePlayback = ref.read(connectProvider.notifier);
        await remotePlayback.load(
          options.collection is SangeetSimpleAlbumObject
              ? WebSocketLoadEventData.album(
                  tracks: allTracks,
                  collection: options.collection as SangeetSimpleAlbumObject,
                )
              : WebSocketLoadEventData.playlist(
                  tracks: allTracks,
                  collection: options.collection as SangeetSimplePlaylistObject,
                ),
        );
      } else {
        if (initialTracks.isEmpty) return;

        await playlistNotifier.load(initialTracks, autoPlay: true);
        playlistNotifier.addCollection(options.collectionId);

        if (options.collection is SangeetSimpleAlbumObject) {
          historyNotifier.addAlbums(
            [options.collection as SangeetSimpleAlbumObject],
          );
        } else {
          historyNotifier.addPlaylists(
            [options.collection as SangeetSimplePlaylistObject],
          );
        }

        final allTracks = await options.pagination.onFetchAll();

        await playlistNotifier.addTracks(
          allTracks.sublist(initialTracks.length),
        );
      }
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      rethrow;
    } finally {
      if (context.mounted) {
        isLoading.value = false;
      }
    }
  }, [options, playlistNotifier, historyNotifier]);

  final onAddToQueue = useCallback(() async {
    if (!await ensureCollectionUnlocked()) return;
    final tracks = options.tracks;
    playlistNotifier.addTracks(tracks);
    playlistNotifier.addCollection(options.collectionId);
    if (options.collection is SangeetSimpleAlbumObject) {
      historyNotifier
          .addAlbums([options.collection as SangeetSimpleAlbumObject]);
    } else {
      historyNotifier
          .addPlaylists([options.collection as SangeetSimplePlaylistObject]);
    }
    if (!context.mounted) return;
    showToastForAction(context, "add-to-queue", tracks.length);
  }, [options, playlistNotifier, historyNotifier]);

  return (
    isActive: isActive,
    isLoading: isLoading.value,
    onShuffle: onShuffle,
    onPlay: onPlay,
    onAddToQueue: onAddToQueue,
  );
}
