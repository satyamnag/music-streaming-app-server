import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/featured_playlist_chips.dart';
import 'package:sangeet/modules/home/sections/featured_playlists.dart';
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
          // The deity's chip, blown up as the screen's hero: the same gradient
          // circle, uploaded icon (or fallback glyph) and name the chip shows,
          // so the screen unmistakably belongs to the chip that opened it.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16 * scale,
                16 * scale,
                16 * scale,
                8 * scale,
              ),
              child: Column(
                children: [
                  _HeroCircle(playlist: playlist),
                  const Gap(12),
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.typography.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    context.l10n.songs_count(playlist.tracks.length),
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
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

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            leading: const [BackButton()],
            title: Text(playlist?.title ?? id),
          ),
        ],
        child: chipsAsync.isLoading && playlist == null
            ? const Center(child: CircularProgressIndicator())
            : body,
      ),
    );
  }
}

/// The chip's circle at hero size: the admin gradient, the uploaded icon image
/// (or the fallback glyph) and the same white-vs-dark glyph rule the chips use.
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
