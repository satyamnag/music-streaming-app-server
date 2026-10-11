// Verifies the two properties of the featured-playlist flow that the existing
// tests do not yet pin:
//
//  1. The screen opened by a carousel "Play Now" renders its tracks in the SAME
//     grid as the home screen — same shared `trackGridDelegate` (the one place
//     grid geometry is defined) and the same shared `HomeTrackCard` — so the UI
//     is identical to the home shelves by construction, not by accident.
//
//  2. Playback continues track-by-track to the last track: the player's `load`
//     hands the whole ordered list to media_kit's `openPlaylist(medias,
//     initialIndex, autoPlay: true)`, which is the API contract that starts at
//     `initialIndex` and automatically walks the queue to the end. A change that
//     dropped the list to one track, or set a non-zero initial index, or cleared
//     autoPlay would break "first plays instantly, then each track after it".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('featured playlist: same grid as home', () {
    test('the detail screen uses the shared grid delegate and card', () {
      final repo = Directory.current.path;
      final page = File('$repo/lib/pages/home/featured_playlist_detail.dart');
      final source = page.readAsStringSync();

      expect(
        source.contains('gridDelegate: trackGridDelegate(context)'),
        isTrue,
        reason: 'the featured playlist grid must be laid out by the SAME '
            'trackGridDelegate the home shelves use, so columns, gutters and '
            'tile height are identical',
      );
      expect(
        source.contains('return HomeTrackCard('),
        isTrue,
        reason: 'the grid must render the SAME shared HomeTrackCard (cover, '
            'corner radius, typography, premium gating) the home rows use',
      );
    });

    test('home shelves and the detail grid resolve the same delegate', () {
      final repo = Directory.current.path;
      final section =
          File('$repo/lib/pages/home/home_see_all.dart')
              .readAsStringSync();
      final page = File('$repo/lib/pages/home/featured_playlist_detail.dart')
          .readAsStringSync();

      // Both callers name the identical symbol; any drift (a new delegate, an
      // inline grid) is caught by this comparison.
      final homeGrid = RegExp(r'gridDelegate:\s*([A-Za-z0-9_]+)')
          .firstMatch(section)
          ?.group(1);
      final pageGrid = RegExp(r'gridDelegate:\s*([A-Za-z0-9_]+)')
          .firstMatch(page)
          ?.group(1);
      expect(homeGrid, isNotNull);
      expect(pageGrid, equals(homeGrid),
          reason: 'home and the featured playlist must share one grid delegate');
    });
  });

  group('featured playlist: playback walks first to last', () {
    test('the player hands the full ordered list to the queue with autoPlay',
        () {
      final repo = Directory.current.path;
      final player = File('$repo/lib/provider/audio_player/audio_player.dart');
      final source = player.readAsStringSync();

      // The whole ordered list must reach the underlying queue...
      expect(
        source.contains('await audioPlayer.openPlaylist('),
        isTrue,
        reason: 'load() must start the media queue via openPlaylist, which is '
            'what walks the list track by track',
      );
      // ...starting at the chosen index (0 for Play Now)...
      expect(
        RegExp(r'openPlaylist\([\s\S]*initialIndex:\s*initialIndex').hasMatch(
          source,
        ),
        isTrue,
        reason: 'openPlaylist must begin at the requested initialIndex so Play '
            'Now (index 0) starts with the first track',
      );
      // ...and actually playing, which advances automatically to the end.
      expect(
        RegExp(r'openPlaylist\([\s\S]*autoPlay:\s*autoPlay').hasMatch(source),
        isTrue,
        reason: 'autoPlay must be forwarded so the first track starts instantly '
            'and the queue keeps advancing track by track to the last one',
      );
    });

    test('the carousel passes the ordered list, index 0, autoPlay true', () {
      final repo = Directory.current.path;
      final carousel =
          File('$repo/lib/modules/home/sections/specials_carousel.dart')
              .readAsStringSync();

      expect(
        RegExp(r'load\(special\.tracks,\s*initialIndex:\s*0,\s*autoPlay:\s*true')
            .hasMatch(carousel),
        isTrue,
        reason: 'Play Now must load the admin-ordered shelf queue at index 0 '
            'with autoPlay on, so the first track plays instantly and the rest '
            'follow to the last',
      );
    });
  });
}