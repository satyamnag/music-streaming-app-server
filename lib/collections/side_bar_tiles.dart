import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/l10n/l10n.dart';

class SideBarTiles {
  final IconData icon;
  final String title;
  final String id;
  final String pathPrefix;
  final PageRouteInfo route;

  SideBarTiles({
    required this.icon,
    required this.title,
    required this.id,
    required this.route,
    required this.pathPrefix,
  });
}

List<SideBarTiles> getSidebarTileList(AppLocalizations l10n) => [
      SideBarTiles(
        id: "home",
        pathPrefix: "/home",
        route: const HomeRoute(),
        icon: SangeetIcons.home,
        title: l10n.browse,
      ),
      SideBarTiles(
        id: "search",
        pathPrefix: "/search",
        route: const SearchRoute(),
        icon: SangeetIcons.search,
        title: l10n.search,
      ),
      SideBarTiles(
        id: "lyrics",
        pathPrefix: "/lyrics",
        route: const LyricsRoute(),
        icon: SangeetIcons.music,
        title: l10n.lyrics,
      ),
      SideBarTiles(
        id: "stats",
        pathPrefix: "/stats",
        route: const StatsRoute(),
        icon: SangeetIcons.chart,
        title: l10n.stats,
      ),
    ];

List<SideBarTiles> getSidebarLibraryTileList(AppLocalizations l10n) => [
      SideBarTiles(
        id: "playlists",
        pathPrefix: "/library/playlists",
        title: l10n.playlists,
        route: const UserPlaylistsRoute(),
        icon: SangeetIcons.playlist,
      ),
    ];

/// The bottom navigation bar's four tabs, in order:
/// Home, Library, My Bhakti, Profile.
///
/// The labels are exactly the four words the product spec asks for, and each
/// tab's icon is the one shown in the reference screens:
///   * Home      — house            -> the /home screen
///   * Library   — books/library    -> the user's playlists (the /library shell)
///   * My Bhakti — music note       -> the listening-stats screen (/stats)
///   * Profile   — person           -> the account screen (/profile)
///
/// Search deliberately has no tab: it moved to the Home header, which is what
/// the reference design shows. The route itself is untouched, so the desktop
/// sidebar and the search intents still reach it.
///
/// "Home" and "My Bhakti" are literals on purpose: there is no `home` l10n key,
/// and "My Bhakti" is a product/brand name that is not translated. Library and
/// Profile reuse the existing localised strings.
List<SideBarTiles> getNavbarTileList(AppLocalizations l10n) => [
      SideBarTiles(
        id: "home",
        pathPrefix: "/home",
        route: const HomeRoute(),
        icon: SangeetIcons.home,
        title: 'Home',
      ),
      SideBarTiles(
        id: "library",
        pathPrefix: "/library",
        route: const UserPlaylistsRoute(),
        icon: SangeetIcons.library,
        title: l10n.library,
      ),
      SideBarTiles(
        id: "my_bhakti",
        pathPrefix: "/stats",
        route: const StatsRoute(),
        icon: SangeetIcons.music,
        title: 'My Bhakti',
      ),
      SideBarTiles(
        id: "profile",
        pathPrefix: "/profile",
        route: const ProfileRoute(),
        icon: SangeetIcons.user,
        title: l10n.profile,
      ),
    ];
