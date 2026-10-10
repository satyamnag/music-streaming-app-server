import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/formatters.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/modules/stats/common/artist_grid_item.dart';
import 'package:sangeet/modules/stats/common/stats_grid_sliver.dart';
import 'package:sangeet/extensions/context.dart';

import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/provider/history/top/tracks.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class StatsArtistsPage extends HookConsumerWidget {
  static const name = "stats_artists";
  const StatsArtistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final topTracks = ref.watch(
      historyTopTracksProvider(HistoryDuration.allTime),
    );
    final topTracksNotifier =
        ref.watch(historyTopTracksProvider(HistoryDuration.allTime).notifier);

    final artistsData = useMemoized(
      () => topTracksNotifier.artists,
      [topTracks.asData?.value],
    );

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            title: Text(context.l10n.artists),
          )
        ],
        child: Skeletonizer(
          enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
          // GRID view, matching the other analytics tabs and the home screen.
          // See `StatsArtistGridItem` for why the `ButtonTile` row shape was
          // replaced: a small fixed avatar plus a trailing stat leaves most of a
          // grid tile empty.
          //
          // The reserve is the grid's own `bottomPadding`, so the last row
          // scrolls clear of the floating player rather than the viewport being
          // shrunk by an outer `Padding`.
          child: CustomScrollView(
            slivers: [
              StatsGridSliver(
                bottomPadding: context.bottomPlayerReserve,
                children: [
                  for (final artist in artistsData)
                    StatsArtistGridItem(
                      key: ValueKey(artist.artist.id),
                      artist: artist.artist,
                      info: Text(
                        context.l10n.count_plays(
                          compactNumberFormatter.format(artist.count),
                        ),
                      ),
                    ),
                ],
              ),
              if (topTracks.asData?.value.hasMore ?? false)
                SliverToBoxAdapter(
                  child: Center(
                    child: Button.text(
                      onPressed: () async {
                        await topTracksNotifier.fetchMore();
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
        ),
      ),
    );
  }
}
