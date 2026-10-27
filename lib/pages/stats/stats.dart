import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/stats/analytics/analytics_activity_chart.dart';
import 'package:sangeet/modules/stats/analytics/analytics_header.dart';
import 'package:sangeet/modules/stats/analytics/analytics_stats.dart';
import 'package:sangeet/modules/stats/analytics/analytics_streak_deity.dart';
import 'package:sangeet/modules/stats/analytics/analytics_top_tracks.dart';
import 'package:sangeet/provider/history/listening_activity.dart';
import 'package:sangeet/provider/history/top.dart';
import 'package:sangeet/utils/platform.dart';

/// The Analytics screen ("My Bhakti Journey").
///
/// Everything on it is derived from the app's own local playback history plus
/// the admin's Featured Playlist chips — no new table, no new endpoint, no
/// schema change. The period selector drives `playbackHistoryTopDurationProvider`
/// (the provider the Top lists already used), so the four cards, the deity card
/// and the Top Tracks list always describe the same period.
///
/// Each card that has a destination keeps one: Listening Time opens the Minutes
/// page, Songs Played and "See all" open the Streams page, and the favourite
/// deity opens the Playlists page — the same pages the old summary tiles
/// reached, so nothing that was reachable before became a dead end.
@RoutePage()
class StatsPage extends HookConsumerWidget {
  static const name = "stats";

  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final range = ref.watch(playbackHistoryTopDurationProvider);
    final activity = ref.watch(listeningActivityProvider(range)).asData?.value;
    final deity = ref.watch(favouriteDeityProvider(range)).asData?.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            if (kTitlebarVisible)
              const TitleBar(automaticallyImplyLeading: false),
          ],
          child: CustomScrollView(
            slivers: [
              if (kIsMacOS) const SliverGap(20),
              // The header and the period selector are drawn even while the
              // first history read is in flight, so the screen is never a bare
              // spinner on a cold start — only the numbers wait.
              const AnalyticsHeader(),
              const SliverToBoxAdapter(child: AnalyticsRangeTabs()),
              if (activity == null)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: AnalyticsStatGrid(
                    activity: activity,
                    onListeningTimeTap: () =>
                        context.navigateTo(const StatsMinutesRoute()),
                    onSongsPlayedTap: () =>
                        context.navigateTo(const StatsStreamsRoute()),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnalyticsActivityChart(activity: activity),
                ),
                SliverToBoxAdapter(
                  child: AnalyticsStreakAndDeity(
                    activity: activity,
                    deity: deity,
                  ),
                ),
                const SliverToBoxAdapter(child: AnalyticsTopTracks()),
              ],
              // Reserve the floating footer's height so the last card scrolls
              // clear of the mini player instead of under it.
              SliverToBoxAdapter(
                child: SizedBox(height: context.bottomPlayerReserve),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
