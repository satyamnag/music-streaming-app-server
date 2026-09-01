import 'dart:async';

import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/audio_player/playback_state.dart';
import 'package:sangeet/services/audio_player/playlist_mode.dart';

/// Engine-agnostic contract for the playback engine.
///
/// Operations are expressed in terms of [SangeetTrackObject] lists so the
/// notifier and UI do not depend on any specific engine (mpv vs just_audio).
/// Concrete engine implementations adapt to their own media/URI types
/// internally. The default engine is the established media_kit/mpv one.
///
/// IMPORTANT: this interface is additive and the existing mpv path remains the
/// default. It exists to allow an opt-in engine (e.g. just_audio) to be swapped
/// in behind the same contract without re-typing consumers.
abstract class AudioEngine {
  Future<void> openPlaylist(
    List<SangeetTrackObject> tracks, {
    int initialIndex = 0,
    bool autoPlay = false,
  });

  Future<void> addTrack(SangeetTrackObject track, {int? index});
  Future<void> removeTrack(int index);
  Future<void> moveTrack(int from, int to);
  Future<void> jumpTo(int index);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> seek(Duration position);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  Future<void> setLoopMode(PlaylistMode mode);
  Future<void> setShuffle(bool shuffle);
  Future<void> dispose();

  int get currentIndex;
  bool get isPlaying;
  bool get isPaused;
  bool get isShuffled;
  bool get isBuffering;
  Duration get position;
  Duration get bufferedPosition;
  Duration? get duration;
  PlaylistMode get loopMode;

  Stream<List<SangeetTrackObject>> get tracksStream;
  Stream<int> get indexStream;
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get completedStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration> get durationStream;
  Stream<PlaylistMode> get loopModeStream;
  Stream<bool> get shuffledStream;
  Stream<AudioPlaybackState> get playerStateStream;
}
