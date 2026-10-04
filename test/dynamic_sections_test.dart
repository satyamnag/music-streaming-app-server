// Pins the admin-driven membership rules for the home screen's two curated
// sections.
//
// Both providers resolve "which tracks belong to this row" in-process from the
// admin's rows, so the whole decision — hand-picked order, optional keyword
// matches, de-duplication, and the "no tracks means no row" rule — is exercised
// here against real rows rather than being inferred from the admin panel.
//
// The three inputs the providers depend on (the catalogue, the global play
// counts and the rows) are all overridden, so nothing here touches the network.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Color;
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/modules/home/sections/specials.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// A track with just the fields the haystack and the cover lookup read.
SangeetTrackObject _track(String id, String name) => SangeetTrackObject.full(
      id: id,
      name: name,
      externalUri: '',
      album: SangeetSimpleAlbumObject(
        id: 'al-$id',
        name: 'Album $id',
        externalUri: '',
        artists: const [],
        albumType: SangeetAlbumType.album,
      ),
      durationMs: 1000,
      isrc: '',
      explicit: false,
    );

/// The catalogue every test resolves against.
///
/// Names are chosen so the shared word-start keyword rule decides membership:
/// "shiva" matches "Shiva Shankara" but "ram" must not match a name that only
/// contains it mid-word.
final _tracks = <SangeetTrackObject>[
  _track('t-om', 'Om Namah Shivaya'),
  _track('t-shiva', 'Shiva Shankara'),
  _track('t-govinda', 'Govinda Govinda'),
  _track('t-k1', 'Krishna Nee Begane'),
  _track('t-k2', 'Krishna Bhajan'),
  _track('t-rama', 'Rama Raksha Stotram'),
];

ProviderContainer _container({
  List<SangeetTrackObject>? tracks,
  List<FeaturedPlaylistRow> featuredRows = const [],
  List<HomeSpecialRow> specialRows = const [],
  Map<String, int> playCounts = const {},
}) {
  return ProviderContainer(overrides: [
    homeTracksProvider.overrideWith((ref) async => tracks ?? _tracks),
    globalPlayCountsProvider.overrideWith((ref) async => playCounts),
    featuredPlaylistRowsProvider.overrideWith((ref) async => featuredRows),
    homeSpecialRowsProvider.overrideWith((ref) async => specialRows),
  ]);
}

/// Resolves the chip row and tears the container down.
Future<List<FeaturedPlaylist>> _chips(ProviderContainer c) async {
  final chips = await c.read(featuredPlaylistsProvider.future);
  c.dispose();
  return chips;
}

/// Resolves the shelf row and tears the container down.
///
/// `homeSpecialsProvider` is synchronous and reads the already-resolved futures,
/// so they are awaited first — exactly the order the home screen hits them in.
Future<List<HomeSpecial>> _specials(ProviderContainer c) async {
  await c.read(homeTracksProvider.future);
  await c.read(globalPlayCountsProvider.future);
  await c.read(homeSpecialRowsProvider.future);
  final specials = c.read(homeSpecialsProvider);
  c.dispose();
  return specials;
}

/// The ids of a resolved list, for terse order assertions.
List<String> _ids(Iterable<dynamic> items) =>
    [for (final t in items) t.id as String];

