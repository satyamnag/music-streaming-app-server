import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/featured_playlist_chips.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
import 'package:sangeet/modules/home/sections/specials.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// The full-screen "deity playlist" opened by tapping one Featured Playlist
/// chip under the home carousel (e.g. "Venkateswara", "Krishna", "Ganesha").
///
/// The playlist data comes from the same [featuredPlaylistsProvider] the home
/// chips render, so this screen always matches what the chips show. The tracks
/// are drawn in a responsive grid of the SAME shared [HomeTrackCard] the home
/// shelves use — cover, corner radius, typography, play control and premium
/// gating included — with a search box, an initial page of [pageSize] items
/// and a "load more" button that reveals the next page. Tapping a card starts
/// playback of the whole playlist from that track.
@RoutePage()
class FeaturedPlaylistPage extends HookConsumerWidget {
  /// Items revealed per page.
  static const int pageSize = 100;

  static const name = "featured_playlist";

  /// The chip's stable id (its primary key in `featured_playlists`).
  final String id;

  const FeaturedPlaylistPage({
    super.key,
    @PathParam("id") required this.id,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final chipsAsync = ref.watch(featuredPlaylistsProvider);
    final chips = chipsAsync.asData?.value ?? const <FeaturedPlaylist>[];

    FeaturedPlaylist? playlist;
    for (final chip in chips) {
      if (chip.id == id) {
        playlist = chip;
        break;
      }
    }

    // The carousel ("Play Now" on a banner) navigates with a `specials` id
    // (e.g. "ganesh-special"), which is a DIFFERENT id space from
    // `featured_playlists` (e.g. "ganesha"). Looking the id up in the chips
    // list alone therefore never matched, and the screen opened showing
    // "nothing found" with no tracks - exactly the reported bug.
    //
    // Resolve against the specials provider as well: the shelf the banner
    // belongs to already carries its ordered tracks, so the same screen can
    // render carousel shelves and chips with one implementation.
    final specials = ref.watch(homeSpecialsProvider);
    for (final special in specials) {
      if (special.id != id) continue;
      playlist ??= FeaturedPlaylist(
        id: special.id,
        title: special.title,
        keywords: const [],
        // When the shelf has an admin-uploaded banner, the screen shows THAT
        // banner where the chip screens show their round icon. `hasBanner`
        // distinguishes a real uploaded banner from a track cover fallback, so
        // only a genuine banner is promoted to the hero.
        bannerUrl: special.hasBanner ? special.imageUrl : null,
        tracks: special.tracks,
      );
      break;
    }

    final query = useState('');
    final visibleCount = useState(FeaturedPlaylistPage.pageSize);

    // Search filter (case-insensitive, applies to the full list).
    final q = query.value.trim().toLowerCase();
    final filtered = q.isEmpty
        ? (playlist?.tracks ?? const <SangeetTrackObject>[])
        : (playlist?.tracks ?? const <SangeetTrackObject>[])
            .where((t) => t.name.toLowerCase().contains(q))
            .toList();
    final shown = filtered.take(visibleCount.value).toList();
    final hasMore = filtered.length > visibleCount.value;

    // The shared home cards resolve the lock state and run the payment gate on
    // their own tap, so this only loads the tapped track's list — exactly like
    // the home rows and the home "see all" page.
    Future<void> playFrom(int index, List<SangeetTrackObject> list) async {
      await ref.read(audioPlayerProvider.notifier).load(
            list,
            initialIndex: index,
            autoPlay: true,
          );
    }

    final Widget body;
    if (playlist == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.l10n.nothing_found),
        ),
      );
    } else {
      body = CustomScrollView(
        slivers: [
          // Full-bleed banner hero, matching the reference screens: the admin's
          // banner artwork (or a placeholder drawn from the shelf's own
          // gradient) runs edge to edge and under the status bar, with the back
          // arrow, title and a decorative song-count divider laid over it.
          SliverToBoxAdapter(
            child: _BannerHero(
              playlist: playlist,
              countLabel: context.l10n.songs_count(playlist.tracks.length),
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16 * scale,
                8 * scale,
                16 * scale,
                8 * scale,
              ),
              child: TextField(
                onChanged: (value) {
                  query.value = value;
                  visibleCount.value = FeaturedPlaylistPage.pageSize;
                },
                features: const [
                  InputFeature.leading(Icon(SangeetIcons.search)),
                ],
                placeholder: Text(context.l10n.search),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(context.l10n.nothing_found),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: trackGridPadding,
                vertical: 4 * scale,
              ),
              sliver: SliverGrid.builder(
                itemCount: shown.length,
                // The shared home-grid delegate: the cards fill their tiles, so
                // the tile width IS the card width and the tile height is the
                // card's exact height — nothing clips, no dead band.
                gridDelegate: trackGridDelegate(context),
                itemBuilder: (context, index) {
                  final track = shown[index];
                  return HomeTrackCard(
                    track: track,
                    imageUrl: trackCardImageUrl(track),
                    // The card's tap already plays its list from this track,
                    // so the play control does the same thing.
                    onTap: () => playFrom(index, filtered),
                    onPlay: () => playFrom(index, filtered),
                  );
                },
              ),
            ),
            if (hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Button.text(
                      onPressed: () {
                        visibleCount.value += FeaturedPlaylistPage.pageSize;
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(SangeetIcons.angleDown, size: 16),
                          const Gap(6),
                          Text(context.l10n.load_more),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
          // Reserve space so the floating player footer never covers the last
          // grid row.
          SliverToBoxAdapter(
            child: SizedBox(height: context.bottomPlayerReserve),
          ),
        ],
      );
    }

    // No TitleBar and no top SafeArea: the banner hero is deliberately
    // full-bleed to the very top of the screen, so it runs under the status bar
    // as it does in the reference design. The back arrow is drawn inside the
    // hero, offset by the status-bar inset.
    return Scaffold(
      child: chipsAsync.isLoading && playlist == null
          ? const Center(child: CircularProgressIndicator())
          : body,
    );
  }
}

/// The full-bleed banner hero shared by BOTH entry points of this page: a
/// `specials` shelf opened from the home carousel and a featured-playlist chip
/// (the deity screens) opened from the chip row.
///
/// It always paints a banner:
///   * the admin-uploaded banner when there is one, and
///   * a PLACEHOLDER drawn from the shelf's own gradient and glyph when there
///     is not — never a blank band, which is the requirement for a deity screen
///     whose banner the admin has not set yet.
/// The back arrow, title and song count are overlaid on the artwork.
class _BannerHero extends StatelessWidget {
  const _BannerHero({
    required this.playlist,
    required this.countLabel,
    required this.onBack,
  });

  final FeaturedPlaylist playlist;
  final String countLabel;
  final VoidCallback onBack;

  /// Title colour from the reference: warm cream over the artwork.
  static const Color _titleColor = Color(0xFFF6E7C8);
  static const Color _ornamentColor = Color(0xFFE0A000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final width = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;
    final banner = playlist.bannerUrl?.trim() ?? '';
    final hasIcon = (playlist.iconUrl?.trim() ?? '').isNotEmpty;

    return SizedBox(
      width: width,
      // 2:1 — the proportion of the reference banners. Taller than the 8:3
      // carousel artwork, so `cover` crops its sides rather than letterboxing.
      height: width / 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (banner.isNotEmpty)
            Image(
              image: CachedNetworkImageProvider(banner, cacheKey: banner),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(theme),
            )
          else
            _placeholder(theme),

          // Scrim: the overlaid text sits on artwork of unknown brightness, so
          // the top (arrow) and bottom (title) edges are gently darkened.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .30),
                  Colors.transparent,
                  Colors.black.withValues(alpha: .62),
                ],
                stops: const [0, .45, 1],
              ),
            ),
          ),

          Positioned(
            top: topInset + 2 * scale,
            left: 2 * scale,
            child: IconButton.ghost(
              icon: const Icon(
                Icons.arrow_back,
                size: 22,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
              ),
              onPressed: onBack,
            ),
          ),

          Positioned(
            right: 16 * scale,
            bottom: 14 * scale,
            left: 16 * scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The deity screens carry an uploaded square icon, and the
                // reference shows it as a ringed circle above the title. A
                // specials banner has no icon, so it shows the title alone.
                if (hasIcon) ...[
                  _HeroBadge(playlist: playlist, size: 56 * scale),
                  Gap(8 * scale),
                ],
                Text(
                  playlist.title,
                  maxLines: 2,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.h2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                    shadows: const [
                      Shadow(color: Color(0xCC000000), blurRadius: 8),
                    ],
                  ),
                ),
                Gap(6 * scale),
                _SongCountDivider(
                  label: countLabel,
                  color: _ornamentColor,
                  textStyle: theme.typography.small.copyWith(
                    color: _titleColor,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The no-banner fallback: the shelf's own gradient with a faint glyph
  /// watermark, so the hero is always a banner and never an empty box.
  Widget _placeholder(ThemeData theme) {
    final from = playlist.colorFromOr(theme.colorScheme.primary);
    final to = playlist.colorToOr(theme.colorScheme.primary);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: .18,
          child: CustomPaint(
            size: const Size(110, 110),
            painter: FeaturedChipGlyphPainter(
              name: playlist.icon ?? '',
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The ringed circular icon over the banner title (the deity screens).
///
/// Reuses [_HeroCircle] — the same gradient/glyph/contrast logic the chip and
/// the old hero used — scaled down, so there is one implementation of "what a
/// shelf's icon looks like".
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.playlist, required this.size});

  final FeaturedPlaylist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    const designSize = 88.0;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        // A gold ring, as in the reference badge.
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE0A000), width: 2),
        ),
        child: Center(
          child: ClipOval(
            child: Transform.scale(
              scale: size / designSize,
              child: SizedBox(
                width: designSize,
                height: designSize,
                child: _HeroCircle(playlist: playlist),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "— ◆  12 songs  ◆ —" : the decorative divider under the banner title.
class _SongCountDivider extends StatelessWidget {
  const _SongCountDivider({
    required this.label,
    required this.color,
    required this.textStyle,
  });

  final String label;
  final Color color;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    Widget rule() => Container(
          width: 26,
          height: 1,
          color: color.withValues(alpha: .85),
        );
    Widget diamond() => Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 5, height: 5, color: color),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        rule(),
        const Gap(6),
        diamond(),
        const Gap(8),
        Text(label, style: textStyle),
        const Gap(8),
        diamond(),
        const Gap(6),
        rule(),
      ],
    );
  }
}

class _HeroCircle extends StatelessWidget {
  final FeaturedPlaylist playlist;

  const _HeroCircle({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final from = playlist.colorFromOr(theme.colorScheme.primary);
    final to = playlist.colorToOr(theme.colorScheme.primary);
    final glyphColor = _contrastRatio(from, Colors.white) >= 2.2
        ? Colors.white
        : const Color(0xDD000000);

    return Container(
      height: 88 * scale,
      width: 88 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
        boxShadow: [
          BoxShadow(
            color: to.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: _artwork(glyphColor)),
    );
  }

  Widget _artwork(Color glyphColor) {
    final url = playlist.iconUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return ClipOval(
        child: Image(
          image: CachedNetworkImageProvider(url, cacheKey: url),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _glyph(glyphColor),
        ),
      );
    }
    return _glyph(glyphColor);
  }

  Widget _glyph(Color glyphColor) => CustomPaint(
        size: const Size(42, 42),
        painter: FeaturedChipGlyphPainter(
          name: playlist.icon ?? '',
          color: glyphColor,
        ),
      );
}

/// WCAG relative luminance of [c].
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colors (1..21).
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
