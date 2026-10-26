import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/services/images/cover_renditions.dart';

/// The rendition switch must be invisible to the UI: it may only ever rewrite
/// cover URLs it recognises, and it must never invent a request for the 1024
/// original (which is already the stored file).
void main() {
  final base = Env.supabaseUrl.replaceAll(RegExp(r'/+$'), '');

  group('Supabase thumbnails bucket', () {
    const originalUrl =
        'https://example.supabase.co/storage/v1/object/public/thumbnails/1790-cover.webp';

    test('maps to the 512 rendition', () {
      expect(
        CoverRendition.urlFor(originalUrl),
        '$base/storage/v1/object/public/thumbnails/variants/512/1790-cover.webp',
      );
    });

    test('keeps the already-selected rendition', () {
      final variant =
          '$base/storage/v1/object/public/thumbnails/variants/512/1790-cover.webp';
      expect(CoverRendition.urlFor(variant), variant);
    });

    test('returns the original for the hero size (no rendition above it)', () {
      expect(CoverRendition.urlFor(originalUrl, pixels: CoverRendition.hero), originalUrl);
      expect(CoverRendition.urlFor(originalUrl, pixels: CoverRendition.original), originalUrl);
    });
  });

  group('R2 album covers', () {
    const albumUrl =
        'https://music.soulfulbhakti.com/images/1792-Durga%20Mahima%20Cover.webp';

    test('maps to the Supabase 512 rendition', () {
      expect(
        CoverRendition.urlFor(albumUrl),
        '$base/storage/v1/object/public/thumbnails/variants/512/1792-Durga%20Mahima%20Cover.webp',
      );
    });
  });

  group('everything else is left alone', () {
    test('avatars and third-party images', () {
      for (final url in const [
        'https://img.clerk.com/abc123',
        'https://avatars.dicebear.com/api/bottts/x.png',
        'http://127.0.0.1:19876/supabase/tracks',
      ]) {
        expect(CoverRendition.urlFor(url), url);
      }
    });

    test('local paths and empty strings', () {
      for (final path in const ['assets/images/album_placeholder.png', '/data/user/0/a.jpg', '']) {
        expect(CoverRendition.urlFor(path), path);
      }
    });
  });
}
