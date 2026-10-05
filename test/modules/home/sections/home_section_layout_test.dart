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

Widget _harness(Widget child) {
  return ProviderScope(
    child: material.MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: L10n.all,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Theme(
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

    // ALBUM row: the card carries a title AND a subtitle, and the original
    // invariant still applies to it unchanged — no dead band between the
    // subtitle and the card's bottom beyond the card's own bottom padding.
    const albumSection = HomeAlbumsSection(albums: []);
    final albumRow = rowOf(albumSection);
    final albumCardRect = cardOf(albumSection, HomeAlbumCard);
    expect(albumCardRect.height, albumRow.height,
        reason: 'album card must fill the row height exactly');
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
    final dead = albumRow.height -
        (subtitleRect.bottom - albumCardRect.top) -
        HomeSectionLayout.cardPadding;
    expect(dead.abs(), lessThanOrEqualTo(1.0),
        reason: 'no dead band between the album subtitle and the card bottom');

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
