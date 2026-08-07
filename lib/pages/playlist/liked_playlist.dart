import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/track_presentation/presentation_props.dart';
import 'package:sangeet/components/track_presentation/track_presentation.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/pages/playlist/playlist.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class LikedPlaylistPage extends HookConsumerWidget {
  static const name = PlaylistPage.name;

  final SangeetSimplePlaylistObject playlist;
  const LikedPlaylistPage({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, ref) {
    final likedTracks = ref.watch(likedSongsProvider);
    final tracks =
        (likedTracks.asData?.value ?? const <SangeetTrackObject>[])
            .whereType<SangeetFullTrackObject>()
            .toList();

    return material.RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(likedSongsProvider);
      },
      child: TrackPresentation(
        options: TrackPresentationOptions(
          collection: playlist,
          image: Assets.images.likedTracks.path,
          pagination: PaginationProps(
            hasNextPage: false,
            isLoading: likedTracks.isLoading,
            onFetchMore: () async {},
            onFetchAll: () async => tracks,
            onRefresh: () async {
              ref.invalidate(likedSongsProvider);
            },
          ),
          title: playlist.name,
          description: playlist.description,
          tracks: tracks,
          error: likedTracks.error,
          routePath: '/playlist/${playlist.id}',
          isLiked: false,
          shareUrl: null,
          onHeart: null,
          owner: playlist.owner.name,
        ),
      ),
    );
  }
}
