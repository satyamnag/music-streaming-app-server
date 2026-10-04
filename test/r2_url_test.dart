import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/sourced_track/r2_url.dart';

/// Tests for R2 object-key URL encoding.
///
/// This catalogue's filenames contain spaces and other reserved characters
/// (e.g. "Maa Inti Daivama.opus"), and an unencoded space makes the stream URL
/// invalid — which shows up as a track that will not play or stutters. The key
/// must therefore be encoded, while still addressing the SAME object.
void main() {
  group('encodeObjectKey', () {
    test('leaves already-safe names untouched', () {
      // The common case must not change, or every existing URL would shift.
      expect(encodeObjectKey('Niluvadu-Manasu.opus'),
          equals('Niluvadu-Manasu.opus'));
      expect(encodeObjectKey('song_1.final.opus'),
          equals('song_1.final.opus'));
    });

    test('encodes spaces (the real filenames in this catalogue)', () {
      expect(encodeObjectKey('Maa Inti Daivama.opus'),
          equals('Maa%20Inti%20Daivama.opus'));
      expect(encodeObjectKey('Gopala Bala - Gopala.opus'),
          equals('Gopala%20Bala%20-%20Gopala.opus'));
    });

    test('encodes characters that would change the URL meaning', () {
      // A raw & or # would be read as a query/fragment separator.
      expect(encodeObjectKey('song&and.opus'), equals('song%26and.opus'));
      expect(encodeObjectKey('song#hash.opus'), equals('song%23hash.opus'));
      expect(encodeObjectKey('song?q.opus'), equals('song%3Fq.opus'));
      expect(encodeObjectKey('song+plus.opus'), equals('song%2Bplus.opus'));
    });

    test('preserves folder separators', () {
      // Keys may be nested; a slash must stay a path separator.
      expect(encodeObjectKey('audio/song one.opus'),
          equals('audio/song%20one.opus'));
      expect(encodeObjectKey('a/b/c/file.opus'), equals('a/b/c/file.opus'));
    });

    test('handles empty and unusual input without throwing', () {
      expect(encodeObjectKey(''), equals(''));
      expect(encodeObjectKey('/'), equals('/'));
      expect(encodeObjectKey('  '), equals('%20%20'));
      // Non-ASCII (e.g. Telugu) must be percent-encoded, not dropped.
      final devanagari = encodeObjectKey('రామ.opus');
      expect(devanagari, isNot(equals('రామ.opus')));
      expect(devanagari.endsWith('.opus'), isTrue);
    });

    test('the encoded key decodes back to the original', () {
      for (final key in [
        'Maa Inti Daivama.opus',
        'audio/Gopala Bala - Gopala.opus',
        'song&and#hash?q+plus.opus',
        'రామ.opus',
      ]) {
        final encoded = encodeObjectKey(key);
        final decoded = encoded.split('/').map(Uri.decodeComponent).join('/');
        expect(decoded, equals(key), reason: 'round trip failed for $key');
      }
    });
  });
}
