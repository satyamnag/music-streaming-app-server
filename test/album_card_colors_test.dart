import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Color;
import 'package:sangeet/components/track_card/card_colors.dart';
import 'package:sangeet/models/metadata/metadata.dart';

/// Regression tests for per-album card colors.
///
/// The bug: admin-configured colors worked for TRACKS but appeared to do nothing
/// for ALBUMS. The album color was stored and served correctly, but both places
/// that BUILD an album object dropped the two color fields:
///
///   1. `homeAdminAlbumsProvider` (lib/provider/home_tracks/home_tracks.dart)
///      constructs a `SangeetSimpleAlbumObject` from the `/supabase/admin-albums`
///      JSON and simply never passed `cardBgColor` / `cardTextColor`.
///   2. `_buildAlbums` constructs one per album NAME by grouping tracks, and
///      likewise omitted them.
///
/// `_AlbumCard` reads the colors off the album object, so a dropped field meant
/// a silent fall back to the theme color - exactly the "works for tracks, not
/// for albums" symptom.
///
/// These tests pin the contract at the model boundary, which is where the data
/// was being lost.
SangeetSimpleAlbumObject _album({String? bg, String? text}) {
  return SangeetSimpleAlbumObject(
    id: 'a1',
    name: 'Krishna Leelalu',
    externalUri: '',
    artists: const [],
    images: const [],
    albumType: SangeetAlbumType.album,
    cardBgColor: bg,
    cardTextColor: text,
  );
}

void main() {
  group('album card colors survive construction', () {
    test('colors passed to the constructor are readable back', () {
      final album = _album(bg: '#ff0000', text: '#ffffff');
      expect(album.cardBgColor, equals('#ff0000'));
      expect(album.cardTextColor, equals('#ffffff'));
    });

    test('unset colors stay null so the card keeps its theme default', () {
      final album = _album();
      expect(album.cardBgColor, isNull);
      expect(album.cardTextColor, isNull);
    });

    test('copyWith preserves colors when they are not overridden', () {
      final album = _album(bg: '#123456', text: '#abcdef');
      final copy = album.copyWith(name: 'Renamed');
      expect(copy.cardBgColor, equals('#123456'));
      expect(copy.cardTextColor, equals('#abcdef'));
    });
  });

  group('album colors round-trip through JSON like the server sends them', () {
    test('fromJson reads cardBgColor and cardTextColor', () {
      // Mirrors what /supabase/admin-albums puts on each item.
      final album = SangeetSimpleAlbumObject.fromJson(<String, dynamic>{
        'id': 'a1',
        'name': 'Govinda Geetham',
        'externalUri': '',
        'artists': <dynamic>[],
        'images': <dynamic>[],
        'albumType': 'album',
        'cardBgColor': '#0a7d55',
        'cardTextColor': '#ffffff',
      });
      expect(album.cardBgColor, equals('#0a7d55'));
      expect(album.cardTextColor, equals('#ffffff'));
    });

    test('absent color keys decode to null rather than throwing', () {
      final album = SangeetSimpleAlbumObject.fromJson(<String, dynamic>{
        'id': 'a2',
        'name': 'No Colors',
        'externalUri': '',
        'artists': <dynamic>[],
        'images': <dynamic>[],
        'albumType': 'album',
      });
      expect(album.cardBgColor, isNull);
      expect(album.cardTextColor, isNull);
    });

    test('toJson emits both color fields', () {
      final json = _album(bg: '#111111', text: '#eeeeee').toJson();
      expect(json['cardBgColor'], equals('#111111'));
      expect(json['cardTextColor'], equals('#eeeeee'));
    });
  });

  group('album colors resolve the same way track colors do', () {
    test('a configured background is used verbatim', () {
      final album = _album(bg: '#0a7d55');
      const fallback = Color(0xFFFFFFFF);
      expect(cardBackgroundColor(album.cardBgColor, fallback),
          equals(const Color(0xFF0A7D55)));
    });

    test('an unset background falls back to the theme card color', () {
      final album = _album();
      const fallback = Color(0xFFFFFFFF);
      expect(cardBackgroundColor(album.cardBgColor, fallback), equals(fallback));
    });

    test('an unset text color falls back to the theme foreground', () {
      final album = _album(bg: '#0a7d55');
      const fallback = Color(0xFF111111);
      expect(cardTextColor(album.cardTextColor, fallback), equals(fallback));
    });

    test('auto text on a configured background is readable (AA contrast)', () {
      // The album card's own rule: with a background but no explicit text
      // color, pick whichever of black/white contrasts better.
      const bg = Color(0xFF0A7D55);
      final auto = readableTextOn(bg);
      expect(contrastRatio(bg, auto), greaterThanOrEqualTo(4.5));
    });

    test('an album color that is malformed degrades to the fallback', () {
      // A hand-edited database value must never break the card.
      final album = _album(bg: 'not-a-color', text: 'zzz');
      const fallback = Color(0xFFFFFFFF);
      expect(cardBackgroundColor(album.cardBgColor, fallback), equals(fallback));
      expect(cardTextColor(album.cardTextColor, fallback), equals(fallback));
    });
  });
}
