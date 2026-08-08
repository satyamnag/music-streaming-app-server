import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Image;
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/assets.gen.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sangeet/components/playbutton_view/playbutton_view.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/playlist/playlist_create_dialog.dart';
import 'package:sangeet/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sangeet/modules/playlist/playlist_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sangeet/services/metadata/errors/exceptions.dart';

@RoutePage()
class UserPlaylistsPage extends HookConsumerWidget {
  static const name = 'user_playlists';
  const UserPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchText = useState('');

    // Owner-made playlists (developer/owner curated) and user-made playlists
    // (created on this device) are served by the local server directly.
    final ownerPlaylistsQuery = ref.watch(ownerPlaylistsProvider);
    final userPlaylistsQuery = ref.watch(userPlaylistsProvider);
    final likedSongsQuery = ref.watch(likedSongsProvider);

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
          )
        ]),
      [context.l10n, likedSongsQuery],
    );

    List<SangeetSimplePlaylistObject> filter(
        List<SangeetSimplePlaylistObject> items) {
      if (searchText.value.isEmpty) return items;
      return items
          .map((e) => (weightedRatio(e.name, searchText.value), e))
          .sorted((a, b) => b.$1.compareTo(a.$1))
          .where((e) => e.$1 > 50)
          .map((e) => e.$2)
          .toList();
    }

    final ownerPlaylists = useMemoized(
      () => filter(ownerPlaylistsQuery.asData?.value ?? []),
      [ownerPlaylistsQuery, searchText.value],
    );
    final userPlaylists = useMemoized(
      () => filter(userPlaylistsQuery.asData?.value ?? []),
      [userPlaylistsQuery, searchText.value],
    );

    final controller = useScrollController();

    if (userPlaylistsQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    final hasError =
        ownerPlaylistsQuery.hasError || userPlaylistsQuery.hasError;
    if (hasError) {
      return ErrorBox(
        error: ownerPlaylistsQuery.error ?? userPlaylistsQuery.error!,
        onRetry: () {
          ref.invalidate(ownerPlaylistsProvider);
          ref.invalidate(userPlaylistsProvider);
        },
      );
    }

    return material.RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(ownerPlaylistsProvider);
        ref.invalidate(userPlaylistsProvider);
      },
      child: SafeArea(
        bottom: false,
        child: InterScrollbar(
          controller: controller,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                floating: true,
                backgroundColor: context.theme.colorScheme.background,
                flexibleSpace: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 48,
                  child: TextField(
                    onChanged: (value) => searchText.value = value,
                    placeholder: Text(context.l10n.filter_playlists),
                    features: const [
                      InputFeature.leading(Icon(SangeetIcons.filter)),
                    ],
                  ),
                ),
              ),
              const SliverGap(10),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.l10n.liked_tracks,
                    style: context.theme.typography.h4,
                  ),
                ),
              ),
              const SliverGap(8),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverToBoxAdapter(
                  child: PlaylistCard.tile(likedTracksPlaylist),
                ),
              ),
              const SliverGap(16),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.l10n.playlists,
                    style: context.theme.typography.h4,
                  ),
                ),
              ),
              const SliverGap(8),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: PlaybuttonView(
                  leading: const Expanded(
                    child: Row(
                      children: [
                        PlaylistCreateDialogButton(),
                      ],
                    ),
                  ),
                  controller: controller,
                  hasMore: false,
                  isLoading: ownerPlaylistsQuery.isLoading ||
                      userPlaylistsQuery.isLoading,
                  onRequestMore: () {},
                  itemCount: ownerPlaylists.length + userPlaylists.length,
                  gridItemBuilder: (context, index) {
                    if (index < ownerPlaylists.length) {
                      return PlaylistCard(ownerPlaylists[index]);
                    }
                    return PlaylistCard(
                        userPlaylists[index - ownerPlaylists.length]);
                  },
                  listItemBuilder: (context, index) {
                    if (index < ownerPlaylists.length) {
                      return PlaylistCard.tile(ownerPlaylists[index]);
                    }
                    return PlaylistCard.tile(
                        userPlaylists[index - ownerPlaylists.length]);
                  },
                ),
              ),
              const SliverSafeArea(sliver: SliverGap(10)),
            ],
          ),
        ),
      ),
    );
  }
}
