import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/playbutton_view/playbutton_view.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/playlist/playlist_card.dart';
import 'package:sangeet/pages/search/search.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';

class SearchPagePlaylistsTab extends HookConsumerWidget {
  const SearchPagePlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();

    final searchTerm = ref.watch(searchTermStateProvider);
    final userPlaylistsQuery = ref.watch(userPlaylistsProvider);
    final likedSongsQuery = ref.watch(likedSongsProvider);

    // Only the liked-tracks playlist and the user's own playlists exist:
    // prebuilt/owner playlists are intentionally not shown anywhere.
    final likedTracksPlaylist = useMemoized(
      () => SangeetSimplePlaylistObject(
        id: "user-liked-tracks",
        name: context.l10n.liked_tracks,
        description: likedSongsQuery.asData?.value.length != null
            ? "${likedSongsQuery.asData!.value.length} tracks"
            : context.l10n.liked_tracks_description,
        externalUri: "",
        owner: SangeetUserObject(
          id: "local",
          name: "You",
          externalUri: "",
        ),
        images: [
          SangeetImageObject(
            url: Assets.images.likedTracks.path,
            width: 300,
            height: 300,
          ),
        ],
      ),
      [context.l10n, likedSongsQuery],
    );

    if (userPlaylistsQuery.hasError) {
      return ErrorBox(
        error: userPlaylistsQuery.error!,
        onRetry: () => ref.invalidate(userPlaylistsProvider),
      );
    }

    final term = searchTerm.trim().toLowerCase();
    final playlists = [
      likedTracksPlaylist,
      ...?userPlaylistsQuery.asData?.value,
    ]
        .where((p) => term.isEmpty || p.name.toLowerCase().contains(term))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        controller: controller,
        slivers: [
          PlaybuttonView(
            controller: controller,
            itemCount: playlists.length,
            hasMore: false,
            isLoading:
                userPlaylistsQuery.isLoading || likedSongsQuery.isLoading,
            onRequestMore: () {},
            gridItemBuilder: (context, index) => PlaylistCard(playlists[index]),
            listItemBuilder: (context, index) =>
                PlaylistCard.tile(playlists[index]),
          ),
        ],
      ),
    );
  }
}