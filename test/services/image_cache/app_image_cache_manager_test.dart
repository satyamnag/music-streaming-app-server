import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/image_cache/app_image_cache_manager.dart';

/// Regression guard for the image cache configuration.
///
/// The bug this exists for was invisible in the source: `cached_network_image`
/// was wired up correctly, but inherited `flutter_cache_manager`'s
/// `maxNrOfCacheObjects` default of 200, so the LRU evicted artwork that was
/// still in use and every launch refetched it. Nothing failed, nothing logged.
/// These tests fail if that default creeps back in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppImageCacheManager', () {
    test('is a singleton, so one cache directory backs the whole app', () {
      expect(
        identical(AppImageCacheManager(), AppImageCacheManager()),
        isTrue,
        reason: 'two instances would mean two directories and two databases',
      );
    });

    test('caps far above the 200-object default that caused the reloads', () {
      final config = AppImageCacheManager().config;
      final defaultCap = DefaultCacheManager().config.maxNrOfCacheObjects;

      expect(
        config.maxNrOfCacheObjects,
        greaterThan(defaultCap),
        reason:
            'flutter_cache_manager defaults maxNrOfCacheObjects to $defaultCap. '
            'This app touches far more distinct artwork URLs than that in one '
            'session, so the LRU evicts images still in use and the next launch '
            'refetches them - the reported "images load every time" symptom.',
      );
      expect(config.maxNrOfCacheObjects, AppImageCacheManager.maxObjects);
    });

    test('keeps artwork well past 30 days', () {
      final config = AppImageCacheManager().config;
      expect(config.stalePeriod, AppImageCacheManager.stalePeriod);
      expect(
        config.stalePeriod,
        greaterThan(const Duration(days: 30)),
        reason: 'track artwork never changes; a 30-day refresh is pure waste',
      );
    });

    test('uses its own cache key, not the shared default', () {
      expect(
        AppImageCacheManager().config.cacheKey,
        AppImageCacheManager.key,
      );
      expect(
        AppImageCacheManager().config.cacheKey,
        isNot(DefaultCacheManager().config.cacheKey),
        reason:
            'sharing libCachedImageData would let anything else evict this '
            'app\'s artwork under the 200-object cap',
      );
    });
  });

  group('configureImageCache', () {
    test('installs AppImageCacheManager as the provider default', () {
      final installed = configureImageCache();

      expect(installed, same(AppImageCacheManager()));
      expect(
        identical(
          CachedNetworkImageProvider.defaultCacheManager,
          AppImageCacheManager(),
        ),
        isTrue,
        reason:
            'every existing call site relies on the static default; if this is '
            'not set they silently fall back to the 200-object cache',
      );
    });

    test('is idempotent', () {
      configureImageCache();
      final first = CachedNetworkImageProvider.defaultCacheManager;
      configureImageCache();
      expect(
        identical(CachedNetworkImageProvider.defaultCacheManager, first),
        isTrue,
      );
    });
  });
}
