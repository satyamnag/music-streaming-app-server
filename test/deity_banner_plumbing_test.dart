// Guards the deity-screen background banner end to end.
//
// The requirement: the admin must be able to set a background banner for a deity
// ("featured playlist" in the admin panel), that banner must be what the detail
// screen shows, and when the admin has NOT set one the screen must still show a
// PLACEHOLDER banner rather than an empty band.
//
// The chain has five links, and breaking any one of them silently disables the
// feature — which is exactly what these probes catch:
//
//   migration (DB column) -> admin API whitelist -> admin UI
//     -> local server JSON -> app model -> hero widget
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('the database can store a deity banner', () {
    test('migration 030 adds featured_playlists.banner_url', () {
      final file = File('server/migrations/030_featured_playlist_banner.sql');
      expect(file.existsSync(), isTrue,
          reason: 'without this column the admin has nowhere to save a banner');
      final sql = file.readAsStringSync().toLowerCase();
      expect(sql.contains('alter table public.featured_playlists'), isTrue);
      expect(sql.contains('add column if not exists banner_url'), isTrue);
    });
  });

  group('the admin API accepts and returns the banner', () {
    final server = _read('server/server.js');

    test('the featured-playlist payload whitelist carries banner_url', () {
      // A whitelist that drops the field makes the upload a silent no-op.
      final start = server.indexOf('function readFeaturedPlaylistPayload');
      expect(start, greaterThan(-1));
      final body = server.substring(start, start + 4000);
      expect(body.contains('banner_url'), isTrue);
    });

    test('there is an upload kind for the deity banner with a 2:1 rule', () {
      expect(server.contains("kind === 'deity_banner'"), isTrue);
      expect(server.contains('DEITY_BANNER_RATIO'), isTrue);
      expect(server.contains('DEITY_BANNER_LABEL'), isTrue);
    });
  });

  group('the admin panel exposes the upload', () {
    final admin = _read('server/admin.html');

    test('a banner upload control calls the deity_banner kind', () {
      expect(admin.contains('handleChipBannerUpload'), isTrue);
      expect(admin.contains("form.append('kind', 'deity_banner')"), isTrue);
      expect(admin.contains('clearChipBanner'), isTrue);
    });

    test('the row renders the saved banner state and offers removal', () {
      expect(admin.contains('row.banner_url'), isTrue);
      expect(admin.contains('banner_url: url'), isTrue);
      expect(admin.contains('banner_url: null'), isTrue);
    });

    test('the panel states the exact size to upload (1080x540)', () {
      // The size was only ever surfaced by a rejection message, so an admin
      // found it after a failed upload instead of before one.
      expect(admin.contains('const DEITY_BANNER_WIDTH = 1080;'), isTrue);
      expect(admin.contains('const DEITY_BANNER_HEIGHT = 540;'), isTrue);
      expect(
        admin.contains("DEITY_BANNER_WIDTH + '&times;' + DEITY_BANNER_HEIGHT"),
        isTrue,
        reason: 'the hint must print the numbers, not just name a ratio',
      );
    });
  });

  group('the app carries the banner from the server into the model', () {
    test('the local server sends bannerUrl', () {
      final route = _read('lib/provider/server/routes/supabase_data.dart');
      final start = route.indexOf("from('featured_playlists')");
      expect(start, greaterThan(-1));
      final body = route.substring(start, start + 2500);
      expect(body.contains("'bannerUrl': trimmed(r['banner_url'])"), isTrue);
    });

    test('the row parses it and the provider passes it on', () {
      final model = _read('lib/modules/home/sections/featured_playlists.dart');
      expect(model.contains('this.bannerUrl'), isTrue);
      expect(model.contains("bannerUrl: json['bannerUrl']"), isTrue);
      expect(model.contains('bannerUrl: row.bannerUrl'), isTrue);
    });
  });

  group('the hero always shows a banner and is full-bleed', () {
    final page = _read('lib/pages/home/featured_playlist_detail.dart');

    test('a placeholder is drawn when no banner is configured', () {
      // `_placeholder` is the gradient fallback; the hero must reach it on the
      // empty-banner path instead of returning a bare circle or nothing.
      expect(page.contains('_placeholder'), isTrue,
          reason: 'the requirement is an explicit placeholder banner, not an '
              'empty band, when the admin has not uploaded artwork');
      expect(page.contains('errorBuilder: (_, __, ___) => _placeholder'),
          isTrue,
          reason: 'a failed image download must also fall back, not break');
    });

    test('the hero is full-bleed with an overlaid back arrow', () {
      expect(page.contains('_BannerHero'), isTrue);
      // No TitleBar for this page: the banner runs under the status bar and
      // carries its own back arrow, as in the reference screens.
      expect(page.contains('headers: ['), isFalse,
          reason: 'a TitleBar would push the banner down off the top edge');
      expect(page.contains('Icons.arrow_back'), isTrue);
      expect(page.contains("onBack: () => Navigator.of(context).maybePop()"),
          isTrue);
    });

    test('the song count is drawn in a decorative divider under the title', () {
      expect(page.contains('_SongCountDivider'), isTrue);
      expect(page.contains('countLabel'), isTrue);
    });

    test('the track grid still uses the Newest Arrivals alignment', () {
      // The requirement is explicit that the tracks must line up exactly as on
      // the Newest Arrivals screen, which is the shared delegate + card.
      expect(page.contains('gridDelegate: trackGridDelegate(context)'), isTrue);
      expect(page.contains('HomeTrackCard('), isTrue);
    });
  });
}
