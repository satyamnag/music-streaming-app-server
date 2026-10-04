import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Color;
import 'package:sangeet/modules/home/sections/featured_playlists.dart';

/// Unit tests for the "Featured Playlist" chip rules.
///
/// The chips re-use the Specials shelves' proven word-start keyword rule, and
/// this file pins that rule plus the row-parsing contract (an admin row may
/// override a built-in chip, extra rows append, blank/whitespace values degrade
/// to "unset" rather than producing a broken chip).
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
