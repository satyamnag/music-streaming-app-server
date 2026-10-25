import 'package:audio_service/audio_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_services/mobile_audio_service.dart';
import 'package:sangeet/services/audio_services/windows_audio_service.dart';
import 'package:sangeet/services/image_cache/app_image_cache_manager.dart';
import 'package:sangeet/utils/platform.dart';

class AudioServices with WidgetsBindingObserver {
  final MobileAudioService? mobile;
  final WindowsAudioService? smtc;

  AudioServices(this.mobile, this.smtc) {
    WidgetsBinding.instance.addObserver(this);
  }

  static Future<AudioServices> create(
    Ref ref,
    AudioPlayerNotifier playback,
  ) async {
    final mobile = kIsMobile || kIsMacOS || kIsLinux
        ? await AudioService.init(
            builder: () => MobileAudioService(playback),
            config: AudioServiceConfig(
              androidNotificationChannelId: switch ((
                kIsLinux,
                Env.releaseChannel
              )) {
                (true, _) => "sangeet",
                (_, ReleaseChannel.stable) => "com.soulfulbhakti.app",
                (_, ReleaseChannel.nightly) => "com.soulfulbhakti.app.nightly",
              },
              androidNotificationChannelName: 'Sangeet',
              androidNotificationOngoing: false,
              androidStopForegroundOnPause: false,
              androidNotificationChannelDescription: "Soulful Bhakti Media Controls",
            ),
          )
        : null;
    final smtc = kIsWindows ? WindowsAudioService(ref, playback) : null;

    return AudioServices(mobile, smtc);
  }

  Future<void> addTrack(SangeetTrackObject track) async {
    await smtc?.addTrack(track);
    mobile?.addItem(MediaItem(
      id: track.id,
      album: track.album.name,
      title: track.name,
      artist: track.artists.asString(),
      duration: Duration(milliseconds: track.durationMs),
      artUri: await _notificationArtUri(track),
      playable: true,
    ));
  }

  /// The notification's artwork URI, preferring the copy already on disk.
  ///
  /// audio_service officially supports `file://`, `http(s)://` and
  /// `content://` for [MediaItem.artUri]. The URL chosen is exactly the one the
  /// UI uses ([SangeetImageExtensions.asUri]), so both surfaces share one cache
  /// entry - but when that entry is already cached the FILE is handed over
  /// instead of the URL. That is the difference, on a weak connection, between
  /// a cover in the notification and an empty box: the media notification then
  /// draws from disk without opening a socket.
  ///
  /// Deliberately a lookup, not a fetch: `getFileFromCache` never downloads, so
  /// a track whose art is not cached yet keeps the network URL it always had and
  /// nothing is prefetched behind the reader's back here.
  Future<Uri?> _notificationArtUri(SangeetTrackObject track) async {
    final images = track.album.images;
    if (images.isEmpty) return null;
    final uri = images.asUri(placeholder: ImagePlaceholder.albumArt);
    if (uri == null) return null;
    try {
      final cached = await AppImageCacheManager().getFileFromCache(
        uri.toString(),
      );
      if (cached != null) return cached.file.uri;
    } catch (_) {
      // Any cache problem: fall back to the network URL, as before.
    }
    return uri;
  }

  void activateSession() {
    mobile?.session?.setActive(true);
  }

  void deactivateSession() {
    mobile?.session?.setActive(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        deactivateSession();
        audioPlayer.pause();
        break;
      default:
        break;
    }
  }

  void dispose() {
    smtc?.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }
}
