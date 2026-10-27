import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/history/listening_activity.dart';

/// The week's listening, one bar per day, with the week's total beside the
/// title.
///
/// The chart is deliberately the CURRENT WEEK (Monday to Sunday) whatever the
/// period selector says, and it says so: "Total this week". The design's chart
/// is a weekly rhythm with a weekly total, and inventing a thirty-bar variant
/// for the 30-day range would have been a second, undesigned chart. The cards
/// above still describe the selected period, and their own labels carry it.
class AnalyticsActivityChart extends StatelessWidget {
  final ListeningActivity activity;

  const AnalyticsActivityChart({super.key, required this.activity});

  /// Short weekday labels, indexed by `DateTime.weekday - 1`. A plain table
  /// rather than `intl`'s date symbols: this mirrors `_months` in
  /// `insights_section.dart`, which formats the "best day" the same way, and it
  /// cannot throw at runtime for a locale whose date symbols were not loaded.
  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// A round ceiling for the y axis, so the tallest bar sits below the top grid
  /// line instead of touching it and the axis reads in familiar numbers.
  static double axisMaxFor(int highestMinutes) {
    if (highestMinutes <= 0) return 60;
    for (final step in const [15, 30, 45, 60, 90, 120, 180, 240, 300, 480, 600]) {
      if (highestMinutes <= step) return step.toDouble();
    }
    return (highestMinutes / 600).ceil() * 600.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final days = activity.weekDays;

    var highest = 0;
    for (final day in days) {
      if (day.minutes > highest) highest = day.minutes;
    }
    final axisMax = axisMaxFor(highest);
    final ticks = <int>[
      axisMax.round(),
      (axisMax / 2).round(),
      0,
    ];
    final muted = theme.colorScheme.mutedForeground;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        fillColor: theme.colorScheme.card,
        filled: true,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
        borderRadius: theme.borderRadiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF8A17).withValues(alpha: 0.16),
                    borderRadius: theme.borderRadiusMd,
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: Color(0xFFEF8A17),
                  ),
                ),
                const Gap(9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.analytics_listening_activity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.base.copyWith(
                          color: theme.colorScheme.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        l10n.analytics_minutes_each_day,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.analytics_total_this_week,
                      maxLines: 1,
                      style: theme.typography.xSmall.copyWith(color: muted),
                    ),
                    const Gap(1),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            // The bars' own sum, so the printed total can never
                            // disagree with what the chart draws.
                            text: '${activity.weekMinutes}',
                            style: theme.typography.large.copyWith(
                              color: theme.colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: ' ${l10n.analytics_min_unit}',
                            style: theme.typography.xSmall.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ],
            ),
            const Gap(12),
            SizedBox(
              height: 158,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final tick in ticks)
                          Text(
                            '$tick',
                            maxLines: 1,
                            style: theme.typography.xSmall.copyWith(
                              color: muted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Gap(6),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              // Faint grid lines at the three labelled ticks.
                              Positioned.fill(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    for (var i = 0; i < ticks.length; i++)
                                      Container(
                                        height: 1,
                                        color: theme.colorScheme.muted
                                            .withValues(alpha: 0.45),
                                      ),
                                  ],
                                ),
                              ),
                              Positioned.fill(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final day in days)
                                      Expanded(
                                        child: _ChartBar(
                                          minutes: day.minutes,
                                          axisMax: axisMax,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(6),
                        Row(
                          children: [
                            for (final day in days)
                              Expanded(
                                child: Text(
                                  _weekdayLabels[(day.day.weekday - 1) %
                                      _weekdayLabels.length],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: theme.typography.xSmall.copyWith(
                                    color: muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day's bar: its minute count above, the bar itself grown from the axis.
class _ChartBar extends StatelessWidget {
  final int minutes;
  final double axisMax;

  const _ChartBar({required this.minutes, required this.axisMax});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$minutes',
          maxLines: 1,
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.foreground,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A bar is a fraction of the plot height. Guarded because a
              // degenerate box (zero or unbounded height) would otherwise
              // divide by zero or ask a Column for infinite space.
              if (!constraints.hasBoundedHeight || constraints.maxHeight <= 0) {
                return const SizedBox.shrink();
              }
              final available = constraints.maxHeight;
              final ratio = axisMax <= 0
                  ? 0.0
                  : (minutes / axisMax).clamp(0.0, 1.0).toDouble();
              final height = minutes <= 0
                  ? 0.0
                  : (available * ratio).clamp(3.0, available).toDouble();
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: double.infinity,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF7B733), Color(0xFFEF8A17)],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                        bottom: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
