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
class StatsMinutesPage extends HookConsumerWidget {
  static const name = "stats_minutes";

  const StatsMinutesPage({super.key});

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
            title: Text(context.l10n.minutes_listened),
          )
        ],
        child: Skeletonizer(
          enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
          // A GRID, matching the home screen and the other analytics tabs.
          //
          // The list form laid the card and its minutes in a `Row`, so the card
          // took the full tile width and the minutes were squeezed into what was
          // left - the blank space this screen showed. `StatsTrackGridItem` puts
          // the stat under the card, and `StatsGridSliver` uses the home screen's
          // own grid delegate so the columns, gutters and card extent agree with
          // every other card surface.
          //
          // The reserve moved from a `Padding` around the list to the grid's own
          // `bottomPadding`, because a `Padding` outside a `CustomScrollView`
          // shrinks the viewport instead of scrolling the last row clear of the
          // player - the grid needs the space INSIDE its scroll extent.
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
                        context.l10n.count_mins(
                          compactNumberFormatter.format(
                            track.count *
                                Duration(
                                  milliseconds: track.track.durationMs,
                                ).inMinutes,
                          ),
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
