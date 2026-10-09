import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/hooks/configurators/use_check_yt_dlp_installed.dart';
import 'package:sangeet/hooks/configurators/use_superwall_deep_links.dart';
import 'package:sangeet/hooks/configurators/use_superwall_subscription_status.dart';
import 'package:sangeet/modules/root/bottom_player.dart';
import 'package:sangeet/modules/root/sidebar/sidebar.dart';
import 'package:sangeet/modules/root/spotube_navigation_bar.dart';
import 'package:sangeet/hooks/configurators/use_endless_playback.dart';
import 'package:sangeet/modules/root/use_global_subscriptions.dart';
import 'package:sangeet/provider/glance/glance.dart';

@RoutePage()
class RootAppPage extends HookConsumerWidget {
  const RootAppPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final backgroundColor = Theme.of(context).colorScheme.background;
    final brightness = Theme.of(context).brightness;

    ref.listen(glanceProvider, (_, __) {});

    useGlobalSubscriptions(ref);
    useEndlessPlayback(ref);
    useCheckYtDlpInstalled(ref);
    // Listen to the Superwall subscription status so the UI can react to
    // plan changes (premium feature access). Result is consumed by widgets
    // via the same hook; calling it here keeps the stream subscribed.
    useSuperwallSubscriptionStatus();
    // Forward incoming deep links to Superwall (paywall previews, web
    // checkout redemption).
    useSuperwallDeepLinks();

    useEffect(() {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: backgroundColor, // status bar color
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      );
      return null;
    }, [backgroundColor, brightness]);

    final scaffold = MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SafeArea(
        top: false,
        child: Scaffold(
          footers: const [
            BottomPlayer(),
            SangeetNavigationBar(),
          ],
          // The footers FLOAT over the body rather than occupying layout space,
          // which is what keeps the mini player pinned to the bottom on every
          // screen without each page having to reserve room for it.
          //
          // Overlaying is only safe because the scaffold compensates: with
          // `floatingFooter: true` shadcn adds the measured `footerHeight` to the
          // body's `MediaQuery.padding.bottom` (see `Scaffold.build`), so a
          // scroll view that respects `MediaQuery.paddingOf(context).bottom`
          // stops its last row above the player.
          floatingFooter: true,
          child: Sidebar(
            // The scaffold's own bottom padding is used AS GIVEN, with a small
            // breathing margin added on top.
            //
            // This previously read `padding.copyWith(bottom: 100 * scaling)`,
            // which DISCARDED the framework's `footerHeight` and substituted a
            // fixed guess. The real footer is the mini player's 86 plus the
            // navigation bar's 50 - roughly 136 at scale 1 - so the hard-coded
            // 100 was about 36 short, and the last row of every screen sat under
            // the mini player. The number also ignored the nav bar animating
            // away (it collapses to 0 while the player panel is open), so it was
            // wrong in the other direction too.
            //
            // Reading the inherited padding instead means the reserve always
            // equals the footers' real height, whatever they are: it follows the
            // nav bar as it animates, the player as it is added or removed, and
            // any future footer, with no constant to keep in sync.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.paddingOf(context).copyWith(
                  // The scaffold has already added `footerHeight`; this is only
                  // a little air between the last row and the player, so the
                  // content does not touch the bar.
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                ),
              ),
              child: const AutoRouter(),
            ),
          ),
        ),
      ),
    );

    return scaffold;
  }
}
