import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/track_card/home_album_card.dart';
import 'package:sangeet/components/track_card/home_card_row.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/pages/search/search.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// The "Albums" row in the search "All" tab. It lists the same albums as the
/// home screen (admin-created + auto-grouped by album name, filtered by the
/// search term), rendered with the home screen's album row and album card so
/// the cover, card shape and text match the home row exactly. Tapping a card
/// opens the album's song list — exactly the same behavior as the home screen
/// albums.
class SearchPlaylistsSection extends HookConsumerWidget {
  const SearchPlaylistsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final homeSections = ref.watch(homeSectionsProvider);
    final albums = homeSections.asData?.value.albums ?? const <HomeAlbum>[];

    final theme = Theme.of(context);
    final scale = theme.scaling;
    final term = searchTerm.trim().toLowerCase();
    final items = albums
        .where((a) => term.isEmpty || a.album.name.toLowerCase().contains(term))
        .toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return HomeCardRow(
      header: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
        child: DefaultTextStyle(
          style: theme.typography.h4.copyWith(
            color: theme.colorScheme.foreground,
          ),
          child: Text(context.l10n.albums),
        ),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final album = items[index].album;
        return HomeAlbumCard(
          album: album,
          subtitle: '${items[index].tracks.length} songs',
          imageUrl: album.images.smallest(ImagePlaceholder.albumArt),
          onTap: () {
            // Open the album screen listing its songs, like the home row.
            context.navigateTo(AlbumRoute(id: album.id, album: album));
          },
        );
      },
    );
  }
}
