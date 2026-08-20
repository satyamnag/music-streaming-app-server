import 'dart:async';
import 'package:sangeet/services/logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:audio_session/audio_session.dart';
// ignore: implementation_imports
import 'package:sangeet/services/audio_player/playback_state.dart';
import 'package:sangeet/utils/platform.dart';

/// MediaKit [Player] by default doesn't have a state stream.
/// This class adds a state stream to the [Player] class.
class CustomPlayer extends Player {
  final StreamController<AudioPlaybackState> _playerStateStream;

  late final List<StreamSubscription> _subscriptions;

  int _androidAudioSessionId = 0;
  String _packageName = "";
  AndroidAudioManager? _androidAudioManager;
  bool _pausedByInterruption = false;
  int _errorRetryCount = 0;
  static const int _maxErrorRetries = 3;
  int _lastSavedPosition = 0;
  int _lastSaveTime = 0;

  // Buffering stall recovery (mirrors the web player's waiting/stalled watchdog):
  // when playback enters buffering with no position advance, wait up to
  // [_stallTimeout] then retry the SAME track (re-open at the current position).
  // Bounded by [_maxStallRetries]; reset whenever playback successfully advances.
  Timer? _stallTimer;
  int _stallRetryCount = 0;
  static const Duration _stallTimeout = Duration(seconds: 5);
  static const int _maxStallRetries = 3;
  Duration _positionAtStallStart = Duration.zero;

