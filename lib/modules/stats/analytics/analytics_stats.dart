import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/formatters.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/history/listening_activity.dart';

/// The four headline numbers of the Analytics screen, in a 2 x 2 grid.
///
/// Every value is real: minutes and play counts come from the local history,
/// the streak from the days that actually had a play, and "out of N days" from
/// the selected period. Nothing is padded or invented when there is no listening
/// yet — an empty history reads as 0, which is the truth.
class AnalyticsStatGrid extends StatelessWidget {
  final ListeningActivity activity;

  /// Opens the Minutes page — the same list of tracks, counted in minutes. Null
  /// leaves the card inert.
  final VoidCallback? onListeningTimeTap;

  /// Opens the Streams page — the same list of tracks, counted in plays.
  final VoidCallback? onSongsPlayedTap;

  const AnalyticsStatGrid({
    super.key,
    required this.activity,
    this.onListeningTimeTap,
    this.onSongsPlayedTap,
  });

  /// Rose, blue, amber, green — the four accents the design uses. Kept as plain
  /// hues rather than theme colours because the four cards must stay
  /// distinguishable from each other in both light and dark mode, which theme
  /// roles (all "primary") cannot do.
  static const Color _minutes = Color(0xFFD6456B);
  static const Color _songs = Color(0xFF2F6BFF);
  static const Color _streak = Color(0xFFE08A00);
  static const Color _days = Color(0xFF12A15A);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final comparisonDays = activity.comparisonDays;

    final trendLabel = comparisonDays == null
        ? null
        : l10n.analytics_vs_previous_days(comparisonDays);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.headphones_rounded,
                    accent: _minutes,
                    value: compactNumberFormatter.format(activity.totalMinutes),
                    unit: l10n.analytics_min_unit,
                    label: l10n.analytics_listening_time,
                    trendPercent: activity.minutesTrendPercent,
                    trendLabel: trendLabel,
                    onTap: onListeningTimeTap,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.music_note_rounded,
                    accent: _songs,
                    value: compactNumberFormatter.format(activity.plays),
                    unit: l10n.summary_songs,
                    label: l10n.analytics_songs_played,
                    trendPercent: activity.playsTrendPercent,
                    trendLabel: trendLabel,
                    onTap: onSongsPlayedTap,
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    accent: _streak,
                    value: '${activity.currentStreakDays}',
                    unit: l10n.analytics_day_unit(activity.currentStreakDays),
                    label: l10n.analytics_bhakti_streak,
                    footnote: l10n.analytics_best_days(activity.bestStreakDays),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.event_available_rounded,
                    accent: _days,
                    value: '${activity.devotionalDays}',
                    unit: l10n.analytics_day_unit(activity.devotionalDays),
                    label: l10n.analytics_devotional_days,
                    footnote: l10n.analytics_listened_days_of(
                      activity.devotionalDays,
                      activity.rangeDays,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One accent card: icon, big number with its unit, the metric's name, and a
/// footer that is either a trend chip or a supporting line.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String value;
  final String unit;
  final String label;
  final double? trendPercent;
  final String? trendLabel;
  final String? footnote;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.accent,
    required this.value,
    required this.unit,
    required this.label,
    this.trendPercent,
    this.trendLabel,
    this.footnote,
    this.onTap,
  });

  /// The accent adjusted for the active brightness.
  ///
  /// A saturated hue that reads well on a light wash is too dark on a dark
  /// surface, so on dark it is lifted towards white instead of being dimmed —
  /// the card must stay legible in both themes, not just match the light mock.
  Color _readable(bool dark) =>
      dark ? (Color.lerp(accent, Colors.white, 0.32) ?? accent) : accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = _readable(dark);
    final muted = foreground.withValues(alpha: 0.78);

    final card = Card(
      fillColor: accent.withValues(alpha: dark ? 0.14 : 0.07),
      filled: true,
      borderColor: accent.withValues(alpha: dark ? 0.30 : 0.18),
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      borderRadius: theme.borderRadiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                ),
                child: Icon(icon, size: 18, color: foreground),
              ),
              const Gap(8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: value,
                            style: theme.typography.h3.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' $unit',
                            style: theme.typography.xSmall.copyWith(
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.xSmall.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(8),
          if (trendPercent != null && trendLabel != null)
            _TrendRow(
              percent: trendPercent!,
              label: trendLabel!,
            )
          else if (footnote != null)
            Text(
              footnote!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(color: muted),
            ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: card,
    );
  }
}

class _TrendRow extends StatelessWidget {
  final double percent;
  final String label;

  const _TrendRow({
    required this.percent,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = percent >= 0;
    final color = up ? const Color(0xFF12A15A) : theme.colorScheme.destructive;
    final readable = theme.brightness == Brightness.dark
        ? (Color.lerp(color, Colors.white, 0.28) ?? color)
        : color;
    // "20%" — the design's arrow-and-number chip. A jump from a zero baseline
    // has no percentage, and percentChange reports that as null, so this row is
    // only ever built with a real comparison behind it.
    final text = '${percent.abs().round()}% $label';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: readable.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 11,
            color: readable,
          ),
          const Gap(3),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: readable,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
