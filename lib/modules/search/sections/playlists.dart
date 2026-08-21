import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/pages/search/search.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// The "Playlists" row in the search "All" tab. It lists the same albums as
/// the home screen (admin-created + auto-grouped by album name, filtered by
/// the search term). Tapping a card opens the album's song list — exactly the
/// same behavior as the home screen albums.
class SearchPlaylistsSection extends HookConsumerWidget {
  const SearchPlaylistsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final homeSections = ref.watch(homeSectionsProvider);
    final albums = homeSections.asData?.value.albums ?? const <HomeAlbum>[];

    final term = searchTerm.trim().toLowerCase();
    final items = albums
        .where((a) => term.isEmpty || a.album.name.toLowerCase().contains(term))
        .map((a) => a.album)
        .toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return HorizontalPlaybuttonCardView<SangeetSimpleAlbumObject>(
      isLoadingNextPage: false,
      hasNextPage: false,
      items: items,
      onFetchMore: () {},
      title: Text(context.l10n.albums),
    );
  }
}