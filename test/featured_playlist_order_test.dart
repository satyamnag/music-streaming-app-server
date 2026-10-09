// Guards the admin-defined track ORDER that "Play Now" plays, and the route it
// opens.
//
// Items 4 and 6 ask that an admin can arrange the tracks in a featured playlist
// and that playing it starts at the first one and continues to the last in that
// order. The backend for this already exists (migration 029: `special_tracks`
// and `featured_playlist_tracks`, each with a `position` column, read ordered by
// `position`), so what these tests pin is that the APP honours the order rather
// than re-deriving one of its own.
//
// The ordering chain is:
//   supabase_data.dart  reads `special_tracks` ORDER BY position
//     -> HomeSpecialRow.trackIds  (already in admin order)
//       -> _buildSpecials         adds trackIds IN THAT ORDER, before keyword
//                                 matches, and never de-duplicates out of order
//         -> HomeSpecial.tracks   carries that sequence
//           -> Play Now calls load(tracks, initialIndex: 0)
//             so playback runs first -> last.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/specials.dart';

/// A minimal full track, enough for shelf assembly.
SangeetTrackObject track(String id, String name) {
  return SangeetTrackObject.full(
    id: id,
    name: name,
    externalUri: '',
    artists: const <SangeetSimpleArtistObject>[],
    album: SangeetSimpleAlbumObject(
      id: 'album-1',
      name: 'Album',
      externalUri: '',
      artists: const <SangeetSimpleArtistObject>[],
      albumType: SangeetAlbumType.album,
    ),
    durationMs: 1000,
    isrc: '',
    explicit: false,
  );
}

void main() {
  group('admin track order is preserved into the shelf', () {
    test('explicit trackIds keep the admin sequence, not the catalogue order',
        () {
      // The catalogue is deliberately in the OPPOSITE order to the admin's list,
      // so a shelf that ignored `position` would come out reversed and fail.
      final catalogue = <SangeetTrackObject>[
        track('c', 'Third'),
        track('b', 'Second'),
        track('a', 'First'),
      ];

      final row = HomeSpecialRow(
        id: 'venkateswara',
        title: 'Venkateswara Special',
        subtitle: '',
        keywords: const [],
        // The admin's chosen order.
        trackIds: const ['a', 'b', 'c'],
      );

      final shelf = buildSpecialsForTest(catalogue, [row]).single;

      expect(
        shelf.tracks.map((t) => t.id).toList(),
        ['a', 'b', 'c'],
        reason: 'the shelf must follow the admin order stored in `position`, '
            'not the order the catalogue happened to return',
      );
    });

    test('a single explicit track still starts playback at that track', () {
      final catalogue = <SangeetTrackObject>[
        track('x', 'X'),
        track('y', 'Y'),
      ];
      final row = HomeSpecialRow(
        id: 's',
        title: 'S',
        subtitle: '',
        keywords: const [],
        trackIds: const ['y'],
      );

      final shelf = buildSpecialsForTest(catalogue, [row]).single;

      expect(shelf.tracks.first.id, 'y',
          reason: 'Play Now starts at index 0, so the first entry of `tracks` '
              'is the track that begins playing');
    });

    test('keyword matches are appended AFTER the admin list', () {
      // With both mechanisms on, the hand-picked list must come first and the
      // rule-matched extras after it, so the admin always controls the opening
      // of the playlist.
      final catalogue = <SangeetTrackObject>[
        track('k1', 'Krishna Bhajan'),
        track('picked', 'Hand Picked'),
        track('k2', 'Krishna Kirtan'),
      ];

      final row = HomeSpecialRow(
        id: 'krishna',
        title: 'Krishna Special',
        subtitle: '',
        keywords: const ['krishna'],
        matchKeywords: true,
        trackIds: const ['picked'],
      );

      final shelf = buildSpecialsForTest(catalogue, [row]).single;

      expect(shelf.tracks.first.id, 'picked',
          reason: 'the admin list must lead, so playback opens with a chosen '
              'track rather than a keyword match');
      expect(
        shelf.tracks.map((t) => t.id).toSet(),
        {'picked', 'k1', 'k2'},
        reason: 'the keyword matches must still be present, appended after',
      );
    });

    test('a duplicate id in the admin list is not repeated', () {
      final catalogue = <SangeetTrackObject>[track('a', 'A')];
      final row = HomeSpecialRow(
        id: 's',
        title: 'S',
        subtitle: '',
        keywords: const [],
        trackIds: const ['a', 'a'],
      );

      final shelf = buildSpecialsForTest(catalogue, [row]).single;
      expect(shelf.tracks.length, 1,
          reason: 'a repeated id must not queue the same track twice');
    });

    test('matchKeywords false means the admin list is the whole shelf', () {
      final catalogue = <SangeetTrackObject>[
        track('a', 'A'),
        track('k', 'Krishna Song'),
      ];
      final row = HomeSpecialRow(
        id: 's',
        title: 'S',
        subtitle: '',
        keywords: const ['krishna'],
        // Admin controls membership entirely by hand.
        matchKeywords: false,
        trackIds: const ['a'],
      );

      final shelf = buildSpecialsForTest(catalogue, [row]).single;
      expect(shelf.tracks.map((t) => t.id).toList(), ['a'],
          reason: 'with the rule off, nothing may be added by keyword');
    });
  });

  group('the ordering is read from the database, not invented', () {
    test('supabase_data reads special_tracks ORDER BY position', () {
      final source =
          File('lib/provider/server/routes/supabase_data.dart').readAsStringSync();

      // The read must be ordered server-side; an unordered read would make the
      // admin's arrangement depend on whatever the database returns.
      expect(
        source.contains("_readTrackMembership(sb, 'special_tracks'") ||
            source.contains("'special_tracks'"),
        isTrue,
        reason: 'the app must read the explicit membership table',
      );
      expect(
        RegExp(r"\.order\('position'").hasMatch(source),
        isTrue,
        reason: 'membership must be read ORDER BY position, which is the column '
            'the admin sorting UI writes',
      );
    });

    test('the carousel starts at the FIRST track of the ordered queue', () {
      final source =
          File('lib/modules/home/sections/specials_carousel.dart')
              .readAsStringSync();

      expect(
        RegExp(r'load\(special\.tracks,\s*initialIndex:\s*0').hasMatch(source),
        isTrue,
        reason: 'Play Now must begin at index 0 so playback runs from the first '
            'admin-ordered track to the last',
      );
      expect(
        source.contains('autoPlay: true'),
        isTrue,
        reason: 'clicking Play Now must actually start playback',
      );
    });

    test('Play Now opens the featured playlist screen', () {
      final source =
          File('lib/modules/home/sections/specials_carousel.dart')
              .readAsStringSync();

      expect(
        source.contains('FeaturedPlaylistRoute('),
        isTrue,
        reason: 'closing the carousel banner must lead to that shelf\'s own '
            'screen, the same destination the Featured Playlist chips open',
      );
      // The navigation must be guarded: the await above can outlive the widget.
      expect(
        source.contains('context.mounted'),
        isTrue,
        reason: 'navigating after an await must check the context is still '
            'mounted, or a fast dismissal navigates from a dead element',
      );
    });
  });
}
