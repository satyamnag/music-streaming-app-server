import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/lyrics/lyrics_markup.dart';

/// Tests for the author-marked lyric line rules.
///
/// `{Heading}`  -> ornament divider (plain lyrics)
/// `{{Music}}`  -> "♪ Music ♪" banner (synced lyrics)
void main() {
  group('double braces -> banner', () {
    test('a simple banner line is detected', () {
      final r = parseMarkedLyricsLine('{{Music}}');
      expect(r.mark, LyricsLineMark.banner);
      expect(r.label, 'Music');
      expect(r.isMarked, isTrue);
    });

    test('whitespace inside the braces is trimmed', () {
      expect(parseMarkedLyricsLine('{{   Interlude   }}').label, 'Interlude');
      expect(parseMarkedLyricsLine('  {{Music}}  ').label, 'Music');
    });

    test('arbitrary labels are preserved verbatim', () {
      expect(parseMarkedLyricsLine('{{Instrumental Break}}').label,
          'Instrumental Break');
      expect(parseMarkedLyricsLine('{{Charanam}}').label, 'Charanam');
    });

    test('an empty banner is not a banner', () {
      expect(parseMarkedLyricsLine('{{}}').mark, LyricsLineMark.none);
      expect(parseMarkedLyricsLine('{{   }}').mark, LyricsLineMark.none);
    });

    test('double braces win over single braces', () {
      // {{x}} must never be treated as a plain heading.
      expect(isHeadingLine('{{Music}}'), isFalse);
      expect(isBannerLine('{{Music}}'), isTrue);
    });
  });

  group('single braces -> ornament heading', () {
    test('a simple heading is detected', () {
      final r = parseMarkedLyricsLine('{Pallavi}');
      expect(r.mark, LyricsLineMark.heading);
      expect(r.label, 'Pallavi');
    });

    test('whitespace is trimmed and real content preserved', () {
      expect(parseMarkedLyricsLine('{  Charanam  }').label, 'Charanam');
      expect(parseMarkedLyricsLine('{Verse 2}').label, 'Verse 2');
    });

    test('an empty heading is not a heading', () {
      expect(parseMarkedLyricsLine('{}').mark, LyricsLineMark.none);
      expect(parseMarkedLyricsLine('{ }').mark, LyricsLineMark.none);
    });

    test('nested braces are not treated as a heading', () {
      // Guards against `{a {b} c}` producing a half-parsed label.
      expect(parseMarkedLyricsLine('{a {b} c}').mark, LyricsLineMark.none);
    });
  });

  group('the banner written in its own glyphs -> banner', () {
    // `♪ Music ♪` is what the banner RENDERS, and it is also what the catalogue
    // actually stores as the cue text of both synced songs. Without this rule the
    // marker the author typed came out as an ordinary sung line, which is
    // indistinguishable from "the double-brace formula does not work".
    test('the rendered spelling is recognised', () {
      final r = parseMarkedLyricsLine('\u266A Music \u266A');
      expect(r.mark, LyricsLineMark.banner);
      expect(r.label, 'Music');
    });

    test('a missing space between label and note is still a banner', () {
      // One cue in the live data is stored as `♪ Music♪` with no space.
      final r = parseMarkedLyricsLine('\u266A Music\u266A');
      expect(r.mark, LyricsLineMark.banner);
      expect(r.label, 'Music');
    });

    test('surrounding whitespace and other labels are handled', () {
      expect(parseMarkedLyricsLine('  \u266A Interlude \u266A  ').label,
          'Interlude');
      expect(parseMarkedLyricsLine('\u266AInstrumental Break\u266A').label,
          'Instrumental Break');
    });

    test('an empty label is not a banner', () {
      expect(parseMarkedLyricsLine('\u266A \u266A').mark, LyricsLineMark.none);
      expect(parseMarkedLyricsLine('\u266A\u266A').mark, LyricsLineMark.none);
    });

    test('a sung line that merely mentions a note is untouched', () {
      // Only a line that is *entirely* note-wrapped counts, exactly like braces.
      for (final line in [
        '\u266A Om Namah Shivaya', // opens but never closes
        'Om Namah Shivaya \u266A', // closes but never opens
        '\u266A a \u266A b \u266A', // a note in the middle
        'Sing \u266A along',
      ]) {
        expect(
          parseMarkedLyricsLine(line).mark,
          LyricsLineMark.none,
          reason: 'line: "$line"',
        );
      }
    });
  });

  group('ordinary lyric lines are untouched', () {
    test('plain text passes through', () {
      for (final line in [
        'Om Namah Shivaya',
        '',
        '   ',
        'Krishna Nee Begane',
        'a } b',
        'a { b',
        'not a } brace { line',
      ]) {
        final r = parseMarkedLyricsLine(line);
        expect(r.mark, LyricsLineMark.none, reason: 'line: "$line"');
        expect(r.label, isEmpty);
        expect(r.raw, line, reason: 'raw must be preserved');
      }
    });

    test('a brace mid-line does not mark the line', () {
      // Only a line that is *entirely* wrapped counts.
      expect(parseMarkedLyricsLine('hello {world}').mark, LyricsLineMark.none);
      expect(parseMarkedLyricsLine('{world} hello').mark, LyricsLineMark.none);
    });

    test('raw is always the original string', () {
      expect(parseMarkedLyricsLine('{{Music}}').raw, '{{Music}}');
      expect(parseMarkedLyricsLine('{Pallavi}').raw, '{Pallavi}');
      expect(parseMarkedLyricsLine('Om').raw, 'Om');
    });
  });

  group('mixed lyrics document', () {
    test('only marked lines are classified as marked', () {
      const lyrics = '''
{Pallavi}
Om Namah Shivaya
{{Music}}
Hari Om
{Charanam}
''';
      final marks =
          lyrics.split('\n').map(parseMarkedLyricsLine).toList();
      expect(marks.where((m) => m.mark == LyricsLineMark.heading).map((m) => m.label),
          equals(['Pallavi', 'Charanam']));
      expect(marks.where((m) => m.mark == LyricsLineMark.banner).map((m) => m.label),
          equals(['Music']));
      // 6 lines: 2 headings + 1 banner + 3 ordinary (2 sung + 1 trailing blank).
      expect(marks.length, 6);
      expect(marks.where((m) => m.mark == LyricsLineMark.none).length, 3);
      expect(marks.where((m) => m.isMarked).length, 3);
    });
  });
}
