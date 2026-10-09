// Guards the lyric SUB-TAB order on both the Plain and Sync tabs.
//
// The rule, stated once: Telugu, then English TRANSLITERATION, then English
// TRANSLATION, then the Hindi pair. A listener reads the original script, then
// how it sounds, then what it means.
//
// ## The bug this replaces
// `lib/pages/player/lyrics.dart` built its sub-tab list as
// `[te, en, hi, enTr, hiTr]` - both TRANSLATIONS before both
// TRANSLITERATIONS - so the Plain and Sync sub-tabs read "Telugu, English
// (Translation), English (Transliteration)".
//
// It survived because the line above it said "All 5 languages in display order
// (matches kLyricLanguages)". The comment asserted correctness, so the list was
// never re-read. That is why the decisive assertion below is a COMPARISON
// against `kLyricLanguages` rather than a hard-coded copy of the expected order:
// a copy can itself be wrong, whereas a comparison cannot disagree with the
// single source of truth.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/pages/lyrics/multilang_lyrics.dart';

void main() {
  group('the canonical language order', () {
    test('kLyricLanguages is Telugu, En-transliteration, En-translation', () {
      final keys = kLyricLanguages.map((d) => d.key).toList();

      expect(keys[0], LyricLanguages.te);
      expect(
        keys[1],
        LyricLanguages.enTr,
        reason: 'transliteration must come before translation: the listener '
            'reads how it sounds before what it means',
      );
      expect(keys[2], LyricLanguages.en);
    });

    test('no TRANSLATION precedes its TRANSLITERATION', () {
      final keys = kLyricLanguages.map((d) => d.key).toList();

      final enTr = keys.indexOf(LyricLanguages.enTr);
      final en = keys.indexOf(LyricLanguages.en);
      final hiTr = keys.indexOf(LyricLanguages.hiTr);
      final hi = keys.indexOf(LyricLanguages.hi);

      expect(enTr, lessThan(en),
          reason: 'English transliteration must precede English translation');
      expect(hiTr, lessThan(hi),
          reason: 'Hindi transliteration must precede Hindi translation');
    });

    test('LyricLanguages.order agrees with kLyricLanguages', () {
      // A THIRD copy of the order, used directly by the synced lyrics screen.
      // It was wrong too, so it is compared rather than trusted.
      expect(
        LyricLanguages.order,
        kLyricLanguages.map((d) => d.key).toList(),
        reason: 'LyricLanguages.order is consumed by `synced_lyrics.dart`; it '
            'must not disagree with the canonical list',
      );
    });
  });

  group('the player sub-tabs use that order', () {
    /// The `allLangs` list literal, read out of the player's lyrics screen.
    ///
    /// Read as source text because the list is a local inside `build` and is not
    /// reachable from a test. The parsing is deliberately strict: it must find
    /// the list and every entry, so a rename fails the test rather than silently
    /// checking nothing.
    List<String> playerSubTabOrder() {
      final source = File('lib/pages/player/lyrics.dart').readAsStringSync();

      final block = RegExp(
        r'const allLangs = \[(.*?)\];',
        dotAll: true,
      ).firstMatch(source);
      expect(block, isNotNull,
          reason: 'the player must still declare `allLangs`; if it was renamed, '
              'update this test so it keeps guarding the order');

      return RegExp(r'LyricLanguages\.(\w+)')
          .allMatches(block!.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }

    test('the sub-tab language order matches kLyricLanguages', () {
      final player = playerSubTabOrder();
      final canonical = kLyricLanguages.map((d) => d.key).toList();

      // The player names the ENUM CONSTANTS; `kLyricLanguages` stores the string
      // keys those constants hold. Map one to the other so the comparison is
      // order-vs-order rather than name-vs-name.
      const constantToKey = <String, String>{
        'te': LyricLanguages.te,
        'en': LyricLanguages.en,
        'hi': LyricLanguages.hi,
        'enTr': LyricLanguages.enTr,
        'hiTr': LyricLanguages.hiTr,
      };
      final playerKeys = player.map((c) => constantToKey[c]).toList();

      expect(player, isNotEmpty, reason: 'the sub-tab list must not be empty');
      expect(
        playerKeys.contains(null),
        isFalse,
        reason: 'an unknown constant appeared in `allLangs`; add it to '
            'constantToKey so this test keeps checking the real order',
      );
      expect(
        playerKeys,
        canonical,
        reason: 'the Player\'s Plain and Sync SUB-TABS must list languages in the '
            'same order as kLyricLanguages. This exact comparison is the point: '
            'the order was wrong before while a comment claimed it matched.',
      );

      // Restate the requirement positively, so a failure reads as the user
      // complaint rather than only as a list mismatch.
      expect(playerKeys[1], LyricLanguages.enTr);
      expect(playerKeys[2], LyricLanguages.en);
    });

    test('both sub-tab bars derive from the same ordered list', () {
      // `plainSubBar` and `syncSubBar` must both filter the ONE list, so they
      // cannot disagree with each other either.
      final source = File('lib/pages/player/lyrics.dart').readAsStringSync();

      expect(source.contains('availablePlain'), isTrue);
      expect(source.contains('availableSync'), isTrue);
      expect(
        RegExp(r'availablePlain\s*=').hasMatch(source) &&
            RegExp(r'availableSync\s*=').hasMatch(source),
        isTrue,
        reason: 'both must be derived, so one source of order feeds both tabs',
      );
      // Both must be filtered FROM allLangs rather than from separate literals.
      expect(
        RegExp(r'allLangs\.where').allMatches(source).length,
        greaterThanOrEqualTo(2),
        reason: 'the Plain and Sync lists must both filter allLangs; a second '
            'hand-written list is how the two orders drifted apart',
      );
    });
  });

  group('the plain-lyrics rows use that order too', () {
    test('the plain block lists transliteration before translation', () {
      final source =
          File('lib/pages/lyrics/plain_lyrics.dart').readAsStringSync();

      final te = source.indexOf("(label: 'Telugu'");
      final enTr = source.indexOf("(label: 'English (Transliteration)'");
      final en = source.indexOf("(label: 'English (Translation)'");

      expect(te, greaterThan(-1), reason: 'Telugu must be listed');
      expect(enTr, greaterThan(-1),
          reason: 'English (Transliteration) must be listed');
      expect(en, greaterThan(-1),
          reason: 'English (Translation) must be listed');

      expect(te, lessThan(enTr));
      expect(
        enTr,
        lessThan(en),
        reason: 'on the Plain tab the English transliteration must be rendered '
            'above the English translation',
      );
    });
  });
}
