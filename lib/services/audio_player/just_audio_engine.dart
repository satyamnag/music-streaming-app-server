import 'dart:async';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/audio_player/audio_engine.dart';
import 'package:sangeet/services/audio_player/audio_player.dart'
    show SangeetMedia;
import 'package:sangeet/services/audio_player/playback_state.dart';
import 'package:sangeet/services/audio_player/playlist_mode.dart';

/// A `just_audio`-backed gapless [AudioEngine] for [SangeetTrackObject]
/// playlists.
///
/// On Android it uses the platform ExoPlayer under the hood, which natively
/// performs gapless playlist playback and robust HTTP rebuffering. Implements
/// the engine-agnostic [AudioEngine] contract so the notifier/UI can use it
/// without depending on a specific engine.
class JustAudioEngine implements AudioEngine {
  final ja.AudioPlayer _player = ja.AudioPlayer();

  final StreamController<List<SangeetTrackObject>> _tracksCtrl =
      StreamController.broadcast();
  final StreamController<int> _indexCtrl = StreamController.broadcast();
  final StreamController<bool> _playingCtrl = StreamController.broadcast();
  final StreamController<bool> _bufferingCtrl = StreamController.broadcast();
  final StreamController<bool> _completedCtrl = StreamController.broadcast();
  final StreamController<Duration> _positionCtrl = StreamController.broadcast();
  final StreamController<Duration> _bufferedCtrl = StreamController.broadcast();
  final StreamController<Duration> _durationCtrl = StreamController.broadcast();
  final StreamController<PlaylistMode> _loopCtrl = StreamController.broadcast();
  final StreamController<bool> _shuffleCtrl = StreamController.broadcast();
  final StreamController<AudioPlaybackState> _stateCtrl =
      StreamController.broadcast();

  List<SangeetTrackObject> _tracks = [];
  int _index = -1;
  PlaylistMode _loopMode = PlaylistMode.none;
  bool _shuffle = false;
  bool _karaoke = false;
  final List<StreamSubscription> _subs = [];

  JustAudioEngine() {
    _subs.add(_player.sequenceStateStream.listen((seq) {
      if (seq == null) return;
      final newIndex = seq.currentIndex;
      if (newIndex != _index) {
        _index = newIndex;
        _indexCtrl.add(newIndex);
      }
    }));
    _subs.add(_player.playingStream.listen((p) => _playingCtrl.add(p)));
    _subs.add(_player.playerStateStream.listen((s) {
      _bufferingCtrl.add(
        s.processingState == ja.ProcessingState.loading ||
            s.processingState == ja.ProcessingState.buffering,
      );
      _stateCtrl.add(fromJaPlayerState(s));
      if (s.processingState == ja.ProcessingState.completed) {
        _completedCtrl.add(true);
      }
    }));
    _subs.add(_player.positionStream.listen((p) => _positionCtrl.add(p)));
    _subs.add(
        _player.bufferedPositionStream.listen((p) => _bufferedCtrl.add(p)));
    _subs.add(_player.durationStream.listen((d) {
      if (d != null) _durationCtrl.add(d);
    }));
    _subs.add(_player.loopModeStream.listen((m) => _loopCtrl.add(fromJa(m))));
    _subs.add(_player.shuffleModeEnabledStream.listen((s) {
      _shuffle = s;
      _shuffleCtrl.add(s);
    }));
  }

  ja.AudioSource _source(SangeetTrackObject t) =>
      ja.AudioSource.uri(Uri.parse(SangeetMedia.uriFor(t, karaoke: _karaoke)));

