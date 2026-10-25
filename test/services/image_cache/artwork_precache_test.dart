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
}
