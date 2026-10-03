import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// Which home section a [HomeSeeAllPage] should display.
enum HomeSeeAllKind { albums, newestArrivals, topTrending, language }

/// A full-screen "see all" page reached from the arrow on a home section
/// header. Every kind renders as a responsive GRID of 1.25x cards (matching
/// the home covers) with a search box, an initial page of [pageSize] items
/// and a "load more" button that reveals the next page — no list view.
/// Data comes from the shared [homeSectionsProvider], so the section always
/// matches what the home screen shows and no extra fetch is needed.
@RoutePage()
class HomeSeeAllPage extends HookConsumerWidget {
  /// Items revealed per page.
  static const int pageSize = 100;

  static const name = "home_see_all";

  final HomeSeeAllKind kind;
  final String? language;

  const HomeSeeAllPage({
    super.key,
    required this.kind,
    this.language,
  });

  String _title(BuildContext context) {
    return switch (kind) {
      HomeSeeAllKind.albums => context.l10n.albums,
      HomeSeeAllKind.newestArrivals => context.l10n.newest_arrivals,
      HomeSeeAllKind.topTrending => context.l10n.top_trending,
      HomeSeeAllKind.language => '${language ?? ''} ${context.l10n.songs}',
    };
  }

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final isAlbums = kind == HomeSeeAllKind.albums;
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final sections = switch (sectionsAsync) {
      AsyncData(value: final s) => s,
      _ => null,
    };

    final query = useState('');
    final visibleCount = useState(HomeSeeAllPage.pageSize);

    final tracks = switch (kind) {
      HomeSeeAllKind.newestArrivals =>
        sections?.newestArrivals ?? const <SangeetTrackObject>[],
      HomeSeeAllKind.topTrending =>
        sections?.topTrending ?? const <SangeetTrackObject>[],
      HomeSeeAllKind.language => sections?.languages
              .where((g) => g.language == language || language == null)
              .expand((g) => g.tracks)
              .toList() ??
          const <SangeetTrackObject>[],
      HomeSeeAllKind.albums => const <SangeetTrackObject>[],
    };

    final albums = switch (kind) {
      HomeSeeAllKind.albums => sections?.albums ?? const <HomeAlbum>[],
      _ => const <HomeAlbum>[],
    };

    // Search filter (case-insensitive, applies to the full list).
    final q = query.value.trim().toLowerCase();
    final filteredAlbums = q.isEmpty
        ? albums
        : albums.where((a) => a.album.name.toLowerCase().contains(q)).toList();
    final filteredTracks = q.isEmpty
        ? tracks
        : tracks.where((t) => t.name.toLowerCase().contains(q)).toList();

    final shownAlbums = filteredAlbums.take(visibleCount.value).toList();
    final shownTracks = filteredTracks.take(visibleCount.value).toList();
    final hasMore = (isAlbums ? filteredAlbums.length : filteredTracks.length) >
        visibleCount.value;

    Future<void> playFrom(HomeSeeAllKind useKind, int index,
        List<SangeetTrackObject> list) async {
      final track = list[index];
      if (PremiumAccess.isTrackLocked(track, ref)) {
        await PremiumAccess.gateTrackPlay(
          context: context,
          ref: ref,
          track: track,
          feature: () async {
            await ref.read(audioPlayerProvider.notifier).load(
                  list,
                  initialIndex: index,
                  autoPlay: true,
                );
          },
        );
        return;
      }
      await ref.read(audioPlayerProvider.notifier).load(
            list,
            initialIndex: index,
            autoPlay: true,
          );
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            leading: const [BackButton()],
            title: Text(_title(context)),
          ),
        ],
        child: CustomScrollView(
          slivers: [
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
                    visibleCount.value = HomeSeeAllPage.pageSize;
                  },
                  features: const [
                    InputFeature.leading(Icon(SangeetIcons.search)),
                  ],
                  placeholder: Text(
                    isAlbums ? context.l10n.filter_artist : context.l10n.search,
                  ),
                ),
              ),
            ),
            if ((isAlbums ? filteredAlbums : filteredTracks).isEmpty)
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
                  horizontal: 12 * scale,
                  vertical: 4 * scale,
                ),
                sliver: SliverGrid.builder(
                  itemCount: isAlbums ? shownAlbums.length : shownTracks.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: trackGridCrossAxisCount(context),
                    mainAxisExtent: HomeSectionLayout.trackCardGridExtent(
                      context,
                      crossAxisCount: trackGridCrossAxisCount(context),
                      horizontalPadding: 12 * scale,
                      withSubtitle: !isAlbums,
                    ),
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    if (isAlbums) {
                      final album = shownAlbums[index].album;
                      final locked = PremiumAccess.isAlbumLocked(album, ref);
                      return _SeeAllAlbumCard(
                        album: album,
                        imageUrl:
                            album.images.smallest(ImagePlaceholder.albumArt),
                        locked: locked,
                        onTap: () {
                          if (locked) {
                            // Paid album: payment gate first (paywall for free
                            // users), then open the album only after access.
                            PremiumAccess.gateAlbumPlay(
                              context: context,
                              ref: ref,
                              album: album,
                              feature: () async {
                                if (context.mounted) {
                                  context.navigateTo(
                                    AlbumRoute(id: album.id, album: album),
                                  );
                                }
                              },
                            );
                            return;
                          }
                          context.navigateTo(
                            AlbumRoute(id: album.id, album: album),
                          );
                        },
                      );
                    }
                    final track = shownTracks[index];
                    return TrackCard(
                      imageUrl: trackCardImageUrl(track),
                      title: track.name,
                      subtitle: track.album.name,
                      locked: PremiumAccess.isTrackLocked(track, ref),
                      onTap: () => playFrom(kind, index, filteredTracks),
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
                          visibleCount.value += HomeSeeAllPage.pageSize;
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
            // Reserve space so the floating player footer never covers the
            // last grid row.
            SliverToBoxAdapter(
              child: SizedBox(height: context.bottomPlayerReserve),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact album card for the "see all albums" grid (1.25x art, same as the
/// home album cards). Tapping it opens the album screen.
class _SeeAllAlbumCard extends HookWidget {
  final SangeetSimpleAlbumObject album;
  final String imageUrl;
  final bool locked;
  final VoidCallback onTap;

  const _SeeAllAlbumCard({
    required this.album,
    required this.imageUrl,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * scale),
          color: theme.colorScheme.card,
        ),
        padding: EdgeInsets.all(10 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Stack(
                  children: [
                    UniversalImage(
                      path: imageUrl,
                      height: 150 * scale,
                      width: 150 * scale,
                      fit: BoxFit.cover,
                    ),
                    LockedBadge(locked: locked, borderRadius: 0),
                  ],
                ),
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.small.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
