import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/services/sourced_track/r2_url.dart';
import 'package:sangeet/utils/platform.dart';

/// Which system sound to replace.
///
/// Android exposes three independent defaults; all three accept the same kind
/// of audio file, so one enum is enough to drive the native call.
enum RingtoneType { ringtone, notification, alarm }

/// True when the app was compiled with an R2 CDN base, i.e. when
/// [setFromStoragePath] can build a URL at all. Exposed so tests can assert the
/// correct branch without hardcoding the build environment.
bool get r2ConfiguredForTest => Env.r2BaseUrl.trim().isNotEmpty;

/// Dart side of the native ringtone bridge.
///
/// Ringtones are an Android-only concept: iOS has no public API to set one and
/// desktop platforms have no equivalent, so every method is a safe no-op that
/// returns false there. Callers must hide the UI affordance on those platforms.
///
/// Android additionally requires the user to grant "modify system settings"
/// (`WRITE_SETTINGS`), which is a special permission the user grants through a
/// system screen - not a runtime prompt. [canWrite] reports whether that has
/// happened; [requestWrite] opens the screen where they grant it.
class RingtoneService {
  RingtoneService._();
  static final RingtoneService instance = RingtoneService._();

  static const _channel = MethodChannel('com.soulfulbhakti.app/ringtone');

  /// Ringtones can only be set on Android.
  ///
  /// Overridable for tests: `dart:io`'s platform check is false under the test
  /// runner, which would otherwise make every method a no-op and leave the
  /// bridge untestable. Production never changes this.
  ///
  /// ignore: avoid_setters_without_getters
  @visibleForTesting
  static bool Function() isSupportedOverride = () => kIsAndroid;

  bool get isSupported => isSupportedOverride();

  /// True when the user has granted "modify system settings".
  ///
  /// Returns false on any error rather than throwing: a failure here must never
  /// crash the player, it should only hide/disable the action.
  Future<bool> canWrite() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canWrite') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system screen where the user grants "modify system settings".
  ///
  /// The user leaves the app for this screen, so callers should re-check
  /// [canWrite] when they resume rather than assuming the grant succeeded.
  Future<void> requestWrite() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('requestWrite');
    } catch (_) {
      // Swallow: the caller re-checks canWrite() on resume.
    }
  }

  /// Downloads the ringtone stored at [storagePath] (an R2 object key) and sets
  /// it as the chosen system sound.
  ///
  /// Returns false - never throws - when the platform is unsupported, the R2
  /// CDN base is not configured, the user has not granted `WRITE_SETTINGS`, or
  /// the download/MediaStore insert fails.
  Future<bool> setFromStoragePath(String storagePath, RingtoneType type) async {
    if (!isSupported) return false;
    if (storagePath.trim().isEmpty) return false;

    // Refuse rather than pass a null URL: r2StreamUrl returns null when the CDN
    // base is unconfigured, and the native side cannot fetch without it.
    final url = r2StreamUrl(storagePath);
    if (url == null) return false;

    try {
      return await _channel.invokeMethod<bool>('setRingtone', {
            'url': url,
            'type': type.name,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
