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
  bool _pausedByNoisy = false;
  int _errorRetryCount = 0;
  static const int _maxErrorRetries = 3;
  String? _positionSaveKey;
  int _lastSavedPosition = 0;
  int _lastSaveTime = 0;

  CustomPlayer({super.configuration})
      : _playerStateStream = StreamController.broadcast() {
    nativePlayer.setProperty("network-timeout", "120");
    nativePlayer.setProperty("cache", "yes");
    nativePlayer.setProperty("cache-secs", "60");
    nativePlayer.setProperty("demuxer-max-bytes", "100M");
    nativePlayer.setProperty("demuxer-max-back-bytes", "50M");
    nativePlayer.setProperty("gapless-audio", "yes");
    nativePlayer.setProperty("audio-pitch-correction", "no");

    _subscriptions = [
      stream.buffering.listen((event) {
        _playerStateStream.add(AudioPlaybackState.buffering);
      }),
      stream.playing.listen((playing) {
        if (playing) {
          _errorRetryCount = 0;
          _playerStateStream.add(AudioPlaybackState.playing);
        } else {
          _playerStateStream.add(AudioPlaybackState.paused);
        }
      }),
      stream.completed.listen((isCompleted) async {
        if (!isCompleted) return;
        _errorRetryCount = 0;
        _lastSavedPosition = 0;
        _playerStateStream.add(AudioPlaybackState.completed);
      }),
      stream.playlist.listen((event) {
        if (event.medias.isEmpty) {
          _playerStateStream.add(AudioPlaybackState.stopped);
        }
      }),
      stream.position.listen((pos) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final posMs = pos.inMilliseconds;
        if (posMs > 0 && posMs != _lastSavedPosition && now - _lastSaveTime > 10000) {
          _lastSavedPosition = posMs;
          _lastSaveTime = now;
        }
      }),
      stream.error.listen((event) {
        AppLogger.reportError('[MediaKitError] \n$event', StackTrace.current);
        if (_errorRetryCount < _maxErrorRetries && state.playlist.index >= 0) {
          _errorRetryCount++;
          final idx = state.playlist.index;
          final medias = state.playlist.medias;
          if (idx < medias.length) {
            Future.delayed(Duration(seconds: _errorRetryCount), () {
              jump(idx);
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
            _pausedByNoisy = true;
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

  /// Restores playback to a saved position after app restart.
  /// Call this after opening a playlist.
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
