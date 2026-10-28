/// A small persistent stale-while-revalidate cache for the app's read-only
/// catalogue data.
///
/// WHY THIS EXISTS
/// ---------------
/// Every screen in the app reads its data through the in-process HTTP server
/// (`/supabase/...`), which queries Supabase on each request. Nothing between
/// Supabase and the widget tree ever stored the result, so a screen paid the
/// full mobile round trip *every time it was opened*. Measured on a real device
/// against the `com.soulfulbhakti.app` server, before this cache existed:
///
///   GET /supabase/tracks            3406 ms (first) / 2866 ms (repeat)
///   GET /supabase/admin-albums      4086 ms (first) / 3699 ms (repeat)
///   GET /supabase/albums            1774 ms (first) / 1888 ms (repeat)
///   GET /supabase/playlists/<id>    1886 ms (first) / 1952 ms (repeat)
///
/// The repeat figure is the important one: it is the same as the first, which
/// proves there was no cache in the path rather than a cache that missed. Only
/// two caches existed, and neither covers this data:
///
///  * `AppImageCacheManager` caches *artwork* (`flutter_cache_manager`), and
///  * Riverpod's `ref.keepAlive()` keeps a provider's value for the *lifetime of
///    the process* - it is empty again on the next launch.
///
/// HOW IT WORKS
/// ------------
/// A value is returned straight from memory, or from a JSON file written by an
/// earlier run, so screen loads cost a file read instead of a network round
/// trip. If that value is older than its TTL it is still returned immediately
/// and refreshed in the background; the *next* request sees the fresh copy.
/// That is the classic stale-while-revalidate trade-off, and it is what makes a
/// page paint in a fraction of a second while still converging on live data.
///
/// Deliberate properties:
///
///  * **A miss is unchanged.** With nothing cached, the caller's `fetch` runs
///    and is awaited exactly as before, so first-launch behaviour, latency and
///    error handling are identical to the pre-cache code.
///  * **A failure never degrades a working screen.** A background refresh that
///    throws keeps the previous value; the caller's `fetch` error still
///    propagates on a miss, so existing route-level try/catch handling is
///    untouched.
///  * **Single flight.** Concurrent requests for the same key share one refresh,
///    so a burst of screens opening at once cannot multiply the traffic.
///  * **Bounded.** Disk persistence is used only for the catalogue-level keys
///    (a fixed set of ~12 small files); per-track entries stay in memory and are
///    evicted oldest-first, so the cache cannot grow without limit.
///  * **Stored outside the OS cache directory.** Files live in
///    `getApplicationSupportDirectory()` (`PathUtils.getFilesDir` on Android),
///    which "Clear cache" does not wipe - see the path_provider documentation
///    for that call. A screen must not go slow again merely because the OS
///    reclaimed a cache directory.
///
/// The values held here are catalogue metadata that is public to every client
/// (titles, artists, artwork URLs, lyrics, storage paths already served by the
/// existing endpoints). No user data, credentials or session material is
/// stored.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One cached value plus when it was stored.
class _Entry {
  final Object? value;

  /// When this value was fetched from the network - not when it was read from
  /// disk. Persisting the original timestamp is what lets a value survive a
  /// restart and still be recognised as stale.
  final DateTime storedAt;

  const _Entry(this.value, this.storedAt);

  bool isStale(Duration ttl) => DateTime.now().difference(storedAt) > ttl;
}

/// The on-disk shape of one entry: the value and its original fetch time.
class _Stored {
  final Object? value;
  final DateTime storedAt;

  const _Stored(this.value, this.storedAt);
}

class CatalogCache {
  CatalogCache({
    this.defaultTtl = const Duration(minutes: 2),
    Directory? directory,
    this.maxMemoryEntries = 256,
  }) : _directoryOverride = directory;

  /// The shared instance the server routes use.
  static final CatalogCache instance = CatalogCache();

  /// How long a value is considered fresh when the caller does not say.
  final Duration defaultTtl;

  /// Hard ceiling on in-memory entries, so the per-track keys (lyrics, stream
  /// URLs) cannot grow without bound. Oldest insertions are evicted first.
  final int maxMemoryEntries;

  final Directory? _directoryOverride;

  /// Values decoded and ready to hand back. [LinkedHashMap] keeps insertion
  /// order, which is what the eviction above walks.
  final LinkedHashMap<String, _Entry> _memory = LinkedHashMap<String, _Entry>();

  /// Background refreshes in flight, keyed so concurrent callers share one.
  final Map<String, Future<void>> _inflight = <String, Future<void>>{};

