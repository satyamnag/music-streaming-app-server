// Guards that the karaoke variant reaches the PLAYER, not just the stream.
//
// ## The bug this replaces
// Karaoke looked removed from the app, but every piece of it was present:
// `_OriginalKaraokeToggle`, the `toggleKaraoke` call, the stream-level
// `?variant=karaoke` switch, and the `karaokeStoragePath` column in the API.
//
// What was missing was ONE field. Both `SangeetFullTrackObject(...)` builders in
// `playback.dart` omitted `karaokeStoragePath`, so it defaulted to null. The
// player decides whether to render the Original/Karaoke switch with
//
//     currentActiveTrack.karaokeStoragePath?.trim().isNotEmpty ?? false
//
// so a null hid the control completely - and because the row's path WAS read for
// stream selection, karaoke audio worked while its only entry point was
// invisible. A feature that is present but unreachable is indistinguishable from
// a feature that was deleted, which is exactly how it was reported.
//
// These tests pin the link that was broken: the track object the UI receives
// must carry the path the row carries.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/models/metadata/metadata.dart';

SangeetFullTrackObject buildTrack({String? karaokeStoragePath}) {
  return SangeetFullTrackObject(
    id: 't1',
    name: 'Niluvadu Manasu',
    externalUri: '',
    artists: const <SangeetSimpleArtistObject>[],
    album: SangeetSimpleAlbumObject(
      id: 'a1',
      name: 'Album',
      externalUri: '',
      artists: const <SangeetSimpleArtistObject>[],
      albumType: SangeetAlbumType.album,
    ),
    durationMs: 1000,
    isrc: '',
    explicit: false,
    karaokeStoragePath: karaokeStoragePath,
  );
}

/// The predicate the player uses to decide whether to show the switch.
///
/// Kept identical to `modules/player/player.dart` on purpose: if that condition
/// changes, this helper must change with it, and the test below reads the player
/// source to make sure it has not.
bool karaokeAvailable(SangeetTrackObject track) =>
    track is SangeetFullTrackObject &&
    (track.karaokeStoragePath?.trim().isNotEmpty ?? false);

void main() {
  group('the karaoke path survives onto the track object', () {
    test('a track with a karaoke file reports karaoke available', () {
      final track = buildTrack(karaokeStoragePath: 'karaoke/t1.mp3');
      expect(karaokeAvailable(track), isTrue,
          reason: 'this is what makes the Original/Karaoke switch render');
    });

    test('a track with no karaoke file reports it unavailable', () {
      expect(karaokeAvailable(buildTrack()), isFalse);
      expect(karaokeAvailable(buildTrack(karaokeStoragePath: '')), isFalse);
      expect(
        karaokeAvailable(buildTrack(karaokeStoragePath: '   ')),
        isFalse,
        reason: 'whitespace is not a karaoke file',
      );
    });
  });

  group('both playback builders carry the column', () {
    test('every SangeetFullTrackObject in playback.dart sets the path', () {
      final source =
          File('lib/provider/server/routes/playback.dart').readAsStringSync();

      // Count the constructions and the `karaokeStoragePath:` arguments. Every
      // construction must carry it; a new one that forgets it silently hides the
      // karaoke switch again.
      final constructions =
          RegExp(r'SangeetFullTrackObject\(').allMatches(source).length;
      final withPath =
          RegExp(r'karaokeStoragePath:').allMatches(source).length;

      expect(constructions, greaterThan(0),
          reason: 'playback.dart is expected to build full track objects');
      expect(
        withPath,
        constructions,
        reason: 'every SangeetFullTrackObject built here must pass '
            'karaokeStoragePath. Omitting it defaults to null, which hides the '
            'karaoke switch even when the track HAS a karaoke file.',
      );
    });

    test('the streaming branch still selects karaoke_storage_path', () {
      final source =
          File('lib/provider/server/routes/playback.dart').readAsStringSync();

      expect(
        source.contains('karaoke_storage_path'),
        isTrue,
        reason: 'the stream needs the path to serve ?variant=karaoke',
      );
      // Both halves in one file: the stream switch and the track field.
      expect(RegExp(r'karaoke and|karaoke\)').hasMatch(source), isTrue,
          reason: 'the karaoke stream switch must remain');
    });
  });

  group('the player still gates on that field', () {
    test('player.dart reads karaokeStoragePath to decide visibility', () {
      final source = File('lib/modules/player/player.dart').readAsStringSync();

      expect(
        source.contains('karaokeStoragePath'),
        isTrue,
        reason: 'if the player stops reading the field, this whole guard is '
            'testing the wrong condition',
      );
      expect(
        source.contains('_OriginalKaraokeToggle'),
        isTrue,
        reason: 'the Original/Karaoke switch must still exist',
      );
      expect(
        RegExp(r'if \(karaokeAvailable\)').hasMatch(source),
        isTrue,
        reason: 'the switch is rendered only when karaoke is available',
      );
    });

    test('the karaoke audio variant is still reachable', () {
      final source =
          File('lib/services/audio_player/audio_player.dart').readAsStringSync();
      expect(
        source.contains('variant=karaoke'),
        isTrue,
        reason: 'the stream URL must still be able to request the karaoke file',
      );
    });
  });
}
