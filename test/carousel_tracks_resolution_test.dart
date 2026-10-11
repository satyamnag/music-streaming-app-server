// Guards that the carousel's "Play Now" screen actually finds its tracks.
//
// The bug: the home carousel is built from the `specials` table, so it
// navigates with a `specials` id (e.g. "ganesh-special"). The screen it opens
// looked the id up ONLY in `featuredPlaylistsProvider`, which is built from the
// `featured_playlists` table (ids like "ganesha"). The two id spaces never
// intersect, so every carousel banner opened a screen with "nothing found" and
// no tracks - which is exactly what was reported.
//
// This test pins that the detail screen resolves BOTH sources.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the featured playlist screen resolves carousel (specials) ids too', () {
    final source =
        File('lib/pages/home/featured_playlist_detail.dart').readAsStringSync();

    expect(
      source.contains('homeSpecialsProvider'),
      isTrue,
      reason: 'the screen must also look up the `specials` provider, because the '
          'carousel navigates with a specials id (e.g. "ganesh-special") while '
          'featured_playlists uses different ids (e.g. "ganesha")',
    );
    expect(
      source.contains('specials.dart'),
      isTrue,
      reason: 'the specials provider import is required for that lookup',
    );
  });

  test('the carousel still passes the special id to the route', () {
    final carousel =
        File('lib/modules/home/sections/specials_carousel.dart')
            .readAsStringSync();
    expect(
      carousel.contains('FeaturedPlaylistRoute(id: special.id)'),
      isTrue,
      reason: 'the carousel must keep navigating with the banner it belongs to',
    );
  });
}
