import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/stats/summary/donut_chart.dart';
import 'package:sangeet/modules/stats/summary/summary_card.dart';
import 'package:sangeet/provider/history/summary.dart';
import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/provider/history/top/tracks.dart';

class StatsPageSummarySection extends HookConsumerWidget {
  const StatsPageSummarySection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(playbackHistorySummaryProvider);
    final summaryData = summary.asData?.value ?? FakeData.historySummary;

    final topTracks = ref.watch(
      historyTopTracksProvider(HistoryDuration.allTime),
    );
    final topTracksList = topTracks.asData?.value.items ?? const [];
    final topTrackName = topTracksList.firstOrNull?.track.name ?? "—";

    // Listening-share donut for the top 5 tracks (by play count).
    final chartSegments = topTracksList
        .take(5)
        .map(
          (e) => (label: e.track.name, value: e.count.toDouble()),
        )
        .toList();
    final hasChart = chartSegments.isNotEmpty;
    final topPlayCount = topTracksList.firstOrNull?.count ?? 0;

    return Skeletonizer.sliver(
      enabled: summary.isLoading,
      child: SliverMainAxisGroup(
        slivers: [
          if (hasChart)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              sliver: SliverToBoxAdapter(
                child: Card(
                  fillColor: theme.colorScheme.card,
                  filled: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  borderRadius: theme.borderRadiusLg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.summary_listening_share,
                              style: theme.typography.h4.copyWith(
                                color: theme.colorScheme.foreground,
                              ),
                            ),
                            const Gap(4),
                            Text(
                              context.l10n.summary_listening_share_description(
                                topTracksList.length,
                              ),
                              style: theme.typography.small.copyWith(
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                            const Gap(10),
                            for (final (index, segment)
                                in chartSegments.indexed)
                              _LegendRow(
                                color: theme.colorScheme.chart1,
                                index: index,
                                label: segment.label,
                                count: segment.value.toInt(),
                              ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      DonutChart(
                        segments: chartSegments,
                        centerValue: topPlayCount.toString(),
                        centerLabel: context.l10n.summary_plays,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverLayoutBuilder(builder: (context, constrains) {
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constrains.isXs
                      ? 2
                      : constrains.smAndDown
                          ? 3
                          : constrains.mdAndDown
                              ? 4
                              : constrains.lgAndDown
                                  ? 5
                                  : 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: constrains.isXs ? 1.3 : 1.5,
                ),
                delegate: SliverChildListDelegate([
                  SummaryCard(
                    title: summaryData.duration.inMinutes.toDouble(),
                    unit: context.l10n.summary_minutes,
                    description: context.l10n.summary_listened_to_music,
                    color: Colors.indigo,
                    onTap: () {
                      context.navigateTo(const StatsMinutesRoute());
                    },
                  ),
                  SummaryCard(
                    title: summaryData.tracks.toDouble(),
                    unit: context.l10n.summary_songs,
                    description: context.l10n.summary_streamed_overall,
                    color: Colors.blue,
                    onTap: () {
                      context.navigateTo(const StatsStreamsRoute());
                    },
                  ),
                  SummaryCard.unformatted(
                    title: topTrackName,
                    unit: "",
                    description: context.l10n.summary_top_track,
                    color: Colors.green,
                    onTap: () {
                      context.navigateTo(const StatsStreamsRoute());
                    },
                  ),
                  SummaryCard(
                    title: summaryData.artists.toDouble(),
                    unit: context.l10n.summary_artists,
                    description: context.l10n.summary_music_reached_you,
                    color: Colors.yellow,
                    onTap: () {
                      context.navigateTo(const StatsArtistsRoute());
                    },
                  ),
                  SummaryCard(
                    title: summaryData.albums.toDouble(),
                    unit: context.l10n.summary_full_albums,
                    description: context.l10n.summary_got_your_love,
                    color: Colors.pink,
                  ),
                  SummaryCard(
                    title: summaryData.playlists.toDouble(),
                    unit: context.l10n.summary_playlists,
                    description: context.l10n.summary_were_on_repeat,
                    color: Colors.teal,
                    onTap: () {
                      context.navigateTo(const StatsPlaylistsRoute());
                    },
                  ),
                ]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final int index;
  final String label;
  final int count;

  const _LegendRow({
    required this.color,
    required this.index,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 1 - index * 0.15),
            ),
          ),
          const Gap(8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: theme.typography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
