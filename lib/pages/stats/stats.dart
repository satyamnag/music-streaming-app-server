import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/stats/insights/insights_section.dart';
import 'package:sangeet/modules/stats/summary/summary.dart';
import 'package:sangeet/modules/stats/top/top.dart';
import 'package:sangeet/utils/platform.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class StatsPage extends HookConsumerWidget {
  static const name = "stats";

  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
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
              const StatsPageInsightsSection(),
              const StatsPageSummarySection(),
              const StatsPageTopSection(),
              // Reserve the floating footer's height. The old end-of-scroll here was an
              // empty insets widget wrapping an empty box — which contributes
              // ZERO height, so the last grid row slid under the mini player.
              // `bottomPlayerReserve` is the footer's measured height plus
              // breathing room.
              SliverToBoxAdapter(
                child: SizedBox(height: context.bottomPlayerReserve),
              )
            ],
          ),
        ),
      ),
    );
  }
}
