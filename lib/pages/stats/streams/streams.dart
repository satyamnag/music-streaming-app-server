import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/formatters.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/modules/stats/common/stats_grid_sliver.dart';
import 'package:sangeet/modules/stats/common/track_grid_item.dart';
import 'package:sangeet/extensions/context.dart';

import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/provider/history/top/tracks.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class StatsStreamsPage extends HookConsumerWidget {
  static const name = "stats_streams";

  const StatsStreamsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final topTracks = ref.watch(
      historyTopTracksProvider(HistoryDuration.allTime),
    );
    final topTracksNotifier =
        ref.watch(historyTopTracksProvider(HistoryDuration.allTime).notifier);

    final tracksData = topTracks.asData?.value.items ?? [];

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            title: Text(context.l10n.streamed_songs),
          )
        ],
        child: Skeletonizer(
          enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
          // GRID view, matching the home screen and the other analytics tabs.
          // See `StatsTrackGridItem` for why the stat moved beneath the card: in
          // a grid a trailing `Expanded` stat has no width left beside a
          // full-tile card, which is the blank column this screen showed.
          //
          // The reserve is the grid's own `bottomPadding` rather than a
          // `Padding` outside the scroll view, so the last row scrolls clear of
          // the floating player instead of the viewport being shrunk.
          child: CustomScrollView(
            slivers: [
              StatsGridSliver(
                bottomPadding: context.bottomPlayerReserve,
                children: [
                  for (final track in tracksData)
                    StatsTrackGridItem(
                      key: ValueKey(track.track.id),
                      track: track.track,
                      info: Text(
                        context.l10n.count_plays(
                          compactNumberFormatter.format(track.count),
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
