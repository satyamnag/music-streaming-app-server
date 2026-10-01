import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/history/insights.dart';
import 'package:sangeet/provider/history/summary.dart';
import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/provider/history/top/tracks.dart';

/// A compact "Insights" strip shown above the summary cards on the analytics
/// screen. Everything derives from the local playback history — no schema or
/// network changes — and gives the user at-a-glance answers:
///   - top track (all-time, matching the donut card's source)
///   - hours listened (nominal sum of scrobbled track lengths)
///   - best day (calendar day with the most scrobbled plays)
///   - current play streak (consecutive days with at least one play)
///   - this-week vs last-week play trend chip
class StatsPageInsightsSection extends HookConsumerWidget {
  const StatsPageInsightsSection({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final insightsAsync = ref.watch(playbackInsightsProvider);
    final insights = insightsAsync.asData?.value;
    final summary =
        ref.watch(playbackHistorySummaryProvider).asData?.value;
    final topTracks = ref
            .watch(historyTopTracksProvider(HistoryDuration.allTime))
            .asData
            ?.value
            .items ??
        const [];
    final topTrackName = topTracks.isEmpty ? '—' : topTracks.first.track.name;
    final bestDay = insights?.bestDay;
    final trend = insights?.weekTrendPercent;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Skeletonizer(
          enabled: insightsAsync.isLoading,
          child: Card(
            fillColor: theme.colorScheme.card,
            filled: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: theme.borderRadiusLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.insights,
                  style: theme.typography.h4.copyWith(
                    color: theme.colorScheme.foreground,
                  ),
                ),
                const Gap(10),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _InsightTile(
                      label: context.l10n.insights_top_track,
                      value: topTrackName,
                      valueWidth: 160,
                    ),
                    _InsightTile(
                      label: context.l10n.insights_listening_hours,
                      value: '${summary?.duration.inHours ?? 0} h',
                    ),
                    _InsightTile(
                      label: context.l10n.insights_best_day,
                      value: bestDay == null
                          ? '—'
                          : '${bestDay.day} ${_months[bestDay.month - 1]}',
                    ),
                    _InsightTile(
                      label: context.l10n.insights_current_streak,
                      value: '${insights?.currentStreakDays ?? 0}',
                    ),
                    if (trend != null) ...[
                      const Gap(4),
                      _TrendChip(
                        percent: trend,
                        label: context.l10n.insights_vs_last_week,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String label;
  final String value;
  final double valueWidth;

  const _InsightTile({
    required this.label,
    required this.value,
    this.valueWidth = 90,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: valueWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const Gap(2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.base.copyWith(
              color: theme.colorScheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final double percent;
  final String label;

  const _TrendChip({required this.percent, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = percent >= 0;
    final color = up
        ? theme.colorScheme.primary
        : theme.colorScheme.destructive;
    final rounded = percent.round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: theme.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        '${up ? '+' : ''}$rounded% $label',
        style: theme.typography.xSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}