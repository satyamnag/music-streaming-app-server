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

/// Full-width "Featured Playlist" carousel shown above the Albums shelf on the
/// home screen. Each slide is a curated shelf (e.g. "Ganesha Special") rendered
/// as a banner carrying a "FEATURED PLAYLIST" eyebrow, the title, its song count
/// and a "Play Now" button that starts the whole queue — all of it set on the
/// RIGHT of the artwork.
///
/// Layout notes:
///  - Each slide occupies ~92% of the viewport width so the neighbouring slide
///    peeks in, signalling that the row scrolls (matching the reference design).
///  - The list uses a [PageView] with `viewportFraction`, giving natural
///    snap-to-slide paging plus a dot indicator, rather than a free-scrolling
///    ListView that would not snap or report its page.
///  - The page dots are painted INSIDE each slide's artwork, at its bottom
///    centre, and only when there is more than one slide. They used to sit in a
///    band beneath the carousel, which put them outside the banner they label.
///  - Nothing darkens the artwork. The banner is shown at full brightness and
///    the white copy carries its own text shadows, so an uploaded banner looks
///    exactly as the admin exported it.
class HomeSpecialsCarousel extends HookConsumerWidget {
  /// Fraction of the viewport width one slide occupies (~92%).
  static const double slideWidthFraction = 0.92;

  /// Aspect ratio of an admin-uploaded landscape banner: 8:3 (2.667:1).
  ///
  /// This is enforced on upload (WebP only, 8:3), so the slide can size itself
  /// from the artwork's own ratio and never letterbox or stretch a banner.
  static const double bannerAspectRatio = 8 / 3;

  /// Aspect ratio of a slide that has NO admin banner and falls back to its
  /// track artwork. Taller than the 8:3 banner because the copy block (eyebrow
  /// + title + count + button) needs room beside a square cover.
  static const double fallbackAspectRatio = 16 / 9;

  /// Slide height when the shelf has NO banner: sized to hold the square
  /// artwork band plus the title/subtitle/button.
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

    // One dot row, handed to each slide so the dots are painted INSIDE the
    // slide's own artwork at its bottom centre, rather than in a separate band
    // below the carousel. A single instance is shared because only one slide is
    // ever fully visible, and every dot tap drives the same controller.
    final dots = specials.length > 1
        ? _PageDots(
            count: specials.length,
            active: page.value,
            // Tapping a dot pages the carousel to that slide. The dots were
            // previously inert (a plain AnimatedContainer with no gesture),
            // so they looked like navigation but did nothing.
            onSelect: (index) {
              if (!controller.hasClients) return;
              controller.animateToPage(
                index,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
              page.value = index;
            },
          )
        : null;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * scale),
        // The row is tall enough for the tallest slide shape: a banner is 8:3
        // (short), while a shelf without a banner falls back to the square-art
        // layout (taller). Each slide centres itself in the row, so a banner is
        // never stretched to fill someone else's height.
        child: SizedBox(
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
                  dots: dots,
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
      ),
    );
  }
}

/// One carousel slide: artwork on the left, title/subtitle and the
/// "Play Now" button on the right.
class _SpecialSlide extends StatelessWidget {
  final HomeSpecial special;
  final VoidCallback onPlay;

  /// The shared page-dot row, painted inside this slide's artwork. Null when
  /// there is only one slide (nothing to page between).
  final Widget? dots;

  const _SpecialSlide({
    super.key,
    required this.special,
    required this.onPlay,
    this.dots,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer the shelf cover; otherwise use the first track's artwork.
    final cover = special.imageUrl.isNotEmpty
        ? special.imageUrl
        : special.tracks.first.album.images
            .smallest(ImagePlaceholder.albumArt);

    // A shelf with an admin landscape banner renders the banner full-bleed
    // with the text laid over it. Its height follows the banner's own 8:3
    // ratio (enforced on upload), so the image is never stretched or cropped
    // to an unrelated shape.
    if (special.hasBanner) {
      return Center(
        child: AspectRatio(
          aspectRatio: HomeSpecialsCarousel.bannerAspectRatio,
          child: _BannerSlide(
            special: special,
            cover: cover,
            onPlay: onPlay,
            dots: dots,
          ),
        ),
      );
    }

    return _SquareSlide(
      special: special,
      cover: cover,
      onPlay: onPlay,
      dots: dots,
    );
  }
}

/// A slide backed by an admin-uploaded landscape banner (8:3 WebP).
///
/// The artwork fills the slide and the copy sits on the RIGHT of it: the
/// eyebrow ("FEATURED PLAYLIST"), the playlist name, its song count and the
/// "Play Now" button, right-aligned as one block.
///
/// There is deliberately NO scrim over the artwork. A left-to-right black
/// gradient (up to 90% opacity) used to darken the copy's half of the banner,
/// which read as an ugly wash across the admin's artwork — the banner is now
/// shown at full brightness and legibility is carried by the text's own shadows,
/// which cost the image nothing. The page dots sit inside the banner at its
/// bottom centre.
class _BannerSlide extends StatelessWidget {
  final HomeSpecial special;
  final String cover;
  final VoidCallback onPlay;
  final Widget? dots;

