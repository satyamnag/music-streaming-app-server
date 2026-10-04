import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/track_card/card_colors.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/specials.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// Full-width "Specials" carousel shown above the Albums shelf on the home
/// screen. Each slide is a curated shelf (e.g. "Ganesha Special") with a
/// "Play Now" button that starts its whole queue.
///
/// Layout notes:
///  - Each slide occupies ~90% of the viewport width so the neighbouring slide
///    peeks in, signalling that the row scrolls.
///  - The list uses a [PageView] with `viewportFraction`, giving natural
///    snap-to-slide paging plus a dot indicator, rather than a free-scrolling
///    ListView that would not snap or report its page.
///  - Page dots appear only when there is more than one slide.
class HomeSpecialsCarousel extends HookConsumerWidget {
  /// Fraction of the viewport width one slide occupies (~90% as requested).
  static const double slideWidthFraction = 0.9;

  /// Slide height, sized to hold the artwork band + title + subtitle + button.
  static const double slideHeight = 190;

  const HomeSpecialsCarousel({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final specials = ref.watch(homeSpecialsProvider);
    final controller = usePageController(viewportFraction: slideWidthFraction);
    final page = useState(0);

    // Nothing to show until the catalogue resolves, or when no shelf matched.
    if (specials.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Text(
                context.l10n.specials,
                style: theme.typography.h4.copyWith(
                  color: theme.colorScheme.foreground,
                ),
              ),
            ),
            Gap(8 * scale),
            SizedBox(
              height: slideHeight * scale,
              child: PageView.builder(
                controller: controller,
                itemCount: specials.length,
                onPageChanged: (index) => page.value = index,
                itemBuilder: (context, index) {
                  final special = specials[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                    child: _SpecialSlide(
                      key: ValueKey(special.id),
                      special: special,
                      onPlay: () async {
                        await ref
                            .read(audioPlayerProvider.notifier)
                            .load(special.tracks, initialIndex: 0, autoPlay: true);
                      },
                    ),
                  );
                },
              ),
            ),
            if (specials.length > 1) ...[
              Gap(8 * scale),
              _PageDots(count: specials.length, active: page.value),
            ],
          ],
        ),
      ),
    );
  }
}

/// One carousel slide: artwork on the left, title/subtitle and the
/// "Play Now" button on the right.
class _SpecialSlide extends StatelessWidget {
  final HomeSpecial special;
  final VoidCallback onPlay;

  const _SpecialSlide({super.key, required this.special, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    // Prefer the shelf cover; otherwise use the first track's artwork.
    final cover = special.imageUrl.isNotEmpty
        ? special.imageUrl
        : special.tracks.first.album.images
            .smallest(ImagePlaceholder.albumArt);

    // The slide takes the first track's admin-configured colors, so a special
    // matches how its tracks look elsewhere in the app.
    final first = special.tracks.first;
    final configuredBg = first is SangeetFullTrackObject ? first.cardBgColor : null;
    final configuredText =
        first is SangeetFullTrackObject ? first.cardTextColor : null;
    final bg = cardBackgroundColor(configuredBg, theme.colorScheme.card);
    final titleColor = parseCardColor(configuredText) ??
        (configuredBg != null
            ? readableTextOn(bg)
            : theme.colorScheme.foreground);
    final subtitleColor = parseCardColor(configuredText) ??
        (configuredBg != null
            ? readableTextOn(bg).withValues(alpha: 0.75)
            : theme.colorScheme.mutedForeground);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14 * scale),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.12)
                : theme.colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square-ish artwork band on the left.
          SizedBox(
            width: HomeSpecialsCarousel.slideHeight * scale,
            child: UniversalImage(path: cover, fit: BoxFit.cover),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12 * scale,
                12 * scale,
                12 * scale,
                12 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        special.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      Gap(2 * scale),
                      Text(
                        special.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                      Gap(2 * scale),
                      Text(
                        context.l10n.songs_count(special.tracks.length),
                        maxLines: 1,
                        style: theme.typography.xSmall.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                  // "Play Now" starts the whole shelf as the play queue.
                  GestureDetector(
                    onTap: onPlay,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 6 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20 * scale),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SangeetIcons.play,
                            size: 14 * scale,
                            color: theme.colorScheme.primaryForeground,
                          ),
                          Gap(6 * scale),
                          Text(
                            context.l10n.play_now,
                            style: theme.typography.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primaryForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dot indicator showing which slide is active.
class _PageDots extends StatelessWidget {
  final int count;
  final int active;

  const _PageDots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: isActive ? 18 : 6,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.mutedForeground.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
