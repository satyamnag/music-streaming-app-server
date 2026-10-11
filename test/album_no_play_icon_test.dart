// Guards the no-play-icon-on-albums behavior.
//
// The requirement: album covers must NOT show a play icon; tapping the cover
// opens the album screen and does NOT start the first song. Playlists and
// tracks keep their play control.
//
// The mechanism: `AlbumCard` passes `onPlaybuttonPressed: null`, and the shared
// `PlaybuttonCard`/`PlaybuttonTile` only render the play button when that
// callback is non-null (the same `if (x != null)` pattern the add-to-queue
// button already used). A regression is any one of:
//   - AlbumCard starts passing a play callback again (icon returns),
//   - the shared cards stop honoring null (every card shows the button),
//   - PlaylistCard stops passing its callback (playlists lose their button).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('album covers show no play icon', () {
    test('AlbumCard passes null as the play callback', () {
      final source =
          File('lib/modules/album/album_card.dart').readAsStringSync();

      // Both the card and tile variants must hand over null.
      final nullCard = RegExp(
        r'onPlaybuttonPressed:\s*null',
      ).allMatches(source).length;
      expect(nullCard, greaterThanOrEqualTo(2),
          reason: 'AlbumCard must pass null for both the PlaybuttonCard and '
              'PlaybuttonTile variants, which is what removes the play icon');
    });

    test('the shared cards render the play button only when a callback exists',
        () {
      for (final file in const [
        'lib/components/playbutton_view/playbutton_card.dart',
        'lib/components/playbutton_view/playbutton_tile.dart',
      ]) {
        final source = File(file).readAsStringSync();
        expect(
          source.contains('if (onPlaybuttonPressed != null)'),
          isTrue,
          reason: '$file must guard the play button on the callback: with a '
              'null callback no play icon may be drawn',
        );
      }
    });

    test('the album card still opens the album screen on tap', () {
      final source =
          File('lib/modules/album/album_card.dart').readAsStringSync();
      expect(
        source.contains('AlbumRoute(id: album.id'),
        isTrue,
        reason: 'tapping the cover must navigate to the album screen',
      );
      // The removed play path: there must be no auto-play on tap.
      expect(
        source.contains('playAlbum'),
        isFalse,
        reason: 'the album play-whole-album path was removed, so tapping the '
            'cover can never start playback',
      );
    });
  });

  group('playlists keep their play icon', () {
    test('PlaylistCard still passes a real play callback', () {
      final source =
          File('lib/modules/playlist/playlist_card.dart').readAsStringSync();
      expect(
        source.contains('onPlaybuttonPressed:'),
        isTrue,
        reason: 'playlists must keep their play button',
      );
    });
  });
}