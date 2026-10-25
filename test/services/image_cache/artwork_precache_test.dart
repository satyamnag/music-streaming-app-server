import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/image_cache/artwork_precache.dart';

/// Guards the pure half of the home artwork warm-up.
///
/// The download half needs a platform cache (and is exercised on a device by
/// the image-cache verification workflow), but the decisions that decide WHAT
/// gets fetched - order, de-duplication, the cap, and refusing non-http entries
/// - are pure and are asserted here. Each one is a way the warm-up could
/// misbehave expensively: fetch a bundled asset over the network, fetch the
/// same banner twice, or quietly turn into a bulk downloader on a reader's data
/// allowance.
void main() {
  group('homeArtworkUrlsForCache', () {
    test('orders URLs by what the reader sees first', () {
      final urls = homeArtworkUrlsForCache(
        wallpaperUrl: 'https://cdn.example/wall.webp',
        bannerUrls: const ['https://cdn.example/banner.webp'],
        coverUrls: const ['https://cdn.example/cover.webp'],
      );

      expect(urls, const [
        'https://cdn.example/wall.webp',
        'https://cdn.example/banner.webp',
        'https://cdn.example/cover.webp',
      ]);
    });

    test('de-duplicates, because one cover repeats across several shelves', () {
      final urls = homeArtworkUrlsForCache(
        wallpaperUrl: 'https://cdn.example/wall.webp',
        bannerUrls: const [
          'https://cdn.example/cover.webp',
          'https://cdn.example/banner.webp',
        ],
        coverUrls: const [
          'https://cdn.example/cover.webp',
          'https://cdn.example/cover.webp',
        ],
      );

      expect(urls, const [
        'https://cdn.example/wall.webp',
        'https://cdn.example/cover.webp',
        'https://cdn.example/banner.webp',
      ]);
    });

    test('never warms a bundled asset or an empty URL', () {
      // Placeholder paths (assets/images/...) are the fallback every artwork
      // slot uses; sending them to the network cache would 404 once per slot.
      final urls = homeArtworkUrlsForCache(
        wallpaperUrl: 'assets/images/placeholder.png',
        bannerUrls: const ['', '   ', 'assets/images/album-placeholder.png'],
        coverUrls: const ['  https://cdn.example/cover.webp  '],
      );

      expect(urls, const ['https://cdn.example/cover.webp']);
    });

    test('caps the cover count and the total', () {
      final covers = [
        for (var i = 0; i < 100; i++) 'https://cdn.example/cover$i.webp',
      ];

      // Default: one screenful of covers.
      expect(homeArtworkUrlsForCache(coverUrls: covers).length, 12);

      // Even asked for everything, the warm-up stops at its hard ceiling.
      expect(
        homeArtworkUrlsForCache(coverUrls: covers, maxCovers: 100).length,
        ArtworkPrecache.maxUrls,
      );
    });
  });

  group('homeArtworkUrlsByCategory', () {
    test('splits artwork into the categories a reader would name', () {
      final byCategory = homeArtworkUrlsByCategory(
        wallpaperUrl: 'https://cdn.example/wall.webp',
        bannerUrls: const ['https://cdn.example/banner.webp'],
        iconUrls: const ['https://cdn.example/icon.webp'],
        coverUrls: const ['https://cdn.example/cover.webp'],
      );

      expect(byCategory.keys.toSet(), {
        'wallpaper',
        'banners',
        'icons',
        'covers',
      });
      expect(byCategory['wallpaper'], const ['https://cdn.example/wall.webp']);
      expect(byCategory['banners'], const ['https://cdn.example/banner.webp']);
      expect(byCategory['icons'], const ['https://cdn.example/icon.webp']);
      expect(byCategory['covers'], const ['https://cdn.example/cover.webp']);
    });

    test('caps each category independently', () {
      final many = [
        for (var i = 0; i < 40; i++) 'https://cdn.example/i$i.webp',
      ];
      final byCategory = homeArtworkUrlsByCategory(
        bannerUrls: many,
        iconUrls: many,
        coverUrls: many,
      );

      expect(byCategory['banners']!.length, 12);
      expect(byCategory['icons']!.length, 12);
      expect(byCategory['covers']!.length, 12);
    });

    test('flatten keeps warm-up order and collapses cross-category repeats', () {
      final flat = flattenArtworkCategories({
        'wallpaper': ['https://cdn.example/wall.webp'],
        'banners': ['https://cdn.example/shared.webp'],
        'icons': [
          'https://cdn.example/shared.webp',
          'https://cdn.example/icon.webp',
        ],
        'covers': ['https://cdn.example/cover.webp'],
      });

      expect(flat, const [
        'https://cdn.example/wall.webp',
        'https://cdn.example/shared.webp',
        'https://cdn.example/icon.webp',
        'https://cdn.example/cover.webp',
      ]);
    });

    test('has no logo category, because logos ship inside the APK', () {
      // Logos are bundled assets; including them would send an APK path to the
      // network cache. The on-device audit reports them separately, from the
      // real asset manifest.
      expect(homeArtworkUrlsByCategory().containsKey('logos'), isFalse);
    });
  });
}
