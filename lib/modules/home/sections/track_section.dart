import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// A titled horizontal row of track cards used for the home screen sections
/// ("Newest Arrivals", "Top Trending"). Keeps the same card layout as the
/// "Recently played" row so every home section scrolls horizontally.
///
/// Shows the section title, then the first [pageSize] tracks. A "See More"
/// card reveals the next [pageSize] tracks on each tap until all tracks are
/// visible. Tapping a track starts playback of the whole section from that
/// track. Shows a compact skeleton while the tracks are loading.
///
/// The header shows a right arrow instead of the track count; tapping it calls
/// [onSeeAll] (which opens the full-screen section) when provided.
class HomeTrackSection extends HookConsumerWidget {
  final String title;
  final List<SangeetTrackObject> tracks;
  final bool isLoading;
  final VoidCallback? onSeeAll;

  /// Number of tracks revealed per page.
  static const int pageSize = 5;

  const HomeTrackSection({
    super.key,
    required this.title,
    required this.tracks,
    this.isLoading = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final visibleCount = useState(pageSize);

    if (isLoading) {
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
                  title,
                  style: theme.typography.h4,
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
                    itemBuilder: (context, index) => _TrackCard(
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
                      child: Text(title),
                    ),
                  ),
                  if (onSeeAll != null)
                    IconButton.ghost(
                      size: ButtonSize.small,
                      icon: const Icon(SangeetIcons.angleRight, size: 18),
                      onPressed: onSeeAll,
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
                        visibleCount.value += HomeTrackSection.pageSize;
                      },
                    );
                  }
                  final track = shown[index];
                  final imageUrl =
                      track.album.images.smallest(ImagePlaceholder.albumArt);

                  return _TrackCard(
                    track: track,
                    imageUrl: imageUrl,
                    onTap: () async {
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

class _TrackCard extends HookConsumerWidget {
  final SangeetTrackObject track;
  final String imageUrl;
  final VoidCallback onTap;

  const _TrackCard({
    required this.track,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final locked = PremiumAccess.isTrackLocked(track, ref);

    return Container(
      width: 140 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        color: theme.colorScheme.card,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: () async {
          if (locked) {
            await PremiumAccess.gateTrackPlay(
              context: context,
              ref: ref,
              track: track,
              feature: () async => onTap(),
            );
            return;
          }
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.all(10 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Stack(
                  children: [
                    UniversalImage(
                      path: imageUrl,
                      height: 120 * scale,
                      width: 120 * scale,
                      fit: BoxFit.cover,
                    ),
                    LockedBadge(locked: locked, borderRadius: 0),
                  ],
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
              Text(
                track.album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A "See More" card shown after the visible track cards. Tapping it reveals
/// the next page of cards.
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
