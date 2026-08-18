import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';

/// A horizontal "Playlists" row shown on the home screen between "Recently
/// played" and "Newest arrivals". It shows the user's "Liked Songs" and any
/// playlists the user created on this device.
class HomePlaylistsSection extends HookConsumerWidget {
  const HomePlaylistsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final userPlaylistsQuery = ref.watch(userPlaylistsProvider);
    final likedSongsQuery = ref.watch(likedSongsProvider);

    final userPlaylists = userPlaylistsQuery.asData?.value ??
        const <SangeetSimplePlaylistObject>[];
    final likedTracks = likedSongsQuery.asData?.value ??
        const <SangeetTrackObject>[];
    final likedCount = likedTracks.length;

    final isLoading =
        userPlaylistsQuery.isLoading || likedSongsQuery.isLoading;

    if (!isLoading && userPlaylists.isEmpty && likedCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // The liked-songs playlist has no server image; give it the cover of the
    // most played liked song (falling back to the first liked song with art).
    final playCounts = ref.watch(globalPlayCountsProvider).asData?.value ?? {};
    final sortedLiked = [...likedTracks]..sort((a, b) {
        final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
    final coverTrack = sortedLiked.firstWhereOrNull(
      (t) => t.album.images.isNotEmpty,
    );

    final likedSongsPlaylist = SangeetSimplePlaylistObject(
      id: "user-liked-tracks",
      name: context.l10n.liked_tracks,
      description: "$likedCount tracks",
      externalUri: "",
      owner: SangeetUserObject(id: "local", name: "You", externalUri: ""),
      images: [
        if (coverTrack != null)
          SangeetImageObject(
            url: coverTrack.album.images.smallest(ImagePlaceholder.albumArt),
            width: 300,
            height: 300,
          ),
      ],
    );

    return SliverToBoxAdapter(
      child: HorizontalPlaybuttonCardView<SangeetSimplePlaylistObject>(
        title: Text(context.l10n.playlists),
        items: [
          likedSongsPlaylist,
          ...userPlaylists,
        ],
        hasNextPage: false,
        onFetchMore: () {},
        isLoadingNextPage: isLoading,
      ),
    );
  }
}
