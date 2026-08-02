import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/track_tile/track_tile.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/modules/connect/connect_device.dart';
import 'package:sangeet/modules/home/sections/recent_tracks.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/pages/auth/login_page.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
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
    final playlist = ref.watch(audioPlayerProvider);
    final tracksAsync = ref.watch(homeTracksProvider);

    return SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            if (kTitlebarVisible) const TitleBar(height: 30),
          ],
          child: CustomScrollView(
            controller: controller,
            slivers: [
              if (mediaQuery.smAndDown || layoutMode == LayoutMode.compact)
                SliverAppBar(
                  floating: true,
                  title: ClipOval(
                    child: Image.asset(
                      'assets/branding/sangeet-logo.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        'Soulful Bhakti',
                        style: TextStyle(
                          fontFamily: "Cookie",
                          fontSize: 30,
                          letterSpacing: 1.8,
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                    ),
                  ),
                  backgroundColor: theme.colorScheme.background,
                  foregroundColor: theme.colorScheme.foreground,
                  actions: [
                    const ConnectDeviceButton(),
                    const Gap(10),
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
              const SliverGap(10),
              const HomeRecentlyPlayedTracksSection(),
              switch (tracksAsync) {
                AsyncData(value: final tracks) => SliverList.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return TrackTile(
                        index: index + 1,
                        track: track,
                        playlist: playlist,
                        onTap: () async {
                          await ref
                              .read(audioPlayerProvider.notifier)
                              .load(tracks, initialIndex: index, autoPlay: true);
                        },
                      );
                    },
                  ),
                AsyncError(error: final error) => SliverFillRemaining(
                    child: Center(
                      child: ErrorBox(
                        error: error,
                        onRetry: () {
                          ref.invalidate(homeTracksProvider);
                        },
                      ),
                    ),
                  ),
                _ => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              },
            ],
          ),
        ));
  }
}