  /// Disk reads in flight / already done, so a key is read from disk once.
  final Map<String, Future<_Stored?>> _diskReads = <String, Future<_Stored?>>{};

  Directory? _directory;

  /// Resolves (and creates) the cache directory, or null when the platform has
  /// no writable application-support directory. A null directory simply means
  /// memory-only caching: the cache must never be the reason a screen fails.
  Future<Directory?> _resolveDirectory() async {
    if (_directory != null) return _directory;
    try {
      final dir = _directoryOverride ?? await getApplicationSupportDirectory();
      final cacheDir = Directory('${dir.path}${Platform.pathSeparator}catalog_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _directory = cacheDir;
      return cacheDir;
    } catch (_) {
      return null;
    }
  }

  /// A filename that is safe on every platform and cannot collide between keys.
  String _fileNameFor(String key) {
    const maxLength = 90;
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    // A long key is truncated and suffixed with a stable hash of the *whole*
    // key, so two long keys sharing a prefix still map to different files.
    if (safe.length <= maxLength) return '$safe.json';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return '${safe.substring(0, maxLength - 10)}-$hash.json';
  }

  Future<_Stored?> _readDisk(String key) {
    return _diskReads.putIfAbsent(key, () async {
      final dir = await _resolveDirectory();
      if (dir == null) return null;
      try {
        final file = File('${dir.path}${Platform.pathSeparator}${_fileNameFor(key)}');
        if (!await file.exists()) return null;
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) return null;
        final storedAtMs = decoded['at'];
        if (storedAtMs is! int) return null;
        return _Stored(
          decoded['value'],
          DateTime.fromMillisecondsSinceEpoch(storedAtMs),
        );
      } catch (_) {
        // Unreadable or corrupt entry: treat it as a miss and refetch.
        return null;
      }
    });
  }

  Future<void> _writeDisk(String key, _Entry entry) async {
    final dir = await _resolveDirectory();
    if (dir == null) return;
    final path = '${dir.path}${Platform.pathSeparator}${_fileNameFor(key)}';
    try {
      final payload = jsonEncode({
        'at': entry.storedAt.millisecondsSinceEpoch,
        'value': entry.value,
      });
      // Write-then-rename: a process killed mid-write must not leave a
      // half-written file that the next launch then fails to parse.
      final tmp = File('$path.tmp');
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(path);
    } catch (_) {
      // A cache that cannot write is still a working cache; the value stays in
      // memory for this session.
    }
  }

