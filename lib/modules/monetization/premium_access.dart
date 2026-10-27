import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/auth/clerk_auth_view.dart';
import 'package:sangeet/modules/monetization/superwall_gate.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/services/superwall_service.dart';
import 'package:sangeet/utils/platform.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Pure playback-gate rule: whether playback may start.
///
/// Split out of [PremiumAccess.isPlaybackAllowed] so the rule can be unit-tested
/// without a Riverpod container or a platform channel (see
/// `test/modules/monetization/playback_login_gate_test.dart`).
///
///  - Where a sign-in bridge exists, listening to ANY track — free or paid —
///    requires a signed-in user, so `signedIn == false` locks playback.
///  - Where no sign-in bridge exists, requiring one would make the app able to
///    play nothing at all, so playback is not gated on sign-in there.
bool isPlaybackUnlocked({
  required bool signInRequiredOnPlatform,
  required bool signedIn,
}) =>
    !signInRequiredOnPlatform || signedIn;

/// Access helpers for playback: the sign-in requirement that applies to every
/// track, plus the paid (premium) rules on top of it.
///
/// **Every** track requires a signed-in user before it can be listened to,
/// whether its `status` is `free` or `paid` — see [isPlaybackAllowed].
///
/// On top of that, a track with `status == 'paid'` is locked for users without
/// an active Superwall subscription and unlocked for those with one. Signing in
/// therefore comes first in every gate, and only then is the paywall considered:
/// a signed-out user cannot complete a purchase anyway, and asking them to pay
/// before they have an account would be the wrong order.
class PremiumAccess {
  PremiumAccess._();

  /// Latest Superwall subscription status. Stored here so non-widget code
  /// (stream handlers, prefetchers) can check entitlement synchronously.
  static SubscriptionStatus _subscriptionStatus = SubscriptionStatus.unknown;

  /// Whether the current user is considered "premium" (signed in AND has an
  /// active subscription). If status is unknown we default to false (safe).
  ///
  /// [ref] is accepted so the call sites of a widget and of a provider look
  /// identical, but it is deliberately NOT used — see [isSignedIn].
  static bool isPremiumUser(dynamic ref) =>
      isSignedIn(ref) && _subscriptionStatus.isActive;

  /// Whether this build requires a signed-in user before ANY track can be
  /// listened to, free or paid.
  ///
  /// Sign-in in this app is the native Clerk bridge at
  /// `android/app/src/main/kotlin/com/sangeet/app/ClerkBridge.kt`, registered by
  /// `MainActivity`, so the requirement is scoped to Android. Desktop, macOS,
  /// Linux and iOS have no sign-in bridge at all, and gating playback on a login
  /// that cannot happen would silence the app instead of gating it.
  static bool get loginRequiredForPlayback => kIsAndroid;

  /// Whether the current user is signed in.
  ///
  /// Reads [ClerkAuthSignal], the synchronous mirror `ClerkAuthNotifier` keeps,
  /// NOT the provider.
  ///
  /// Reading `clerkAuthProvider` here was the bug behind "signed in but playback
  /// refused": from a provider's `Ref` the read returns `AsyncLoading` (no
  /// value) even for a signed-in user, so this answered `false` while the same
  /// account's profile dialog showed it signed in — measured on a device, where
  /// a signed-in account was blocked from playing and the stream endpoint
  /// answered 401. The mirror is written on every resolved auth state, so it is
  /// the reliable synchronous view; it starts signed OUT, which is the safe
  /// default for a gate that must never let audio through on an unknown session.
  ///
  /// [ref] is accepted for call-site compatibility (`WidgetRef` or `Ref`) and is
  /// intentionally unused.
  static bool isSignedIn(dynamic ref) => ClerkAuthSignal.current.signedIn;

  /// Whether playback may start at all: every track — free or paid — requires a
  /// signed-in user where [loginRequiredForPlayback] is true.
  ///
  /// Used by the local stream server (the authoritative byte-level check) and by
  /// the audio player notifier (so no code path can start audio around the UI
  /// gates).
  static bool isPlaybackAllowed(dynamic ref) => isPlaybackUnlocked(
        signInRequiredOnPlatform: loginRequiredForPlayback,
        signedIn: isSignedIn(ref),
      );

