// Tests for the shared plain-lyrics renderer.
//
// It is shared precisely because the two plain surfaces used to disagree: the
// standalone lyrics page classified `{Pallavi}` lines and drew a divider, while
// the player's Plain tab printed the braces verbatim, so the same song looked
// different on two screens. These tests pin the widget behaviour that both
// surfaces now get from one place.
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/lyrics/lyrics_ornament_divider.dart';
import 'package:sangeet/components/lyrics/marked_plain_lyrics.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

Widget _harness(Widget child) => Theme(
      data: ThemeData(
        radius: .5,
        iconTheme: const IconThemeProperties(),
        colorScheme: BhaktiColorSchemes.lightMaroon(),
        surfaceOpacity: .8,
        surfaceBlur: 10,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800)),
          child: child,
        ),
      ),
    );

void main() {
  group('hasMarks drives the cheap path', () {
    test('a song with no heading does not ask for per-line rendering', () {
      expect(MarkedPlainLyrics.hasMarks('Om Namah Shivaya\nHari Om'), isFalse);
      expect(MarkedPlainLyrics.hasMarks(''), isFalse);
      expect(MarkedPlainLyrics.hasMarks('a { b\nc } d'), isFalse);
    });

    test('a song with a heading does', () {
      expect(MarkedPlainLyrics.hasMarks('{Pallavi}\nOm Namah Shivaya'), isTrue);
      expect(MarkedPlainLyrics.hasMarks('Om\n{Charanam}\nHari'), isTrue);
    });

    test('a BANNER is not a heading, so it does not trigger this path', () {
      // `{{Music}}` belongs to the synced renderer; treating it as a plain
      // heading would put a divider where a banner belongs.
      expect(MarkedPlainLyrics.hasMarks('{{Music}}'), isFalse);
    });
  });

  testWidgets('a heading line renders as an ornament divider', (tester) async {
    await tester.pumpWidget(
      _harness(
        MarkedPlainLyrics(
          lyrics: '{Pallavi}\nOm Namah Shivaya\n{Charanam}\nHari Om',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LyricsOrnamentDivider), findsNWidgets(2));
    // The heading TEXT must not also be printed as a sung line.
    expect(find.text('{Pallavi}'), findsNothing);
    expect(find.text('Om Namah Shivaya'), findsOneWidget);
    expect(find.text('Hari Om'), findsOneWidget);
  });

  testWidgets('a song with no headings renders every line as text',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        MarkedPlainLyrics(
          lyrics: 'Om Namah Shivaya\nHari Om',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LyricsOrnamentDivider), findsNothing);
    expect(find.text('Om Namah Shivaya'), findsOneWidget);
    expect(find.text('Hari Om'), findsOneWidget);
  });

  testWidgets('the banner spelling is NOT turned into a plain divider',
      (tester) async {
    // It is the synced renderer's marker; the plain path must leave it alone
    // rather than half-honouring it.
    await tester.pumpWidget(
      _harness(
        MarkedPlainLyrics(
          lyrics: '\u266A Music \u266A\nHari Om',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LyricsOrnamentDivider), findsNothing);
  });
}
