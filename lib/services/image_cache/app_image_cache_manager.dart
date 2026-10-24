import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The image cache every network image in the app is served from.
///
/// WHY THIS EXISTS
/// ---------------
/// `cached_network_image` was already wired up correctly: `UniversalImage`
/// routes every http(s) path through `CachedNetworkImageProvider` with a stable
/// `cacheKey`, no raw `Image.network` bypasses exist anywhere in `lib/`, and
/// nothing in the app clears the cache on startup. What it did NOT have was a
/// cache sized for this catalogue - it inherited `flutter_cache_manager`'s
/// defaults, and one of those defaults explains "images load again on every
/// launch".
///
/// `maxNrOfCacheObjects` defaults to **200**. This app touches far more than 200
/// distinct artwork URLs in an ordinary session: the home carousels alone pull
/// dozens, then track cards, artist headers, playlist covers and the palette
/// extraction pass re-reference the same artwork. Once the 200th distinct URL is
/// stored, the least-recently-used files are deleted - and the ones evicted
/// first are the ones seen EARLIEST in the session, which is precisely the home
/// screen. The next launch therefore finds the home artwork missing, refetches
/// it, and the cycle repeats forever. Code that looks perfectly cached behaves
/// like no cache at all across launches.
///
/// `stalePeriod` defaults to 30 days, which is simply too short for artwork that
/// never changes; a listener returning after a month would be made to refetch
/// the whole catalogue for no reason.
///
/// KNOWN RESIDUAL RISK, stated rather than hidden: `flutter_cache_manager`
/// stores files under `getTemporaryDirectory()` (the OS cache directory) and
/// offers no public option to relocate it, so Android may still reclaim the
/// cache under storage pressure or when the user presses "Clear cache". That is
/// a rare, deliberate event, unlike the LRU churn above which happens in normal
/// use. Moving the store to the application-support directory would need
/// `package:file` as a direct dependency purely to satisfy the `FileSystem`
/// interface, which is not a trade worth making for this fix.
library;

class AppImageCacheManager extends CacheManager with ImageCacheManager {
  /// A distinct key, so this cache has its own directory and its own metadata
  /// database rather than sharing `libCachedImageData` with anything else.
  static const String key = 'soulfulBhaktiImageCache';

  /// Sized for the curated catalogue with headroom. At roughly 20-60 KB per
  /// 300x300 WebP thumbnail this stays in the tens of MB, not hundreds.
  static const int maxObjects = 1200;

  /// Track artwork does not change, so a periodic refresh buys nothing. Long
  /// enough that a returning listener is never made to refetch.
  static const Duration stalePeriod = Duration(days: 90);

  static final AppImageCacheManager _instance = AppImageCacheManager._();

  factory AppImageCacheManager() => _instance;

  AppImageCacheManager._()
    : super(
        Config(key, stalePeriod: stalePeriod, maxNrOfCacheObjects: maxObjects),
      );
}

/// Points every `CachedNetworkImageProvider` in the app at
/// [AppImageCacheManager].
///
/// Called once from `main()` before the first frame. Doing it centrally means
/// the existing call sites - `UniversalImage`, the markdown image builder, the
/// featured-playlist surfaces that construct a provider directly - need no edit,
/// and any future call site inherits the corrected cache instead of silently
/// reverting to the 200-object default.
///
/// Returns the manager that is now in force, so a caller (or a test) can assert
/// what actually got installed rather than trusting that the static was set.
BaseCacheManager configureImageCache() {
  final manager = AppImageCacheManager();
  CachedNetworkImageProvider.defaultCacheManager = manager;
  return manager;
}
