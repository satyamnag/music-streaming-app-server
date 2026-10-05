// Regression tests for the track card's title layout.
//
// The contract the card has to hold, on a 110dp tile:
//
//   * the name gets at most TWO lines and never a third;
//   * line one holds the first word and line two holds the rest;
//   * a name short enough to fit on one line keeps its single line;
//   * the play control is right-aligned on line ONE, and only drops to line two
//     when the first word would not fit beside it;
//   * every card is EXACTLY the same height, whatever the name does.
//
// These are render-box assertions against the real widget, so a change to the
// measuring rule, the split rule or the reserved block fails here rather than
// only being visible as a clipped name on a device.
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

/// A 110dp tile at the density the grids actually use (3 columns, 9dp insets,
/// 6dp gutters on a 360dp-wide screen).
const double _tile = 110;

/// Names that exercise every branch of the split rule, all real catalogue names.
const List<String> _names = <String>[
  'Narayana!', // one word, comfortably short
  'Maya Kadali', // two short words
  'Niluvadu Manasu', // two words, wraps under natural wrapping
  'Bhadradri Ramayya Nidra Levayya', // five words, line two overflows
  'Vandanam Sreeraama! Inakula Soma', // the longest name in the catalogue
  'Sooryavamsha Ratna', // first word too wide to sit beside the control
  'Haaratulettare Sreeraamuniki', // first word too wide, 14 characters
];

Widget _harness(Widget child) {
  return Theme(
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
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: _tile, child: child),
        ),
      ),
    ),
  );
}

Widget _card(String title, {bool withControl = true}) {
  return TrackCard(
    width: _tile,
    // An asset path (not a URL) keeps the cover synchronous and offline, so the
    // test measures the title block and never waits on a network image.
    imageUrl: Assets.images.placeholder.path,
    title: title,
    titleLines: 2,
    locked: false,
    onTap: () {},
    onPlay: withControl ? () {} : null,
  );
}

/// The play control, found by the semantics label it publishes.
Finder _controlFor(String title) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Play $title',
    );

void main() {
  testWidgets('every name yields a card of exactly the reserved height',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final heights = <String, double>{};
    for (final name in _names) {
      await tester.pumpWidget(_harness(_card(name)));
      expect(tester.takeException(), isNull, reason: 'rendering "$name"');
      heights[name] = tester.getSize(find.byType(TrackCard)).height;
    }

    final distinct = heights.values.toSet();
    expect(
      distinct.length,
      1,
      reason: 'all cards must be the same height, got $heights',
    );

    // And that one height is the number the layout published, so the rows and
    // grids that size themselves from it cannot disagree with the card.
    final context = tester.element(find.byType(TrackCard));
    expect(
      heights.values.first,
      closeTo(HomeSectionLayout.twoLineTrackCardHeight(context, _tile), 0.01),
    );
  });

  testWidgets('the reserved block and the control keep their sizes',
      (tester) async {
    await tester.pumpWidget(_harness(_card('Niluvadu Manasu')));
    final context = tester.element(find.byType(TrackCard));

    // The control is still 0.75x the album card's 30dp.
    expect(
      tester.getSize(_controlFor('Niluvadu Manasu')).width,
      closeTo(HomeSectionLayout.trackPlayButtonDiameter(context), 0.01),
    );
    expect(
      HomeSectionLayout.trackPlayButtonDiameter(context),
      closeTo(22.5, 0.01),
    );
  });

  testWidgets('the control sits on line one when the first word fits beside it',
      (tester) async {
    // "Maya" is deliberately short. `flutter test` renders with a fixed-width
    // fallback font whose every glyph is one em wide, so a first word that fits
    // beside the control under Roboto on a device can still be "too wide" here.
    // Four characters fit under either font, which keeps this assertion about the
    // LAYOUT rather than about the test font's metrics.
    const name = 'Maya Kadali';
    await tester.pumpWidget(_harness(_card(name)));
    final context = tester.element(find.byType(TrackCard));

    final cardTop = tester.getTopLeft(find.byType(TrackCard)).dy;
    final blockTop = cardTop +
        _tile +
        (HomeSectionLayout.cardTextGap * Theme.of(context).scaling);
    final lineBox = HomeSectionLayout.trackTitleLineBox(context);
    // Line one is as tall as the control, which is taller than a text line.
    final diameter = HomeSectionLayout.trackPlayButtonDiameter(context);

    final controlTop = tester.getTopLeft(_controlFor(name)).dy;
    expect(
      controlTop,
      closeTo(blockTop, 0.5),
      reason: 'a short first word must leave the control on line one',
    );
    expect(
      controlTop,
      lessThan(blockTop + math_max(lineBox, diameter)),
    );
  });

  testWidgets('the control drops to line two when the first word is too wide',
      (tester) async {
    // "Sooryavamsha" alone is ~93dp against the ~75dp line one has beside a
    // 22.5dp control, so the control must move rather than truncate the word.
    const name = 'Sooryavamsha Ratna';
    await tester.pumpWidget(_harness(_card(name)));
    final context = tester.element(find.byType(TrackCard));

    final cardTop = tester.getTopLeft(find.byType(TrackCard)).dy;
    final blockTop = cardTop +
        _tile +
        (HomeSectionLayout.cardTextGap * Theme.of(context).scaling);
    final lineBox = HomeSectionLayout.trackTitleLineBox(context);

    final controlTop = tester.getTopLeft(_controlFor(name)).dy;
    expect(
      controlTop,
      greaterThanOrEqualTo(blockTop + lineBox - 0.5),
      reason: 'a first word too wide for line one pushes the control to line two',
    );
  });

  testWidgets('a card without a control is the same height as one with it',
      (tester) async {
    await tester.pumpWidget(_harness(_card('Niluvadu Manasu')));
    final withControl = tester.getSize(find.byType(TrackCard)).height;

    await tester.pumpWidget(
      _harness(_card('Niluvadu Manasu', withControl: false)),
    );
    final withoutControl = tester.getSize(find.byType(TrackCard)).height;

    expect(withoutControl, closeTo(withControl, 0.01));
    expect(_controlFor('Niluvadu Manasu'), findsNothing);
  });

  testWidgets('the layout survives large text scales without overflowing',
      (tester) async {
    for (final scale in <double>[0.8, 1.0, 1.3, 2.0]) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(scale),
          ),
          child: _harness(_card('Bhadradri Ramayya Nidra Levayya')),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'text scale $scale must not overflow the reserved block',
      );
    }
  });
}

/// Local helper so the assertions above read the way the layout does.
double math_max(double a, double b) => a > b ? a : b;
