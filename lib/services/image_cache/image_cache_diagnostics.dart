/// Reports the artwork cache's own numbers from inside the app, on demand.
///
/// WHY THIS EXISTS
/// ---------------
/// "Is the artwork still on disk after a restart" cannot be answered from a
/// release build by looking at the device:
///
///  * `flutter_cache_manager` writes into the app's private cache directory
///    (`<temporaryDirectory>/<cacheKey>`), which is unreadable without root, and
///    this app ships `android:allowBackup="false"`, so no backup trick either;
///  * `dumpsys diskstats`' per-package cache gauge is stale - measured on a real
///    device, it did not move after `pm trim-caches` freed the caches;
///  * `cmd storagestats`, the on-demand API Settings uses, does not exist on
///    Android 11;
///  * `du` on `/data/data/<pkg>` is denied to the shell user.
///
/// So the app reports it itself. A build compiled with
/// `--dart-define=IMAGE_CACHE_DIAGNOSTICS=true` logs one line per call:
///
///     [IMGDIAG] after-home-load files=37 bytes=4194304 written_since_launch=9
///
/// `written_since_launch` is the number that answers the question: files whose
/// mtime is newer than this process's start are files this launch downloaded. A
/// second launch of the same screen that still reports a large number is a cache
/// that does not survive a restart, which is precisely the defect the tuned
/// manager exists to prevent.
///
/// COST WHEN DISABLED
/// ------------------
/// None. [imageCacheDiagnosticsEnabled] is a compile-time constant, so a normal
/// build has no timer, no directory walk and no logging: the call sites collapse
/// to a `false` check. The strings are still in the binary, which is the only
/// price and is not worth a conditional import.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sangeet/services/image_cache/app_image_cache_manager.dart';

/// Whether this build was compiled with `IMAGE_CACHE_DIAGNOSTICS=true`.
const bool imageCacheDiagnosticsEnabled =
    bool.fromEnvironment('IMAGE_CACHE_DIAGNOSTICS');

/// When this process started, used to tell "already on disk" from "downloaded
/// this launch". Set by [imageCacheDiagnosticsStart].
DateTime? _launchTime;

/// Marks the start of this launch. Call once, as early as possible.
void imageCacheDiagnosticsStart() {
  if (!imageCacheDiagnosticsEnabled) return;
  _launchTime = DateTime.now();
}

/// Logs the artwork cache's file count, size, and how many files this launch
/// wrote. A no-op unless the build was compiled with the flag.
Future<void> logImageCacheDiagnostics(String label) async {
  if (!imageCacheDiagnosticsEnabled) return;
  try {
    final temp = await getTemporaryDirectory();
    // Same layout flutter_cache_manager uses: IOFileSystem.createDirectory()
    // puts the cache under `<temporaryDirectory>/<cacheKey>`.
    final dir = Directory('${temp.path}/${AppImageCacheManager.key}');

    var files = 0;
    var bytes = 0;
    var writtenSinceLaunch = 0;
    if (await dir.exists()) {
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) continue;
        final stat = await entry.stat();
        files++;
        bytes += stat.size;
        final started = _launchTime;
        if (started != null && stat.modified.isAfter(started)) {
          writtenSinceLaunch++;
        }
      }
    }
    debugPrint(
      '[IMGDIAG] $label files=$files bytes=$bytes '
      'written_since_launch=$writtenSinceLaunch',
    );
  } catch (e) {
    // Diagnostics must never be the reason a screen fails.
    debugPrint('[IMGDIAG] $label failed: $e');
  }
}
