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
                      floating: true,
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
                              color: theme.colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: theme.colorScheme.background,
                      foregroundColor: theme.colorScheme.foreground,
                      actions: [
                        // Signed-in users see their account avatar (same as the
                        // Google account); signed-out users see the user icon.
                        IconButton.ghost(
                          icon: (clerkState.signedIn && clerkState.imageUrl != null)
                              ? ClipOval(
                                  child: UniversalImage(
                                    path: clerkState.imageUrl!,
                                    height: 26,
                                    width: 26,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(SangeetIcons.user, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const ProfileDialog(),
                            );
                          },
                        ),
                        const Gap(10),
                        IconButton.ghost(
                          icon: const Icon(SangeetIcons.settings, size: 20),
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
