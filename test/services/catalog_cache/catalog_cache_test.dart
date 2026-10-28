import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/catalog_cache/catalog_cache.dart';

/// Guards the caching contract the whole app now depends on.
///
/// Every screen reads through this cache, so the properties asserted here are
/// the difference between "pages open instantly" and "pages open instantly but
/// show data that never updates" - or, worse, a page that goes blank when a
/// background refresh fails. Each test names the failure it prevents.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catalog_cache_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  CatalogCache cacheWith({Duration? ttl}) => CatalogCache(
        directory: tempDir,
        defaultTtl: ttl ?? const Duration(minutes: 2),
      );

  group('CatalogCache', () {
    test('a miss awaits the fetch and a hit does not repeat it', () async {
      final cache = cacheWith();
      var fetches = 0;

      Future<List<Map<String, dynamic>>> fetch() async {
        fetches++;
        return [
          {'id': 'a', 'title': 'Song A'},
        ];
      }

      final first = await cache.rows('tracks', fetch: fetch);
      final second = await cache.rows('tracks', fetch: fetch);

      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(fetches, 1, reason: 'the second read must be served from memory');
    });

    test('a value survives a relaunch: a fresh instance reads it from disk',
        () async {
      final writer = cacheWith();
      await writer.rows(
        'catalogue-tracks-100',
        fetch: () async => [
          {'id': 'a', 'storage_path': 'music/a.opus'},
        ],
      );

      // A new instance with the same directory stands in for the next app
      // launch: memory is empty, so only the persisted file can answer.
      final reader = cacheWith();
      var fetches = 0;
      final rows = await reader.rows(
        'catalogue-tracks-100',
        fetch: () async {
          fetches++;
          return const [];
        },
      );

      expect(fetches, 0, reason: 'the relaunch must not hit the network');
      expect(rows.single['storage_path'], 'music/a.opus');
    });

    test('a stale value is returned immediately and refreshed in the '
        'background', () async {
      final cache = cacheWith(ttl: Duration.zero);
      var version = 1;

      Future<List<Map<String, dynamic>>> fetch() async => [
            {'id': 'a', 'version': version},
          ];

      await cache.rows('tracks', fetch: fetch);
      // A zero TTL means "stale as soon as it is stored", but the staleness
      // test compares against wall-clock time, so let one tick pass rather than
      // depending on two calls landing in different milliseconds.
      await Future<void>.delayed(const Duration(milliseconds: 2));

      // The next read must hand back the cached copy without waiting, and
      // refresh behind it.
      version = 2;
      final stale = await cache.rows('tracks', fetch: fetch);
      expect(stale.single['version'], 1, reason: 'stale value served at once');

      // Let the background refresh land.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final fresh = await cache.rows('tracks', fetch: fetch);
      expect(fresh.single['version'], 2, reason: 'next read sees the refresh');
    });

    test('a failed background refresh keeps the working value', () async {
      final cache = cacheWith(ttl: Duration.zero);
      await cache.rows(
        'tracks',
        fetch: () async => [
          {'id': 'a'},
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));

      final kept = await cache.rows(
        'tracks',
        fetch: () async => throw StateError('network down'),
      );
      expect(kept.single['id'], 'a');

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Still serving the old value: a warm-up failure must never blank a
      // screen that is already working.
      final again = await cache.rows(
        'tracks',
        fetch: () async => throw StateError('network still down'),
      );
      expect(again.single['id'], 'a');
    });

    test('a failed fetch on a miss still propagates', () async {
      final cache = cacheWith();

      // Callers rely on this: the routes turn it into their existing 500 /
      // error-box behaviour, which must not change just because caching exists.
      await expectLater(
        cache.rows(
          'tracks',
          fetch: () async => throw StateError('boom'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('concurrent reads of a stale key share one refresh', () async {
      final cache = cacheWith(ttl: Duration.zero);
      var fetches = 0;

      Future<List<Map<String, dynamic>>> fetch() async {
        fetches++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return [
          {'id': 'a', 'n': fetches},
        ];
      }

      await cache.rows('tracks', fetch: fetch);
      expect(fetches, 1);
      await Future<void>.delayed(const Duration(milliseconds: 2));

      // Three screens opening at once must not multiply the traffic.
      await Future.wait([
        cache.rows('tracks', fetch: fetch),
        cache.rows('tracks', fetch: fetch),
        cache.rows('tracks', fetch: fetch),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(fetches, 2, reason: 'one shared background refresh, not three');
    });

    test('clear() makes the next read go to the network again', () async {
      final cache = cacheWith();
      var fetches = 0;

      Future<List<Map<String, dynamic>>> fetch() async {
        fetches++;
        return const [];
      }

      await cache.rows('tracks', fetch: fetch);
      await cache.clear();
      await cache.rows('tracks', fetch: fetch);

      expect(fetches, 2);
    });

    test('a corrupt file is treated as a miss', () async {
      final cache = cacheWith();
      await cache.rows(
        'tracks',
        fetch: () async => [
          {'id': 'a'},
        ],
      );

      final file = Directory('${tempDir.path}${Platform.pathSeparator}catalog_cache')
          .listSync()
          .whereType<File>()
          .first;
      await file.writeAsString('{not json');

      final reader = cacheWith();
      final rows = await reader.rows(
        'tracks',
        fetch: () async => [
          {'id': 'recovered'},
        ],
      );

      expect(rows.single['id'], 'recovered');
    });

    test('intMap and object round-trip their shapes', () async {
      final cache = cacheWith();

      final counts = await cache.intMap(
        'play-counts',
        fetch: () async => {'track-1': 7, 'track-2': 0},
      );
      expect(counts, {'track-1': 7, 'track-2': 0});

      // A cached null is a real answer ("no wallpaper configured") and must not
      // be re-fetched on every screen.
      var wallpapers = 0;
      Future<Map<String, dynamic>?> fetchWallpaper() async {
        wallpapers++;
        return null;
      }

      expect(await cache.object('wallpaper', fetch: fetchWallpaper), isNull);
      expect(await cache.object('wallpaper', fetch: fetchWallpaper), isNull);
      expect(wallpapers, 1, reason: 'the null answer is cached too');
    });

    test('storage paths are readable without another query', () {
      final cache = cacheWith();
      expect(cache.storagePaths, isEmpty);

      cache.rememberStoragePaths({'track-1': 'music/one.opus'});

      expect(cache.storagePaths['track-1'], 'music/one.opus');
    });
  });
}
