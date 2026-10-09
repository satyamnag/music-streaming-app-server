import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/routes.gr.dart';
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
/// This is a plain BOX widget, not a sliver: the home screen lays it inside the
/// wallpaper's stack so the carousel sits ON the artwork, and it paints no
/// background of its own so the wallpaper shows around the banner.
///
/// Layout notes:
///  - One slide fills the carousel exactly ([slideWidthFraction] is 1). It used
///    to be 0.92 so the neighbouring slide peeked in at the screen edges to
///    signal that the row scrolls — which instead meant a swipe brought artwork
///    in from OUTSIDE the carousel. The gutter is now applied OUTSIDE the pager
///    (see [slideMargin]) and the pager is clipped to the inset box, so the
///    banner slides within the carousel and nothing enters from beyond it.
///  - The list uses a [PageView], which clips its viewport and snaps to a slide,
///    rather than a free-scrolling ListView that would neither snap nor report
///    its page.
///  - The page dots are painted INSIDE each slide's artwork, at its bottom
///    centre, and only when there is more than one slide.
///  - Nothing darkens the artwork. The banner is shown at full brightness and
///    the white copy carries its own text shadows, so an uploaded banner looks
///    exactly as the admin exported it.
class HomeSpecialsCarousel extends HookConsumerWidget {
  /// Fraction of the viewport one slide occupies.
  ///
  /// A full 1.0 deliberately: at 0.92 the next and previous banners were visible
  /// at the left and right edges of the screen, which reads as the carousel
  /// leaking outside itself. At 1.0 exactly one banner occupies the carousel and
  /// [slideMargin] provides the gutter.
  static const double slideWidthFraction = 1;

  /// Horizontal margin around a slide, at scale == 1.
  ///
  /// This is what separates the banner from the carousel's edge now that a slide
  /// fills the viewport. 12 matches the gutter the design shows on a 360dp
  /// phone.
  ///
  /// Applied as padding AROUND the pager, not inside each page: padding inside a
  /// page leaves the page's own edge flush with the carousel's edge, so during a
  /// swipe the incoming banner is clipped at the carousel edge and reads as
  /// sliding in from beside the app. Padding outside insets the clip itself, so
  /// a slide can only ever be seen inside the box the resting banner occupies.
  static const double slideMargin = 12;

  /// Corner radius of a slide, and of the carousel's own clip.
  ///
  /// ONE constant for both, deliberately. Every slide rounds its corners with
  /// this radius, and the pager is clipped with the same value, so the two curves
  /// coincide and a corner reads as curved at every point of a swipe. If the clip
  /// were the plain `ClipRect` this replaced, its right angles would cut across
  /// the slide's rounded corner mid-slide, which is exactly the "the corners are
  /// right angled while sliding" defect.
  ///
  /// Keeping it shared is what stops the two drifting apart later: a clip rounder
  /// than the slide would reveal background through the slide's own square
  /// corner, and a squarer clip would bring the right angle back.
  static const double slideRadius = 14;

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
    // A zero-size box, not a sliver: this widget is laid inside the home
    // screen's wallpaper stack.
    if (specials.isEmpty) return const SizedBox.shrink();

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

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * scale),
      // The row is tall enough for the tallest slide shape: a banner is 8:3
      // (short), while a shelf without a banner falls back to the square-art
      // layout (taller). Each slide centres itself in the row, so a banner is
      // never stretched to fill someone else's height.
      child: SizedBox(
        height: slideHeight * scale,
        // ---------------------------------------------------------------------
        // The carousel CLIPS to its own bounds, and the gutter lives OUTSIDE
        // the pager rather than inside each page.
        //
        // WHY, because the previous arrangement looked correct and was not:
        // the margin used to be the padding of each PAGE, so a page filled the
        // viewport and its 12dp gutter sat INSIDE the pager's own rect. During a
        // swipe the incoming page's left edge therefore landed exactly on the
        // carousel's right edge, and what the reader saw was the next banner
        // appearing at the extreme right of the PHONE and sliding in — the page
        // was clipped at the screen edge, so it read as arriving from outside the
        // app rather than as a card moving within its own row. Measured on a
        // 360dp viewport: mid-swipe the incoming page's rect was L=502..R=838
        // against a carousel at 220..580, i.e. 258dp of it painted beyond the
        // carousel's right edge before any clip was applied.
        //
        // Moving the margin to `Padding` around the pager insets the CLIP itself,
        // so the visible area of the carousel is the visible area of a slide:
        // nothing a slide paints can appear anywhere the resting banner does not
        // already occupy. `ClipRect` then makes that guarantee structural - the
        // pager can no longer paint a single pixel outside the box it was given,
        // whatever the page transformer does.
        //
        // The gutter stays identical to before (12dp each side), and the resting
        // banner keeps exactly the size and position it had, so nothing about the
        // settled layout changes - only what is visible mid-swipe.
        // ---------------------------------------------------------------------
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: slideMargin * scale),
          // ClipRRect with the SAME radius a slide rounds its own corners with
          // ([slideRadius]), not a plain ClipRect.
          //
          // WHY: every slide draws its corners with `BorderRadius.circular(14)`.
          // A `ClipRect` cuts the carousel with RIGHT ANGLES, so while a slide is
          // moving, its rounded corner is intersected with a square edge and the
          // visible corner is square - the banner's own curves disappear exactly
          // during the slide, which is when they are most noticeable. At rest the
          // slide is fully inside the clip and its own radius shows, so the
          // defect is only visible mid-swipe. Matching the clip's radius to the
          // slide's makes the two curves coincide, so the corner reads as curved
          // at every point of the animation.
          //
          // The radius is a shared constant so the clip and the slides cannot
          // drift apart: a clip rounder than the slide would show background
          // through the slide's square corner, and a squarer clip reintroduces
          // the right angle this replaces.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(slideRadius * scale),
            child: PageView.builder(
              controller: controller,
              itemCount: specials.length,
              onPageChanged: (index) => page.value = index,
              itemBuilder: (context, index) {
                final special = specials[index];
                return _SpecialSlide(
                  key: ValueKey(special.id),
                  special: special,
                  dots: dots,
                  onPlay: () async {
                    // Start the shelf's queue FIRST, then open its screen.
                    //
                    // The order matters. Playback is started here rather than
                    // being handed to the destination, so the audio begins from
                    // the very first track of the admin's ordered list without
                    // waiting for that screen to build its own providers - the
                    // destination only has to RENDER the queue, never start it,
                    // and the two cannot disagree about what is playing.
                    //
                    // `special.tracks` is already in the admin's order: the
                    // explicit `trackIds` first, in their stored `position`
                    // sequence, followed by any keyword matches (see
                    // `_buildSpecials`). `initialIndex: 0` therefore starts at
                    // the first track, and the player walks the list to the last
                    // one one after another as the queue advances.
                    await ref
                        .read(audioPlayerProvider.notifier)
                        .load(special.tracks, initialIndex: 0, autoPlay: true);

                    // Then show the shelf's own screen, so the listener sees the
                    // tracks that just started and can pick any of them. The same
                    // destination the Featured Playlist chips open, reached only
                    // when the artist has not already been disposed mid-await.
                    if (!context.mounted) return;
                    context.navigateTo(FeaturedPlaylistRoute(id: special.id));
                  },
                );
              },
            ),
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
        borderRadius: BorderRadius.circular(HomeSpecialsCarousel.slideRadius * scale),
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
        borderRadius: BorderRadius.circular(HomeSpecialsCarousel.slideRadius * scale),
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
