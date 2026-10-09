// Guards that brace-marked labels are parsed WHOLE and rendered without
// truncation.
//
// The braces are a markup instruction: `{Pallavi}` is a section heading and
// `{{Music}}` is a music banner. The label an author writes between them is
// display text and must appear in full. Two things could cut it:
//
//  1. the PARSER, if a regex failed to capture a long or nested label, and
//  2. the RENDERER, if the Text carrying it used `maxLines: 1` with an ellipsis
//     overflow - which is exactly what the ornament divider did, cutting long
//     headings to "{Vachan...".
//
// These tests pin both. The renderer half is asserted by laying the real widgets
// out at a narrow width and checking that the label's rendered text is not
// clipped, and that the widget does not overflow its box.

// The theme harness below is rebuilt per test with a differing `MediaQuery`, so
// several of its sub-widgets cannot be `const`; the lint is noise here.
// ignore_for_file: prefer_const_constructors

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/lyrics/lyrics_music_banner.dart';
import 'package:sangeet/components/lyrics/lyrics_ornament_divider.dart';
import 'package:sangeet/modules/lyrics/lyrics_markup.dart';

void main() {
  group('brace parsing keeps the whole label', () {
    test('a single-braced heading yields its full inner text', () {
      final parsed = parseMarkedLyricsLine('{Pallavi}');
      expect(parsed.mark, LyricsLineMark.heading);
      expect(parsed.label, 'Pallavi');
    });

    test('a double-braced banner yields its full inner text', () {
      final parsed = parseMarkedLyricsLine('{{Music}}');
      expect(parsed.mark, LyricsLineMark.banner);
      expect(parsed.label, 'Music');
    });

    test('a LONG label is not truncated by the parser', () {
      const long = 'Charanam 1 - Nee Pada Bhakti Yento Goppa';
      final parsed = parseMarkedLyricsLine('{$long}');
      expect(parsed.mark, LyricsLineMark.heading);
      expect(parsed.label, long,
          reason: 'the parser must capture the whole label; a regex that '
              'over-trimmed would lose words before the renderer ever saw them');
    });

    test('a long banner label is not truncated by the parser', () {
      const long = 'Interlude - Flute and Mridangam';
      final parsed = parseMarkedLyricsLine('{{$long}}');
      expect(parsed.mark, LyricsLineMark.banner);
      expect(parsed.label, long);
    });

    test('whitespace around the label is trimmed but inner words are kept', () {
      final parsed = parseMarkedLyricsLine('{  Anupallavi  }');
      expect(parsed.label, 'Anupallavi');
    });

    test('a nested single brace inside a double-braced label is preserved', () {
      final parsed = parseMarkedLyricsLine('{{a {b} c}}');
      expect(parsed.mark, LyricsLineMark.banner);
      expect(parsed.label, 'a {b} c');
    });

    test('an empty brace pair is not a heading', () {
      expect(parseMarkedLyricsLine('{}').mark, LyricsLineMark.none);
      expect(parseMarkedLyricsLine('{{}}').mark, LyricsLineMark.none);
    });

    test('a plain sung line is untouched', () {
      final parsed = parseMarkedLyricsLine('Rama Rama Rama');
      expect(parsed.mark, LyricsLineMark.none);
      expect(parsed.label, '');
    });
  });

  group('brace labels render whole on ONE line', () {
    /// The number of lines a rendered [Text] actually occupies.
    ///
    /// Read from the paint-time layout rather than from the widget's
    /// configuration: `maxLines: 1` alone would not prove the label fits on one
    /// line, only that it is not allowed more.
    /// The height of the rendered label, in logical pixels.
    ///
    /// Measured off the actual `RenderParagraph` in the tree, so it reflects the
    /// real laid-out widget rather than a reconstruction of its style.
    double renderedHeight(WidgetTester tester, String text) =>
        tester.getSize(find.text(text)).height;

    /// The width the label's paragraph occupies.
    double renderedWidth(WidgetTester tester, String text) =>
        tester.getSize(find.text(text)).width;

    testWidgets('a long ornament heading stays on ONE line, untruncated',
        (tester) async {
      const long = 'Charanam 1 - Nee Pada Bhakti Yento Goppa';

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(
              radius: .5,
              iconTheme: const IconThemeProperties(),
              surfaceOpacity: .8,
              surfaceBlur: 10,
            ),
            child: const MediaQuery(
              data: MediaQueryData(size: Size(320, 800)),
              child: SizedBox(
                width: 320,
                child: LyricsOrnamentDivider(label: long),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(long));
      expect(text.data, long, reason: 'the whole label must be laid out');
      expect(
        text.overflow,
        isNot(TextOverflow.ellipsis),
        reason: 'an ellipsis silently hides the tail of the label',
      );
      expect(text.maxLines, 1, reason: 'the label must be capped at one line');
      expect(text.softWrap, isFalse,
          reason: 'soft wrap must be off, or a long label becomes two lines');

      // ONE line means the rendered height stays within a single line box. A
      // wrapped label would be roughly twice the line height, so comparing the
      // measured height against one line's height is what actually proves the
      // single-line requirement (a `maxLines` cap alone would not: it only
      // forbids more lines, it does not make the text fit on one).
      final oneLineHeight = (text.style?.fontSize ?? 12) *
          (text.style?.height ?? 1.0);
      expect(
        renderedHeight(tester, long),
        lessThanOrEqualTo(oneLineHeight * 1.6),
        reason: 'the heading must be rendered on exactly ONE line',
      );
    });

    testWidgets('the music banner keeps a long label on ONE line',
        (tester) async {
      const long = 'Interlude - Flute and Mridangam';

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(
              radius: .5,
              iconTheme: const IconThemeProperties(),
              surfaceOpacity: .8,
              surfaceBlur: 10,
            ),
            child: const MediaQuery(
              data: MediaQueryData(size: Size(320, 800)),
              child: SizedBox(
                width: 320,
                child: LyricsMusicBanner(label: long),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(long));
      expect(text.data, long);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, 1, reason: 'the label must be capped at one line');
      expect(text.softWrap, isFalse,
          reason: 'soft wrap must be off, or a long label becomes two lines');
      expect(
        renderedHeight(tester, long),
        lessThanOrEqualTo((text.style?.fontSize ?? 12) * 1.6),
        reason: 'the banner label must be rendered on exactly ONE line',
      );
    });

    testWidgets('a FittedBox scales the label rather than truncating it',
        (tester) async {
      // The mechanism that makes one line and no ellipsis possible at once.
      const long = 'Charanam 1 - Nee Pada Bhakti Yento Goppa';
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(
              radius: .5,
              iconTheme: const IconThemeProperties(),
              surfaceOpacity: .8,
              surfaceBlur: 10,
            ),
            child: const MediaQuery(
              data: MediaQueryData(size: Size(320, 800)),
              child: SizedBox(
                width: 320,
                child: LyricsOrnamentDivider(label: long),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(LyricsOrnamentDivider),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
        reason: 'scaleDown is what keeps the label whole AND on one line; '
            'without it the choice is between wrapping and an ellipsis',
      );
    });
  });

  group('the labels survive the worst case', () {
    testWidgets('neither widget overflows a narrow phone at a large text scale',
        (tester) async {
      // A long label at 1.5x text scale on a 320dp phone is the worst case for
      // both widgets. Overflowing would paint the yellow/black stripes and, in
      // release, silently clip the label.
      //
      // Each widget is laid out on its own inside a scrollable, which is how
      // the lyrics page actually presents them: a `CustomScrollView` gives
      // unbounded height and lets a wrapped label grow the row rather than
      // overflow it. (An earlier version of this test stacked them in a bare
      // `Column` with no height, which overflowed by its own construction and
      // said nothing about the widgets.)
      const long = 'Charanam 1 - Nee Pada Bhakti Yento Goppa';

      Future<void> expectNoOverflow(Widget child) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(1.5),
              ),
              child: Theme(
                data: ThemeData(
                  radius: .5,
                  iconTheme: const IconThemeProperties(),
                  surfaceOpacity: .8,
                  surfaceBlur: 10,
                ),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'a long braced label at a large text scale must not '
                'overflow its row');
      }

      await expectNoOverflow(
        const SizedBox(width: 320, child: LyricsOrnamentDivider(label: long)),
      );
      await expectNoOverflow(
        const SizedBox(width: 320, child: LyricsMusicBanner(label: long)),
      );
    });
  });
}