  const _BannerSlide({
    required this.special,
    required this.cover,
    required this.onPlay,
    this.dots,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          UniversalImage(path: cover, fit: BoxFit.cover),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 10 * scale,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FeaturedEyebrow(scale: scale),
                  Gap(3 * scale),
                  Text(
                    // The shelf titles already end in "Special"; the design shows
                    // a bare playlist name, so the suffix is dropped for display.
                    _displayTitle(special.title),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.05,
                      // The shadow is what keeps white text readable now that
                      // the scrim is gone. It darkens only the glyph edges.
                      shadows: const [
                        Shadow(color: Color(0xCC000000), blurRadius: 8),
                      ],
                    ),
                  ),
                  Gap(2 * scale),
                  Text(
                    context.l10n.songs_count(special.tracks.length),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.xSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      shadows: const [
                        Shadow(color: Color(0xCC000000), blurRadius: 6),
                      ],
                    ),
                  ),
                  Gap(8 * scale),
                  _PlayNowButton(onPlay: onPlay),
                ],
              ),
            ),
          ),
          if (dots != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 2 * scale,
              child: dots!,
            ),
        ],
      ),
    );
  }
}

/// Strips a trailing " Special" from a shelf title for the banner headline.
///
/// The curated shelves are named "Ganesha Special", "Rama Special", ... which
/// is correct in the admin panel but reads as a label rather than a playlist
/// name on the banner. An admin-set title without the suffix is left untouched.
String _displayTitle(String title) {
  final trimmed = title.trim();
  const suffix = ' special';
  if (trimmed.toLowerCase().endsWith(suffix)) {
    final stripped = trimmed.substring(0, trimmed.length - suffix.length).trim();
    if (stripped.isNotEmpty) return stripped;
  }
  return trimmed;
}

/// The small uppercase "FEATURED PLAYLIST" label above a banner's title.
class _FeaturedEyebrow extends StatelessWidget {
  final double scale;

  const _FeaturedEyebrow({required this.scale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FittedBox so the label shrinks to fit a narrow slide instead of
    // truncating to "FEATURED PL…" (which is what a fixed size did on a
    // 360dp phone, where the slide is ~330dp and the copy column ~200dp).
    // Aligned right because the whole copy block sits on the banner's right.
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          context.l10n.featured_playlist.toUpperCase(),
          maxLines: 1,
          style: theme.typography.xSmall.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

/// The "Play Now" pill, shared by both slide layouts.
class _PlayNowButton extends StatelessWidget {
  final VoidCallback onPlay;

  const _PlayNowButton({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return GestureDetector(
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
    );
  }
}

/// The fallback slide for a shelf with no banner: square track art on the left,
/// title/subtitle/button on the right.
///
/// The page dots ride inside the square artwork so they stay within the card,
/// matching where they sit on a banner slide, instead of hanging in a band
/// underneath the carousel.
class _SquareSlide extends StatelessWidget {
  final HomeSpecial special;
  final String cover;
  final VoidCallback onPlay;
  final Widget? dots;

  const _SquareSlide({
    required this.special,
    required this.cover,
    required this.onPlay,
    this.dots,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

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
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square-ish artwork band on the left, with the page dots inside it.
          SizedBox(
            width: HomeSpecialsCarousel.slideHeight * scale,
            child: Stack(
              fit: StackFit.expand,
              children: [
                UniversalImage(path: cover, fit: BoxFit.cover),
                if (dots != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6 * scale,
                    child: dots!,
                  ),
              ],
            ),
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
                        context.l10n.featured_playlist.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Gap(2 * scale),
                      Text(
                        _displayTitle(special.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
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
                  _PlayNowButton(onPlay: onPlay),
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
///
/// The dots are drawn ON the slide's artwork, so they are styled for an image
/// background rather than for the page: white on any banner, with a soft shadow
/// so they survive a pale photo. A theme-coloured dot (the previous styling)
/// disappeared entirely against a bright banner.
///
/// Each dot is a real control: tapping it pages the carousel to that slide.
/// The dot itself stays visually tiny, but sits in a 44x44 (scaled) tap target so
/// it meets the minimum comfortable touch size on a phone.
class _PageDots extends StatelessWidget {
  /// Side of the square tap target around each dot, at scale == 1. 44 is the
  /// floor both Material and the app's other icon buttons use.
  static const double tapTarget = 44;

  final int count;
  final int active;
  final ValueChanged<int> onSelect;

  const _PageDots({
    required this.count,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == active;
        return Semantics(
          button: true,
          selected: isActive,
          label: 'Show slide ${index + 1} of $count',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(index),
            child: SizedBox(
              height: tapTarget * scale,
              width: tapTarget * scale,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 6,
                  width: isActive ? 18 : 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
