import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/audio_player/state.dart';
import 'package:sangeet/provider/discord_provider.dart';
import 'package:sangeet/provider/history/history.dart';
import 'package:sangeet/provider/metadata_plugin/core/scrobble.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/server/sourced_track_provider.dart';
import 'package:sangeet/provider/skip_segments/skip_segments.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_services/audio_services.dart';
import 'package:sangeet/services/dio/dio.dart';
import 'package:sangeet/services/logger/logger.dart';

class AudioPlayerStreamListeners {
  final Ref ref;
  late final AudioServices notificationService;
  AudioPlayerStreamListeners(this.ref) {
    AudioServices.create(ref, ref.read(audioPlayerProvider.notifier)).then(
      (value) => notificationService = value,
    );

    final subscriptions = [
      subscribeToPlaylist(),
      subscribeToSkipSponsor(),
      subscribeToScrobbleChanged(),
      subscribeToPosition(),
      subscribeToPlayerError(),
      subscribeToCompleted(),
    ];

    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
  }

  UserPreferences get preferences => ref.read(userPreferencesProvider);
  DiscordNotifier get discord => ref.read(discordProvider.notifier);
  AudioPlayerState get audioPlayerState => ref.read(audioPlayerProvider);
  PlaybackHistoryActions get history =>
      ref.read(playbackHistoryActionsProvider);

