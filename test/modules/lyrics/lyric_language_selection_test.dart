// Guards the multi-language lyrics rules ported from the Soulful Bhakti web app's
// lyrics panel (`components/LyricsPanel.tsx`).
//
// The facility is: the listener picks which lyric languages to read (Telugu,
// English transliteration, English translation, ...), and the Plain and Sync tabs
// stack every picked language, one, two, three or all of them at once.
//
// These are the rules that can silently empty the screen or misalign it, so they
// are tested as pure functions rather than only through the widget tree:
//  * a tab must never render nothing while it has any text;
//  * pressing the only shown chip must not clear it;
//  * the languages must appear in display order, not selection order;
//  * the plain sheet's per-language blocks must line up line by line.

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/modules/lyrics/lyric_language_selection.dart';

void main() {
  const available = [
    LyricLanguages.te,
    LyricLanguages.enTr,
    LyricLanguages.en,
  ];

  group('activeLanguages', () {
    test('one language selected draws exactly that one', () {
      expect(
        LyricLanguageSelection.activeLanguages(
          available: available,
          selected: {LyricLanguages.te},
        ),
        [LyricLanguages.te],
      );
    });

    test('two and three selected draw two and three, in display order', () {
      // Selected out of order on purpose: the sheet must still read
      // Telugu -> transliteration -> translation.
      expect(
        LyricLanguageSelection.activeLanguages(
          available: available,
          selected: {LyricLanguages.en, LyricLanguages.te},
        ),
        [LyricLanguages.te, LyricLanguages.en],
      );
      expect(
        LyricLanguageSelection.activeLanguages(
          available: available,
          selected: {
            LyricLanguages.en,
            LyricLanguages.te,
            LyricLanguages.enTr,
          },
        ),
        [LyricLanguages.te, LyricLanguages.enTr, LyricLanguages.en],
      );
    });

    test('a selection this tab cannot show falls back to its first language',
        () {
      // e.g. the reader picked only Hindi on the Sync tab, but this track has no
      // Hindi synced lines: the tab still shows Telugu rather than nothing.
      expect(
        LyricLanguageSelection.activeLanguages(
          available: available,
          selected: {LyricLanguages.hi},
        ),
        [LyricLanguages.te],
      );
    });

    test('a tab with no text at all draws nothing', () {
      expect(
        LyricLanguageSelection.activeLanguages(
          available: const [],
          selected: {LyricLanguages.te},
        ),
        isEmpty,
      );
    });

    test('languages the reader selected but the tab lacks are dropped', () {
      expect(
        LyricLanguageSelection.activeLanguages(
          available: [LyricLanguages.te, LyricLanguages.hi],
          selected: {LyricLanguages.te, LyricLanguages.en, LyricLanguages.hi},
        ),
        [LyricLanguages.te, LyricLanguages.hi],
      );
    });
  });

  group('toggle', () {
    test('adds a language that is not selected', () {
      expect(
        LyricLanguageSelection.toggle(
          selected: {LyricLanguages.te},
          language: LyricLanguages.en,
          available: available,
        ),
        {LyricLanguages.te, LyricLanguages.en},
      );
    });

    test('removes a language when others are still shown', () {
      expect(
        LyricLanguageSelection.toggle(
          selected: {LyricLanguages.te, LyricLanguages.en},
          language: LyricLanguages.en,
          available: available,
        ),
        {LyricLanguages.te},
      );
    });

    test('refuses to remove the only shown language', () {
      // Pressing the single selected chip must leave the sheet as it is, not
      // blank it - the web app's "keep at least one language selected" rule.
      expect(
        LyricLanguageSelection.toggle(
          selected: {LyricLanguages.te},
          language: LyricLanguages.te,
          available: available,
        ),
        {LyricLanguages.te},
      );
    });

    test('still removes a selected language this tab cannot show', () {
      // It is not being drawn here, so removing it cannot empty this tab.
      expect(
        LyricLanguageSelection.toggle(
          selected: {LyricLanguages.te, LyricLanguages.hi},
          language: LyricLanguages.hi,
          available: available,
        ),
        {LyricLanguages.te},
      );
    });

    test('returns a new set instead of mutating the caller\'s', () {
      final selected = {LyricLanguages.te};
      final next = LyricLanguageSelection.toggle(
        selected: selected,
        language: LyricLanguages.en,
        available: available,
      );
      expect(selected, {LyricLanguages.te});
      expect(next, isNot(same(selected)));
    });
  });

  group('buildPlainLyricRows', () {
    test('aligns the languages line by line', () {
      final rows = buildPlainLyricRows(
        languages: const [LyricLanguages.te, LyricLanguages.enTr],
        textByLanguage: const {
          LyricLanguages.te: 'సుఖ మధువు కడలిలో\nసోలు నా మదికి',
          LyricLanguages.enTr: 'Sukha madhuvu kadalilo\nSolu na madiki',
        },
      );

      expect(rows, hasLength(2));
      expect(rows[0].texts[LyricLanguages.te], 'సుఖ మధువు కడలిలో');
      expect(rows[0].texts[LyricLanguages.enTr], 'Sukha madhuvu kadalilo');
      expect(rows[1].texts[LyricLanguages.te], 'సోలు నా మదికి');
      expect(rows[1].texts[LyricLanguages.enTr], 'Solu na madiki');
    });

    test('a shorter language simply has no text on the extra rows', () {
      final rows = buildPlainLyricRows(
        languages: const [LyricLanguages.te, LyricLanguages.en],
        textByLanguage: const {
          LyricLanguages.te: 'one\ntwo\nthree',
          LyricLanguages.en: 'ONE',
        },
      );

      expect(rows, hasLength(3));
      expect(rows[0].texts[LyricLanguages.en], 'ONE');
      expect(rows[1].texts.containsKey(LyricLanguages.en), isFalse);
      expect(rows[2].texts.containsKey(LyricLanguages.en), isFalse);
    });

    test('keeps blank rows, so stanza breaks survive', () {
      final rows = buildPlainLyricRows(
        languages: const [LyricLanguages.te],
        textByLanguage: const {LyricLanguages.te: 'first\n\nsecond'},
      );

      expect(rows, hasLength(3));
      expect(rows[1].isBlank, isTrue);
      expect(rows[2].texts[LyricLanguages.te], 'second');
    });

    test('the markup source is the first non-empty language in display order',
        () {
      // Telugu carries the author's {Heading}; when it is empty the next shown
      // language supplies it.
      final rows = buildPlainLyricRows(
        languages: const [LyricLanguages.te, LyricLanguages.en],
        textByLanguage: const {
          LyricLanguages.te: '\n{Pallavi}',
          LyricLanguages.en: 'Pallavi\nPallavi',
        },
      );

      expect(rows[0].primary, 'Pallavi',
          reason: 'Telugu is blank on row 0, so English supplies the markup');
      expect(rows[1].primary, '{Pallavi}',
          reason: 'Telugu wins where it has text');
    });

    test('handles CRLF input and trims trailing spaces', () {
      final rows = buildPlainLyricRows(
        languages: const [LyricLanguages.te],
        textByLanguage: const {LyricLanguages.te: 'one  \r\ntwo\r\n'},
      );

      expect(rows.map((r) => r.primary).toList(), ['one', 'two']);
    });

    test('no text at all yields no rows', () {
      expect(
        buildPlainLyricRows(
          languages: const [LyricLanguages.te],
          textByLanguage: const {LyricLanguages.te: ''},
        ),
        isEmpty,
      );
      expect(
        buildPlainLyricRows(
          languages: const [LyricLanguages.te],
          textByLanguage: const {},
        ),
        isEmpty,
      );
    });
  });
}
