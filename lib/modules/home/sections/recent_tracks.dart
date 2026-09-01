import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
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
  static const int pageSize = 5;

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
          padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (context, index) => _RecentTrackCard(
                      track: FakeData.track,
                      imageUrl: '',
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
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
                  Tooltip(
                    tooltip: TooltipContainer(
                      child: Text(context.l10n.recently_played),
                    ).call,
                    child: IconButton.ghost(
                      size: ButtonSize.small,
                      icon: const Icon(SangeetIcons.clock, size: 18),
                      onPressed: () {
                        context.navigateTo(const RecentlyPlayedRoute());
                      },
                    ),
                  ),
                ],
              ),
            ),
            Gap(8 * scale),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                scrollDirection: Axis.horizontal,
                itemCount: shown.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, __) => Gap(12 * scale),
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
                  final imageUrl =
                      images.smallest(ImagePlaceholder.albumArt);

                  return _RecentTrackCard(
                    track: track,
                    imageUrl: imageUrl,
                    onTap: () async {
                      if (PremiumAccess.isTrackLocked(track, ref)) {
                        await PremiumAccess.gateTrackPlay(
                          context: context,
                          ref: ref,
                          track: track,
                          feature: () async {
                            await ref
                                .read(audioPlayerProvider.notifier)
                                .load(tracks, initialIndex: index, autoPlay: true);
                          },
                        );
                        return;
                      }

                      await ref
                          .read(audioPlayerProvider.notifier)
                          .load(tracks, initialIndex: index, autoPlay: true);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTrackCard extends HookWidget {
  final SangeetTrackObject track;
  final String imageUrl;
  final VoidCallback onTap;

  const _RecentTrackCard({
    required this.track,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Container(
      width: 140 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        color: theme.colorScheme.card,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.12)
                : theme.colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.all(10 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: UniversalImage(
                  path: imageUrl,
                  height: 120 * scale,
                  width: 120 * scale,
                  fit: BoxFit.cover,
                ),
              ),
              Gap(8 * scale),
              Text(
                track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              Gap(2 * scale),
              const SizedBox.shrink(),
            ],
          ),
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
      width: 140 * scale,
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
                size: 28,
                color: theme.colorScheme.primary,
              ),
              Gap(8 * scale),
              Text(
                context.l10n.see_more,
                style: theme.typography.base.copyWith(
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
