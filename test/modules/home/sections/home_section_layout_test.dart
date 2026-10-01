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

    // For the first card of each section: the row (horizontal ListView) must
    // be exactly as tall as its card, and the card must leave no more than
    // its own design padding (10 logical px) below the subtitle text.
    void expectTightFit(Widget sectionWidget, String titleText) {
      final section = find.byWidgetPredicate(
        (w) => w.runtimeType == sectionWidget.runtimeType,
      );
      final row = tester.getRect(
        find.descendant(of: section, matching: find.byType(ListView)).first,
      );
      final card = find
          .ancestor(
            of: find.descendant(of: section, matching: find.text(titleText)),
            matching: find.byType(Container),
          )
          .first;
      final cardRect = tester.getRect(card);
      // The second Text inside the card is the subtitle ("N songs" /
      // album name), scoped to this card so the measurement never leaks
      // across sections.
      final subtitle =
          find.descendant(of: card, matching: find.byType(Text)).at(1);
      final subtitleRect = tester.getRect(subtitle);

      expect(cardRect.height, row.height,
          reason: 'card must fill the row height exactly');
      // Dead space = row height - (content bottom from card top) - the card's
      // own bottom padding (HomeSectionLayout.cardPadding).
      final contentBottom = subtitleRect.bottom - cardRect.top;
      final dead = row.height - contentBottom - HomeSectionLayout.cardPadding;
      expect(dead.abs(), lessThanOrEqualTo(1.0),
          reason: 'no dead band between the subtitle and the card bottom');
    }

    expectTightFit(const HomeAlbumsSection(albums: []), 'Album Zero');
    expectTightFit(
        const HomeLanguageSongsSections(languages: []), 'A good track');
    expectTightFit(
      const HomeTrackSection(title: '', tracks: []),
      'A good track',
    );
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
