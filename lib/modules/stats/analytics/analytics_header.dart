import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/provider/history/top.dart';

/// The Analytics screen's header: the journey title over the admin wallpaper,
/// followed by the period selector.
///
/// The wallpaper is the SAME admin-uploaded artwork the home screen uses
/// (`app_settings.home_wallpaper_url`), so the two screens are branded
/// identically and no second image has to be uploaded. With no wallpaper
/// configured the header is simply the title on the page surface — never a
/// broken image, and never an empty band.
///
/// Legibility over the artwork comes from text SHADOWS, not from a scrim over
/// the image: the same decision `HomeWallpaper` documents, so the artwork is not
/// dimmed and the title stays readable over any uploaded photo. A gradient at
/// the very bottom fades the image into the page, which is what keeps the
/// cards below from looking pasted onto a photograph.
class AnalyticsHeader extends HookConsumerWidget {
  const AnalyticsHeader({super.key});

  /// Height of the band when an admin wallpaper is configured. Fixed rather
  /// than ratio-based because the title block has a fixed content height: a
  /// ratio would make the band taller on a tablet while the text stayed the same
  /// size, leaving a dead strip of artwork.
  static const double height = 148;

  /// Height when NO wallpaper is configured.
  ///
  /// The band exists to show artwork. With none, keeping the full 148dp would
  /// spend 148dp of the screen on empty page surface above the title, so the
  /// header collapses to a page title of a sensible size instead.
  static const double plainHeight = 92;

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final wallpaper = ref.watch(homeWallpaperProvider).asData?.value;
    final hasWallpaper = wallpaper != null && wallpaper.isNotEmpty;

    final titleColor = hasWallpaper ? Colors.white : theme.colorScheme.foreground;
    final subtitleColor = hasWallpaper
        ? Colors.white.withValues(alpha: 0.92)
        : theme.colorScheme.mutedForeground;
    final shadows = hasWallpaper
        ? const [
            Shadow(
              blurRadius: 12,
              color: Color(0xCC000000),
              offset: Offset(0, 1),
            ),
          ]
        : const <Shadow>[];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: hasWallpaper ? height : plainHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasWallpaper)
              UniversalImage(
                path: wallpaper,
                fit: BoxFit.cover,
                // No `coverPixels`: the wallpaper is an admin upload, not album
                // art, and CoverRendition.urlFor rewrites any requested size
                // into `variants/<pixels>/<name>` — folders that only exist for
                // the 512px COVER renditions.
              ),
            if (hasWallpaper)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      theme.colorScheme.background.withValues(alpha: 0.05),
                      theme.colorScheme.background,
                    ],
                    stops: const [0.25, 0.72, 1],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.analytics_journey_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.h2.copyWith(
                      fontSize: 27,
                      height: 1.1,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      shadows: shadows,
                    ),
                  ),
                  const Gap(5),
                  Text(
                    context.l10n.analytics_journey_subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.small.copyWith(
                      color: subtitleColor,
                      shadows: shadows,
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

/// The period selector: 7 Days / 30 Days / All Time.
///
/// It drives `playbackHistoryTopDurationProvider`, the SAME provider the Top
/// lists have always used, so the cards and the Top Tracks list below can only
/// ever describe one period. Adding a second "analytics range" provider would
/// have let the two halves of one screen disagree.
class AnalyticsRangeTabs extends ConsumerWidget {
  const AnalyticsRangeTabs({super.key});

  /// The ranges offered here, in reading order. `HistoryDuration` also carries
  /// 6 months / 1 year / 2 years for the Top lists' own dropdown; those stay
  /// reachable there and are deliberately not squeezed into this control.
  static const List<HistoryDuration> ranges = [
    HistoryDuration.days7,
    HistoryDuration.days30,
    HistoryDuration.allTime,
  ];

  String _label(BuildContext context, HistoryDuration range) =>
      switch (range) {
        HistoryDuration.days7 => context.l10n.analytics_range_7_days,
        HistoryDuration.days30 => context.l10n.analytics_range_30_days,
        _ => context.l10n.all_time,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(playbackHistoryTopDurationProvider);
    final notifier = ref.watch(playbackHistoryTopDurationProvider.notifier);
    // A range the control does not offer (e.g. "2 years" left over from the Top
    // lists' dropdown) selects nothing rather than mis-selecting "All Time".
    final active = ranges.contains(selected) ? selected : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.muted.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            for (final range in ranges)
              Expanded(
                child: _RangeTab(
                  label: _label(context, range),
                  selected: active == range,
                  onTap: () => notifier.update((_) => range),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.small.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? theme.colorScheme.primaryForeground
                  : theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
