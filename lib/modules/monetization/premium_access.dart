import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/auth/clerk_auth_view.dart';
import 'package:sangeet/modules/monetization/superwall_gate.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/services/superwall_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Access helpers for paid (premium) tracks.
///
/// A track with `status == 'paid'` is locked for free users and unlocked for
/// signed-in users with an active Superwall subscription. Free users (whether
/// signed in or signed out) must sign in first, then purchase a plan, to play
/// a paid track.
class PremiumAccess {
  PremiumAccess._();

  /// Latest Superwall subscription status. Stored here so non-widget code
  /// (stream handlers, prefetchers) can check entitlement synchronously.
  static SubscriptionStatus _subscriptionStatus = SubscriptionStatus.unknown;

  /// Whether the current user is considered "premium" (signed in AND has an
  /// active subscription). If status is unknown we default to false (safe).
  ///
  /// [ref] may be a `WidgetRef` (widgets) or a `Ref` (providers/server) — both
  /// expose `read`. It is passed as [dynamic] to accept both without coupling
  /// this module to a specific Riverpod type.
  static bool isPremiumUser(dynamic ref) {
    final bool signedIn;
    try {
      signedIn = ref.read(clerkAuthProvider).valueOrNull?.signedIn == true;
    } catch (_) {
      // Provider not ready yet (e.g. read during first build): treat as not
      // signed in — safest default for gating.
      return false;
    }
    if (!signedIn) return false;
    return _subscriptionStatus.isActive;
  }

  /// Whether a track is a paid (premium) track.
  static bool isPaidTrack(SangeetTrackObject track) {
    return track is SangeetFullTrackObject && track.status == 'paid';
  }

  /// Whether a paid track is locked for the current user (i.e. it should show
  /// a lock badge and be intercepted on tap).
  static bool isTrackLocked(SangeetTrackObject track, dynamic ref) {
    return isPaidTrack(track) && !isPremiumUser(ref);
  }

  /// Whether the current user may stream a track given its `status` string
  /// (used by server-side stream handlers that only have the raw status).
  static bool canStreamStatus(String? status, dynamic ref) {
    if (status != 'paid') return true;
    return isPremiumUser(ref);
  }

  /// Keeps the cached subscription status in sync with the Superwall stream.
  /// Call once at app startup (e.g. in main()).
  static void subscribeToStatus() {
    SuperwallService.instance.subscriptionStatus.listen((status) {
      _subscriptionStatus = status;
    });
  }

  /// Gates playback of a (possibly paid) track.
  ///
  ///  - Free track: [feature] runs immediately.
  ///  - Paid track + premium user: [feature] runs immediately.
  ///  - Paid track + signed-out user: prompts sign-in first, then presents the
  ///    paywall, then runs [feature] only after a successful purchase.
  ///  - Paid track + signed-in free user: presents the paywall; [feature] runs
  ///    only after a successful purchase (Gated mode).
  ///
  /// Returns true when [feature] ran (track was unlocked), false otherwise.
  static Future<bool> gateTrackPlay({
    required BuildContext context,
    required WidgetRef ref,
    required SangeetTrackObject track,
    required Future<void> Function() feature,
  }) async {
    if (!isPaidTrack(track) || isPremiumUser(ref)) {
      await feature();
      return true;
    }

    // Paid track and the user is not premium.
    final auth = ref.read(clerkAuthProvider).valueOrNull;
    if (auth?.signedIn != true) {
      // User must sign in first in all conditions before paying.
      final signedIn = await promptSignIn(context, ref);
      if (!signedIn) return false;
    }

    // Present the paywall (Gated mode: feature runs only after purchase).
    var unlocked = false;
    await gateFeature(
      placement: SuperwallPlacements.premiumTrackPlay,
      params: {'track_id': track.id},
      feature: () async {
        unlocked = true;
        await feature();
      },
    );
    return unlocked;
  }

  /// Prompts the user to sign in (if needed) and then presents the Superwall
  /// paywall with the monthly/yearly plans. Used by the "Go for Paid Plan"
  /// banner. Returns true when the user completed a purchase (became premium).
  static Future<bool> promptForPaidPlan(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (isPremiumUser(ref)) return true;

    final auth = ref.read(clerkAuthProvider).valueOrNull;
    if (auth?.signedIn != true) {
      final signedIn = await promptSignIn(context, ref);
      if (!signedIn) return false;
    }

    var purchased = false;
    await gateFeature(
      placement: SuperwallPlacements.premiumTrackPlay,
      params: {'source': 'go_for_paid_plan'},
      feature: () async {
        purchased = true;
      },
    );
    return purchased;
  }

  /// Shows the Clerk email-OTP sign-in dialog and waits until the user is
  /// signed in (or the dialog is dismissed). Returns true if signed in.
  static Future<bool> promptSignIn(
    BuildContext context,
    WidgetRef ref,
  ) async {    // Present the sign-in dialog and wait for it to be dismissed. After the
    // flow completes the auth state is refreshed by the dialog itself.
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ClerkAuthView(),
    );
    // Re-read auth state after the dialog closed.
    final state = ref.read(clerkAuthProvider).valueOrNull;
    return state?.signedIn == true;
  }
}