  /// Whether the playlist is prepared LAZILY (the plugin's default).
  ///
  /// ## Why this is true again
  /// It was set to `false` (eager) to remove the buffering seam between tracks,
  /// and eager preparation does that by loading EVERY child of the queue up
  /// front. That is exactly what made tapping a track slow: a 20-track album, or
  /// a 100-track "see all" list, opened a stream for every item before the first
  /// one could start, and each of those goes through the local stream server,
  /// which resolves a signed URL and issues its own upstream HEAD before it
  /// serves a single byte. On a phone that is a network storm on every tap, and
  /// any one failed child could fail the whole `setAudioSource` call, so the
  /// track the user tapped sometimes never started at all.
  ///
  /// The just_audio API documentation for
  /// `ConcatenatingAudioSource.useLazyPreparation` states: "If
  /// [useLazyPreparation] is `true`, children will be loaded/buffered as late as
  /// possible before needed for playback (currently supported on Android, iOS,
  /// MacOS)". The default is `true`, and ExoPlayer still pre-rolls the NEXT item
  /// while the current one plays, so ordinary sequential playback stays gapless.
  /// What is dropped is preparing the WHOLE queue, which nothing needs.
  ///
  /// Verified against just_audio 0.9.46's own API documentation (the version
  /// pinned in `pubspec.lock`) for `ConcatenatingAudioSource` and
  /// `AudioPlayer.setAudioSource`.
  static const bool _eagerPreparation = true;

  /// The live playlist object handed to the platform, when one is loaded.
  ///
  /// Kept so queue edits can be applied INCREMENTALLY through its own
  /// `add`/`insert`/`removeAt`/`move`/`clear` methods. The just_audio API docs
  /// state that a `ConcatenatingAudioSource`'s "audio sources can be dynamically
  /// added, removed and reordered while the audio is playing" — which is what
  /// lets a queue edit leave the playing item's decoder and buffer untouched.
  ja.ConcatenatingAudioSource? _queue;

  /// Builds the playback queue, prepared EAGERLY — see [_eagerPreparation].
  ///
  /// Centralised so the eager setting cannot be applied on one code path
  /// (initial load) and forgotten on another (rebuild), which is exactly the
  /// drift that would bring the seam back after a karaoke toggle.
  ja.ConcatenatingAudioSource _concat() => ja.ConcatenatingAudioSource(
        children: _tracks.map(_source).toList(),
        useLazyPreparation: _eagerPreparation,
      );

  /// Applies the current loop/shuffle state.
  ///
  /// Set AFTER the source (the order matters: replacing the source resets these
  /// on the platform side), and awaited together so a caller cannot observe a
  /// half-configured player.
  Future<void> _applyModes() async {
    await _player.setLoopMode(toJa(_loopMode));
    await _player.setShuffleModeEnabled(_shuffle);
  }

  @override
  Future<void> openPlaylist(
    List<SangeetTrackObject> tracks, {
    int initialIndex = 0,
    bool autoPlay = false,
  }) async {
    _tracks = List.of(tracks);
    _tracksCtrl.add(_tracks);
    final queue = _concat();
    _queue = queue;
    await _player.setAudioSource(
      queue,
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
    );
    _index = initialIndex;
    _indexCtrl.add(initialIndex);
    // Start audio as soon as the source is ready.
    //
    // The loop/shuffle round trips below only decide what happens at the END of
    // a track, so awaiting them before `play()` added two platform-channel
    // round trips to every single tap for no audible benefit. They are issued
    // first and awaited together with the play call instead.
    final modes = _applyModes();
    if (autoPlay) unawaited(_player.play());
    await modes;
  }

  /// Rebuilds the queue, keeping the current track and position.
  ///
  /// ## When this is needed at all
  /// Only when the set of URIs genuinely changes for items already queued —
  /// in practice, switching original <-> karaoke, which rewrites every URI.
  /// Queue edits (add/remove/move) go through the live
  /// [ja.ConcatenatingAudioSource] instead, so they never come here.
  ///
  /// `setAudioSource` releases the decoder and the whole buffer, so it is
  /// audible; the position is therefore captured BEFORE the swap and restored
  /// after, and playback resumes only if it was actually playing.
  Future<void> _rebuild({int? atIndex}) async {
    final wasPlaying = _player.playing;
    final position = _player.position;
    final queue = _concat();
    _queue = queue;
    await _player.setAudioSource(
      queue,
      initialIndex: (atIndex ?? _index).clamp(0, _tracks.length - 1),
      initialPosition: position,
    );
    await _applyModes();
    // Restore playback: rebuilding the source (e.g. when "Endless playback"
    // radio-appends tracks at the end of the queue) must never restart the
    // currently playing track at 0:00.
    if (wasPlaying) _player.play();
  }

