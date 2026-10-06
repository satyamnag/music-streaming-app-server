import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/track_card/home_card_row.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';
import 'package:sangeet/provider/history/recent_tracks.dart';

/// A horizontal "Recently played" row of track cards shown on the home screen.
/// Devotional & calm mood: rounded corners, soft shadow, maroon accent.
/// Tapping a card plays the full recently-played list from that track.
/// Shows the first [pageSize] cards plus a "See More" card that reveals the
/// next [pageSize] on each tap. Hidden when there is no listening history yet.
class HomeRecentlyPlayedTracksSection extends HookConsumerWidget {
  /// Number of cards revealed per page.
  static const int pageSize = 25;

  const HomeRecentlyPlayedTracksSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final history = ref.watch(recentlyPlayedTracksProvider);
    final tracks = history.asData?.value ?? const <SangeetTrackObject>[];
    final visibleCount = useState(HomeRecentlyPlayedTracksSection.pageSize);

    // History snapshots may predate cover art (thumbnails uploaded later).
    // Resolve any missing album images from the live catalog by track id so
    // recently-played cards always show their cover photo.
    final catalog = ref.watch(homeTracksProvider).asData?.value ?? const [];
    final catalogByTrackId = {for (final t in catalog) t.id: t};

    if (history.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Skeletonizer(
                enabled: true,
                child: Text(
                  context.l10n.recently_played,
                  style: Theme.of(context).typography.h4,
                ),
              ),
              const Gap(8),
              Skeletonizer(
                enabled: true,
                child: SizedBox(
                  height: HomeSectionLayout.rowHeight(
                        context,
                        withSubtitle: false,
                      ) +
                      HomeSectionLayout.skeletonHeadroom,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, __) => const Gap(6),
                    itemBuilder: (context, index) => HomeTrackCard(
                      track: FakeData.track,
                      imageUrl: '',
                      width: HomeSectionLayout.cardWidth *
                          Theme.of(context).scaling,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (tracks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final scale = theme.scaling;
    final shown = tracks.take(visibleCount.value).toList();
    final hasMore = tracks.length > visibleCount.value;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: HomeCardRow(
          // These are TRACK cards: two reserved title lines and no album line,
          // so the row is sized to that card — exactly like the "Newest
          // Arrivals" and "Top Trending" rows, and the same shared layout the
          // Albums row uses.
          height: HomeSectionLayout.twoLineTrackRowHeight(context),
          header: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style: theme.typography.h4.copyWith(
                      color: theme.colorScheme.foreground,
                    ),
                    child: Text(context.l10n.recently_played),
                  ),
                ),
                if (tracks.length > 5)
                  IconButton.ghost(
                    size: ButtonSize.small,
                    icon: const Icon(SangeetIcons.angleRight, size: 18),
                    onPressed: () {
                      context.navigateTo(const RecentlyPlayedRoute());
                    },
                  ),
              ],
            ),
          ),
          itemCount: shown.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (hasMore && index == shown.length) {
              return _SeeMoreCard(
                onTap: () {
                  visibleCount.value +=
                      HomeRecentlyPlayedTracksSection.pageSize;
                },
              );
            }
            final track = shown[index];
            final historyTrack = catalogByTrackId[track.id];
            final images = track.album.images.isNotEmpty
                ? track.album.images
                : (historyTrack?.album.images ?? const []);
            final imageUrl = images.smallest(ImagePlaceholder.albumArt);

            // Play the LIVE CATALOGUE object, not the history snapshot.
            //
            // History rows are snapshots taken when the track was last
            // played, so they carry only what the row stored — none of the
            // admin-configured fields (the mini player background, the card
            // colours). Loading them made the mini player fall back to the
            // theme even though the track HAD a colour set in the admin,
            // which is exactly the "background does not work from Recently
            // Played" bug. The catalogue is already fetched above for the
            // cover art, so this costs nothing; the history object stays the
            // fallback for a track that is no longer in the catalogue.
            final playable = [
              for (final t in tracks) catalogByTrackId[t.id] ?? t,
            ];

            // The SHARED track card, so Recently Played gets the same
            // bottom-right play control, typography, admin colours and
            // two-line name as every other shelf, and the header is the same
            // h4 + "see all" arrow the Albums and Track rows carry.
            //
            // The CATALOGUE object is used for the card as well as for
            // playback, so a track's admin-configured colours apply here the
            // same way they do everywhere else.
            final cardTrack = playable[index];
            void playThis() => ref
                .read(audioPlayerProvider.notifier)
                .load(playable, initialIndex: index, autoPlay: true);

            // No explicit premium gate: HomeTrackCard gates BOTH of its tap
            // targets through PremiumAccess itself, so gating here as well
            // would be the same check twice.
            return HomeTrackCard(
              track: cardTrack,
              imageUrl: imageUrl,
              onTap: playThis,
              onPlay: playThis,
            );
          },
        ),
      ),
    );
  }
}

/// A "See More" card shown after the visible recent-played cards. Tapping it
/// reveals the next page of cards.
class _SeeMoreCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SeeMoreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Container(
      width: HomeSectionLayout.cardWidth * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        color: theme.colorScheme.card,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                SangeetIcons.angleDown,
                size: 22 * scale,
                color: theme.colorScheme.primary,
              ),
              Gap(8 * scale),
              Text(
                context.l10n.see_more,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