  /// [isPlaybackAllowed] for callers that hold no ref at all.
  ///
  /// `TrackBytePrefetcher` is handed `ref.read` as a tear-off — its
  /// `ProviderReader` typedef — which is a plain function with no `read` method
  /// of its own, so it can pass neither a `WidgetRef` nor a `Ref`.
  static bool get isPlaybackAllowedNow => isPlaybackAllowed(null);

  /// Enforces "sign in before listening" for EVERY track, free or paid.
  ///
  /// Returns true when playback may proceed: no sign-in is required on this
  /// platform, the user is already signed in, or they just signed in. Shows the
  /// Google sign-in dialog when one is needed.
  ///
  /// [ref] may be a `WidgetRef` (widgets) or a `Ref` (providers), matching
  /// [isPremiumUser] — provider code such as `TrackOptionsActions` has a `Ref`.
  static Future<bool> requireSignInToPlay(
    BuildContext context,
    dynamic ref,
  ) async {
    if (!loginRequiredForPlayback) return true;
    if (isSignedIn(ref)) return true;
    return promptSignIn(context, ref);
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

  /// Whether an album is a paid (premium) album.
  ///
  /// Albums have no shared base type, so this accepts either album variant and
  /// reads its `status` field (default `'free'`).
  static bool isPaidAlbum(Object album) {
    final status = switch (album) {
      SangeetFullAlbumObject a => a.status,
      SangeetSimpleAlbumObject a => a.status,
      _ => 'free',
    };
    return status == 'paid';
  }

  /// Whether a paid album is locked for the current user (i.e. it should show
  /// a lock badge and be intercepted on tap).
  static bool isAlbumLocked(Object album, dynamic ref) {
    return isPaidAlbum(album) && !isPremiumUser(ref);
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

  /// Gating logic shared by tracks and albums: sign-in is required for EVERY
  /// playback (free or paid); on top of that, if the object is paid and the user
  /// is not premium, the paywall is presented and only then does [feature] run.
  /// Returns true if [feature] ran.
  static Future<bool> _gate({
    required BuildContext context,
    required WidgetRef ref,
    required bool isPaid,
    required Map<String, String> params,
    required Future<void> Function() feature,
  }) async {
    // Sign-in comes FIRST, before the paid check: playback of a FREE track now
    // needs a signed-in user too, and a signed-out user must be asked to sign in
    // rather than shown a paywall they cannot complete a purchase through.
    if (!await requireSignInToPlay(context, ref)) return false;

    if (!isPaid || isPremiumUser(ref)) {
      await feature();
      return true;
    }

    // See gateTrackPlay: ensure Superwall knows the identity before evaluating
    // the placement so returning subscribers don't hit a spurious paywall.
    final user = ref.read(clerkAuthProvider).valueOrNull;
    if (user?.signedIn == true && user?.userId != null) {
      await SuperwallService.instance.identify(user!.userId!);
    }

    var unlocked = false;
    final result = await gateFeature(
      placement: SuperwallPlacements.premiumTrackPlay,
      params: params,
      feature: () async {
        unlocked = true;
        await feature();
      },
    );

    if (result == GateResult.failed && context.mounted) {
      showPaywallError(context);
    }
    return unlocked;
  }

  /// Gates opening/playing an album.
  ///
  ///  - Free album: [feature] runs immediately.
  ///  - Paid album + premium user: [feature] runs immediately.
  ///  - Paid album + signed-out user: prompts sign-in, then paywall, then runs
  ///    [feature] only after purchase.
  ///  - Paid album + signed-in free user: paywall; [feature] only after purchase.
  static Future<bool> gateAlbumPlay({
    required BuildContext context,
    required WidgetRef ref,
    required Object album,
    required Future<void> Function() feature,
  }) {
    return _gate(
      context: context,
      ref: ref,
      isPaid: isPaidAlbum(album),
      params: {'album_id': _albumId(album)},
      feature: feature,
    );
  }

  static String _albumId(Object album) => switch (album) {
        SangeetFullAlbumObject a => a.id,
        SangeetSimpleAlbumObject a => a.id,
        _ => '',
      };

  /// Gates playback of a (possibly paid) track.
  ///
  ///  - Signed-out user: prompts sign-in first. Nothing is played until the user
  ///    is signed in — this holds for FREE tracks as well as paid ones.
  ///  - Free track + signed-in user: [feature] runs immediately.
  ///  - Paid track + premium user: [feature] runs immediately.
  ///  - Paid track + signed-in free user: presents the paywall; [feature] runs
  ///    only after a successful purchase (Gated mode).
  ///
  /// [albumLock] optionally carries the album this track was tapped from: when
  /// the album itself is paid, the track is treated as locked too (album lock
  /// cascades to its tracks, matching the padlock the row already shows).
  ///
  /// Returns true when [feature] ran (track was unlocked), false otherwise.
  static Future<bool> gateTrackPlay({
    required BuildContext context,
    required WidgetRef ref,
    required SangeetTrackObject track,
    Object? albumLock,
    required Future<void> Function() feature,
  }) async {
    final isPaid =
        isPaidTrack(track) || (albumLock != null && isPaidAlbum(albumLock));

    // Sign-in for EVERY track, free or paid (see _gate).
    if (!await requireSignInToPlay(context, ref)) return false;

    if (!isPaid || isPremiumUser(ref)) {
      await feature();
      return true;
    }

    // Paid track (or a track inside a paid album) and the user is not premium:
    // present the paywall. Make sure Superwall knows the (possibly just signed-in)
    // identity BEFORE the placement is evaluated: identify() is normally
    // fire-and-forget from the auth sync, so without this a returning subscriber
    // could hit a spurious paywall while identify() is still in flight.
    final user = ref.read(clerkAuthProvider).valueOrNull;
    if (user?.signedIn == true && user?.userId != null) {
      await SuperwallService.instance.identify(user!.userId!);
    }

    // Present the paywall (Gated mode: feature runs only after purchase).
    var unlocked = false;
    final result = await gateFeature(
      placement: SuperwallPlacements.premiumTrackPlay,
      params: {
        'track_id': track.id,
        if (albumLock != null) 'album_id': _albumId(albumLock),
      },
      feature: () async {
        unlocked = true;
        await feature();
      },
    );

    if (result == GateResult.failed && context.mounted) {
      showPaywallError(context);
    }
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

    // See gateTrackPlay: identify before evaluating the placement.
    final user = ref.read(clerkAuthProvider).valueOrNull;
    if (user?.signedIn == true && user?.userId != null) {
      await SuperwallService.instance.identify(user!.userId!);
    }

    var purchased = false;
    final result = await gateFeature(
      placement: SuperwallPlacements.premiumTrackPlay,
      params: {'source': 'upgrade_to_pro_plan'},
      feature: () async {
        purchased = true;
      },
    );

    if (result == GateResult.failed && context.mounted) {
      showPaywallError(context);
    }
    return purchased;
  }

  /// Shows a friendly message when the paywall could not be presented
  /// (e.g. Google Play Billing unavailable or the plans are not yet live).
  static void showPaywallError(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Plans are not available yet'),
        content: const Text(
          'We could not load the subscription plans. Please make sure you are '
          'signed in to your Google account and try again in a moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows the Clerk Google-only sign-in dialog and waits until the user is
  /// signed in (or the dialog is dismissed). Returns true if signed in.
  ///
  /// [ref] may be a `WidgetRef` or a `Ref` (see [isPremiumUser]): the gate is
  /// reached from provider code as well as from widgets.
  static Future<bool> promptSignIn(
    BuildContext context,
    dynamic ref,
  ) async {
    // Present the sign-in dialog and wait for it to be dismissed. After the
    // flow completes the auth state is refreshed by the dialog itself.
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ClerkAuthView(),
    );
    // Re-read auth state only AFTER the provider has refreshed. The sign-in
    // dialog invalidates the auth provider and pops; an immediate read can
    // return the STALE signed-out value (the rebuild is async) and wrongly
    // abort the gate before the paywall. Force a refresh and await it.
    try {
      ref.invalidate(clerkAuthProvider);
      await ref.read(clerkAuthProvider.future);
    } catch (_) {
      // A refresh failure must not crash the gate; fall through to a read.
    }
    final state = ref.read(clerkAuthProvider).valueOrNull;
    return state?.signedIn == true;
  }
}
