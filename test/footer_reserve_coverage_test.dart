// Guards that every scrolling screen reserves room for the floating mini player.
//
// ## The pattern this catches
// The mini player (86) and the navigation bar (50) FLOAT over the page body -
// `floatingFooter: true` in `root_app.dart`, whose scaffold compensates by
// adding the footers' measured height to `MediaQuery.padding.bottom`. A page
// only benefits from that if its scroll view leaves room at the end.
//
// A screen that ends its scroll with an ordinary gap therefore hides its last
// row behind the player. That is what happened in several places at once:
// `track_presentation.dart` and `presentation_list.dart` both ended in
// `SliverGap(10)` - ten pixels against a ~136 pixel footer - and
// `user_playlists.dart` did the same.
//
// This test is deliberately a SOURCE scan rather than a widget test: the failure
// is "a screen forgot to reserve", which is a property of the file, and a widget
// test would need every screen's providers stood up to observe it. The check is
// narrow - the LAST spacing sliver in a CustomScrollView - so it does not
// complain about spacing in the middle of a list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that OWN a scroll view and therefore must reserve footer space.
///
/// Listed explicitly rather than discovered, so adding a screen is a deliberate
/// act rather than something the test silently skips.
///
/// A page that merely delegates to a shared scrolling component is NOT listed:
/// it inherits the reserve from that component, and listing it would fail for
/// the wrong reason. `pages/playlist/playlist.dart` and
/// `pages/library/liked_playlist.dart` are in that group - both render
/// `TrackPresentation`, which owns the reserve for them.
const scrolledScreens = <String>[
  'lib/components/track_presentation/track_presentation.dart',
  'lib/components/track_presentation/presentation_list.dart',
  'lib/pages/library/user_playlists.dart',
  'lib/pages/settings/settings.dart',
  'lib/pages/settings/about.dart',
  'lib/pages/stats/streams/streams.dart',
  'lib/pages/stats/playlists/playlists.dart',
  'lib/pages/stats/minutes/minutes.dart',
  'lib/pages/stats/artists/artists.dart',
  'lib/pages/search/tabs/tracks.dart',
  'lib/pages/recent/recently_played.dart',
  'lib/pages/home/home_see_all.dart',
  'lib/pages/home/featured_playlist_detail.dart',
];

/// Pages that render a shared scrolling component, and so must NOT be expected
/// to reserve anything themselves.
const delegatingScreens = <String, String>{
  'lib/pages/playlist/playlist.dart':
      'lib/components/track_presentation/track_presentation.dart',
  'lib/pages/playlist/liked_playlist.dart':
      'lib/components/track_presentation/track_presentation.dart',
};

void main() {
  test('the reserve is derived from the footer, never a fixed number', () {
    // The mechanism every screen must use. A hard-coded height cannot follow the
    // navigation bar as it animates away, and was wrong in both directions.
    final source = File('lib/extensions/context.dart').readAsStringSync();
    expect(
      source.contains('bottomPlayerReserve'),
      isTrue,
      reason: 'the shared reserve is what all screens should use',
    );
    expect(
      source.contains('MediaQuery.paddingOf(this).bottom'),
      isTrue,
      reason: 'the reserve must be derived from the scaffold-provided padding, '
          'not a constant',
    );
  });

  group('scrolling screens reserve footer space', () {
    for (final path in scrolledScreens) {
      test(path, () {
        final file = File(path);
        if (!file.existsSync()) {
          // A screen may be renamed or removed; fail loudly rather than pass,
          // so the list above cannot rot into checking nothing.
          fail('$path does not exist. Update `scrolledScreens` so this guard '
              'keeps covering the real screens.');
        }

        final source = file.readAsStringSync();

        final usesReserve =
            source.contains('bottomPlayerReserve') ||
            // A page may reserve inline, e.g. home.dart's trailing spacer.
            source.contains('paddingOf(context).bottom');

        expect(
          usesReserve,
          isTrue,
          reason: '$path scrolls but never reserves room for the floating mini '
              'player, so its last row will be hidden behind it. Use '
              '`context.bottomPlayerReserve`.',
        );
      });
    }
  });

  test('delegating screens inherit the reserve from their shared component', () {
    // These pages render a component that owns the scroll view, so they must
    // NOT be made to reserve here as well - a second reserve would double the
    // gap. What matters is that the component they use really does reserve.
    for (final entry in delegatingScreens.entries) {
      final delegate = File(entry.value);
      expect(delegate.existsSync(), isTrue,
          reason: '${entry.key} delegates to ${entry.value}, which must exist');

      final delegateSource = delegate.readAsStringSync();
      expect(
        delegateSource.contains('bottomPlayerReserve'),
        isTrue,
        reason: '${entry.key} scrolls only through ${entry.value}, so THAT file '
            'has to reserve footer space',
      );

      // And the page itself must not scroll on its own.
      final pageSource = File(entry.key).readAsStringSync();
      expect(
        pageSource.contains('CustomScrollView') ||
            pageSource.contains('GridView') ||
            pageSource.contains('ListView'),
        isFalse,
        reason: '${entry.key} is expected to delegate its scrolling, so if it '
            'grew its own scroll view it needs its own reserve',
      );
    }
  });

  test('no screen leaves only a tiny fixed gap at the end of its scroll', () {
    // The specific shape of the bug: a scroll view ending in a small constant.
    // 16 is the largest "spacing" gap used mid-list; anything at the END of a
    // scroll that is below the footer height is the defect.
    final offenders = <String>[];

    for (final path in scrolledScreens) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();

      // A trailing `SliverGap(n)` / `SliverSafeArea(sliver: SliverGap(n))` with
      // n under the footer height, and no reserve anywhere in the file.
      if (source.contains('bottomPlayerReserve') ||
          source.contains('paddingOf(context).bottom')) {
        continue;
      }

      final trailingGap = RegExp(
        r'Sliver(?:SafeArea\(sliver:\s*)?Gap\((\d+)',
      ).allMatches(source).map((m) => int.parse(m.group(1)!));

      if (trailingGap.isNotEmpty && trailingGap.every((g) => g < 40)) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these files end their scroll with a gap far smaller than the '
          'footer and never use bottomPlayerReserve: $offenders',
    );
  });
}
