import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/fonts.gen.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/models/metadata/metadata.dart';
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
    // Drives which shelf takes the slot under Featured Playlists: Recently Played
    // when the user has history, Albums when they do not. Read here rather than
    // inside the section so the DECISION is made in one place.
    final recentlyPlayed =
        ref.watch(recentlyPlayedTracksProvider).asData?.value ??
            const <SangeetTrackObject>[];

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
        ? const [
            Shadow(
                color: Color(0xCC000000),
                blurRadius: 5,
                offset: Offset(0, 1.5)),
          ]
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
                // The wallpaper, the header row and the carousel are ONE block.
                //
                // The wallpaper is not the app bar's background any more: it is a
                // full-width band behind this whole block, so the carousel sits
                // ON the artwork the way the design shows, with the header above
                // it. Because it is a single sliver, scrolling moves the
                // wallpaper, the logo, the title, the icons and the carousel up
                // the screen together and none of them is pinned.
                SliverToBoxAdapter(
                  child: ConstrainedBox(
                    // At least the wallpaper's own band height, so the artwork
                    // still reads as a band rather than a thin strip when no
                    // shelf has any tracks and the carousel collapses to nothing.
                    constraints: BoxConstraints(
                      minHeight: wallpaperUrl == null
                          ? 0
                          : HomeWallpaper.heightFor(mediaQuery.size),
                    ),
                    child: Stack(
                      children: [
                        if (wallpaperUrl != null)
                          // The band, NOT the whole block. The artwork used to be
                          // `Positioned.fill`, which stretched it behind the
                          // carousel as well and made it as tall as the header and
                          // the carousel together (~273dp on a 360x800 phone) —
                          // far more of the screen than the band it is meant to
                          // be. It is now exactly HomeWallpaper.heightFor tall and
                          // anchored to the top, so the header row sits on the
                          // artwork and the carousel sits below it on the page
                          // surface.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: HomeWallpaper.heightFor(mediaQuery.size),
                            child: HomeWallpaper(url: wallpaperUrl),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (mediaQuery.smAndDown ||
                                layoutMode == LayoutMode.compact)
                              _HomeHeaderRow(
                                color: headerColor,
                                shadows: headerShadows,
                                clerkState: clerkState,
                              )
                            else if (kIsMacOS)
                              const Gap(10),
                            // The carousel paints no background of its own, so
                            // whatever is behind it shows through: now the page
                            // surface, since the band stops above it.
                            const HomeSpecialsCarousel(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Featured Playlists sit DIRECTLY under the carousel, as close to
                // it as the layout allows — the two are one block visually, so the
                // gap is the minimum the carousel's own slide margin leaves rather
                // than a section break.
                const SliverGap(2),
                // Collapses to nothing when no chip has matching tracks.
                const FeaturedPlaylistChips(),
                // Recently Played sits right under the chips when the listener
                // has history; Albums is ALWAYS rendered beneath it — below
                // Recently Played when there is history, directly under Featured
                // Playlists when there is not. Albums is the catalogue's front
                // shelf and must never vanish, so the condition only decides
                // whether Recently Played takes the slot above it.
                if (recentlyPlayed.isNotEmpty)
                  const HomeRecentlyPlayedTracksSection(),
                ...switch (sectionsAsync) {
                  AsyncData(value: final sections) => [
                      HomeAlbumsSection(albums: sections.albums),
                    ],
                  _ => [const HomeAlbumsSection(albums: [])],
                },
                const HomePlaylistsSection(),
                ...switch (sectionsAsync) {
                  AsyncData(value: final sections) => [
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

/// The home screen's header row: the brand logo, the app name and the three
/// actions, drawn over the wallpaper.
///
/// It replaces a `SliverAppBar` because the header had to become part of the
/// wallpaper block: the artwork runs behind the header AND the carousel, so the
/// header can no longer be a bar of its own with the wallpaper behind it. The
/// geometry is the app bar's own — [material.kToolbarHeight] tall, contents
/// flush to the leading edge.
///
/// [color] and [shadows] come from the caller, which derives them from whether a
/// wallpaper is configured: white with a shadow over artwork, the theme's
/// foreground on the plain page surface, where white would be invisible.
class _HomeHeaderRow extends StatelessWidget {
  final Color color;
  final List<Shadow> shadows;
  final ClerkAuthState clerkState;

  const _HomeHeaderRow({
    required this.color,
    required this.shadows,
    required this.clerkState,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: material.kToolbarHeight,
      child: Row(
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
          // FittedBox(scaleDown) rather than an ellipsis. The script name IS the
          // app's identity on its own home screen, and `Expanded` + ellipsis
          // truncated it to "Soulful B..." on a 360dp phone, where the name, the
          // logo and three action icons together need slightly more width than
          // the row has. Scaling down keeps the whole name at every width, and
          // only scales when it must, so nothing changes when there is room.
          Expanded(
            // scaleDown keeps the whole brand name visible at every width — it
            // only shrinks, as a last resort, on a screen so narrow that the row
            // physically cannot hold it: never cropped, never truncated, never
            // wrapped. The scale is exactly 1.0 whenever the name fits.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Soulful Bhakti',
                maxLines: 1,
                style: TextStyle(
                  // Dancing Script — the brand name's typeface.
                  //
                  // A script face, so its glyphs are much NARROWER per point than
                  // the geometric Cookie it replaces while its ascenders and
                  // descenders run far outside the em box. 26px (down from
                  // Cookie's 30) keeps the name the same optical height and
                  // roughly the same width in the header row; the taller
                  // line-height below stops the flourishes on the 'S', 'f' and
                  // 'k' from being clipped by the row's fixed toolbar height.
                  fontFamily: FontFamily.dancingScript,
                  fontSize: 26,
                  height: 1.35,
                  // Script faces are joined by design, so the word-spacing should
                  // read as handwriting rather than as tracked-out capitals.
                  // Cookie's 1.8 letter-spacing made Dancing Script look spaced
                  // apart; 0.4 keeps the two words distinct without breaking the
                  // cursive flow.
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                  color: color,
                  shadows: shadows,
                ),
              ),
            ),
          ),
          // Search: opens the app's search page. Placed first so the row reads
          // logo | title | search | account | settings, matching the design.
          IconButton.ghost(
            icon: Icon(
              SangeetIcons.search,
              size: 20,
              color: color,
              shadows: shadows,
            ),
            onPressed: () {
              context.navigateTo(const SearchRoute());
            },
          ),
          const Gap(10),
          // Signed-in users see their account avatar (same as the Google
          // account); signed-out users see the user icon.
          IconButton.ghost(
            icon: (clerkState.signedIn && clerkState.imageUrl != null)
                ? Container(
                    // A hairline white ring keeps a photo avatar legible against
                    // a photo wallpaper, which a bare circle is not.
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
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
                    color: color,
                    shadows: shadows,
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
              color: color,
              shadows: shadows,
            ),
            onPressed: () {
              context.navigateTo(const SettingsRoute());
            },
          ),
          const Gap(10),
        ],
      ),
    );
  }
}
