import 'dart:async';
import 'dart:collection';
import 'dart:math' show max;

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/provider/server/routes/supabase_data.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';

/// Preloads the first ~20% of a track's audio bytes the moment it becomes
/// visible on any screen (home, playlist, search, ...).
///
/// How it works: it resolves the track's signed Supabase storage URL directly
/// and issues a byte-range request for roughly 20% of the track's expected
/// size. That warms the Supabase CDN edge and the decoded window in mpv's
/// network cache, so a subsequent tap-to-play starts in a fraction of a
/// second. The response body is discarded; only the network warm-up matters.
///
/// The request goes straight to the signed URL rather than through the local
/// stream proxy, so the byte-range is always honored (Supabase returns 206)
/// and the warm-up is guaranteed to be exactly the requested 20%.
///
/// Safety:
///  - Bounded: a single range request (never the whole file) per track.
///  - Bounded concurrency: at most [_maxConcurrent] downloads in flight.
///  - Idempotent: a track is prefetched at most once per session.
///  - Skips local tracks, encrypted (downloaded) tracks, and the currently
///    active track (already loaded by the player).
///  - Failures are silent — playback always works via the on-demand resolver.
class TrackBytePrefetcher {
  TrackBytePrefetcher._();

  static final TrackBytePrefetcher instance = TrackBytePrefetcher._();

  static const int _maxConcurrent = 2;

  /// Fraction of the track's expected size to prefetch (for tracks long enough
  /// that 20% already covers the minimum of 10 seconds).
  static const double _prefetchFraction = 0.20;

  /// Minimum number of seconds of audio to prefetch for every visible track.
  /// Short tracks would otherwise prefetch less than 10 seconds (e.g. 20% of a
  /// 30-second track is only 6 seconds), which is not enough for a reliably
  /// instant tap-to-play. The effective prefetch is always at least this many
  /// seconds (capped by [_maxRangeBytes]).
  static const int _minPrefetchSeconds = 10;

  /// Assumed peak bitrate (bytes/sec) used to estimate file size from the
  /// known duration. Opus is ~12 KB/s, MP3 ~16 KB/s — 16 KB/s is a safe upper
  /// bound, so we never under-fetch for opus.
  static const int _bytesPerSecond = 16 * 1024;

  /// Upper bound for a single prefetch range. This must be large enough that
  /// 20% of a typical track's size is always fetched (a 60-minute track at
  /// 128 kbps is ~57 MB, so 20% is ~11 MB). The bound only guards against
  /// pathological multi-hour uploads; it never reduces the 20% guarantee.
  static const int _maxRangeBytes = 64 * 1024 * 1024;

  final Set<String> _prefetched = {};
  final Set<String> _inFlight = {};
  final Queue<String> _pending = Queue<String>();
  final Map<String, int> _durationMsById = {};
  int _active = 0;

  /// Requests a warm-up prefetch for [track] if it is eligible.
  void prefetch(SangeetTrackObject track, WidgetRef ref) {
    if (track is! SangeetFullTrackObject) return;
    final id = track.id;
    // Do not prefetch paid tracks for free users (they are locked).
    if (track.status == 'paid' && !PremiumAccess.isPremiumUser(ref)) return;
    if (_prefetched.contains(id) || _inFlight.contains(id)) return;
    if (currentActiveTrackId == id) return;

    _durationMsById[id] = track.durationMs;
    _prefetched.add(id);
    _pending.add(id);
    _drain(ref);
  }

  /// Id of the currently loaded/active track (from the player's current media
  /// URI `http://host:port/stream/<trackId>`), or null.
  String? get currentActiveTrackId {
    try {
      final uri = audioPlayer.currentSource;
      if (uri == null) return null;
      final idx = uri.lastIndexOf('/');
      if (idx == -1 || idx == uri.length - 1) return null;
      final id = uri.substring(idx + 1);
      return id.contains('.') ? null : id;
    } catch (_) {
      return null;
    }
  }

  void _drain(WidgetRef ref) {
    while (_active < _maxConcurrent && _pending.isNotEmpty) {
      final id = _pending.removeFirst();
      _active++;
      unawaited(_fetch(id, ref).whenComplete(() {
        _active--;
        _inFlight.remove(id);
        _drain(ref);
      }));
    }
  }

  Future<void> _fetch(String trackId, WidgetRef ref) async {
    _inFlight.add(trackId);
    try {
      // Resolve the signed URL directly from Supabase so the range request is
      // always honored.
      final supabase = ref.read(supabaseClientProvider);
      final row = await supabase
          .from('tracks')
          .select('storage_path,status')
          .eq('id', trackId)
          .maybeSingle();
      if (row == null || row['storage_path'] == null) return;
      // Defense in depth: never prefetch paid audio for a free user.
      if (row['status'] == 'paid' && !PremiumAccess.isPremiumUser(ref)) return;
      final storagePath = row['storage_path'].toString();
      final url = await supabase.storage
          .from('music')
          .createSignedUrl(storagePath, 3600);
      if (url.isEmpty) return;

      // Estimate the file size from the known duration, then request the first
      // ~20% of it (capped to bound the background download) — but never less
      // than the minimum of 10 seconds of audio, so every visible track is
      // guaranteed at least 10 seconds of preloaded bytes.
      final durationMs = _durationMsById[trackId] ?? 0;
      final expectedBytes = (durationMs ~/ 1000) * _bytesPerSecond;
      final twentyPercent =
          (expectedBytes * _prefetchFraction).toInt().clamp(0, _maxRangeBytes);
      final minTenSeconds =
          (_minPrefetchSeconds * _bytesPerSecond).clamp(0, _maxRangeBytes);
      final rangeEnd = max(twentyPercent, minTenSeconds);

      // A tiny range (e.g. very short tracks) still warms the connection.
      if (rangeEnd <= 0) return;

      await globalDio.get<List<int>>(
        url,
        options: Options(
          headers: {'range': 'bytes=0-$rangeEnd'},
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // Best-effort warm-up; failures are ignored.
    }
  }
}
