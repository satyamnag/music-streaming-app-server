// Regression guard for the home-screen section rows: a horizontal ListView
// stretches its children to the row height, so the row must be sized to the
// cards' exact content height or every card paints a dead empty band at its
// bottom. These tests pump the real sections on a phone-sized viewport and
// assert that the rows fit their cards with zero dead space (only the card's
// own bottom padding remains below the text).
//
// Regression reference: before the fix, albums/language/newest/trending rows
// were hard-coded to 200px while cards needed ~176px -> ~24-34px of blank
// surface under each card row on the home screen.
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/components/track_card/home_album_card.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/albums.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/home/sections/language_songs.dart';
import 'package:sangeet/modules/home/sections/track_section.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

SangeetSimpleAlbumObject _album(String id, String name) {
  return SangeetSimpleAlbumObject(
    albumType: SangeetAlbumType.album,
    artists: const [],
    externalUri: 'https://example.com/$id',
    id: id,
    name: name,
    releaseDate: '2021-01-01',
    images: [
      SangeetImageObject(
        height: 1,
        width: 1,
        url: 'https://dummyimage.com/100x100/cfcfcf/cfcfcf.jpg',
      ),
    ],
  );
}

Widget _harness(Widget child, {double textScale = 1.0}) {
  return ProviderScope(
    child: material.MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: L10n.all,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => MediaQuery(
          // The system font size. The card's `Text` widgets scale with this, so
          // the layout's own measurements must too — the device overflow this
          // pins only appears at scales other than 1.0.
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Theme(
            data: ThemeData(
              radius: .5,
              iconTheme: const IconThemeProperties(),
              colorScheme: BhaktiColorSchemes.lightMaroon(),
              surfaceOpacity: .8,
              surfaceBlur: 10,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('home section rows fit their cards with no dead space',
      (tester) async {
    tester.view.physicalSize = const material.Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final albums = <HomeAlbum>[
      (
        album: _album('a0', 'Album Zero'),
        tracks: [FakeData.track, FakeData.track]
      ),
      (
        album: _album('a1', 'Album One'),
        tracks: [FakeData.track, FakeData.track]
      ),
    ];
    final languages = <HomeLanguageGroup>[
      (language: 'Telugu', tracks: [FakeData.track, FakeData.track]),
    ];

    await tester.pumpWidget(
      _harness(
        CustomScrollView(
          slivers: [
            HomeAlbumsSection(albums: albums),
            HomeLanguageSongsSections(languages: languages),
            HomeTrackSection(
              title: 'Newest Arrivals',
              tracks: [FakeData.track, FakeData.track, FakeData.track],
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    // The row (horizontal ListView) of a section, and the first card inside it.
    //
    // Cards are located by their WIDGET TYPE, not by their title text. The track
    // card splits its name across up to two Text widgets — first word on line one,
    // the rest on line two — so `find.text(fullName)` no longer matches anything,
    // and a test that matched on the name would silently stop testing the card it
    // was written for.
    Finder sectionOf(Widget sectionWidget) => find.byWidgetPredicate(
          (w) => w.runtimeType == sectionWidget.runtimeType,
        );
    Rect rowOf(Widget sectionWidget) => tester.getRect(
          find
              .descendant(
                of: sectionOf(sectionWidget),
                matching: find.byType(ListView),
              )
              .first,
        );
    Rect cardOf(Widget sectionWidget, Type cardType) => tester.getRect(
          find
              .descendant(
                of: sectionOf(sectionWidget),
                matching: find.byType(cardType),
              )
              .first,
        );

    // ALBUM row: the card carries a title AND a subtitle. The invariant this
    // test exists to protect is that the row has no DEAD BAND — no reserved
    // space the card does not actually fill.
    //
    // ## Why this no longer measures from the subtitle's bottom
    // The album title is now a FIXED two-line block (so the real album names are
    // not truncated — see `TrackCard.albumTitleBlock`). A name that fits on one
    // line therefore leaves its second line unused INSIDE the block. Measuring
    // "subtitle bottom to card bottom" would read that unused line as a dead
    // band, but it is not one: it is the deliberate reserve that makes a
    // one-line name ("Soulful") and a two-line name ("Ganesha Lahari") render
    // cards of exactly the same height.
    //
    // The invariant that still matters, and that a dead band would break, is that
    // the card fills its row EXACTLY: the row is derived from the card's own
    // geometry, so any reserve the card does not use shows up as the card being
    // shorter than its row.
    const albumSection = HomeAlbumsSection(albums: []);
    final albumRow = rowOf(albumSection);
    final albumCardRect = cardOf(albumSection, HomeAlbumCard);
    expect(albumCardRect.height, albumRow.height,
        reason: 'album card must fill the row height exactly — a row taller '
            'than its card is the dead band this test exists to catch');
    expect(
      albumRow.height,
      closeTo(
        HomeSectionLayout.rowHeight(
          tester.element(find.byType(HomeAlbumCard).first),
        ),
        0.5,
      ),
      reason: 'the album row must be exactly the published row height',
    );

    // The card's text block must still be fully inside the card: the fixed
    // two-line title plus the subtitle and the bottom padding is what the row
    // height is derived from.
    final subtitle = find
        .descendant(
          of: find
              .descendant(
                of: sectionOf(albumSection),
                matching: find.byType(HomeAlbumCard),
              )
              .first,
          matching: find.byType(Text),
        )
        .at(1);
    final subtitleRect = tester.getRect(subtitle);
    expect(
      subtitleRect.bottom,
      lessThanOrEqualTo(albumCardRect.bottom),
      reason: 'the subtitle must never be pushed past the card bottom',
    );

    // TRACK rows: the track card has NO subtitle any more (the album line was
    // removed so the name could use the full width) and its name is split across
    // up to two Text widgets, so the subtitle-based measurement above cannot
    // apply to it. The invariants that must still hold are that the card fills
    // the row exactly, and that the row is exactly the height the layout
    // publishes for a two-line track card — which is what keeps these rows free
    // of the dead band this test exists to catch, whatever a name does.
    final context = tester.element(find.byType(HomeTrackSection).first);
    final expectedRow = HomeSectionLayout.twoLineTrackRowHeight(context);
    for (final section in <Widget>[
      const HomeLanguageSongsSections(languages: []),
      const HomeTrackSection(title: '', tracks: []),
    ]) {
      final row = rowOf(section);
      final card = cardOf(section, HomeTrackCard);
      expect(card.height, row.height,
          reason: '${section.runtimeType}: track card must fill the row height');
      expect(row.height, closeTo(expectedRow, 0.5),
          reason: '${section.runtimeType}: row must be the published track-row height');
    }
  });

  testWidgets(
      'subtitle-less rows are exactly a subtitle line plus its gap shorter',
      (tester) async {
    // Font-agnostic invariant: the only difference between the two row
    // heights is the subtitle line plus the gap above it, both from the same
    // theme, so the assertion holds under any font metrics or scaling.
    double? full;
    double? slim;
    double? expectedDelta;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            final theme = Theme.of(context);
            full = HomeSectionLayout.rowHeight(context);
            slim = HomeSectionLayout.rowHeight(
              context,
              withSubtitle: false,
            );
            final painter = TextPainter(
              text: TextSpan(text: 'Ag', style: theme.typography.xSmall),
              textDirection: TextDirection.ltr,
            )..layout();
            expectedDelta =
                (painter.height + HomeSectionLayout.titleSubtitleGap) *
                    theme.scaling;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(full! - slim!, moreOrLessEquals(expectedDelta!, epsilon: 0.5));
  });

  testWidgets(
      'the published row height matches the card at a NON-1.0 text scale',
      (tester) async {
    // ## Why this test exists
    // The album card overflowed its row by 2dp ON A REAL PHONE — Flutter's
    // yellow-and-black "BOTTOM OVERFLOWED BY 2.0 PIXEL" stripes across every
    // card in the home Albums row — while the whole suite stayed green.
    //
    // The cause was that `HomeSectionLayout._lineHeight` measured text WITHOUT
    // `MediaQuery.textScalerOf(context)`, while the card's own `Text` widgets
    // render WITH it. The harness runs at textScaler 1.0, where the two
    // measurements happen to agree, so every existing assertion passed; the
    // device runs at its own system font size, where they differ by 2dp.
    //
    // So this test deliberately renders at a text scale other than 1.0 — that is
    // the only condition under which the bug is observable at all.
    for (final textScale in <double>[1.0, 1.15, 1.3, 1.5]) {
      // A NON-empty section: an empty album list renders `SizedBox.shrink`, so
      // there would be no card to measure at all.
      final albums = <HomeAlbum>[
        (
          album: _album('a0', 'Ganesha Lahari'),
          tracks: [FakeData.track, FakeData.track]
        ),
        (
          album: _album('a1', 'Ganapati Vaibhavam'),
          tracks: [FakeData.track, FakeData.track]
        ),
      ];
      await tester.pumpWidget(
        _harness(
          // The section is a SLIVER, so it needs a sliver host to render into.
          CustomScrollView(
            slivers: [
              HomeAlbumsSection(albums: albums),
            ],
          ),
          textScale: textScale,
        ),
      );
      await tester.pumpAndSettle();

      final section = find.byWidgetPredicate(
        (w) => w.runtimeType == HomeAlbumsSection,
      );
      final row = tester.getRect(
        find.descendant(of: section, matching: find.byType(ListView)).first,
      );
      final card = tester.getRect(
        find
            .descendant(of: section, matching: find.byType(HomeAlbumCard))
            .first,
      );

      expect(
        card.height,
        closeTo(row.height, 0.5),
        reason: 'at textScale $textScale the album card must fit its row; '
            'a card taller than its row is the overflow reported on device',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'at textScale $textScale the card must not overflow',
      );
    }
  });

  testWidgets('card/artist metrics keep their internal invariants',
      (tester) async {
    double? cardH;
    double? rowH;
    double? artistH;
    double? artistRow;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            cardH = HomeSectionLayout.playbuttonCardHeight(context);
            rowH = HomeSectionLayout.playbuttonRowHeight(context);
            artistH = HomeSectionLayout.artistCardHeight(context);
            artistRow = HomeSectionLayout.artistRowHeight(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(cardH, isNotNull);
    expect(cardH!, greaterThan(150)); // artwork + text block
    expect(rowH! - cardH!, moreOrLessEquals(16)); // 8px top/bottom row padding
    expect(artistH!, greaterThan(130));
    expect(artistRow! - artistH!, moreOrLessEquals(16));
  });
}
