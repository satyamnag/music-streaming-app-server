import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/hooks/configurators/use_check_yt_dlp_installed.dart';
import 'package:sangeet/hooks/configurators/use_onesignal_deep_links.dart';
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
    // Replay a OneSignal link that arrived before the navigator existed — the
    // cold-start notification tap. Listeners themselves are registered in
    // main.dart, right after the SDK initializes.
    useOneSignalDeepLinks();

    useEffect(() {
      // Icon brightness ONLY. The bar colours used to be set here too, but
      // `statusBarColor` / `systemNavigationBarColor` reach the platform through
      // Flutter's `PlatformPlugin.setSystemChromeSystemUIOverlayStyle`, i.e.
      // `Window#setStatusBarColor` / `Window#setNavigationBarColor` — both
      // deprecated for apps targeting 35+, and no-ops on Android 15 where the
      // bars are transparent and the app's background shows through them.
      // Play Console reported exactly that call path, so it is no longer made.
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      );
      return null;
      // `backgroundColor` stays in the dependency list: it is what the bars show
      // through now, so a theme change must still re-apply the icon contrast.
    }, [backgroundColor, brightness]);

    final scaffold = MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SafeArea(
        // BOTH insets are handled here now.
        //
        // `top: false` was correct while the Activity was NOT edge-to-edge: the
        // window itself started below the status bar, so a page's own SafeArea
        // was doing the work. `MainActivity` now calls
        // `WindowCompat.enableEdgeToEdge(window)` (Play's recommendation for
        // apps targeting SDK 35+), which makes the Flutter view span the whole
        // screen on EVERY Android version — so the top inset must be consumed
        // here, or the header would slide under the status bar.
        //
        // Nested SafeAreas are harmless: a SafeArea hands zero top padding to
        // its descendants, so the per-page ones (home, library, profile, …)
        // simply become no-ops and the app is inset exactly once.
        top: true,
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
