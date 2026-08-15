import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart' hide Page;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/components/track_presentation/presentation_props.dart';
import 'package:sangeet/components/track_presentation/track_presentation.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sangeet/provider/metadata_plugin/library/albums.dart';
import 'package:sangeet/provider/metadata_plugin/tracks/album.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';

@RoutePage()
class AlbumPage extends HookConsumerWidget {
  static const name = "album";

  final SangeetSimpleAlbumObject _album;
  final String id;
  const AlbumPage({
    super.key,
    @PathParam("id") required this.id,
    required SangeetSimpleAlbumObject album,
  }) : _album = album;

  @override
  Widget build(BuildContext context, ref) {
    final album = _album;

    final tracks = ref.watch(metadataPluginAlbumTracksProvider(album.id));
    final tracksNotifier =
        ref.watch(metadataPluginAlbumTracksProvider(album.id).notifier);
    final isFavoriteAlbum =
        ref.watch(metadataPluginIsSavedAlbumProvider(album.id));
    final savedAlbumsNotifier =
        ref.watch(metadataPluginSavedAlbumsProvider.notifier);

    final artistName = album.artists.asString();

    return material.RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(metadataPluginAlbumTracksProvider(album.id));
        ref.invalidate(metadataPluginIsSavedAlbumProvider(album.id));
      },
      child: TrackPresentation(
        options: TrackPresentationOptions(
          collection: album,
          image: album.images.asUrlString(
            placeholder: ImagePlaceholder.collection,
          ),
          pagination: PaginationProps(
            hasNextPage: tracks.asData?.value.hasMore ?? false,
            isLoading: tracks.isLoading || tracks.isLoadingNextPage,
            onFetchMore: tracksNotifier.fetchMore,
            onRefresh: () async {
              ref.invalidate(metadataPluginAlbumTracksProvider(album.id));
            },
            onFetchAll: () async {
              return await tracksNotifier.fetchAll();
            },
          ),
          title: album.name,
          description: artistName.isEmpty
              ? null
              : "${album.albumType.name} • $artistName",
          owner: artistName.isEmpty ? null : artistName,
          tracks: tracks.asData?.value.items ?? [],
          error: tracks.error,
          routePath: '/album/${album.id}',
          isLiked: isFavoriteAlbum.asData?.value ?? false,
          shareUrl: album.externalUri,
          onHeart: isFavoriteAlbum.asData?.value == null
              ? null
              : () async {
                  if (isFavoriteAlbum.asData!.value) {
                    await savedAlbumsNotifier.removeFavorite([album]);
                  } else {
                    await savedAlbumsNotifier.addFavorite([album]);
                  }
                  ref.invalidate(metadataPluginIsSavedAlbumProvider(album.id));
                  return isFavoriteAlbum.asData!.value;
                },
        ),
      ),
    );
  }
}
