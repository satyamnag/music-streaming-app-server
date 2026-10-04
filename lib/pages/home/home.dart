import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/modules/auth/profile_dialog.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/modules/home/sections/albums.dart';
import 'package:sangeet/modules/home/sections/language_songs.dart';
import 'package:sangeet/modules/home/sections/playlists.dart';
import 'package:sangeet/modules/home/sections/recent_tracks.dart';
import 'package:sangeet/modules/home/sections/featured_playlist_chips.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/modules/home/sections/home_wallpaper.dart';
import 'package:sangeet/modules/home/sections/specials_carousel.dart';
import 'package:sangeet/modules/home/sections/track_section.dart';
import 'package:sangeet/pages/home/home_see_all.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/history/recent_tracks.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/utils/platform.dart';

@RoutePage()
class HomePage extends HookConsumerWidget {
  static const name = "home";
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final controller = useScrollController();
    final mediaQuery = MediaQuery.of(context);
    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));
    final sectionsAsync = ref.watch(homeSectionsProvider);
    // Fire-and-forget: pre-warm stream URLs so tapping a song starts instantly.
    ref.watch(prewarmHomeStreamsProvider);
    final clerkAuth = ref.watch(clerkAuthProvider);
    final clerkState = clerkAuth.valueOrNull ?? const ClerkAuthState();
    // Admin-managed home wallpaper. Null (unset, table absent, or a failed
    // fetch) simply renders the normal themed background.
    final wallpaperUrl = ref.watch(homeWallpaperProvider).valueOrNull;
    final hasWallpaper = wallpaperUrl != null && wallpaperUrl.isNotEmpty;

    // The header rides ON the wallpaper, so over artwork its text and icons are
    // white with a shadow. With no wallpaper the page background is the light
    // themed surface, where white would be invisible — so there it keeps the
    // theme's foreground colour. One rule, and the header can never end up
    // unreadable in either state.
    //
    // The shadow is doing the work the removed scrim used to do: it darkens the
    // glyph edges only, instead of washing a grey film over the whole artwork.
    final headerColor =
        hasWallpaper ? Colors.white : theme.colorScheme.foreground;
    final headerShadows = hasWallpaper
        ? const [Shadow(color: Color(0xCC000000), blurRadius: 6)]
        : const <Shadow>[];

    return PopScope(
      canPop: !kIsAndroid,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !kIsAndroid) return;
        confirmExit(context);
      },
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            if (kTitlebarVisible) const TitleBar(height: 30),
          ],
          child: material.RefreshIndicator.adaptive(
            // Theme the Material refresh spinner so it matches the app instead
            // of rendering the default grey overlay on pull-down.
            color: context.theme.colorScheme.primary,
            backgroundColor: context.theme.colorScheme.background,
            onRefresh: () async {
              ref.invalidate(homeTracksProvider);
              ref.invalidate(homeSectionsProvider);
              ref.invalidate(recentlyPlayedTracksProvider);
            },
            child: CustomScrollView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (mediaQuery.smAndDown || layoutMode == LayoutMode.compact)
                  SliverAppBar(
                    // The header is part of the page, not furniture on top of it.
                    //
                    // `pinned: false` + `floating: false` is the whole point of
                    // this bar: the wallpaper, the logo, the "Soulful Bhakti"
                    // title and the three icons leave the screen together when
                    // the user scrolls down, and come back as one unit when they
                    // scroll up. Previously the wallpaper sat in a fixed
                    // Positioned band behind the scroll view while the bar was
                    // `floating: true` (pinned), so the page scrolled underneath
                    // a header and a wallpaper that never moved.
                    pinned: false,
                    floating: false,
                    // As tall as the wallpaper band itself, so the artwork fills
                    // the header edge to edge and the title row overlays its top.
                    // With no wallpaper the bar collapses to a plain toolbar,
                    // which is exactly what a header over the page surface should
                    // be.
                    //
                    // Both ternaries test `wallpaperUrl` directly rather than the
                    // `hasWallpaper` flag: a null check on the variable itself is
                    // what lets Dart promote it to a non-null String on the other
                    // branch, which a stored bool cannot do.
                    expandedHeight: wallpaperUrl == null
                        ? null
                        : HomeWallpaper.heightFor(mediaQuery.size),
                    flexibleSpace: wallpaperUrl == null
                        ? null
                        : material.FlexibleSpaceBar(
                            // Parallax keeps the photo at its own size while the
                            // header collapses, so the artwork slides out of view
                            // instead of being squashed as the bar shrinks.
                            collapseMode: material.CollapseMode.parallax,
                            background: HomeWallpaper(url: wallpaperUrl),
                          ),
                    titleSpacing: 0,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 16),
                        ClipOval(
                          child: Image.asset(
                            'assets/branding/sangeet-logo.png',
                            height: 32,
                            width: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Soulful Bhakti',
                          style: TextStyle(
                            fontFamily: "Cookie",
                            fontSize: 30,
                            letterSpacing: 1.8,
                            color: headerColor,
                            shadows: headerShadows,
                          ),
                        ),
                      ],
                    ),
                    // Transparent so the app bar never paints an opaque slab
                    // over the wallpaper or the page: the title, logo and icons
                    // draw straight onto the artwork behind them.
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                    elevation: 0,
                    foregroundColor: headerColor,
                    actions: [
                      // Search: opens the app's search page. Placed first so
                      // the row reads logo | title | search | account |
                      // settings, matching the design.
                      IconButton.ghost(
                        icon: Icon(
                          SangeetIcons.search,
                          size: 20,
                          color: headerColor,
                          shadows: headerShadows,
                        ),
                        onPressed: () {
                          context.navigateTo(const SearchRoute());
                        },
                      ),
                      const Gap(10),
                      // Signed-in users see their account avatar (same as the
                      // Google account); signed-out users see the user icon.
                      IconButton.ghost(
                        icon: (clerkState.signedIn &&
                                clerkState.imageUrl != null)
                            ? Container(
                                // A hairline white ring keeps a photo avatar
                                // legible against a photo wallpaper, which a
                                // bare circle is not.
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: UniversalImage(
                                    path: clerkState.imageUrl!,
                                    height: 26,
                                    width: 26,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : Icon(
                                SangeetIcons.user,
                                size: 20,
                                color: headerColor,
                                shadows: headerShadows,
                              ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const ProfileDialog(),
                          );
                        },
                      ),
                      const Gap(10),
                      IconButton.ghost(
                        icon: Icon(
                          SangeetIcons.settings,
                          size: 20,
                          color: headerColor,
                          shadows: headerShadows,
                        ),
                        onPressed: () {
                          context.navigateTo(const SettingsRoute());
                        },
                      ),
                      const Gap(10),
                    ],
                  )
                else if (kIsMacOS)
                  const SliverGap(10),
                const SliverGap(10),
                const HomeRecentlyPlayedTracksSection(),
                const HomePlaylistsSection(),
                // Curated "Specials" carousels (Ganesha Special, Krishna
                // Special, ...) sit directly above the Albums shelf. The
                // widget collapses to nothing when no shelf has tracks, so
                // an empty catalogue never shows a blank carousel.
                const HomeSpecialsCarousel(),
                // Round "Featured Playlist" chips (Venkateswara, Krishna,
                // Ganesha, ...) directly under the carousel, per the design.
                // Collapses to nothing when no chip has matching tracks.
                const FeaturedPlaylistChips(),
                ...switch (sectionsAsync) {
                  AsyncData(value: final sections) => [
                      HomeAlbumsSection(albums: sections.albums),
                      HomeLanguageSongsSections(languages: sections.languages),
                      HomeTrackSection(
                        title: context.l10n.newest_arrivals,
                        tracks: sections.newestArrivals,
                        onSeeAll: () {
                          context.navigateTo(
                            HomeSeeAllRoute(
                              kind: HomeSeeAllKind.newestArrivals,
                            ),
                          );
                        },
                      ),
                      HomeTrackSection(
                        title: context.l10n.top_trending,
                        tracks: sections.topTrending,
                        onSeeAll: () {
                          context.navigateTo(
                            HomeSeeAllRoute(
                              kind: HomeSeeAllKind.topTrending,
                            ),
                          );
                        },
                      ),
                    ],
                  AsyncLoading() => [
                      const HomeAlbumsSection(albums: []),
                      const HomeLanguageSongsSections(languages: []),
                      HomeTrackSection(
                        title: context.l10n.newest_arrivals,
                        tracks: const [],
                        isLoading: true,
                      ),
                    ],
                  AsyncError(error: final error) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.0 * theme.scaling,
                            vertical: 8,
                          ),
                          child: ErrorBox(
                            error: error,
                            onRetry: () {
                              ref.invalidate(homeSectionsProvider);
                            },
                          ),
                        ),
                      ),
                    ],
                  _ => [
                      const HomeAlbumsSection(albums: []),
                      const HomeLanguageSongsSections(languages: []),
                      HomeTrackSection(
                        title: context.l10n.newest_arrivals,
                        tracks: const [],
                        isLoading: true,
                      ),
                    ],
                },
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom +
                        12 * theme.scaling,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a confirmation dialog before the Android back button exits the app.
  /// The app only exits after the user confirms; cancelling keeps them in the
  /// app.
  static Future<void> confirmExit(BuildContext context) async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Soulful Bhakti?'),
        content: const Text(
          'Are you sure you want to exit Soulful Bhakti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (exit == true) {
      SystemNavigator.pop();
    }
  }
}
