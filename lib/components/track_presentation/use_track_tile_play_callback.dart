import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sangeet/components/dialogs/select_device_dialog.dart';
import 'package:sangeet/components/track_presentation/presentation_props.dart';
import 'package:sangeet/components/track_presentation/presentation_state.dart';
import 'package:sangeet/extensions/list.dart';

import 'package:sangeet/models/connect/connect.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/connect/connect.dart';
import 'package:sangeet/provider/history/history.dart';

void _log(String msg) => print('[SANGEET] $msg');

Future<void> Function(SangeetTrackObject track, int index)
    useTrackTilePlayCallback(
  WidgetRef ref,
) {
  final context = useContext();
  final options = TrackPresentationOptions.of(context);
  final playlist = ref.watch(audioPlayerProvider);
  final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
  final historyNotifier = ref.watch(playbackHistoryActionsProvider);

  final isActive = useMemoized(
    () => playlist.collections.contains(options.collectionId),
    [playlist.collections, options.collectionId],
  );

  final onTapTrackTile =
      useCallback((SangeetTrackObject track, int index) async {
    _log('onTapTrackTile: track=${track.name} id=${track.id} index=$index');
    final state = ref.read(presentationStateProvider(options.collection));
    final notifier =
        ref.read(presentationStateProvider(options.collection).notifier);

    if (state.selectedTracks.isNotEmpty) {
      _log('onTapTrackTile: selection mode active');
      if (state.selectedTracks.contains(track)) {
        notifier.deselectTrack(track);
      } else {
        notifier.selectTrack(track);
      }
      return;
    }

    _log('onTapTrackTile: calling showSelectDeviceDialog...');
    final isRemoteDevice = await showSelectDeviceDialog(context, ref);
    _log('onTapTrackTile: isRemoteDevice=$isRemoteDevice');
    if (isRemoteDevice == null) return;

    if (isRemoteDevice) {
      final remotePlayback = ref.read(connectProvider.notifier);
      final remoteQueue = ref.read(queueProvider);
      if (remoteQueue.collections.contains(options.collectionId) ||
          remoteQueue.tracks.any((s) => s.id == track.id)) {
        _log('onTapTrackTile: remote jumpToTrack');
        await playlistNotifier.jumpToTrack(track);
      } else {
        _log('onTapTrackTile: remote onFetchAll...');
        final tracks = await options.pagination.onFetchAll();
        _log('onTapTrackTile: remote onFetchAll got ${tracks.length} tracks');
        await remotePlayback.load(
          options.collection is SangeetSimpleAlbumObject
              ? WebSocketLoadEventData.album(
                  tracks: tracks,
                  collection: options.collection as SangeetSimpleAlbumObject,
                  initialIndex: index,
                )
              : WebSocketLoadEventData.playlist(
                  tracks: tracks,
                  collection: options.collection as SangeetSimplePlaylistObject,
                  initialIndex: index,
                ),
        );
      }
    } else {
      if (isActive || playlist.tracks.containsBy(track, (a) => a.id)) {
        _log('onTapTrackTile: local jumpToTrack');
        await playlistNotifier.jumpToTrack(track);
      } else {
        _log('onTapTrackTile: local onFetchAll...');
        final tracks = await options.pagination.onFetchAll();
        _log('onTapTrackTile: local onFetchAll got ${tracks.length} tracks');
        await playlistNotifier.load(
          tracks,
          initialIndex: index,
          autoPlay: true,
        );
        _log('onTapTrackTile: load completed, adding collection...');
        playlistNotifier.addCollection(options.collectionId);
        if (options.collection is SangeetSimpleAlbumObject) {
          historyNotifier
              .addAlbums([options.collection as SangeetSimpleAlbumObject]);
        } else {
          historyNotifier.addPlaylists(
              [options.collection as SangeetSimplePlaylistObject]);
        }
      }
    }
  }, [isActive, playlist, options, playlistNotifier, historyNotifier]);

  return onTapTrackTile;
}
