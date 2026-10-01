import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

/// Pure dedupe for the endless-playback radio append: drops the currently
/// playing track and any track already present in the queue, preserving the
/// incoming order. Tested in isolation so the toggle's append behavior stays
/// verifiable without an audio engine.
List<SangeetTrackObject> dedupeRadioTracks(
  Iterable<SangeetTrackObject> incoming,
  List<SangeetTrackObject> queue,
  String currentTrackId,
) {
  final known = <String>{currentTrackId, ...queue.map((t) => t.id)};
  return [
    for (final t in incoming)
      if (!known.contains(t.id)) t,
  ];
}

void useEndlessPlayback(WidgetRef ref) {
  final playback = ref.watch(audioPlayerProvider.notifier);
  final audioPlayerState = ref.watch(audioPlayerProvider);
  final endlessPlayback =
      ref.watch(userPreferencesProvider.select((s) => s.endlessPlayback));
  final metadataPlugin = ref.watch(metadataPluginProvider.future);

  useEffect(
    () {
      if (!endlessPlayback) return null;

      void listener(int index) async {
        try {
          final playlist = ref.read(audioPlayerProvider);
          if (index != playlist.tracks.length - 1) return;

          final track = playlist.tracks.last;

          final tracks = await (await metadataPlugin)?.track.radio(track.id);

          if (tracks == null || tracks.isEmpty) return;

          // Append at most the fresh tracks (not the current one, not queue
          // dupes); the engine preserves position across the rebuild.
          final deduped = dedupeRadioTracks(
            tracks.whereType<SangeetTrackObject>(),
            playlist.tracks,
            track.id,
          );
          if (deduped.isEmpty) return;
          await playback.addTracks(deduped);
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }

      // Sometimes user can change settings for which the currentIndexChanged
      // might not be called. So we need to check if the current track is the
      // last track and if it is then we need to call the listener manually.
      if (audioPlayerState.currentIndex == audioPlayerState.tracks.length - 1 &&
          audioPlayer.isPlaying) {
        listener(audioPlayerState.currentIndex);
      }

      final subscription =
          audioPlayer.currentIndexChangedStream.listen(listener);

      return subscription.cancel;
    },
    [
      metadataPlugin,
      playback,
      audioPlayerState.tracks,
      audioPlayerState.currentIndex,
      endlessPlayback,
    ],
  );
}
