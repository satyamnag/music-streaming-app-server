import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/formatters.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/stats/common/album_grid_item.dart';
import 'package:sangeet/modules/stats/common/stats_grid_sliver.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/provider/history/top/albums.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';

class TopAlbums extends HookConsumerWidget {
  const TopAlbums({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final historyDuration = ref.watch(playbackHistoryTopDurationProvider);
    final topAlbums = ref.watch(historyTopAlbumsProvider(historyDuration));
    final topAlbumsNotifier =
        ref.watch(historyTopAlbumsProvider(historyDuration).notifier);

    final albumsData = topAlbums.asData?.value.items ?? [];
    final hasMore = topAlbums.asData?.value.hasMore ?? false;

    return Skeletonizer.sliver(
      enabled: topAlbums.isLoading && !topAlbums.isLoadingNextPage,
      child: SliverMainAxisGroup(
        slivers: [
          // A GRID, matching Top Tracks and the home screen. The list form put
          // the play count in a `Row` beside a full-width card, which left a
          // blank column in every tile.
          if (albumsData.isEmpty && !topAlbums.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Gap(16),
                    Undraw(
                      illustration: UndrawIllustration.happyMusic,
                      color: context.theme.colorScheme.primary,
                      height: 120 * context.theme.scaling,
                    ),
                    Text(
                      context.l10n.no_tracks_listened_yet,
                      textAlign: TextAlign.center,
                    ).muted().small(),
                  ],
                ),
              ),
            )
          else
            StatsGridSliver(
              // The floating player must not hide the last row.
              bottomPadding: context.bottomPlayerReserve,
              children: [
                for (final album in albumsData)
                  StatsAlbumGridItem(
                    key: ValueKey(album.album.id),
                    album: album.album,
                    info: Text(
                      context.l10n.count_plays(
                        compactNumberFormatter.format(album.count),
                      ),
                    ),
                  ),
              ],
            ),
          if (hasMore)
            SliverToBoxAdapter(
              child: Center(
                child: Button.text(
                  onPressed: () async {
                    await topAlbumsNotifier.fetchMore();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(SangeetIcons.angleDown, size: 16),
                      const Gap(6),
                      Text(context.l10n.see_more),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
