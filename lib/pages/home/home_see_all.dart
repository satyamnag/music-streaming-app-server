import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/components/track_card/home_album_card.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// Which home section a [HomeSeeAllPage] should display.
enum HomeSeeAllKind { albums, newestArrivals, topTrending, language }

/// A full-screen "see all" page reached from the arrow on a home section
/// header. Every kind renders as a responsive GRID of the SAME shared home
/// cards as the section it expands (cover, corner radius, typography and gaps
/// included) with a search box, an initial page of [pageSize] items and a
/// "load more" button that reveals the next page — no list view. Data comes
/// from the shared [homeSectionsProvider], so the section always matches what
/// the home screen shows and no extra fetch is needed.
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

    // The shared home cards resolve the lock state and run the payment gate on
    // their own tap, so this only loads the tapped track's list — exactly like
    // the home rows. Gating here as well would present the paywall twice when
    // the purchase has not propagated to the cached subscription status yet.
    Future<void> playFrom(int index, List<SangeetTrackObject> list) async {
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
                  horizontal: trackGridPadding,
                  vertical: 4 * scale,
                ),
                sliver: SliverGrid.builder(
                  itemCount: isAlbums ? shownAlbums.length : shownTracks.length,
                  // Three cards per row with the minimum padding and gutter
                  // (see trackGridDelegate): the cards fill their tiles, so the
                  // tile width IS the card width and the tile height is the
                  // card's exact height — nothing clips, no dead band.
                  gridDelegate: trackGridDelegate(context),
                  itemBuilder: (context, index) {
                    if (isAlbums) {
                      final homeAlbum = shownAlbums[index];
                      final album = homeAlbum.album;
                      final albumTracks = homeAlbum.tracks;
                      // The shared home album card resolves the album's lock
                      // state and gates its own tap, then opens the album.
                      return HomeAlbumCard(
                        album: album,
                        imageUrl:
                            album.images.smallest(ImagePlaceholder.albumArt),
                        subtitle: '${albumTracks.length} songs',
                        onTap: () {
                          context.navigateTo(
                            AlbumRoute(id: album.id, album: album),
                          );
                        },
                        // The card's tap opens the album; the play control
                        // starts it, which is what the circle means here.
                        onPlay: () => playFrom(0, albumTracks),
                      );
                    }
                    final track = shownTracks[index];
                    return HomeTrackCard(
                      track: track,
                      imageUrl: trackCardImageUrl(track),
                      // The card's tap already plays its list from this track,
                      // so the play control does the same thing.
                      onTap: () => playFrom(index, filteredTracks),
                      onPlay: () => playFrom(index, filteredTracks),
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
