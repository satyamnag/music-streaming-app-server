// Guards the capsule drawn around the line being sung.
//
// Two things about it can break the screen rather than merely look wrong:
//  * it must never overflow. It sits inside a centred lyric row beside two fixed
//    ornaments, so a long Telugu line at a small width is the exact case that
//    would throw a layout overflow if the pill were not flexible;
//  * its ink must stay readable on its own cream surface, which is a different
//    surface from the artwork the rest of the screen is drawn on. The palette
//    colour used for the other lines is chosen against the artwork and would be
//    white on cream, so the capsule carries a fixed dark ink - and this test
//    holds it to the WCAG AA ratio rather than to "looks dark enough".

import 'dart:math' as math;

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/lyrics/lyrics_active_line_capsule.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

/// Relative luminance, per WCAG 2.x.
double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

Widget _harness(Widget child, {double width = 360}) {
  return material.MaterialApp(
    home: Builder(
      builder: (context) => Theme(
        data: ThemeData(
          radius: .5,
          iconTheme: const IconThemeProperties(),
          colorScheme: BhaktiColorSchemes.lightMaroon(),
          surfaceOpacity: .8,
          surfaceBlur: 10,
        ),
        child: material.Scaffold(
          body: material.Center(
            child: material.SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('LyricsActiveLineCapsule', () {
    testWidgets('draws the line it is given', (tester) async {
      await tester.pumpWidget(
        _harness(
          const LyricsActiveLineCapsule(
            child: Text('కన్న తల్లీ నీవే మాదిక్కు ఇంక.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('కన్న తల్లీ నీవే మాదిక్కు ఇంక.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long line and its translations stay inside a narrow phone',
        (tester) async {
      // 320dp is a real small-phone width, and this is roughly the longest line
      // in the catalogue plus four translation sub-lines - the worst case the
      // capsule has to absorb without a layout overflow.
      await tester.pumpWidget(
        _harness(
          const LyricsActiveLineCapsule(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'స్వర్ణ కవచ శ్రీ దుర్గాంబిక, సర్వ జన రక్షకి వజ్ర కవచ, '
                  'కనక స్వరూపిణై కనుముందు వెలసిన కన్న తల్లీ నీవే మాదిక్కు ఇంక.',
                  textAlign: TextAlign.center,
                ),
                Text('O Mother, you alone are my refuge and my strength.'),
                Text('हे माता, तुम ही मेरा आश्रय और शक्ति हो।'),
                Text('Suvarna kavacha Sri Durgaambika, sarva jana rakshaki.'),
              ],
            ),
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the capsule must shrink to the width its ornaments leave');
      expect(
        tester.getSize(find.byType(LyricsActiveLineCapsule)).width,
        lessThanOrEqualTo(320),
      );
    });

    test('the singing line keeps WCAG AA contrast on the cream capsule', () {
      // Normal-size text: 4.5:1. Both ends of the gradient are checked, because
      // the text can sit anywhere between them.
      expect(
        _contrast(LyricsActiveLineCapsule.ink, LyricsActiveLineCapsule.creamTop),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
          LyricsActiveLineCapsule.ink,
          LyricsActiveLineCapsule.creamBottom,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('uses the cream and gold the lyric decorations already use', () {
      // One visual family with LyricsOrnamentDivider ({Heading}) and
      // LyricsMusicBanner ({{Music}}) - not a second, invented palette.
      expect(LyricsActiveLineCapsule.gold, const Color(0xFFC9A227));
      expect(LyricsActiveLineCapsule.creamTop, const Color(0xFFFDF7E7));
    });
  });
}
