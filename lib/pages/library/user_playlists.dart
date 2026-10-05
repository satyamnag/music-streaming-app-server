import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Image;
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/assets.gen.dart';

import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sangeet/components/playbutton_view/playbutton_view.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/string.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/playlist/playlist_create_dialog.dart';
import 'package:sangeet/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sangeet/services/metadata/errors/exceptions.dart';

/// Skeleton card for the library's loading state: the same shared home card the
/// library renders once loaded, so the placeholder matches the loaded grid.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return TrackCard(
      imageUrl: '',
      title: 'Loading',
      subtitle: 'Loading',
      onTap: () {},
    );
  }
}

@RoutePage()
class UserPlaylistsPage extends HookConsumerWidget {
  static const name = 'user_playlists';
  const UserPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchText = useState('');

    // User-made playlists (created on this device) and the liked-tracks
    // playlist are served by the local server directly. Only these two groups
    // are shown: owner/developer playlists are intentionally not listed.
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

    final userPlaylists = useMemoized(
      () => filter(userPlaylistsQuery.asData?.value ?? []),
      [userPlaylistsQuery, searchText.value],
    );

    // The library's collection cards are the same shared home card the home
    // screen's album and track rows render, so the cover, card shape and text
    // match those rows exactly.
    //
    // No `onPlay`: a playlist's tracks are only fetched when its page is
    // opened (metadataPluginPlaylistTracksProvider), so this screen has no
    // playable list in hand and nothing to hand the card's play control. All
    // the cards here stay consistent that way instead of only some of them
    // growing a play button.
    Widget playlistCard(SangeetSimplePlaylistObject playlist) {
      return TrackCard(
        width: HomeSectionLayout.cardWidth * context.theme.scaling,
        imageUrl: playlist.images.from200PxTo300PxOrSmallestImage(
          ImagePlaceholder.collection,
        ),
        title: playlist.name,
        subtitle: playlist.description.unescapeHtml().cleanHtml(),
        onTap: () {
          context.navigateTo(
            PlaylistRoute(id: playlist.id, playlist: playlist),
          );
        },
      );
    }

    final controller = useScrollController();

    if (userPlaylistsQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    final hasError = userPlaylistsQuery.hasError;
    if (hasError) {
      return ErrorBox(
        error: userPlaylistsQuery.error!,
        onRetry: () {
          ref.invalidate(userPlaylistsProvider);
        },
      );
    }

    return material.RefreshIndicator.adaptive(
      onRefresh: () async {
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
                  // The card is the home screen's card, so the row keeps the
                  // cover's size instead of stretching it to the page width.
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: playlistCard(likedTracksPlaylist),
                  ),
                ),
              ),
              const SliverGap(16),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Your Playlists',
                    style: context.theme.typography.h4,
                  ),
                ),
              ),
              const SliverGap(8),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: trackGridPadding),
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
                  isLoading: userPlaylistsQuery.isLoading,
                  onRequestMore: () {},
                  itemCount: userPlaylists.length,
                  // Three cards per row with the shared padding and gutter
                  // (see trackGridDelegate), and the same padding above, so the
                  // cards fill their tiles and the tile height is the card's
                  // exact height — nothing clips, no dead band.
                  gridDelegate: trackGridDelegate(context),
                  gridPlaceholder: const _LoadingCard(),
                  listPlaceholder: const Align(
                    alignment: Alignment.centerLeft,
                    child: _LoadingCard(),
                  ),
                  gridItemBuilder: (context, index) =>
                      playlistCard(userPlaylists[index]),
                  listItemBuilder: (context, index) => Align(
                    alignment: Alignment.centerLeft,
                    child: playlistCard(userPlaylists[index]),
                  ),
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
