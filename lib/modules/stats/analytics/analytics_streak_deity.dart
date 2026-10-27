import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/history/listening_activity.dart';

/// The current streak and the favourite deity, side by side.
///
/// Both halves are real: the streak comes from the days that actually had a
/// play, and the deity comes from the admin's own Featured Playlist chips (the
/// round shelves under the home carousel). When nothing the user listened to is
/// filed under a deity, only the streak card is shown — the card is never filled
/// with a placeholder.
class AnalyticsStreakAndDeity extends StatelessWidget {
  final ListeningActivity activity;
  final FavouriteDeity? deity;

  const AnalyticsStreakAndDeity({
    super.key,
    required this.activity,
    required this.deity,
  });

  /// Short weekday labels, indexed by `DateTime.weekday - 1`. Same plain-table
  /// approach as the chart, and as `_months` in `insights_section.dart`.
  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const Color _flame = Color(0xFFE08A00);
  static const Color _heart = Color(0xFFD6456B);
  static const Color _leaf = Color(0xFF12A15A);

  @override
  Widget build(BuildContext context) {
    final favourite = deity;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: _StreakCard(activity: activity)),
            if (favourite != null) ...[
              const Gap(10),
              Expanded(flex: 5, child: _DeityCard(deity: favourite)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final ListeningActivity activity;

  const _StreakCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.colorScheme.mutedForeground;

    return Card(
      fillColor: theme.colorScheme.card,
      filled: true,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      borderRadius: theme.borderRadiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 17,
                color: AnalyticsStreakAndDeity._flame,
              ),
              const Gap(5),
              Expanded(
                child: Text(
                  l10n.analytics_current_streak,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Gap(3),
          Text(
            l10n.analytics_current_streak_desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.xSmall.copyWith(color: muted),
          ),
          const Gap(9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${activity.currentStreakDays}',
                        style: theme.typography.h2.copyWith(
                          color: theme.colorScheme.foreground,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' ${l10n.analytics_day_unit(activity.currentStreakDays)}',
                        style: theme.typography.xSmall.copyWith(color: muted),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(6),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 13,
                      color: AnalyticsStreakAndDeity._flame,
                    ),
                    const Gap(3),
                    Flexible(
                      child: Text(
                        l10n.analytics_best_days(activity.bestStreakDays),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(11),
          Row(
            children: [
              for (final day in activity.weekDays)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DayDot(played: day.hasPlay),
                      const Gap(3),
                      Text(
                        AnalyticsStreakAndDeity
                            ._weekdayLabels[(day.day.weekday - 1) %
                                AnalyticsStreakAndDeity._weekdayLabels.length],
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.typography.xSmall.copyWith(
                          color: muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One day of the streak row: filled with a tick when that day had a play,
/// outlined when it did not. Sized by its Expanded cell so seven of them always
/// fit the card, whatever the screen width.
class _DayDot extends StatelessWidget {
  final bool played;

  const _DayDot({required this.played});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AnalyticsStreakAndDeity._leaf;
    return SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: played ? color : Colors.transparent,
          border: played
              ? null
              : Border.all(
                  color: theme.colorScheme.mutedForeground
                      .withValues(alpha: 0.45),
                ),
        ),
        child: played
            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _DeityCard extends StatelessWidget {
  final FavouriteDeity deity;

  const _DeityCard({required this.deity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.colorScheme.mutedForeground;
    final accent = AnalyticsStreakAndDeity._heart;

    return Card(
      fillColor: theme.colorScheme.card,
      filled: true,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      borderRadius: theme.borderRadiusLg,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The deity IS one of the admin's Featured Playlist shelves, so the card
        // opens the playlists analytics rather than inventing a destination.
        onTap: () => context.navigateTo(const StatsPlaylistsRoute()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 16, color: accent),
                const Gap(5),
                Expanded(
                  child: Text(
                    l10n.analytics_favourite_deity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: muted.withValues(alpha: 0.8),
                ),
              ],
            ),
            const Gap(3),
            Text(
              l10n.analytics_favourite_deity_desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(color: muted),
            ),
            const Gap(9),
            Center(
              child: SizedBox(
                width: 74,
                height: 74,
                child: ClipOval(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: _DeityArtwork(url: deity.iconUrl, accent: accent),
                  ),
                ),
              ),
            ),
            const Gap(8),
            Center(
              child: Text(
                deity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.base.copyWith(
                  color: theme.colorScheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Gap(2),
            Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${deity.sharePercent}%',
                      style: theme.typography.large.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            Center(
              child: Text(
                l10n.analytics_deity_share_caption,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(color: muted),
              ),
            ),
            const Gap(8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE08A00).withValues(alpha: 0.10),
                borderRadius: theme.borderRadiusMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.spa_rounded,
                    size: 13,
                    color: Color(0xFFE08A00),
                  ),
                  const Gap(5),
                  Expanded(
                    child: Text(
                      l10n.analytics_deity_blessing(deity.title),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.xSmall.copyWith(
                        color: theme.colorScheme.foreground,
                        fontSize: 10,
                        height: 1.25,
                      ),
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

/// The admin-uploaded deity artwork for the circle, falling back to the theme's
/// glyph so the circle is never blank (an admin row with no image, or an image
/// that fails to load, still renders something deliberate).
class _DeityArtwork extends StatelessWidget {
  final String? url;
  final Color accent;

  const _DeityArtwork({required this.url, required this.accent});

  @override
  Widget build(BuildContext context) {
    final path = url;
    if (path == null || path.isEmpty) {
      return Icon(Icons.spa_rounded, size: 30, color: accent);
    }
    return UniversalImage(
      path: path,
      fit: BoxFit.cover,
      // A 74dp circle has no use for a 1024px cover.
      coverPixels: 148,
      placeholder: null,
    );
  }
}
