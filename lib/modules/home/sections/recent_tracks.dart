import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/history/recent_tracks.dart';

/// A horizontal "Recently played" row of track cards shown on the home screen.
/// Devotional & calm mood: rounded corners, soft shadow, maroon accent.
/// Tapping a card plays the full recently-played list from that track.
/// Hidden when there is no listening history yet.
class HomeRecentlyPlayedTracksSection extends HookConsumerWidget {
  const HomeRecentlyPlayedTracksSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final history = ref.watch(recentlyPlayedTracksProvider);
    final tracks = history.asData?.value ?? const <SangeetTrackObject>[];

    if (history.isLoading) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (tracks.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final theme = Theme.of(context);
    final scale = theme.scaling;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
              child: DefaultTextStyle(
                style: theme.typography.h4.copyWith(
                  color: theme.colorScheme.foreground,
                ),
                child: Text(context.l10n.recently_played),
              ),
            ),
            Gap(8 * scale),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length,
                separatorBuilder: (_, __) => Gap(12 * scale),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final imageUrl = track.album.images
                          .smallest(ImagePlaceholder.albumArt);

                  return _RecentTrackCard(
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
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
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
              Text(
                track.artists.asString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
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