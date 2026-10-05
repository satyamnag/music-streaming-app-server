// Regression tests for the per-track MINI PLAYER background colour.
//
// The danger with a new admin-driven field is not the database, it is the wiring:
// a field that is stored, served and then silently dropped on the way to the
// widget looks exactly like a field that was never set. The album colours had
// precisely that bug once — built correctly, then dropped by both places that
// constructed the object (see album_card_colors_test.dart).
//
// These tests pin the contract at the model boundary and at the parser, and pin
// that the mini player's colour is INDEPENDENT of the card colours, because
// reusing the card colour was the tempting shortcut.
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Color;
import 'package:sangeet/components/track_card/card_colors.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/player/player_overlay_collapsed.dart';

SangeetTrackObject _track({String? cardBg, String? miniBg}) {
  return SangeetTrackObject.full(
    id: 't1',
    name: 'Niluvadu Manasu',
    externalUri: '',
    album: SangeetSimpleAlbumObject(
      id: 'a1',
      name: 'Govinda Geetham',
      externalUri: '',
      artists: const [],
      images: const [],
      albumType: SangeetAlbumType.album,
    ),
    durationMs: 0,
    isrc: '',
    explicit: false,
    cardBgColor: cardBg,
    miniplayerBgColor: miniBg,
  );
}

void main() {
  group('the mini player colour survives construction', () {
    test('a value passed to the factory is readable back', () {
      final track = _track(miniBg: '#0a7d55');
      expect(track, isA<SangeetFullTrackObject>());
      expect((track as SangeetFullTrackObject).miniplayerBgColor, '#0a7d55');
    });

    test('unset stays null so the mini player keeps the theme surface', () {
      final track = _track() as SangeetFullTrackObject;
      expect(track.miniplayerBgColor, isNull);
    });

    test('copyWith preserves it when another field changes', () {
      final track = _track(miniBg: '#123456') as SangeetFullTrackObject;
      final copy = track.copyWith(name: 'Renamed') as SangeetFullTrackObject;
      expect(copy.miniplayerBgColor, '#123456');
      expect(copy.name, 'Renamed');
    });

    test('it is INDEPENDENT of the card colours', () {
      // The whole reason this is a separate column rather than a reuse of
      // card_bg_color: a track may want a card colour and no mini player colour,
      // the other way round, or two different colours.
      final cardOnly = _track(cardBg: '#ff0000') as SangeetFullTrackObject;
      expect(cardOnly.cardBgColor, '#ff0000');
      expect(cardOnly.miniplayerBgColor, isNull);

      final miniOnly = _track(miniBg: '#0000ff') as SangeetFullTrackObject;
      expect(miniOnly.cardBgColor, isNull);
      expect(miniOnly.miniplayerBgColor, '#0000ff');

      final both = _track(cardBg: '#ff0000', miniBg: '#0000ff')
          as SangeetFullTrackObject;
      expect(both.cardBgColor, '#ff0000');
      expect(both.miniplayerBgColor, '#0000ff');
    });
  });

  group('the field round-trips through JSON like the server sends it', () {
    test('fromJson reads miniplayerBgColor', () {
      final track = SangeetTrackObject.fromJson(<String, dynamic>{
        'id': 't1',
        'name': 'Saati Neekevaru',
        'externalUri': '',
        'artists': <dynamic>[],
        'album': <String, dynamic>{
          'id': 'a1',
          'name': 'Album',
          'externalUri': '',
          'artists': <dynamic>[],
          'images': <dynamic>[],
          'albumType': 'album',
        },
        'durationMs': 0,
        'isrc': '',
        'explicit': false,
        'miniplayerBgColor': '#1f2937',
      });
      expect((track as SangeetFullTrackObject).miniplayerBgColor, '#1f2937');
    });

    test('an absent key decodes to null rather than throwing', () {
      // Older cached rows predate the column, so this must stay safe.
      final track = SangeetTrackObject.fromJson(<String, dynamic>{
        'id': 't2',
        'name': 'No Colour',
        'externalUri': '',
        'artists': <dynamic>[],
        'album': <String, dynamic>{
          'id': 'a1',
          'name': 'Album',
          'externalUri': '',
          'artists': <dynamic>[],
          'images': <dynamic>[],
          'albumType': 'album',
        },
        'durationMs': 0,
        'isrc': '',
        'explicit': false,
      });
      expect((track as SangeetFullTrackObject).miniplayerBgColor, isNull);
    });

    test('toJson emits the field', () {
      final json = (_track(miniBg: '#abcdef') as SangeetFullTrackObject).toJson();
      expect(json['miniplayerBgColor'], '#abcdef');
    });
  });

  group('the value resolves the way the mini player reads it', () {
    test('a configured colour is used verbatim', () {
      expect(parseCardColor('#0a7d55'), const Color(0xFF0A7D55));
    });

    test('unset and malformed values fall back to the theme surface', () {
      // A hand-edited database value must never break the player bar.
      for (final bad in <String?>[null, '', '   ', 'not-a-color', '#12', '#1234567']) {
        expect(parseCardColor(bad), isNull, reason: 'value: "$bad"');
      }
    });

    test('short hex and a missing # are both accepted', () {
      expect(parseCardColor('#0a7'), const Color(0xFF00AA77));
      expect(parseCardColor('0a7d55'), const Color(0xFF0A7D55));
    });
  });

  group('the mini player resolves whatever track it is playing', () {
    test('a configured colour on the active track is used', () {
      expect(
        miniplayerBackgroundFor(_track(miniBg: '#0a7d55')),
        const Color(0xFF0A7D55),
      );
    });

    test('an unset colour keeps the theme surface', () {
      expect(miniplayerBackgroundFor(_track()), isNull);
    });

    test('a LOCAL file track is safe and keeps the theme surface', () {
      // The guard that actually matters, and it is reachable in production: the
      // player bar renders whatever is playing, including a file opened from the
      // device. A local track never came from the database and has no such
      // column, so reading it without the type guard would throw.
      final local = SangeetTrackObject.local(
        id: '/music/a.mp3',
        name: 'Local Song',
        externalUri: 'file:///music/a.mp3',
        album: SangeetSimpleAlbumObject(
          id: 'a1',
          name: 'Album',
          externalUri: '',
          artists: const [],
          images: const [],
          albumType: SangeetAlbumType.album,
        ),
        durationMs: 0,
        path: '/music/a.mp3',
      );
      expect(local, isA<SangeetLocalTrackObject>());
      expect(miniplayerBackgroundFor(local), isNull);
    });

    test('nothing playing resolves to nothing', () {
      expect(miniplayerBackgroundFor(null), isNull);
    });

    test('a malformed stored value keeps the theme surface', () {
      for (final bad in <String>['not-a-color', '', '   ', '#12']) {
        expect(
          miniplayerBackgroundFor(_track(miniBg: bad)),
          isNull,
          reason: 'value: "$bad"',
        );
      }
    });
  });
}
