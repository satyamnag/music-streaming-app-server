import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/components/track_tile/track_tile.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// Which home section a [HomeSeeAllPage] should display.
enum HomeSeeAllKind { albums, newestArrivals, topTrending, language }

/// A full-screen "see all" page reached from the arrow on a home section
/// header. It shows every item of that section in one scrollable screen:
///  - [HomeSeeAllKind.albums]        -> a grid of all albums.
///  - [HomeSeeAllKind.newestArrivals]-> a list of up to [HomeSeeAllPage.limit]
///    newest tracks.
///  - [HomeSeeAllKind.topTrending]   -> a list of up to [HomeSeeAllPage.limit]
///    most-played tracks.
///  - [HomeSeeAllKind.language]      -> a list of all songs in [language].
///
/// Data comes from the shared [homeSectionsProvider], so the section always
/// matches what the home screen shows and no extra fetch is needed.
@RoutePage()
class HomeSeeAllPage extends HookConsumerWidget {
  /// Max tracks shown for "Newest Arrivals" and "Top Trending" screens.
  static const int limit = 100;

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
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final playlist = ref.watch(audioPlayerProvider);

    final sections = switch (sectionsAsync) {
      AsyncData(value: final s) => s,
      _ => null,
    };

    // Tracks shown by this page (empty for the albums grid).
    final tracks = switch (kind) {
      HomeSeeAllKind.newestArrivals =>
        sections?.newestArrivals.take(limit).toList() ??
            const <SangeetTrackObject>[],
      HomeSeeAllKind.topTrending =>
        sections?.topTrending.take(limit).toList() ??
            const <SangeetTrackObject>[],
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

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            leading: const [BackButton()],
            title: Text(_title(context)),
          ),
        ],
        child: kind == HomeSeeAllKind.albums
            ? CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(16.0 * scale),
                    sliver: SliverGrid.builder(
                      itemCount: albums.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160 * scale,
                        mainAxisExtent: 220 * scale,
                        crossAxisSpacing: 12 * scale,
                        mainAxisSpacing: 12 * scale,
                      ),
                      itemBuilder: (context, index) {
                        final album = albums[index].album;
                        final cover = album.images
                            .smallest(ImagePlaceholder.albumArt);
                        return _SeeAllAlbumCard(
                          album: album,
                          imageUrl: cover,
                          onTap: () {
                            context.navigateTo(
                              AlbumRoute(id: album.id, album: album),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              )
            : ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  return TrackTile(
                    index: index,
                    track: tracks[index],
                    playlist: playlist,
                    onTap: () async {
                      await ref.read(audioPlayerProvider.notifier).load(
                            tracks,
                            initialIndex: index,
                            autoPlay: true,
                          );
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// A compact album card used in the "see all albums" grid. Tapping it opens
/// the album screen with its full song list, matching the home album cards.
class _SeeAllAlbumCard extends HookWidget {
  final SangeetSimpleAlbumObject album;
  final String imageUrl;
  final VoidCallback onTap;

  const _SeeAllAlbumCard({
    required this.album,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return GestureDetector(
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8 * scale),
              child: UniversalImage(
                path: imageUrl,
                height: 120 * scale,
                width: 120 * scale,
                fit: BoxFit.cover,
              ),
            ),
            Gap(8 * scale),
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
