// Guards the bottom navigation bar and the home header search entry.
//
// The requirement, from the reference screens: the bar shows exactly four tabs
// — Home, Library, My Bhakti, Profile — each with its label under the icon, and
// Search lives at the top right of the Home header instead of in the bar.
//
// These are source probes, the same style as `album_no_play_icon_test.dart`:
// the point is that removing a tab, renaming a label, or dropping the header
// search fails here rather than only being visible on a device.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the bottom bar is exactly Home / Library / My Bhakti / Profile', () {
    final source =
        File('lib/collections/side_bar_tiles.dart').readAsStringSync();

    /// Only the navbar list — the file also holds the sidebar lists.
    String navbarList() {
      final start = source.indexOf('List<SideBarTiles> getNavbarTileList');
      expect(start, greaterThan(-1), reason: 'getNavbarTileList must exist');
      return source.substring(start);
    }

    test('it declares four tabs, with the four required labels in order', () {
      final nav = navbarList();
      final labels = RegExp(r'title:\s*([^,\n]+),')
          .allMatches(nav)
          .map((m) => m.group(1)!.trim())
          .toList();

      expect(labels.length, 4,
          reason: 'the reference design shows exactly four tabs: $labels');
      expect(labels[0], "'Home'");
      expect(labels[1], 'l10n.library',
          reason: 'Library reuses the existing localised string');
      expect(labels[2], "'My Bhakti'");
      expect(labels[3], 'l10n.profile',
          reason: 'Profile reuses the existing localised string');
    });

    test('the four icons are the ones the screenshots show, in order', () {
      final nav = navbarList();
      final icons = RegExp(r'icon:\s*SangeetIcons\.(\w+),')
          .allMatches(nav)
          .map((m) => m.group(1)!)
          .toList();
      expect(icons, ['home', 'library', 'music', 'user']);
    });

    test('Search is NOT a tab any more (it moved to the home header)', () {
      expect(
        navbarList().contains('SearchRoute'),
        isFalse,
        reason: 'the bar must be the four reference tabs only',
      );
    });

    test('My Bhakti opens the stats screen and Profile opens /profile', () {
      final nav = navbarList();
      expect(nav.contains('const StatsRoute()'), isTrue);
      expect(nav.contains('const ProfileRoute()'), isTrue);
      expect(nav.contains('pathPrefix: "/stats"'), isTrue);
      expect(nav.contains('pathPrefix: "/profile"'), isTrue);
    });
  });

  group('the bar renders a label under every icon', () {
    test('the NavigationBar asks for labels on every tab', () {
      final source = File(
        'lib/modules/root/spotube_navigation_bar.dart',
      ).readAsStringSync();
      expect(source.contains('labelType: NavigationLabelType.all'), isTrue,
          reason: 'labels must be visible on all four tabs, not only the '
              'selected one');
      expect(source.contains('labelPosition: NavigationLabelPosition.bottom'),
          isTrue,
          reason: 'the label sits BELOW its icon, as in the reference design');
      expect(source.contains('label: Text('), isTrue,
          reason: 'each tab must pass its label text');
    });
  });

  group('the bar height is one shared constant, not per-file magic numbers', () {
    test('the bar defines the height and the player reads it', () {
      final bar = File(
        'lib/modules/root/spotube_navigation_bar.dart',
      ).readAsStringSync();
      expect(
        bar.contains('const double kNavigationBarHeight = '),
        isTrue,
        reason: 'a labelled tab needs more room than the old icon-only 50dp; '
            'the height must live in one place',
      );

      final overlay =
          File('lib/modules/player/player_overlay.dart').readAsStringSync();
      expect(overlay.contains('kNavigationBarHeight * invertedPosition'), isTrue);
      expect(
        overlay.contains('50 * invertedPosition'),
        isFalse,
        reason: 'the slide maths must follow the bar height, otherwise the '
            'mini player no longer sits on top of the bar',
      );

      final player = File('lib/modules/player/player.dart').readAsStringSync();
      expect(player.contains('kNavigationBarHeight'), isTrue);
      expect(
        player.contains('== 50'),
        isFalse,
        reason: 'the collapse test must compare against the same constant',
      );
    });
  });

  group('the home header keeps search reachable', () {
    final home = File('lib/pages/home/home.dart').readAsStringSync();

    test('the header has a search action that opens the search screen', () {
      expect(home.contains('SangeetIcons.search'), isTrue,
          reason: 'the top-right search icon was asked for explicitly');
      expect(home.contains('const SearchRoute()'), isTrue,
          reason: 'tapping it must open the existing search screen');
    });
  });
}