  CustomPlayer({super.configuration})
      : _playerStateStream = StreamController.broadcast() {
    nativePlayer.setProperty("network-timeout", "120");
    nativePlayer.setProperty("cache", "yes");
    // Sixty-minute network cache lookahead: mpv keeps up to this much decoded
    // audio buffered ahead of the playhead, so buffering pauses are avoided as
    // long as the network can keep up. (Official mpv manual: "How many seconds
    // of audio/video to prefetch if the cache is active.")
    nativePlayer.setProperty("cache-secs", "3600");
    // Low-connectivity smooth start: enter "buffering" mode before playback and
    // wait until ~5s of audio is buffered, so playback does not start then
    // immediately underrun on a slow network. (Official mpv manual:
    // cache-pause-initial "can be used to ensure playback starts smoothly, in
    // exchange for waiting some time to prefetch network data".) The stall
    // watchdog below still re-opens the track if buffering gets stuck.
    nativePlayer.setProperty("cache-pause-initial", "yes");
    nativePlayer.setProperty("cache-pause-wait", "5");
    // Byte caps large enough to hold 60 minutes at high bitrates: 60 min at
    // 320 kbps is ~144 MB, at lossless ~630 MB — 512M comfortably covers the
    // catalog while still bounding memory.
    nativePlayer.setProperty("demuxer-max-bytes", "512M");
    nativePlayer.setProperty("demuxer-max-back-bytes", "256M");
    nativePlayer.setProperty("gapless-audio", "yes");
    nativePlayer.setProperty("audio-pitch-correction", "no");
    // Never auto-advance to the next track: mpv must stop at the end of the
    // current track (or on an error) instead of skipping ahead. Only an
    // explicit user action (next / previous / selecting another song) should
    // change the playing track. This prevents the "skips through songs
    // without playing" behaviour.
    nativePlayer.setProperty("keep-open", "always");

    _subscriptions = [
      stream.buffering.listen((event) {
        _playerStateStream.add(AudioPlaybackState.buffering);
        if (event) {
          // Buffering started: note the current position and arm the stall
          // watchdog. If the player is still stuck without advancing after
          // [_stallTimeout], we retry the same track (bounded).
          _positionAtStallStart = state.position;
          _stallTimer?.cancel();
          _stallTimer = Timer(_stallTimeout, () {
            if (!state.buffering) return;
            final now = state.position;
            final advanced = now > _positionAtStallStart;
            if (advanced) return; // still making progress — keep waiting
            if (_stallRetryCount >= _maxStallRetries) return;
            _stallRetryCount++;
            final idx = state.playlist.index;
            final medias = state.playlist.medias;
            if (idx < 0 || idx >= medias.length) return;
            final resumePos = _positionAtStallStart;
            // Re-open the same media (never advance to the next track) and
            // restore the playhead so the stall recovers in place.
            open(Playlist(medias, index: idx), play: true).then((_) {
              return seek(resumePos);
            });
          });
        } else {
          _stallTimer?.cancel();
          _stallTimer = null;
        }
      }),
      stream.playing.listen((playing) {
        if (playing) {
          _errorRetryCount = 0;
          _stallRetryCount = 0;
          _playerStateStream.add(AudioPlaybackState.playing);
        } else {
          _playerStateStream.add(AudioPlaybackState.paused);
        }
      }),
      stream.completed.listen((isCompleted) async {
        if (!isCompleted) return;
        _errorRetryCount = 0;
        _stallRetryCount = 0;
        _lastSavedPosition = 0;
        _playerStateStream.add(AudioPlaybackState.completed);
      }),
      stream.playlist.listen((event) {
        if (event.medias.isEmpty) {
          _playerStateStream.add(AudioPlaybackState.stopped);
        }
      }),
      stream.position.listen((pos) {
        // Any forward position movement means playback is progressing, so a
        // buffering stall is not stuck — reset the watchdog.
        if (pos > _positionAtStallStart) {
          _stallRetryCount = 0;
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final posMs = pos.inMilliseconds;
        if (posMs > 0 && posMs != _lastSavedPosition && now - _lastSaveTime > 10000) {
          _lastSavedPosition = posMs;
          _lastSaveTime = now;
        }
      }),
      stream.error.listen((event) {
        AppLogger.reportError('[MediaKitError] \n$event', StackTrace.current);
        // On error, pause and stay on the current track rather than letting
        // mpv advance. If the stream URL is stale/expired, refresh it and
        // retry the same track a limited number of times.
        if (_errorRetryCount < _maxErrorRetries && state.playlist.index >= 0) {
          _errorRetryCount++;
          final idx = state.playlist.index;
          final medias = state.playlist.medias;
          if (idx < medias.length) {
            pause();
            Future.delayed(Duration(seconds: _errorRetryCount), () {
              // Re-open the same media (not the next one) so playback resumes
              // on the current track. With keep-open=always, mpv will not
              // advance past it.
              open(Playlist(medias, index: idx), play: true);
            });
          }
        }
      }),
    ];
    PackageInfo.fromPlatform().then((packageInfo) {
      _packageName = packageInfo.packageName;
    });
    if (kIsAndroid) {
      _androidAudioManager = AndroidAudioManager();
      AudioSession.instance.then((s) async {
        // Configure audio session for music playback per official docs:
        // https://github.com/ryanheise/audio_session#configure
        await s.configure(const AudioSessionConfiguration(
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));

        // Handle audio interruptions (phone calls, other apps) per official docs:
        // https://github.com/ryanheise/audio_session#interruption-event-stream
        s.interruptionEventStream.listen((event) {
          if (event.begin) {
            switch (event.type) {
              case AudioInterruptionType.pause:
              case AudioInterruptionType.unknown:
                if (state.playing) {
                  _pausedByInterruption = true;
                  pause();
                }
                break;
              case AudioInterruptionType.duck:
                // Will auto-duck due to androidWillPauseWhenDucked: true
                break;
            }
          } else {
            if (_pausedByInterruption) {
              _pausedByInterruption = false;
              play();
            }
          }
        });

        // Pause on headphone unplug per official docs:
        // https://github.com/ryanheise/audio_session#becoming-noisy
        s.becomingNoisyEventStream.listen((_) {
          if (state.playing) {
            pause();
          }
        });

        _androidAudioSessionId =
            await _androidAudioManager!.generateAudioSessionId();
        notifyAudioSessionUpdate(true);

        await nativePlayer.setProperty(
          "audiotrack-session-id",
          _androidAudioSessionId.toString(),
        );
        await nativePlayer.setProperty("ao", "audiotrack,opensles,");
      });
    }
  }

  Future<void> notifyAudioSessionUpdate(bool active) async {
    if (kIsAndroid) {
      sendBroadcast(
        BroadcastMessage(
          name: active
              ? "android.media.action.OPEN_AUDIO_EFFECT_CONTROL_SESSION"
              : "android.media.action.CLOSE_AUDIO_EFFECT_CONTROL_SESSION",
          data: {
            "android.media.extra.AUDIO_SESSION": _androidAudioSessionId,
            "android.media.extra.PACKAGE_NAME": _packageName
          },
        ),
      );
    }
  }

  bool get shuffled => state.shuffle;

  Stream<AudioPlaybackState> get playerStateStream => _playerStateStream.stream;
  Stream<bool> get shuffleStream => stream.shuffle;
  Stream<int> get indexChangeStream {
    int oldIndex = state.playlist.index;
    return stream.playlist.map((event) => event.index).where((newIndex) {
      if (newIndex != oldIndex) {
        oldIndex = newIndex;
        return true;
      }
      return false;
    });
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    await super.setShuffle(shuffle);
  }

  @override
  Future<void> stop() async {
    await super.stop();

    _playerStateStream.add(AudioPlaybackState.stopped);
  }

  @override
  Future<void> dispose() async {
    _stallTimer?.cancel();
    _stallTimer = null;
    for (var element in _subscriptions) {
      element.cancel();
    }
    await notifyAudioSessionUpdate(false);
    return super.dispose();
  }

  NativePlayer get nativePlayer => platform as NativePlayer;

  Future<void> insert(int index, Media media) async {
    final addedMediaCompleter = Completer<int>();
    final playlistStream = stream.playlist.listen(
      (event) {
        final mediaAddedIndex =
            event.medias.indexWhere((m) => m.uri == media.uri);
        if (mediaAddedIndex != -1 && !addedMediaCompleter.isCompleted) {
          addedMediaCompleter.complete(mediaAddedIndex);
        }
      },
    );
    try {
      await add(media);
      final mediaAddedIndex = await addedMediaCompleter.future;
      await move(mediaAddedIndex, index);
    } finally {
      playlistStream.cancel();
    }
  }

  Future<void> setAudioNormalization(bool normalize) async {
    if (normalize) {
      await nativePlayer.setProperty('af', 'dynaudnorm=g=5:f=250:r=0.9:p=0.5');
    } else {
      await nativePlayer.setProperty('af', '');
    }
  }

  Future<void> setDemuxerBufferSize(int sizeInBytes) async {
    await nativePlayer.setProperty('demuxer-max-bytes', sizeInBytes.toString());
    await nativePlayer.setProperty(
      'demuxer-max-back-bytes',
      sizeInBytes.toString(),
    );
  }

  /// Crossfade: sets duration in seconds between tracks. 0 = disabled.
  Future<void> setCrossfade(int durationSeconds) async {
    if (durationSeconds > 0) {
      await nativePlayer.setProperty('audio-delay', (-durationSeconds * 0.5).toString());
      await nativePlayer.setProperty('gapless-audio', 'weak');
    } else {
      await nativePlayer.setProperty('audio-delay', '0');
      await nativePlayer.setProperty('gapless-audio', 'yes');
    }
  }

  /// Sets the 10-band graphic equalizer using mpv audio filter.
  /// Gains: -12 to +12 dB for each band. Frequencies: [31,62,125,250,500,1k,2k,4k,8k,16k] Hz.
  Future<void> setEqualizer(List<double> gains) async {
    if (gains.length != 10) return;
    const freq = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    final filterParts = <String>[];
    for (int i = 0; i < 10; i++) {
      final g = gains[i].clamp(-12.0, 12.0);
      filterParts.add('equalizer=${freq[i]}:0.5:${g.toStringAsFixed(1)}');
    }
    await nativePlayer.setProperty('af', filterParts.join(','));
  }

  /// Resets equalizer to flat (0 dB for all bands).
  Future<void> resetEqualizer() async {
    await nativePlayer.setProperty('af', '');
  }

  /// Sets pitch without changing playback speed (0.5 to 2.0, 1.0 = normal).
  Future<void> setPitch(double pitch) async {
    await nativePlayer.setProperty('pitch', pitch.toStringAsFixed(3));
  }

  /// Restores playback to a saved position after app restart.
  Future<void> restorePosition({required int savedPositionMs, required int trackIndex}) async {
    if (savedPositionMs <= 0) return;
    if (state.playlist.index != trackIndex) {
      await jump(trackIndex);
    }
    await seek(Duration(milliseconds: savedPositionMs));
  }

  /// Gets the last saved position for persistence.
  int get savedPosition => _lastSavedPosition;
}