  void _remember(String key, _Entry entry) {
    _memory.remove(key);
    _memory[key] = entry;
    while (_memory.length > maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  /// Records [entry] as the current value of [key], in memory and - when the
  /// key is persisted - on disk.
  ///
  /// The disk-read cache is replaced with the new value rather than left
  /// holding the old parse: otherwise evicting the in-memory entry could
  /// resurrect a stale copy from that cache instead of the file just written.
  Future<void> _store(
    String key,
    _Entry entry, {
    required bool persist,
  }) async {
    _remember(key, entry);
    _diskReads[key] = Future<_Stored?>.value(
      _Stored(entry.value, entry.storedAt),
    );
    if (persist) await _writeDisk(key, entry);
  }

  /// Evicts [key] everywhere. Used by the explicit refresh path so a
  /// pull-to-refresh always shows live data instead of the cached copy.
  Future<void> evict(String key) async {
    _memory.remove(key);
    _diskReads.remove(key);
    final dir = await _resolveDirectory();
    if (dir == null) return;
    try {
      final file = File('${dir.path}${Platform.pathSeparator}${_fileNameFor(key)}');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing to evict.
    }
  }

  /// Evicts every catalog-level key.
  ///
  /// Deliberately does NOT touch the OS-level caches (artwork): this is about
  /// data freshness, and re-downloading artwork is not implied by a refresh.
  Future<void> clear() async {
    _memory.clear();
    _diskReads.clear();
    final dir = await _resolveDirectory();
    if (dir == null) return;
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Best effort.
    }
  }

  void _refreshInBackground<T>(
    String key,
    Future<T> Function() fetch,
    bool persist,
  ) {
    if (_inflight.containsKey(key)) return;
    _inflight[key] = () async {
      try {
        final value = await fetch();
        await _store(key, _Entry(value, DateTime.now()), persist: persist);
      } catch (_) {
        // Keep serving the previous value: a failed warm-up must never turn a
        // working screen into a broken one.
      } finally {
        _inflight.remove(key);
      }
    }();
  }

  /// The single entry point every typed helper below funnels through.
  ///
  /// Returns the cached value when one exists (refreshing it in the background
  /// when stale), and otherwise awaits [fetch] and stores the result - which is
  /// exactly what the caller did before this cache existed.
  Future<T> _resolve<T>({
    required String key,
    required Future<T> Function() fetch,
    required T Function(Object? json) decode,
    required bool persist,
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) await evict(key);

    final effectiveTtl = ttl ?? defaultTtl;

    final cached = _memory[key];
    if (cached != null) {
      if (cached.isStale(effectiveTtl)) {
        _refreshInBackground<T>(key, fetch, persist);
      }
      return cached.value as T;
    }

    if (persist) {
      final stored = await _readDisk(key);
      if (stored != null) {
        try {
          final value = decode(stored.value);
          final entry = _Entry(value, stored.storedAt);
          _remember(key, entry);
          if (entry.isStale(effectiveTtl)) {
            _refreshInBackground<T>(key, fetch, persist);
          }
          return value;
        } catch (_) {
          // Shape changed (or corrupt): fall through and refetch.
        }
      }
    }

    final value = await fetch();
    await _store(key, _Entry(value, DateTime.now()), persist: persist);
    return value;
  }

  /// Catalogue rows: `[{...}, ...]`.
  Future<List<Map<String, dynamic>>> rows(
    String key, {
    required Future<List<Map<String, dynamic>>> Function() fetch,
    Duration? ttl,
    bool persist = true,
    bool forceRefresh = false,
  }) {
    return _resolve<List<Map<String, dynamic>>>(
      key: key,
      fetch: fetch,
      persist: persist,
      ttl: ttl,
      forceRefresh: forceRefresh,
      decode: (json) {
        final list = json as List<dynamic>;
        return [
          for (final item in list) Map<String, dynamic>.from(item as Map),
        ];
      },
    );
  }

  /// A single row or null: `{...}` / `null`.
  Future<Map<String, dynamic>?> object(
    String key, {
    required Future<Map<String, dynamic>?> Function() fetch,
    Duration? ttl,
    bool persist = true,
    bool forceRefresh = false,
  }) {
    return _resolve<Map<String, dynamic>?>(
      key: key,
      fetch: fetch,
      persist: persist,
      ttl: ttl,
      forceRefresh: forceRefresh,
      decode: (json) => json == null ? null : Map<String, dynamic>.from(json as Map),
    );
  }

  /// Counters keyed by id: `{"a": 1, "b": 2}`.
  Future<Map<String, int>> intMap(
    String key, {
    required Future<Map<String, int>> Function() fetch,
    Duration? ttl,
    bool persist = true,
    bool forceRefresh = false,
  }) {
    return _resolve<Map<String, int>>(
      key: key,
      fetch: fetch,
      persist: persist,
      ttl: ttl,
      forceRefresh: forceRefresh,
      decode: (json) => {
        for (final entry in (json as Map).entries)
          entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
      },
    );
  }

  /// A string map keyed by id: `{"id": "path"}`.
  Future<Map<String, String>> stringMap(
    String key, {
    required Future<Map<String, String>> Function() fetch,
    Duration? ttl,
    bool persist = true,
    bool forceRefresh = false,
  }) {
    return _resolve<Map<String, String>>(
      key: key,
      fetch: fetch,
      persist: persist,
      ttl: ttl,
      forceRefresh: forceRefresh,
      decode: (json) => {
        for (final entry in (json as Map).entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  /// The track-id -> storage-path lookup filled from a catalogue fetch.
  ///
  /// Read synchronously by the stream resolver so warming playback for a
  /// screenful of tracks costs no network at all; see
  /// `lib/services/sourced_track/direct_supabase.dart`. Empty until the first
  /// catalogue read, which is why every caller must still be able to fall back
  /// to its own query.
  Map<String, String> get storagePaths {
    final entry = _memory[streamPathKey];
    final value = entry?.value;
    return value is Map<String, String> ? value : const <String, String>{};
  }

  /// Replaces the storage-path index. Called by the catalogue fetch, which is
  /// the only place that has the rows.
  void rememberStoragePaths(Map<String, String> paths) {
    if (paths.isEmpty) return;
    _remember(streamPathKey, _Entry(Map<String, String>.from(paths), DateTime.now()));
  }

  /// Key holding the track-id -> storage-path index.
  static const String streamPathKey = 'track-storage-paths';
}
