import 'dart:io';

import 'package:media_kit/media_kit.dart' hide Track;
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:sangeet/services/audio_player/custom_player.dart';
import 'dart:async';

import 'package:media_kit/media_kit.dart' as mk;

import 'package:sangeet/services/audio_player/playback_state.dart';
import 'package:sangeet/utils/platform.dart';

part 'audio_players_streams_mixin.dart';
part 'audio_player_impl.dart';

class SangeetMedia extends mk.Media {
  static int serverPort = 0;
  static final Completer<int> _portReady = Completer<int>();

  static Future<void> ensurePortReady() async {
    if (serverPort == 0) {
      await _portReady.future;
    }
  }

  static void setPort(int port) {
    serverPort = port;
    if (!_portReady.isCompleted) {
      _portReady.complete(port);
    }
  }

  static String get _host =>
      kIsWindows ? "localhost" : "127.0.0.1";

  final SangeetTrackObject track;
  SangeetMedia(this.track)
      : assert(
          track is SangeetLocalTrackObject || track is SangeetFullTrackObject,
          "Track must be a either a local track or a full track object with ISRC",
        ),
        // If the track is a local track, use its path, otherwise use the server URL
        super(
          track is SangeetLocalTrackObject
              ? track.path
              : "http://$_host:$serverPort/stream/${track.id}",
          extras: track.toJson(),
        );

  factory SangeetMedia.media(Media media) {
    assert(media.extras != null, "[Media] must have extra metadata set");
    return SangeetMedia(SangeetTrackObject.fromJson(media.extras!));
  }
}

abstract class AudioPlayerInterface {
  final CustomPlayer _mkPlayer;

  AudioPlayerInterface()
      : _mkPlayer = CustomPlayer(
          configuration: const mk.PlayerConfiguration(
            title: "Sangeet",
            logLevel: kDebugMode ? mk.MPVLogLevel.info : mk.MPVLogLevel.error,
            async: true,
          ),
        ) {
    _mkPlayer.stream.error.listen((event) {
      AppLogger.reportError(event, StackTrace.current);
    });
  }

  /// Whether the current platform supports the audioplayers plugin
  static const bool _mkSupportedPlatform = true;

  bool get mkSupportedPlatform => _mkSupportedPlatform;

  Duration get duration {
    return _mkPlayer.state.duration;
  }

  Playlist get playlist {
    return _mkPlayer.state.playlist;
  }

  Duration get position {
    return _mkPlayer.state.position;
  }

  Duration get bufferedPosition {
    return _mkPlayer.state.buffer;
  }

  Future<mk.AudioDevice> get selectedDevice async {
    return _mkPlayer.state.audioDevice;
  }

  Future<List<mk.AudioDevice>> get devices async {
    return _mkPlayer.state.audioDevices;
  }

  bool get hasSource {
    return _mkPlayer.state.playlist.medias.isNotEmpty;
  }

  // states
  bool get isPlaying {
    return _mkPlayer.state.playing;
  }

  bool get isPaused {
    return !_mkPlayer.state.playing;
  }

  bool get isStopped {
    return !hasSource;
  }

  Future<bool> get isCompleted async {
    return _mkPlayer.state.completed;
  }

  bool get isShuffled {
    return _mkPlayer.shuffled;
  }

  PlaylistMode get loopMode {
    return _mkPlayer.state.playlistMode;
  }

  /// Returns the current volume of the player, between 0 and 1
  double get volume {
    return _mkPlayer.state.volume / 100;
  }

  bool get isBuffering {
    return _mkPlayer.state.buffering;
  }
}
