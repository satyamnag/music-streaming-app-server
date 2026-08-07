import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/modules/auth/profile_dialog.dart';
import 'package:sangeet/modules/home/sections/go_for_paid_plan_banner.dart';
import 'package:sangeet/modules/home/sections/playlists.dart';
import 'package:sangeet/modules/home/sections/recent_tracks.dart';
import 'package:sangeet/modules/home/sections/track_section.dart';
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

    return SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            if (kTitlebarVisible) const TitleBar(height: 30),
          ],
          child: material.RefreshIndicator.adaptive(
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
                        IconButton.ghost(
                          icon: const Icon(SangeetIcons.user, size: 20),
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
                  const GoForPaidPlanBanner(),
                  const SliverGap(10),
                  const HomeRecentlyPlayedTracksSection(),
                  const HomePlaylistsSection(),
                  ...switch (sectionsAsync) {
                    AsyncData(value: final sections) => [
                        HomeTrackSection(
                          title: context.l10n.newest_arrivals,
                          tracks: sections.newestArrivals,
                        ),
                        HomeTrackSection(
                          title: context.l10n.top_trending,
                          tracks: sections.topTrending,
                        ),
                      ],
                    AsyncLoading() => [
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
                        HomeTrackSection(
                          title: context.l10n.newest_arrivals,
                          tracks: const [],
                          isLoading: true,
                        ),
                      ],
                  },
                ],
              ),
            ),
          ),
        );
  }
}
