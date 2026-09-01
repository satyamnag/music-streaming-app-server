import 'package:sangeet/models/metadata/metadata.dart';
import 'dart:async';

import 'package:sangeet/services/audio_player/just_audio_engine.dart';
import 'package:sangeet/services/audio_player/playback_state.dart';
import 'package:sangeet/services/audio_player/playlist_mode.dart';
import 'package:sangeet/utils/platform.dart';

/// A [SangeetTrackObject] plus its playable stream URI, engine-agnostic.
class SangeetMedia {
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

  /// Playable URI: local path for local tracks, or the local stream-server
  /// endpoint (which audits paid-track access) for full tracks.
  String get uri {
    if (track is SangeetLocalTrackObject) {
      return (track as SangeetLocalTrackObject).path;
    }
    return 'http://$_host:$serverPort/stream/${track.id}';
  }

  SangeetMedia(this.track)
      : assert(
          track is SangeetLocalTrackObject || track is SangeetFullTrackObject,
          "Track must be a either a local track or a full track object with ISRC",
        );

  /// Playable URI for a track, engine-agnostic (used by just_audio). When
  /// [karaoke] is true and the track has a karaoke file, the local stream
  /// server serves the karaoke variant via the `?variant=karaoke` query param.
  static String uriFor(SangeetTrackObject track, {bool karaoke = false}) {
    if (track is SangeetLocalTrackObject) return track.path;
    final suffix = karaoke && track is SangeetFullTrackObject &&
            (track.karaokeStoragePath?.trim().isNotEmpty ?? false)
        ? '?variant=karaoke'
        : '';
    return 'http://$_host:$serverPort/stream/${track.id}$suffix';
  }
}

/// A just_audio-backed playback engine exposing the same public surface the
/// app's notifier and consumers rely on. It preserves the prior method names
/// (openPlaylist, addTrackAt, moveTrack, jumpTo, etc.) so callers are unchanged,
/// while delegating playback to the platform ExoPlayer via just_audio.
class SangeetAudioPlayer {
  final JustAudioEngine _bridge;

  SangeetAudioPlayer() : _bridge = JustAudioEngine();

  Future<void> pause() => _bridge.pause();
  Future<void> resume() => _bridge.resume();
  Future<void> stop() => _bridge.stop();
  Future<void> seek(Duration position) => _bridge.seek(position);

  /// Volume is between 0 and 1
  Future<void> setVolume(double volume) => _bridge.setVolume(volume);

  Future<void> setSpeed(double speed) => _bridge.setSpeed(speed);

  Future<void> setAudioDevice(Object device) async {
    // just_audio does not support arbitrary audio-device switching.
  }

  /// No switchable output devices (just_audio); the connect/devices UI shows
  /// an empty list so nothing can be selected incorrectly.
  Future<List<AudioOutputDevice>> get devices async => const [];
  Stream<List<AudioOutputDevice>> get devicesStream =>
      const Stream<List<AudioOutputDevice>>.empty();
  Future<AudioOutputDevice?> get selectedDevice async => null;
  Stream<AudioOutputDevice?> get selectedDeviceStream =>
      const Stream<AudioOutputDevice?>.empty();

  Future<void> dispose() => _bridge.dispose();

  // Playlist related

  Future<void> openPlaylist(
    List<SangeetMedia> tracks, {
    bool autoPlay = true,
    int initialIndex = 0,
  }) async {
    assert(tracks.isNotEmpty);
    assert(initialIndex <= tracks.length - 1);
    await _bridge.openPlaylist(
      tracks.map((e) => e.track).toList(),
      initialIndex: initialIndex,
      autoPlay: autoPlay,
    );
  }

  List<String> get sources => _bridge.sources;
  String? get currentSource => _bridge.currentSource;
  String? get nextSource => _bridge.nextSource;
  String? get previousSource => _bridge.previousSource;
  int get currentIndex => _bridge.currentIndex;

  Future<void> skipToNext() => _bridge.skipToNext();
  Future<void> skipToPrevious() => _bridge.skipToPrevious();
  Future<void> jumpTo(int index) => _bridge.jumpTo(index);

  Future<void> addTrack(SangeetMedia media) =>
      _bridge.addTrack(media.track, index: null);

  Future<void> addTrackAt(SangeetMedia media, int index) =>
      _bridge.addTrack(media.track, index: index);

  Future<void> removeTrack(int index) => _bridge.removeTrack(index);

  Future<void> moveTrack(int from, int to) => _bridge.moveTrack(from, to);

  Future<void> clearPlaylist() => _bridge.stop();

  Future<void> setShuffle(bool shuffle) => _bridge.setShuffle(shuffle);

  Future<void> setKaraoke(bool karaoke) => _bridge.setKaraoke(karaoke);

  Future<void> setLoopMode(PlaylistMode loop) => _bridge.setLoopMode(loop);

  Future<void> setAudioNormalization(bool normalize) async {
    // just_audio does not expose mpv's dynamic audio normalization.
  }

  Future<void> setDemuxerBufferSize(int sizeInBytes) async {
    // just_audio manages its own network buffer; no-op.
  }

  // Streams & state forwarded from the engine
  Stream<Duration> get durationStream => _bridge.durationStream;
  Stream<Duration> get positionStream => _bridge.positionStream;
  Stream<Duration> get bufferedPositionStream => _bridge.bufferedPositionStream;
  Stream<bool> get completedStream => _bridge.completedStream;
  Stream<bool> get playingStream => _bridge.playingStream;
  Stream<bool> get shuffledStream => _bridge.shuffledStream;
  Stream<PlaylistMode> get loopModeStream => _bridge.loopModeStream;
  Stream<double> get volumeStream => _bridge.volumeStream;
  Stream<bool> get bufferingStream => _bridge.bufferingStream;
  Stream<AudioPlaybackState> get playerStateStream => _bridge.playerStateStream;
  Stream<int> get currentIndexChangedStream => _bridge.currentIndexChangedStream;
  Stream<String> get activeSourceChangedStream =>
      _bridge.activeSourceChangedStream;
  Stream<String> get errorStream => _bridge.errorStream;
  Stream<List<SangeetTrackObject>> get playlistTrackStream =>
      _bridge.playlistTrackStream;

  // Future<string?>.playlistStream-like: expose current tracks so the notifier
  // can rebuild its state from a playlist update.
  Stream<List<SangeetTrackObject>> get playlistStream =>
      _bridge.playlistTrackStream;

  List<SangeetTrackObject> get playlistTracks => _bridge.tracks;
  bool get isPlaying => _bridge.isPlaying;
  bool get isPaused => _bridge.isPaused;
  bool get isStopped => _bridge.isStopped;
  bool get isShuffled => _bridge.isShuffled;
  PlaylistMode get loopMode => _bridge.loopMode;
  bool get isBuffering => _bridge.isBuffering;
  Duration get position => _bridge.position;
  Duration get bufferedPosition => _bridge.bufferedPosition;
  Duration get duration => _bridge.duration ?? Duration.zero;
  bool get hasSource => _bridge.tracks.isNotEmpty;
  double get volume => _bridge.volume;
  Future<bool> get isCompleted async => _bridge.isCompleted;
  bool get mkSupportedPlatform => true;
}

/// A minimal audio-output-device descriptor for the connect/devices UI.
///
/// just_audio does not expose arbitrary output-device switching on Android, so
/// the device picker surfaces no entries (a deliberate option-1 feature drop).
class AudioOutputDevice {
  final String name;
  final String description;
  const AudioOutputDevice(this.name, this.description);
}

final audioPlayer = SangeetAudioPlayer();
