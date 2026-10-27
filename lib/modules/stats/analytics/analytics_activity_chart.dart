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

  /// Fixed height reserved under the plot for the weekday row.
  ///
  /// Fixed, and shared with the y-axis column, so the axis labels and the grid
  /// lines end at the same pixel. Letting the row size itself made the "0" tick
  /// sit one text-line below the bottom grid line (seen on a device).
  static const double weekdayRowHeight = 14;

  /// Gap between the plot and the weekday row.
  static const double _plotToLabelsGap = 6;

  /// A round ceiling for the y axis, so the tallest bar sits below the top grid
  /// line instead of touching it and the axis reads in familiar numbers.
  static double axisMaxFor(int highestMinutes) {
    if (highestMinutes <= 0) return 60;
    for (final step in const [
      15,
      30,
      45,
      60,
      90,
      120,
      180,
      240,
      300,
      480,
      600,
    ]) {
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
                  // The y axis ends where the PLOT ends, not where the card
                  // does: the weekday row's height is reserved out of it.
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Expanded(
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
                                    height: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: _plotToLabelsGap + weekdayRowHeight,
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
                        const SizedBox(height: _plotToLabelsGap),
                        SizedBox(
                          height: weekdayRowHeight,
                          child: Row(
                            children: [
                              for (final day in days)
                                Expanded(
                                  child: Text(
                                    _weekdayLabels[(day.day.weekday - 1) %
                                        _weekdayLabels.length],
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: theme.typography.xSmall.copyWith(
                                      color: muted,
                                      fontSize: 10,
                                      height: 1,
                                    ),
                                  ),
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
          ],
        ),
      ),
    );
  }
}

/// One day's bar: its minute count directly above the bar, and the bar grown
/// from the plot's baseline.
///
/// The label shares a bottom-aligned column with its bar instead of sitting
/// above an `Expanded` plot slot: an `Expanded` child claims the whole column,
/// which pinned every label to the top of the chart whatever its bar did — all
/// seven numbers sat level with the axis maximum on a device.
class _ChartBar extends StatelessWidget {
  final int minutes;
  final double axisMax;

  /// Height reserved for the value label, so a full-height bar can never push
  /// it out of the plot (label + gap + bar is exactly the plot height).
  static const double _labelHeight = 14;
  static const double _labelGap = 2;

  const _ChartBar({required this.minutes, required this.axisMax});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
        final barSpace =
            (available - _labelHeight - _labelGap).clamp(0.0, double.infinity);

        final ratio =
            axisMax <= 0 ? 0.0 : (minutes / axisMax).clamp(0.0, 1.0).toDouble();

        var barHeight = 0.0;
        if (minutes > 0 && barSpace > 0) {
          // A non-zero day always draws at least a sliver, so "listened a
          // little" never looks like "did not listen".
          final minimum = barSpace < 3 ? barSpace : 3.0;
          barHeight = (barSpace * ratio).clamp(minimum, barSpace).toDouble();
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: _labelHeight,
              child: Center(
                child: Text(
                  '$minutes',
                  maxLines: 1,
                  style: theme.typography.xSmall.copyWith(
                    color: theme.colorScheme.foreground,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _labelGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: double.infinity,
                height: barHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7B733), Color(0xFFEF8A17)],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(5),
                    bottom: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