  StreamSubscription subscribeToPlaylist() {
    return audioPlayer.playlistStream.listen((mpvPlaylist) {
      try {
        if (audioPlayerState.activeTrack == null) return;
        notificationService.addTrack(audioPlayerState.activeTrack!);
        discord.updatePresence(audioPlayerState.activeTrack!);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  StreamSubscription subscribeToSkipSponsor() {
    return audioPlayer.positionStream.listen((position) async {
      try {
        final currentSegments = await ref.read(segmentProvider.future);

        if (currentSegments?.segments.isNotEmpty != true ||
            position < const Duration(seconds: 3)) {
          return;
        }

        for (final segment in currentSegments!.segments) {
          final seconds = position.inSeconds;

          if (seconds < segment.start || seconds >= segment.end) continue;

          await audioPlayer.seek(Duration(seconds: segment.end + 1));
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  StreamSubscription subscribeToScrobbleChanged() {
    String? lastScrobbled;
    return audioPlayer.positionStream.listen((position) async {
      try {
        final uid = audioPlayerState.activeTrack is SangeetLocalTrackObject
            ? (audioPlayerState.activeTrack as SangeetLocalTrackObject).path
            : audioPlayerState.activeTrack?.id;

        /// A scrobble should be sent after 4 minutes of listening or 50% of
        /// the track duration, whichever is less.
        final minimumListenTime = min(audioPlayer.duration.inSeconds ~/ 2, 240);

        if (audioPlayerState.activeTrack == null ||
            lastScrobbled == uid ||
            position.inSeconds < minimumListenTime ||
            audioPlayer.duration == Duration.zero ||
            position == Duration.zero) {
          return;
        }

        ref
            .read(metadataPluginScrobbleProvider.notifier)
            .scrobble(audioPlayerState.activeTrack!);
        lastScrobbled = uid;
        /// The [Track] from Playlist.getTracks doesn't contain artist images
        /// so we need to fetch them from the API
        var activeTrack = audioPlayerState.activeTrack!;
        if (activeTrack.artists.any((a) => a.images == null)) {
          final metadataPlugin = await ref.read(metadataPluginProvider.future);
          final artists = await Future.wait(
            activeTrack.artists
                .map((artist) => metadataPlugin!.artist.getArtist(artist.id)),
          );
          activeTrack = activeTrack.copyWith(
            artists: artists
                .map((e) => SangeetSimpleArtistObject.fromJson(e.toJson()))
                .toList(),
          );
        }

        await history.addTrack(activeTrack);

        // Record the play globally so "Top Trending" reflects listening across
        // all users. Fire-and-forget: analytics must never block or fail
        // playback.
        if (activeTrack is SangeetFullTrackObject) {
          unawaited(
            _recordGlobalPlay(activeTrack.id),
          );
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  StreamSubscription subscribeToPosition() {
    String lastTrack = "";
    int lastSaveMs = 0;
    return audioPlayer.positionStream.listen((event) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final posMs = event.inMilliseconds;
      final percentProgress =
          (event.inSeconds / max(audioPlayer.duration.inSeconds, 1)) * 100;

      // Save playback position every 10 seconds for crash recovery
      if (posMs > 0 && audioPlayerState.currentIndex >= 0) {
        final saveInterval = nowMs - lastSaveMs;
        if (saveInterval > 10000) {
          lastSaveMs = nowMs;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('last_position_ms', posMs);
            await prefs.setInt('last_track_index', audioPlayerState.currentIndex);
          } catch (_) {}
        }
      }

      try {
        if (percentProgress < 80 ||
            audioPlayerState.currentIndex == -1 ||
            audioPlayerState.currentIndex ==
                audioPlayerState.tracks.length - 1) {
          return;
        }
        final nextTrack = audioPlayerState.tracks
            .elementAtOrNull(audioPlayerState.currentIndex + 1);

        if (nextTrack == null ||
            lastTrack == nextTrack.id ||
            nextTrack is SangeetLocalTrackObject) {
          return;
        }

        try {
          await ref.read(
            sourcedTrackProvider(nextTrack as SangeetFullTrackObject).future,
          );
        } finally {
          lastTrack = nextTrack.id;
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  StreamSubscription subscribeToPlayerError() {
    return audioPlayer.errorStream.listen((event) {});
  }

  /// Advances to the next track **only** when the current song finishes
  /// successfully (a genuine natural completion — the song played all the way
  /// through to its end).
  ///
  /// Guarantees:
  ///  - mpv `keep-open=always` means the player NEVER advances on its own,
  ///    either at EOF or on an error. This handler is the ONLY thing that moves
  ///    to the next track, and it reacts exclusively to a `completed=true`
  ///    event, which mpv only fires after the media reaches its true end.
  ///  - Mid-track it can never skip: errors pause + retry the same track, and
  ///    no other code path changes the index.
  ///  - User-initiated skips (next / previous / selecting another song) go
  ///    directly through the player API and always win.
  ///
  /// We use [SangeetAudioPlayer.jumpTo] (an explicit playlist-pos write) rather
  /// than [SangeetAudioPlayer.skipToNext]: media_kit's `next()` first calls
  /// `play()`, and when `state.completed` is true (right after EOF) `play()`
  /// resets the playlist position to 0 — which would corrupt the target index.
  /// `jump()` always ends with the requested index, so it is reliable after a
  /// natural completion.
  StreamSubscription subscribeToCompleted() {
    // The stream emits `true` on EOF and `false` whenever playback is reset
    // (open/seek/stop) — only a `true` event means the song finished naturally.
    return audioPlayer.completedStream.where((completed) => completed).listen(
          (_) async {
            try {
              final state = audioPlayerState;
              if (state.tracks.isEmpty || state.currentIndex < 0) return;
              final currentIndex = state.currentIndex;

              int? targetIndex;
              switch (audioPlayer.loopMode) {
                case PlaylistMode.loop:
                  // Repeat-all: wrap to the first track after the last one.
                  targetIndex = currentIndex >= state.tracks.length - 1
                      ? 0
                      : currentIndex + 1;
                case PlaylistMode.single:
                  // Repeat-one: replay the same track.
                  targetIndex = currentIndex;
                case PlaylistMode.none:
                  // Normal queue: advance unless we are on the last track.
                  if (currentIndex < state.tracks.length - 1) {
                    targetIndex = currentIndex + 1;
                  }
              }

              if (targetIndex == null || targetIndex == currentIndex) {
                return;
              }
              await audioPlayer.jumpTo(targetIndex);
            } catch (e, stack) {
              AppLogger.reportError(e, stack);
            }
          },
        );
  }

  /// POSTs a play to the local server which records it in the global
  /// `song_plays` table (via the SECURITY DEFINER `record_play` RPC). Failures
  /// are swallowed so analytics never interrupts playback.
  Future<void> _recordGlobalPlay(String trackId) async {
    try {
      await SangeetMedia.ensurePortReady();
      await globalDio.post(
        'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/plays',
        data: {'track_id': trackId},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (_) {
      // Analytics must never affect playback.
    }
  }
}

final audioPlayerStreamListenersProvider =
    Provider<AudioPlayerStreamListeners>(AudioPlayerStreamListeners.new);
