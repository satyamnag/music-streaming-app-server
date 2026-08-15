import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/modules/monetization/coupon_entry.dart';
import 'package:sangeet/modules/splash/splash_gate.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';
import 'package:sangeet/utils/platform.dart';

/// Key recording that the first-install coupon prompt has been shown. Once
/// set, the auto-popup never appears again (the persistent entry in the
/// profile dialog remains available until the user applies a coupon).
const kCouponFirstRunPromptShownKey = 'couponFirstRunPromptShown';

/// Shows the affiliate coupon popup once, on the first app launch after
/// install (mobile only), as soon as the splash screen has finished.
///
/// The user may apply a code or skip — either way the prompt is not shown
/// again automatically. Skipping has zero effect on app functionality; the
/// user can always open the same popup later from the persistent entry in the
/// profile dialog.
///
/// Redemption is verified server-side through Supabase (validate + redeem
/// RPCs); applying a coupon only records attribution so the affiliate earns a
/// commission on the user's future paid subscription.
void useCouponFirstRunPrompt(WidgetRef ref) {
  final splash = ref.watch(splashGateProvider);
  final splashDone = !splash.isLoading;
  final context = useContext();

  useEffect(() {
    if (!splashDone) return null;
    if (!kIsMobile) return null;

    final alreadyShown =
        KVStoreService.sharedPreferences
                .getBool(kCouponFirstRunPromptShownKey) ??
            false;
    if (alreadyShown) return null;

    final timer = Timer(const Duration(milliseconds: 800), () {
      if (!context.mounted) return;
      CouponEntry.prompt(context, ref);
      // Record that the prompt was shown (apply or skip — it never auto-reappears).
      KVStoreService.sharedPreferences
          .setBool(kCouponFirstRunPromptShownKey, true);
    });
    return timer.cancel;
  }, [splashDone, context, ref]);
}
