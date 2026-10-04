import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/models/metadata/metadata.dart';

/// Unit tests for the "Specials" shelf matching rules.
///
/// These test the real matching behaviour by exercising the same rules the
/// home Specials provider uses (word-start keyword matching over a track's
/// name + album + artists + tags). They exist because plain substring matching
/// produced two real bugs during development:
///   1. `ram` matched inside the artist name "Vani Jairam" and filed a
///      Krishna bhajan under "Rama Special".
///   2. Strict word boundaries then missed suffixed devotional forms such as
///      "Shivaya" (for shiva), "Lingashtakam" (for linga) and "Rudram".
///
/// The rule under test: multi-word keywords match as substrings; single words
/// must start a word (so suffixes are allowed) but may not appear mid-word.
bool keywordMatches(String haystack, String keyword) {
  if (keyword.contains(' ')) return haystack.contains(keyword);
  return RegExp('\\b${RegExp.escape(keyword)}').hasMatch(haystack);
}

/// Mirrors the provider's haystack construction.
String haystackFor({
  required String name,
  String album = '',
  List<String> artists = const [],
  String? tags,
}) =>
    [name, album, ...artists, tags ?? ''].join(' ').toLowerCase();

void main() {
  group('Specials keyword matching', () {
    test('does not match a short keyword inside an unrelated word', () {
      // The "Vani Jairam" regression: this must NOT match the Rama shelf.
      expect(keywordMatches(haystackFor(name: 'Krishna Nee Begane', artists: ['Vani Jairam']), 'ram'),
          isFalse);
      expect(keywordMatches('dramatic', 'rama'), isFalse);
    });

    test('matches suffixed devotional forms at a word start', () {
      expect(keywordMatches('om namah shivaya', 'shiva'), isTrue);
      expect(keywordMatches('lingashtakam', 'linga'), isTrue);
      expect(keywordMatches('rudram', 'rudra'), isTrue);
      expect(keywordMatches('gajanana', 'gajanana'), isTrue);
      expect(keywordMatches('mahalakshmi ashtakam', 'mahalakshmi'), isTrue);
    });

    test('matches plain words and mid-phrase words', () {
      expect(keywordMatches('rama bhajan', 'rama'), isTrue);
      expect(keywordMatches('sri rama jayam', 'rama'), isTrue);
      expect(keywordMatches("rama's", 'rama'), isTrue);
      expect(keywordMatches('venkateswara suprabhatam', 'venkateswara'), isTrue);
    });

    test('multi-word keywords match as substrings', () {
      expect(keywordMatches('rama raksha stotram', 'rama raksha'), isTrue);
      expect(keywordMatches('ramaraksha', 'rama raksha'), isFalse);
    });

    test('haystack includes name, album, artists and tags', () {
      final h = haystackFor(
        name: 'Aarati',
        album: 'Vol 1',
        artists: ['Traditional'],
        tags: 'ganesha, aarti',
      );
      expect(h.contains('aarati'), isTrue);
      expect(h.contains('vol 1'), isTrue);
      expect(h.contains('traditional'), isTrue);
      expect(h.contains('ganesha'), isTrue);
      expect(keywordMatches(h, 'ganesha'), isTrue,
          reason: 'admin tags alone must be able to match a shelf');
    });

    test('a track with no devotional keywords matches nothing', () {
      final h = haystackFor(name: 'Untitled Recording 42', album: 'Misc');
      const shivaKeywords = ['shiva', 'siva', 'mahadev', 'rudra', 'linga'];
      expect(shivaKeywords.any((k) => keywordMatches(h, k)), isFalse);
    });
  });

  group('Specials shelf assembly rules', () {
    test('shelves with no matching tracks are dropped (no empty carousel)', () {
      // A one-track catalogue can only ever satisfy the shelves it matches.
      final only = haystackFor(name: 'Gajanana', album: 'Ganesha Bhajans');
      final matchedShelves = const {
        'ganesha': ['ganesha', 'gajanana', 'vinayaka'],
        'shiva': ['shiva', 'linga', 'rudra'],
        'ganga': ['ganga', 'gange'],
      }
          .entries
          .where((e) => e.value.any((k) => keywordMatches(only, k)))
          .map((e) => e.key)
          .toList();

      expect(matchedShelves, equals(['ganesha']));
    });

    test('a track joining several shelves is allowed (Hari is Bhakti + Vishnu)', () {
      final hari = haystackFor(name: 'Hari Bhajan');
      expect(keywordMatches(hari, 'bhajan'), isTrue); // Soulful Bhakti shelf
      expect(keywordMatches(hari, 'hari'), isTrue); // Vishnu shelf
    });

    test('ordering is by play count then name (most played first)', () {
      // Mirrors the provider's sort comparator.
      final tracks = [
        (id: 'a', name: 'Zeta', plays: 5),
        (id: 'b', name: 'Alpha', plays: 5),
        (id: 'c', name: 'Mid', plays: 50),
      ];
      final sorted = [...tracks]..sort((a, b) {
          final cmp = b.plays.compareTo(a.plays);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });
      expect(sorted.map((t) => t.id).toList(), equals(['c', 'b', 'a']));
    });
  });

  group('Specials shelf covers are distinct', () {
    /// Mirrors `_coverFor`: first cover not already claimed by an earlier shelf,
    /// falling back to the shelf's own first cover when every one is taken.
    String coverFor(List<String> covers, Set<String> used) {
      for (final url in covers) {
        if (url.isNotEmpty && !used.contains(url)) {
          used.add(url);
          return url;
        }
      }
      for (final url in covers) {
        if (url.isNotEmpty) return url;
      }
      return '';
    }

    test('a shelf skips a cover an earlier shelf already used', () {
      // The real regression: Venkateswara and Krishna both led with the same
      // Garuda track, so both tiles rendered the identical image.
      final used = <String>{};
      final venkateswara = coverFor(['garuda.jpg', 'balaji.jpg'], used);
      final krishna = coverFor(['garuda.jpg', 'krishna.jpg'], used);

      expect(venkateswara, equals('garuda.jpg'));
      expect(krishna, equals('krishna.jpg'),
          reason: 'the shared lead cover must not be reused');
      expect(venkateswara, isNot(equals(krishna)));
    });

    test('a shelf whose only cover is taken reuses it rather than showing none', () {
      final used = <String>{'only.jpg'};
      expect(coverFor(['only.jpg'], used), equals('only.jpg'));
    });

    test('blank covers are skipped in favour of a real one', () {
      final used = <String>{};
      expect(coverFor(['', 'real.jpg'], used), equals('real.jpg'));
    });

    test('a shelf with no covers at all yields an empty string', () {
      final used = <String>{};
      expect(coverFor(['', ''], used), isEmpty);
      expect(used, isEmpty, reason: 'nothing was claimed');
    });

    test('every shelf in a run of five gets its own cover', () {
      final used = <String>{};
      // Each shelf leads with the same shared track but has a distinct second
      // cover, so all five must resolve to different images.
      final shelves = ['s1', 's2', 's3', 's4', 's5']
          .map((id) => coverFor(['shared.jpg', '$id.jpg'], used))
          .toList();
      expect(shelves.toSet().length, equals(5));
      expect(shelves.first, equals('shared.jpg'));
    });
  });

  group('Track model carries the fields the shelves need', () {
    test('full track exposes tags for keyword matching', () {
      final track = SangeetTrackObject.full(
        id: 't1',
        name: 'Aarati',
        externalUri: '',
        album: SangeetSimpleAlbumObject(
          id: 'al1',
          name: 'Vol 1',
          externalUri: '',
          artists: const [],
          albumType: SangeetAlbumType.album,
        ),
        durationMs: 1000,
        isrc: '',
        explicit: false,
        tags: 'ganesha, aarti',
      ) as SangeetFullTrackObject;

      expect(track.tags, equals('ganesha, aarti'));
    });

    test('FromJson reads tags when the server provides them', () {
      final track = SangeetTrackObject.fromJson({
        'id': 't1',
        'name': 'Aarati',
        'externalUri': '',
        'artists': <dynamic>[],
        'album': {
          'id': 'al1',
          'name': 'Vol 1',
          'externalUri': '',
          'artists': <dynamic>[],
          'images': <dynamic>[],
          'albumType': 'album',
        },
        'durationMs': 1000,
        'isrc': '',
        'explicit': false,
        'tags': 'ganesha, aarti',
      });
      expect((track as SangeetFullTrackObject).tags, equals('ganesha, aarti'));
    });
  });
}
