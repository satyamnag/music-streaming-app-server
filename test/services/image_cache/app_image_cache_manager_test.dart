import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/image_cache/app_image_cache_manager.dart';

/// Regression guard for the image cache configuration.
///
/// The bug this exists for was invisible in source: `cached_network_image` was
/// wired up correctly but inherited `flutter_cache_manager`'s
/// `maxNrOfCacheObjects` default of 200, so the LRU evicted artwork that was
/// still in use and every launch refetched it. Nothing failed, nothing logged.
/// These tests fail if that default creeps back in.
///
/// WHY THESE ASSERT CONSTANTS INSTEAD OF CONSTRUCTING THE MANAGER
/// --------------------------------------------------------------
/// Constructing a `CacheManager` is not safe in a unit test. `Config` builds
/// `IOFileSystem(cacheKey)`, whose initialiser is
///     IOFileSystem(this._cacheKey) : _fileDir = createDirectory(_cacheKey);
/// so it calls `getTemporaryDirectory()` eagerly, in the constructor. Under
/// `flutter test` path_provider has no implementation, that future completes with
/// an error nobody awaits, and the test runner reports
/// "failed after test completion". This was observed, not theorised: run
/// 40090219829 failed both construction tests with exactly that message.
///
/// WHAT THIS THEREFORE DOES *NOT* PROVE
/// ------------------------------------
///  * That `main()` calls `configureImageCache()`. Covered instead by the
///    analyzer (the call and import must resolve) and by the release build.
///  * That artwork actually survives an app restart. That needs a real device
///    and two launches, and is deliberately NOT claimed here.
void main() {
  group('AppImageCacheManager configuration', () {
    test('caps far above the 200-object default that caused the reloads', () {
      // flutter_cache_manager-3.4.2/lib/src/config/_config_io.dart:
      //     maxNrOfCacheObjects = maxNrOfCacheObjects ?? 200
      const int packageDefault = 200;

      expect(
        AppImageCacheManager.maxObjects,
        greaterThan(packageDefault),
        reason:
            'at the default cap this app evicts artwork still in use and '
            'refetches it on the next launch - the reported symptom',
      );
      expect(AppImageCacheManager.maxObjects, 1200);
    });

    test('keeps artwork far longer than the 30-day default', () {
      // flutter_cache_manager-3.4.2/lib/src/config/_config_io.dart:
      //     stalePeriod = stalePeriod ?? const Duration(days: 30)
      const Duration packageDefault = Duration(days: 30);

      expect(
        AppImageCacheManager.stalePeriod,
        greaterThan(packageDefault),
        reason: 'track artwork never changes; a 30-day refresh is pure waste',
      );
      expect(AppImageCacheManager.stalePeriod, const Duration(days: 90));
    });

    test('uses a cache key of its own, not the shared default', () {
      // DefaultCacheManager.key == 'libCachedImageData'
      expect(
        AppImageCacheManager.key,
        isNot('libCachedImageData'),
        reason:
            'sharing the default key would let anything else in the app evict '
            'this artwork under the cap that is already too small',
      );
      expect(AppImageCacheManager.key, 'soulfulBhaktiImageCache');
    });
  });
}
