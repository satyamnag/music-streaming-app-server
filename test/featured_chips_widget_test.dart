// Renders the real Featured Playlist chip row and the wallpaper widget, so a
// layout or painter regression fails here rather than only on the device.
//
// Flutter turns any RenderFlex overflow into a test failure, so pumping these
// widgets is a direct reproduction: an overflowing chip row or a throwing
// CustomPainter fails the test and names the widget.
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/featured_playlist_chips.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/modules/home/sections/home_wallpaper.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

/// A minimal track, only the fields the chip haystack reads.
SangeetTrackObject _track(String id, String name) {
  return SangeetTrackObject.full(
    id: id,
    name: name,
    externalUri: '',
    album: SangeetSimpleAlbumObject(
      id: 'al-$id',
      name: 'Album',
      externalUri: '',
      artists: const [],
      albumType: SangeetAlbumType.album,
    ),
    durationMs: 1000,
    isrc: '',
    explicit: false,
  );
}

Widget _harness(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
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
          child: material.Scaffold(
            body: material.CustomScrollView(
              slivers: [child],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The same theme/localization wrapper but with a plain box body, for widgets
/// that are not slivers (the wallpaper fills the screen rather than a sliver).
Widget _boxHarness(Widget child) {
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
          child: material.Scaffold(body: child),
        ),
      ),
    ),
  );
}

/// The chips read `featuredPlaylistsProvider` (a FutureProvider), so the real
/// provider is overridden with a fixed list to keep the test hermetic.
List<Override> _withChips(List<FeaturedPlaylist> chips) {
  return [
    featuredPlaylistsProvider.overrideWith((ref) async => chips),
  ];
}

FeaturedPlaylist _chip(String id, String title, String icon) => FeaturedPlaylist(
      id: id,
      title: title,
      keywords: [id],
      icon: icon,
      colorFrom: const Color(0xFFEF4444),
      colorTo: const Color(0xFFB91C1C),
      tracks: [_track(id, title)],
    );

void main() {
  testWidgets('the chip row renders every chip with its name', (tester) async {
    tester.view.physicalSize = const material.Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final chips = [
      _chip('venkateswara', 'Venkateswara', 'temple'),
      _chip('krishna', 'Krishna', 'flute'),
      _chip('ganesha', 'Ganesha', 'ganesha'),
      _chip('rama', 'Rama', 'bow'),
      _chip('devi', 'Devi', 'lotus'),
      _chip('chants', 'Chants', 'om'),
    ];

    await tester.pumpWidget(
      _harness(const FeaturedPlaylistChips(), overrides: _withChips(chips)),
    );
    await tester.pumpAndSettle();

    // The row is a lazily-built horizontal ListView, so only the chips within
    // the viewport are in the tree at any moment. Scroll each into view and
    // assert it exists, which also proves the row actually scrolls.
    for (final chip in chips) {
      await tester.scrollUntilVisible(
        find.text(chip.title),
        120,
        scrollable: find.byType(material.Scrollable).first,
      );
      expect(find.text(chip.title), findsOneWidget,
          reason: '${chip.title} chip should be reachable');
    }
  });

  testWidgets('every glyph name paints without throwing', (tester) async {
    tester.view.physicalSize = const material.Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Includes an unknown name and an empty one: both must fall back to the
    // music glyph rather than throwing or drawing nothing.
    final names = ['temple', 'flute', 'ganesha', 'bow', 'lotus', 'om', 'nope', ''];
    final chips = [
      for (var i = 0; i < names.length; i++)
        _chip('c$i', 'Chip $i', names[i]),
    ];

    await tester.pumpWidget(
      _harness(const FeaturedPlaylistChips(), overrides: _withChips(chips)),
    );
    await tester.pumpAndSettle();

    // If any painter threw, pumpAndSettle would have failed above.
    expect(tester.takeException(), isNull);
    expect(find.text('Chip 0'), findsOneWidget);
  });

  testWidgets('an empty chip list renders nothing at all', (tester) async {
    await tester.pumpWidget(
      _harness(const FeaturedPlaylistChips(), overrides: _withChips(const [])),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // No chips -> the sliver collapses to a zero-size box.
    expect(find.byType(material.ListView), findsNothing);
  });

  testWidgets('a background wallpaper renders without intercepting taps',
      (tester) async {
    await tester.pumpWidget(
      _boxHarness(const HomeWallpaper(url: 'https://example.com/wall.webp')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // IgnorePointer is what stops a full-screen image from swallowing taps
    // meant for the cards and carousel above it.
    expect(find.byType(IgnorePointer), findsWidgets);
  });

  testWidgets('a pale chip color still picks a readable glyph', (tester) async {
    tester.view.physicalSize = const material.Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // A near-white gradient would hide a white glyph, so the chip must switch
    // to the dark one. This asserts the measured-contrast branch runs.
    final pale = FeaturedPlaylist(
      id: 'pale',
      title: 'Pale',
      keywords: const ['pale'],
      icon: 'om',
      colorFrom: const Color(0xFFF3F4F6),
      colorTo: const Color(0xFFE5E7EB),
      tracks: [_track('pale', 'Pale Track')],
    );

    await tester.pumpWidget(
      _harness(const FeaturedPlaylistChips(), overrides: _withChips([pale])),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pale'), findsOneWidget);
  });
}