  @override
  Future<void> addTrack(SangeetTrackObject track, {int? index}) async {
    _tracks = List.of(_tracks)..add(track);
    _tracksCtrl.add(_tracks);
    final queue = _queue;
    if (queue == null) {
      await _rebuild();
      return;
    }
    // Mutate the LIVE queue. The playing item keeps its decoder and its buffer,
    // so appending (e.g. "Endless playback" radio) is inaudible.
    if (index != null && index >= 0 && index < queue.length) {
      await queue.insert(index, _source(track));
    } else {
      await queue.add(_source(track));
    }
  }

  @override
  Future<void> removeTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    _tracks = List.of(_tracks)..removeAt(index);
    _tracksCtrl.add(_tracks);
    final queue = _queue;
    if (queue == null) return;
    if (_tracks.isEmpty) {
      // Nothing left to play: clear the live queue rather than leaving a
      // dangling source the UI would still show.
      await queue.clear();
      _queue = null;
      _index = -1;
      _indexCtrl.add(-1);
      return;
    }
    await queue.removeAt(index);
  }

  @override
  Future<void> moveTrack(int from, int to) async {
    if (from < 0 || from >= _tracks.length || to < 0 || to >= _tracks.length) {
      return;
    }
    final list = List.of(_tracks);
    final t = list.removeAt(from);
    list.insert(to, t);
    _tracks = list;
    _tracksCtrl.add(_tracks);
    // Reordering is a platform-side move: no decoder, buffer or connection is
    // touched, so the currently playing track is not interrupted at all.
    await _queue?.move(from, to);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
  @override
  Future<void> jumpTo(int index) async {
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.play();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setLoopMode(PlaylistMode mode) async {
    _loopMode = mode;
    await _player.setLoopMode(toJa(mode));
    _loopCtrl.add(mode);
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    _shuffle = shuffle;
    await _player.setShuffleModeEnabled(shuffle);
    _shuffleCtrl.add(shuffle);
  }

  /// Reloads the current playlist with the given karaoke variant so the
  /// currently playing track switches between its original and karaoke audio.
  /// Preserves the playing track (index and position) so playback is seamless.
  /// This is a no-op when there is nothing loaded.
  ///
  /// ## Why the no-op guards matter
  /// Every URI in the queue changes when this flips, so the source genuinely has
  /// to be replaced — but only when the value ACTUALLY changes. The engine is
  /// called from the UI on every rebuild, so without the first guard a track
  /// would be torn down and re-buffered on unrelated frames.
  ///
  /// The second guard covers a track that has no karaoke file: `uriFor` returns
  /// the same URI for both variants, so the queue is identical and the audibly
  /// expensive reload would buy nothing.
  Future<void> setKaraoke(bool karaoke) async {
    if (_tracks.isEmpty) return;
    if (_karaoke == karaoke) return;
    if (_karaokeVariantAvailable() == false) return;
    final wasPlaying = _player.playing;
    final position = _player.position;
    final index = _index.clamp(0, _tracks.length - 1);
    _karaoke = karaoke;
    await _rebuild(atIndex: index);
    if (position > Duration.zero) {
      await _player.seek(position);
    }
    if (wasPlaying) _player.play();
  }

  /// Whether flipping the karaoke flag would change ANY track's URI.
  ///
  /// Mirrors the rule `SangeetMedia.uriFor` applies: the karaoke suffix is only
  /// added for a full track that actually has a karaoke file. When no track in
  /// the queue has one, the flag cannot alter a single URI, so the reload would
  /// cost the listener a buffer for no audible difference at all.
  bool _karaokeVariantAvailable() {
    for (final t in _tracks) {
      if (t is! SangeetFullTrackObject) continue;
      if (t.karaokeStoragePath?.trim().isNotEmpty ?? false) return true;
    }
    return false;
  }

  @override
  Future<void> dispose() async {
    _queue = null;
    await _player.dispose();
    for (final s in _subs) {
      await s.cancel();
    }
    for (final c in [
      _tracksCtrl,
      _indexCtrl,
      _playingCtrl,
      _bufferingCtrl,
      _completedCtrl,
      _positionCtrl,
      _bufferedCtrl,
      _durationCtrl,
      _loopCtrl,
      _shuffleCtrl,
      _stateCtrl,
    ]) {
      await c.close();
    }
  }

  @override
  int get currentIndex => _index;
  @override
  bool get isPlaying => _player.playing;
  @override
  bool get isPaused => !_player.playing;
  @override
  bool get isShuffled => _shuffle;
  @override
  PlaylistMode get loopMode => _loopMode;
  @override
  Duration get position => _player.position;
  @override
  Duration get bufferedPosition => _player.bufferedPosition;
  @override
  Duration? get duration => _player.duration;
  @override
  bool get isBuffering =>
      _player.processingState == ja.ProcessingState.loading ||
      _player.processingState == ja.ProcessingState.buffering;

  List<SangeetTrackObject> get tracks => _tracks;
  List<String> get sources =>
      _tracks.map((t) => SangeetMedia.uriFor(t)).toList();
  String? get currentSource => _index >= 0 && _index < _tracks.length
      ? SangeetMedia.uriFor(_tracks[_index])
      : null;
  String? get nextSource => _index + 1 >= 0 && _index + 1 < _tracks.length
      ? SangeetMedia.uriFor(_tracks[_index + 1])
      : null;
  String? get previousSource => _index - 1 >= 0 && _index - 1 < _tracks.length
      ? SangeetMedia.uriFor(_tracks[_index - 1])
      : null;
  bool get isStopped => _tracks.isEmpty;
  Future<bool> get isCompleted async =>
      _player.processingState == ja.ProcessingState.completed;
  double get volume => _player.volume;

  Stream<List<SangeetTrackObject>> get playlistTrackStream =>
      _tracksCtrl.stream;
  Stream<int> get currentIndexChangedStream => _indexCtrl.stream;
  Stream<String> get activeSourceChangedStream => _indexCtrl.stream
      .map((i) =>
          i >= 0 && i < _tracks.length ? SangeetMedia.uriFor(_tracks[i]) : '')
      .where((s) => s.isNotEmpty);
  Stream<String> get errorStream => StreamController<String>().stream;
  Stream<double> get volumeStream => _player.volumeStream;

  @override
  Stream<List<SangeetTrackObject>> get tracksStream => _tracksCtrl.stream;
  @override
  Stream<int> get indexStream => _indexCtrl.stream;
  @override
  Stream<bool> get playingStream => _playingCtrl.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  @override
  Stream<bool> get completedStream => _completedCtrl.stream;
  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufferedCtrl.stream;
  @override
  Stream<Duration> get durationStream => _durationCtrl.stream;
  @override
  Stream<PlaylistMode> get loopModeStream => _loopCtrl.stream;
  @override
  Stream<bool> get shuffledStream => _shuffleCtrl.stream;
  @override
  Stream<AudioPlaybackState> get playerStateStream => _stateCtrl.stream;
}

ja.LoopMode toJa(PlaylistMode mode) {
  switch (mode) {
    case PlaylistMode.single:
      return ja.LoopMode.one;
    case PlaylistMode.loop:
      return ja.LoopMode.all;
    case PlaylistMode.none:
      return ja.LoopMode.off;
  }
}

PlaylistMode fromJa(ja.LoopMode mode) {
  switch (mode) {
    case ja.LoopMode.one:
      return PlaylistMode.single;
    case ja.LoopMode.all:
      return PlaylistMode.loop;
    case ja.LoopMode.off:
      return PlaylistMode.none;
  }
}

AudioPlaybackState fromJaPlayerState(ja.PlayerState s) {
  if (!s.playing) {
    return s.processingState == ja.ProcessingState.completed
        ? AudioPlaybackState.completed
        : AudioPlaybackState.paused;
  }
  switch (s.processingState) {
    case ja.ProcessingState.loading:
    case ja.ProcessingState.buffering:
      return AudioPlaybackState.buffering;
    case ja.ProcessingState.ready:
      return AudioPlaybackState.playing;
    case ja.ProcessingState.completed:
      return AudioPlaybackState.completed;
    case ja.ProcessingState.idle:
      return AudioPlaybackState.stopped;
  }
}