void main() {
  // ------------------------------------------------------------ Featured chips
  group('Featured Playlist chips are built from the admin rows only', () {
    test('no rows means no chips (there is no built-in catalogue)', () async {
      final chips = await _chips(_container());
      expect(chips, isEmpty);
    });

    test('hand-picked tracks keep the admin order, keyword matches append after',
        () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(
            id: 'mix',
            title: 'Mix',
            keywords: ['krishna'],
            trackIds: ['t-rama', 't-om'],
          ),
        ],
        // Only the keyword-matched tracks have play counts, so they sort by them.
        playCounts: const {'t-k1': 5, 't-k2': 9},
      ));

      expect(chips, hasLength(1));
      expect(
        _ids(chips.single.tracks),
        equals(['t-rama', 't-om', 't-k2', 't-k1']),
        reason: 'explicit ids first in admin order, then matches by play count',
      );
    });

    test('turning the keyword rule off leaves the hand-picked list alone',
        () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(
            id: 'hand',
            title: 'Hand picked',
            keywords: ['krishna'],
            matchKeywords: false,
            trackIds: ['t-rama'],
          ),
        ],
      ));

      expect(_ids(chips.single.tracks), equals(['t-rama']));
    });

    test('a track that is both hand-picked and matched appears once, first',
        () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(
            id: 'both',
            title: 'Both',
            keywords: ['krishna'],
            trackIds: ['t-k1'],
          ),
        ],
        playCounts: const {'t-k1': 1, 't-k2': 9},
      ));

      expect(_ids(chips.single.tracks), equals(['t-k1', 't-k2']),
          reason: 'the explicit position wins and the duplicate is not re-added');
    });

    test('a row with no resolvable tracks is dropped, not rendered empty',
        () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(id: 'empty', title: 'Empty', keywords: []),
          FeaturedPlaylistRow(
            id: 'only-bad-ids',
            title: 'Gone',
            keywords: [],
            trackIds: ['t-deleted', 't-also-gone'],
          ),
          FeaturedPlaylistRow(
            id: 'ok',
            title: 'Ok',
            keywords: [],
            trackIds: ['t-om'],
          ),
        ],
      ));

      expect(_ids(chips), equals(['ok']),
          reason: 'unknown track ids are skipped, and an empty row never ships');
    });

    test('a hidden row is dropped even when it has tracks', () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(
            id: 'vs',
            title: 'Hidden',
            keywords: [],
            trackIds: ['t-om'],
            isHidden: true,
          ),
        ],
      ));

      expect(chips, isEmpty);
    });

    test('admin sort order wins, then title for unordered rows', () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(
              id: 'z', title: 'Zeta', keywords: [], trackIds: ['t-om']),
          FeaturedPlaylistRow(
              id: 'b', title: 'Beta', keywords: [], trackIds: ['t-om']),
          FeaturedPlaylistRow(
              id: 'a',
              title: 'Alpha',
              keywords: [],
              trackIds: ['t-om'],
              sortOrder: 1),
        ],
      ));

      expect(_ids(chips), equals(['a', 'b', 'z']));
    });

    test('colors, glyph and uploaded icon come straight from the row', () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(
            id: 'styled',
            title: 'Styled',
            keywords: [],
            trackIds: ['t-om'],
            colorFrom: '#112233',
            colorTo: '#445566',
            icon: 'trishul',
            iconUrl: 'https://cdn.example.com/icon.webp',
          ),
        ],
      ));

      final chip = chips.single;
      expect(chip.colorFrom, equals(const Color(0xFF112233)));
      expect(chip.colorTo, equals(const Color(0xFF445566)));
      expect(chip.icon, equals('trishul'));
      expect(chip.iconUrl, equals('https://cdn.example.com/icon.webp'));
    });

    test('a malformed color falls back to the theme rather than throwing',
        () async {
      final chips = await _chips(_container(
        featuredRows: const [
          FeaturedPlaylistRow(
            id: 'bad-color',
            title: 'Bad',
            keywords: [],
            trackIds: ['t-om'],
            colorFrom: 'not-a-color',
          ),
        ],
      ));

      expect(chips.single.colorFrom, isNull);
    });
  });

  // ---------------------------------------------------------------- Specials
  group('Specials shelves are built from the admin rows only', () {
    test('no rows means no shelves', () async {
      expect(await _specials(_container()), isEmpty);
    });

    test('hand-picked tracks keep the admin order, keyword matches append after',
        () async {
      final specials = await _specials(_container(
        specialRows: const [
          HomeSpecialRow(
            id: 'shiva',
            title: 'Shiva Special',
            subtitle: 'Chants',
            keywords: ['shiva'],
            trackIds: ['t-rama'],
          ),
        ],
        playCounts: const {'t-om': 4, 't-shiva': 8},
      ));

      expect(specials, hasLength(1));
      expect(specials.single.title, equals('Shiva Special'));
      expect(_ids(specials.single.tracks), equals(['t-rama', 't-shiva', 't-om']));
    });

    test('an uploaded banner wins and is flagged, otherwise track art is used',
        () async {
      final withBanner = await _specials(_container(
        specialRows: const [
          HomeSpecialRow(
            id: 'b',
            title: 'Banner',
            keywords: [],
            trackIds: ['t-om'],
            bannerUrl: 'https://cdn.example.com/banner.webp',
          ),
        ],
      ));
      expect(withBanner.single.hasBanner, isTrue);
      expect(withBanner.single.imageUrl,
          equals('https://cdn.example.com/banner.webp'));

      final withoutBanner = await _specials(_container(
        specialRows: const [
          HomeSpecialRow(
            id: 'c',
            title: 'Cover',
            keywords: [],
            trackIds: ['t-om'],
          ),
        ],
      ));
      expect(withoutBanner.single.hasBanner, isFalse);
      expect(withoutBanner.single.imageUrl, isNotEmpty,
          reason: 'a shelf with no banner falls back to its track artwork');
    });

    test('hidden rows and rows with no tracks never reach the carousel',
        () async {
      final specials = await _specials(_container(
        specialRows: const [
          HomeSpecialRow(
            id: 'hidden',
            title: 'Hidden',
            keywords: [],
            trackIds: ['t-om'],
            isHidden: true,
          ),
          HomeSpecialRow(id: 'empty', title: 'Empty', keywords: []),
          HomeSpecialRow(id: 'untitled', keywords: [], trackIds: ['t-om']),
          HomeSpecialRow(
              id: 'ok', title: 'Ok', keywords: [], trackIds: ['t-om']),
        ],
      ));

      expect(_ids(specials), equals(['ok']));
    });

    test('admin sort order wins, then title for unordered rows', () async {
      final specials = await _specials(_container(
        specialRows: const [
          HomeSpecialRow(
              id: 'z', title: 'Zeta', keywords: [], trackIds: ['t-om']),
          HomeSpecialRow(
              id: 'b', title: 'Beta', keywords: [], trackIds: ['t-om']),
          HomeSpecialRow(
            id: 'a',
            title: 'Alpha',
            keywords: [],
            trackIds: ['t-om'],
            sortOrder: 1,
          ),
        ],
      ));

      expect(_ids(specials), equals(['a', 'b', 'z']));
    });

    test('turning the keyword rule off leaves the hand-picked list alone',
        () async {
      final specials = await _specials(_container(
        specialRows: const [
          HomeSpecialRow(
            id: 'hand',
            title: 'Hand picked',
            keywords: ['shiva'],
            matchKeywords: false,
            trackIds: ['t-rama'],
          ),
        ],
      ));

      expect(_ids(specials.single.tracks), equals(['t-rama']));
    });
  });
}
