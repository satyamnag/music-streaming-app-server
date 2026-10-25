/// Warms the artwork disk cache with what the home screen draws first.
///
/// WHY THIS EXISTS
/// ---------------
/// Every artwork surface already goes through [AppImageCacheManager] - covers,
/// banners, the wallpaper band, the shelf icons - so a *second* visit is served
/// from disk. The FIRST visit is the problem: with a cold cache the home screen
/// has to fetch the wallpaper, the carousel banners and a screenful of covers
/// before it looks like anything, and on a weak connection that is a screen of
/// placeholders for as long as it takes.
///
/// These particular images are the same for every reader, and they change only
/// when the admin uploads a new banner or wallpaper. Fetching them once - right
/// after the home data resolves, before the reader has scrolled anywhere - is
/// what makes the app usable on a 2G-ish connection: they are already on disk
/// when the first frame asks for them, and they stay there for the manager's
/// 90-day `stalePeriod`.
///
/// BOUNDED ON PURPOSE
/// ------------------
///  * a hard cap of [maxUrls] files, so this can never turn into a bulk
///    downloader that eats a reader's data allowance;
///  * served through the SAME cache manager as the UI, and a URL that is already
///    on disk costs no network at all (`getFileFromCache` is a lookup, not a
///    fetch);
///  * strictly best-effort: every failure is swallowed, because a warm-up must
///    never be the reason a screen fails to load.
library;

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/modules/home/sections/specials.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';
import 'package:sangeet/services/image_cache/app_image_cache_manager.dart';

/// The ordered, de-duplicated, capped list of home artwork worth warming.
///
/// Ordered by what the reader sees first: the wallpaper band behind the header,
/// then the carousel banners, then the first screenful of covers. Pure, so the
/// ordering, the de-duplication and the cap can be asserted without a platform
/// cache - see `test/services/image_cache/artwork_precache_test.dart`.
///
/// Non-http entries are dropped: placeholder paths point at bundled assets and
/// must never be sent to the network cache.
@visibleForTesting
List<String> homeArtworkUrlsForCache({
  String? wallpaperUrl,
  List<String?> bannerUrls = const [],
  List<String> coverUrls = const [],
  int maxCovers = 12,
  int maxUrls = ArtworkPrecache.maxUrls,
}) {
  final urls = <String>[];

  void add(String? raw) {
    final url = raw?.trim() ?? '';
    if (url.isEmpty || !url.startsWith('http')) return;
    if (urls.length >= maxUrls || urls.contains(url)) return;
    urls.add(url);
  }

  add(wallpaperUrl);
  for (final banner in bannerUrls) {
    add(banner);
  }
  for (final cover in coverUrls.take(maxCovers)) {
    add(cover);
  }
  return urls;
}

/// Fetches first-paint artwork into the shared cache, once, in the background.
class ArtworkPrecache {
  ArtworkPrecache._();

  static final ArtworkPrecache instance = ArtworkPrecache._();

  /// Hard cap on how many files a single warm-up may fetch.
  ///
  /// Chosen against what the home screen actually draws before the first
  /// scroll: one wallpaper, a handful of banners, and the first covers. It is a
  /// ceiling, not a target - a screen with three banners warms four files.
  static const int maxUrls = 24;

  /// URLs already handled this session, so a rebuild of the home screen cannot
  /// re-request the same file. Cheap insurance rather than a correctness need:
  /// the manager would answer from disk anyway.
  final Set<String> _attempted = {};

  /// Warms [urls] into the shared artwork cache and returns how many files were
  /// actually fetched (anything already on disk is a hit and costs nothing).
  Future<int> warm(Iterable<String> urls) async {
    final manager = AppImageCacheManager();
    var fetched = 0;
    for (final url in urls) {
      if (fetched >= maxUrls) break;
      if (!_attempted.add(url)) continue;
      try {
        // Lookup first, deliberately: getFileFromCache never downloads, so an
        // already-cached banner costs one database read instead of a request.
        if (await manager.getFileFromCache(url) != null) continue;
        await manager.getSingleFile(url);
        fetched++;
      } catch (_) {
        // Best-effort by design: a failed warm-up is not an error the reader
        // should ever see, and the URL still resolves on screen if requested.
      }
    }
    return fetched;
  }
}

/// Fire-and-forget warm-up of the home screen's first-paint artwork.
///
/// Watched (not awaited) by the home page, mirroring
/// [prewarmHomeStreamsProvider]'s pattern for stream URLs: the screen paints
/// from whatever is already cached, and this fills the disk behind it.
final precacheHomeArtworkProvider = FutureProvider<int>((ref) async {
  final wallpaper = await ref.watch(homeWallpaperProvider.future);
  final rows = await ref.watch(homeSpecialRowsProvider.future);
  final tracks = await ref.watch(homeTracksProvider.future);

  final urls = homeArtworkUrlsForCache(
    wallpaperUrl: wallpaper,
    bannerUrls: [for (final row in rows) row.bannerUrl],
    coverUrls: [
      for (final track in tracks)
        if (track is SangeetFullTrackObject)
          track.album.images.smallest(ImagePlaceholder.albumArt),
    ],
  );

  return ArtworkPrecache.instance.warm(urls);
});
