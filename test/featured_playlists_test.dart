import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Color;
import 'package:sangeet/modules/home/sections/featured_playlists.dart';

/// Unit tests for the "Featured Playlist" chip rules.
///
/// The chips re-use the Specials shelves' proven word-start keyword rule, and
/// this file pins that rule plus the row-parsing contract: the chips are built
/// entirely from admin rows — there is no built-in catalogue any more — so a
/// missing or malformed field has to degrade to a sane default instead of
/// producing a broken or invisible chip. Membership resolution (hand-picked
/// tracks, the optional keyword rule, de-duplication, ordering) is covered end
/// to end in dynamic_sections_test.dart.
void main() {
  group('chip keyword matching (shared with the Specials shelves)', () {
    test('a keyword matches at a word start, allowing suffixes', () {
      expect(matchesKeyword('om namah shivaya', 'shiva'), isTrue);
      expect(matchesKeyword('lingashtakam', 'linga'), isTrue);
      expect(matchesKeyword('govinda govinda', 'govinda'), isTrue);
      expect(matchesKeyword('gajanana', 'gajanana'), isTrue);
    });

    test('a short keyword does not match inside an unrelated word', () {
      // The "Vani Jairam" regression that drove this rule for the shelves.
      expect(matchesKeyword('krishna nee begane vani jairam', 'ram'), isFalse);
      expect(matchesKeyword('dramatic', 'rama'), isFalse);
    });

    test('multi-word keywords match as substrings', () {
      expect(matchesKeyword('rama raksha stotram', 'rama raksha'), isTrue);
      expect(matchesKeyword('ramaraksha', 'rama raksha'), isFalse);
    });
  });

  group('FeaturedPlaylistRow.fromJson', () {
    test('splits, trims and lowercases the comma-separated keywords', () {
      final row = FeaturedPlaylistRow.fromJson(<String, dynamic>{
        'id': 'krishna',
        'title': 'Krishna',
        'keywords': ' Krishna , GOVINDA ,, radha ',
      });
      expect(row.keywords, equals(['krishna', 'govinda', 'radha']));
    });

    test('reads colors and icon, treating blank strings as unset', () {
      final row = FeaturedPlaylistRow.fromJson(<String, dynamic>{
        'id': 'x',
        'title': 'X',
        'keywords': 'x',
        'colorFrom': '#112233',
        'colorTo': '   ',
        'icon': '',
      });
      expect(row.colorFrom, equals('#112233'));
      // The server sends '' for an unset color; the raw value is kept as-is and
      // the chip falls back to the theme when it cannot be parsed.
      expect(row.icon, equals(''));
    });

    test('a missing title or id still parses without throwing', () {
      final row = FeaturedPlaylistRow.fromJson(<String, dynamic>{});
      expect(row.id, isEmpty);
      expect(row.title, isEmpty);
      expect(row.keywords, isEmpty);
      expect(row.isHidden, isFalse);
    });

    test('sortOrder accepts a numeric string (JSON numbers can arrive as text)', () {
      final row = FeaturedPlaylistRow.fromJson(<String, dynamic>{
        'id': 'x',
        'title': 'X',
        'sortOrder': '3',
      });
      expect(row.sortOrder, equals(3));
    });

    test('isHidden is true only for an explicit boolean true', () {
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{'isHidden': true}).isHidden,
        isTrue,
      );
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{'isHidden': 'true'})
            .isHidden,
        isFalse,
      );
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{}).isHidden,
        isFalse,
      );
    });

    test('reads the hand-picked track list, dropping blanks', () {
      final row = FeaturedPlaylistRow.fromJson(<String, dynamic>{
        'trackIds': ['a', ' b ', ''],
      });
      expect(row.trackIds, equals(['a', 'b']));
    });

    test('a non-list trackIds is treated as "none" rather than throwing', () {
      // The server always sends an array; a string here would mean an older or
      // unexpected payload, and it must not take the whole chip row down.
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{'trackIds': 'a,b'})
            .trackIds,
        isEmpty,
      );
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{}).trackIds,
        isEmpty,
      );
    });

    test('matchKeywords defaults on and only an explicit false turns it off', () {
      // Defaulting on keeps a row whose payload predates migration 029 behaving
      // the way it did before (keyword matching), rather than silently emptying.
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{}).matchKeywords,
        isTrue,
      );
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{'matchKeywords': false})
            .matchKeywords,
        isFalse,
      );
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{'matchKeywords': 'false'})
            .matchKeywords,
        isTrue,
        reason: 'only a real boolean false disables the rule',
      );
    });

    test('reads the admin-uploaded icon url', () {
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{
          'iconUrl': 'https://cdn.example.com/icon.webp',
        }).iconUrl,
        equals('https://cdn.example.com/icon.webp'),
      );
      expect(
        FeaturedPlaylistRow.fromJson(<String, dynamic>{}).iconUrl,
        isNull,
      );
    });
  });

  group('chip color resolution', () {
    test('a configured color is used for both stops when only one is set', () {
      const chip = FeaturedPlaylist(
        id: 'x',
        title: 'X',
        keywords: ['x'],
        colorFrom: Color(0xFF123456),
        tracks: [],
      );
      const fallback = Color(0xFFABCDEF);
      expect(chip.colorFromOr(fallback), equals(const Color(0xFF123456)));
      // The second stop falls back to the first, so a single-color chip still
      // renders a sensible flat circle rather than transparent.
      expect(chip.colorToOr(fallback), equals(const Color(0xFF123456)));
    });

    test('an unconfigured chip falls back to the theme color for both stops', () {
      const chip = FeaturedPlaylist(
        id: 'x',
        title: 'X',
        keywords: ['x'],
        tracks: [],
      );
      const fallback = Color(0xFFABCDEF);
      expect(chip.colorFromOr(fallback), equals(fallback));
      expect(chip.colorToOr(fallback), equals(fallback));
    });
  });
}
