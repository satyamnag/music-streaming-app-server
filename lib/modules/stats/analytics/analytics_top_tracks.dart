import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/provider/history/top/tracks.dart';

/// "Your Top Tracks" — the three most-played tracks of the selected period, with
/// a link to the full list.
///
/// The rows are `historyTopTracksProvider`'s own items, so this card and the
/// Streams/Minutes pages (which read the same provider) can never disagree about
/// what the top tracks are. When nothing has been played yet the card is not
/// rendered at all rather than showing three empty slots.
class AnalyticsTopTracks extends ConsumerWidget {
  const AnalyticsTopTracks({super.key});

  /// Rank badge colours for 1st / 2nd / 3rd, as the design shows them.
  static const List<Color> _rankColors = [
    Color(0xFFF0A020),
    Color(0xFF9AA3AF),
    Color(0xFFB5651D),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final range = ref.watch(playbackHistoryTopDurationProvider);
    final items =
        ref.watch(historyTopTracksProvider(range)).asData?.value.items ??
            const <PlaybackHistoryTrack>[];

    if (items.isEmpty) return const SizedBox.shrink();

    final shown = items.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        fillColor: theme.colorScheme.card,
        filled: true,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 6),
        borderRadius: theme.borderRadiusLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 17,
                  color: Color(0xFFE08A00),
                ),
                const Gap(6),
                Expanded(
                  child: Text(
                    l10n.analytics_your_top_tracks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.base.copyWith(
                      color: theme.colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // The full list the card summarises: the Streams page, which
                  // is every streamed song with its play count.
                  onTap: () => context.navigateTo(const StatsStreamsRoute()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.analytics_see_all,
                          maxLines: 1,
                          style: theme.typography.small.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Gap(2),
            Text(
              l10n.analytics_top_tracks_desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const Gap(6),
            for (var index = 0; index < shown.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Container(
                    height: 1,
                    color: theme.colorScheme.muted.withValues(alpha: 0.6),
                  ),
                ),
              _TopTrackRow(
                rank: index + 1,
                entry: shown[index],
                rankColor: _rankColors[index % _rankColors.length],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopTrackRow extends StatelessWidget {
  final int rank;
  final PlaybackHistoryTrack entry;
  final Color rankColor;

  const _TopTrackRow({
    required this.rank,
    required this.entry,
    required this.rankColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = entry.track;
    // Nominal minutes: the track's own length times how often it was played,
    // the same basis the summary uses — not wall-clock listening time.
    final minutes = ((entry.count * track.durationMs) / 60000).round();
    final coverUrl = track.album.images.smallest(ImagePlaceholder.albumArt);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.navigateTo(TrackRoute(trackId: track.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rankColor,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    maxLines: 1,
                    style: theme.typography.xSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: UniversalImage(
                  path: coverUrl,
                  fit: BoxFit.cover,
                  coverPixels: 176,
                ),
              ),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    context.l10n.analytics_played_times_mins(entry.count, minutes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.xSmall.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.mutedForeground.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
