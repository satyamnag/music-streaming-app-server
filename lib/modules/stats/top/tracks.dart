import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/formatters.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/stats/common/track_item.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/provider/history/top/tracks.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class TopTracks extends HookConsumerWidget {
  const TopTracks({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final historyDuration = ref.watch(playbackHistoryTopDurationProvider);
    final topTracks = ref.watch(
      historyTopTracksProvider(historyDuration),
    );
    final topTracksNotifier =
        ref.watch(historyTopTracksProvider(historyDuration).notifier);

    final tracksData = topTracks.asData?.value.items ?? [];
    final hasMore = topTracks.asData?.value.hasMore ?? false;

    return Skeletonizer.sliver(
      enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
      child: SliverMainAxisGroup(
        slivers: [
          SliverInfiniteList(
            onFetchData: () async {
              await topTracksNotifier.fetchMore();
            },
            hasError: topTracks.hasError,
            isLoading: topTracks.isLoading && !topTracks.isLoadingNextPage,
            hasReachedMax: topTracks.asData?.value.hasMore ?? true,
            itemCount: tracksData.length,
            emptyBuilder: (context) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Gap(50),
                  Undraw(
                    illustration: UndrawIllustration.happyMusic,
                    color: context.theme.colorScheme.primary,
                    height: 200 * context.theme.scaling,
                  ),
                  Text(
                    context.l10n.no_tracks_listened_yet,
                    textAlign: TextAlign.center,
                  ).muted().small(),
                ],
              ),
            ),
            itemBuilder: (context, index) {
              final track = tracksData[index];
              return StatsTrackItem(
                track: track.track,
                info: Text(
                  context.l10n
                      .count_plays(compactNumberFormatter.format(track.count)),
                ),
              );
            },
          ),
          if (hasMore)
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
    );
  }
}
