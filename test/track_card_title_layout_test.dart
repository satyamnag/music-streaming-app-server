// Regression tests for the track card's title layout.
//
// The contract the card has to hold, on a 110dp tile:
//
//   * the name gets at most TWO lines and never a third;
//   * line one holds the first word and line two holds the rest;
//   * a name short enough to fit on one line keeps its single line;
//   * the play control is FIXED AT THE CARD'S BOTTOM-RIGHT CORNER, beside the
//     title block and bottom-aligned with it, exactly like the album card — it
//     does not share a text line, so it costs the title no width;
//   * every card is EXACTLY the same height, whatever the name does and whether
//     or not it has a control.
//
// These are render-box assertions against the real widget, so a change to the
// measuring rule, the split rule or the reserved block fails here rather than only
// being visible as a clipped name on a device.
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
  'Sooryavamsha Ratna', // a wide FIRST word: it must not be truncated
  'Haaratulettare Sreeraamuniki', // a 14-character first word
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

    expect(
      heights.values.toSet().length,
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

  testWidgets('the control is 0.75x the album control', (tester) async {
    await tester.pumpWidget(_harness(_card('Niluvadu Manasu')));
    final context = tester.element(find.byType(TrackCard));
    expect(
      HomeSectionLayout.trackPlayButtonDiameter(context),
      closeTo(22.5, 0.01),
    );
    expect(
      tester.getSize(_controlFor('Niluvadu Manasu')).width,
      closeTo(HomeSectionLayout.trackPlayButtonDiameter(context), 0.01),
    );
  });

  testWidgets('the control is pinned to the card BOTTOM-RIGHT corner',
      (tester) async {
    const name = 'Niluvadu Manasu';
    await tester.pumpWidget(_harness(_card(name)));
    final context = tester.element(find.byType(TrackCard));
    final scale = Theme.of(context).scaling;

    final card = tester.getRect(find.byType(TrackCard));
    final control = tester.getRect(_controlFor(name));

    // Bottom: flush with the title block's bottom edge, which is the card's
    // content bottom.
    final blockTop = card.top +
        _tile +
        (HomeSectionLayout.cardTextGap * scale);
    final blockBottom =
        blockTop + HomeSectionLayout.trackTitleBlockHeight(context);
    expect(
      control.bottom,
      closeTo(blockBottom, 0.5),
      reason: 'the control must sit on the block bottom, not float above it',
    );

    // Right: the card's right edge less the card's own text inset.
    final inset = HomeSectionLayout.trackCardTextPadding * scale;
    expect(
      control.right,
      closeTo(card.right - inset, 0.5),
      reason: 'the control must be flush with the card right edge',
    );

    // And it must be INSIDE the bottom half of the card — the placement is the
    // bottom corner, not the middle of the text block.
    expect(control.bottom, greaterThan(card.top + _tile));
  });

  testWidgets('a wide first word is NOT truncated by the control',
      (tester) async {
    // The reason the control moved off the text line: 8 of the catalogue's first
    // words are 76-93dp wide, and a 110dp tile only left ~75dp once the control
    // shared the line, which truncated the front of those names. Beside the block
    // the whole line is available, so the first word must render in full.
    const name = 'Haaratulettare Sreeraamuniki';
    await tester.pumpWidget(_harness(_card(name)));
    expect(tester.takeException(), isNull);

    // Both the first word and the remainder are rendered as separate Text widgets
    // with no ellipsis on the first, i.e. it is given the block's full width.
    final texts = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(TrackCard),
          matching: find.byType(Text),
        ))
        .toList();
    expect(texts.any((t) => t.data == 'Haaratulettare'), isTrue,
        reason: 'the first word must be rendered whole');
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
