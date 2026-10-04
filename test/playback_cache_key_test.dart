import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the stream-resolution cache key.
///
/// A track has two audio files: the ORIGINAL and the KARAOKE variant. They were
/// cached under the track id alone, so requesting karaoke within the URL's
/// lifetime returned the *original* audio (and vice versa) — meaning toggling to
/// karaoke could silently play the wrong file, which read as "karaoke playback
/// is broken". The key must include the variant.
///
/// This mirrors `_cacheKey` in
/// lib/provider/server/routes/playback.dart.
///
/// The variant is a PREFIX separated by a NUL character, so a track id can
/// never be confused with another track's variant key.
String cacheKey(String trackId, {bool karaoke = false}) =>
    karaoke ? 'karaoke\u0000$trackId' : 'original\u0000$trackId';

void main() {
  group('stream cache key is variant-aware', () {
    test('original and karaoke never share a key', () {
      const id = 'track-123';
      expect(cacheKey(id), isNot(equals(cacheKey(id, karaoke: true))));
    });

    test('the key namespaces by variant', () {
      expect(cacheKey('abc'), equals('original\u0000abc'));
      expect(cacheKey('abc', karaoke: true), equals('karaoke\u0000abc'));
    });

    test('different tracks never collide', () {
      expect(cacheKey('a'), isNot(equals(cacheKey('b'))));
      expect(cacheKey('a', karaoke: true), isNot(equals(cacheKey('b', karaoke: true))));
      // A track id that literally contains the marker text must not collide
      // with another track's karaoke key.
      expect(cacheKey('a::karaoke'), isNot(equals(cacheKey('a', karaoke: true))));
      expect(cacheKey('karaoke\u0000a'), isNot(equals(cacheKey('a', karaoke: true))));
    });

    test('a cache holding both variants keeps them distinct', () {
      final cache = <String, String>{};
      void put(String id, {bool karaoke = false, required String url}) {
        cache[cacheKey(id, karaoke: karaoke)] = url;
      }

      put('t1', url: 'original.mp3');
      put('t1', karaoke: true, url: 'karaoke.opus');

      expect(cache[cacheKey('t1')], equals('original.mp3'));
      expect(cache[cacheKey('t1', karaoke: true)], equals('karaoke.opus'));
      expect(cache.length, equals(2));
    });

    test('the regression scenario: karaoke after original is NOT the original', () {
      final cache = <String, String>{};
      const id = 'song-9';

      // Play the original first (this is what cached the wrong entry before).
      cache[cacheKey(id)] = 'original-url';

      // Requesting karaoke must miss the cache and resolve the karaoke file,
      // not return 'original-url'.
      final karaokeHit = cache[cacheKey(id, karaoke: true)];
      expect(karaokeHit, isNull, reason: 'karaoke must not hit the original cache entry');

      cache[cacheKey(id, karaoke: true)] = 'karaoke-url';
      expect(cache[cacheKey(id, karaoke: true)], equals('karaoke-url'));
      expect(cache[cacheKey(id)], equals('original-url'));
    });
  });
}
