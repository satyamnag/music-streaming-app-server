import 'package:sangeet/services/superwall_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Placement names used for feature gating in the app.
///
/// These must be configured as placements/campaigns in the Superwall Dashboard
/// to control which features are paywalled and when a paywall is shown.
abstract class SuperwallPlacements {
  /// Gates full playback of the music catalog. In the dashboard, this placement
  /// can be configured to present a paywall for free users and allow access for
  /// subscribers (gated mode).
  static const String premiumPlayback = 'premium_playback';

  /// Gates playback of an individual paid (premium) track. Configure this
  /// placement in the Superwall Dashboard (Gated) to present the paywall with
  /// the monthly (₹120) and yearly (₹1,200) plans to free users.
  static const String premiumTrackPlay = 'paid_track_play';
}

/// Result of a gated feature attempt.
enum GateResult {
  /// The feature ran (user is subscribed, or the paywall was successfully
  /// presented and completed).
  success,

  /// The user declined / dismissed the paywall without purchasing.
  declined,

  /// The paywall could not be presented (e.g. billing unavailable, products
  /// not configured, no campaign). The user should be shown a message instead
  /// of an endless spinner.
  failed,
}

/// Gates a premium feature behind a Superwall placement.
///
/// Superwall remotely decides whether a paywall is shown. If the user is
/// entitled (e.g. active subscription), [feature] runs immediately. If a
/// paywall is required, it is presented first and [feature] runs only after a
/// successful purchase (gated mode) — or not at all if the user declines.
///
/// If the paywall cannot be presented (billing unavailable, missing products,
/// campaign not configured), the SDK reports an error and this returns
/// [GateResult.failed] so callers can show a clear message instead of letting
/// a loading spinner run forever.
Future<GateResult> gateFeature({
  required String placement,
  Map<String, Object>? params,
  required Future<void> Function() feature,
}) async {
  var error = false;
  var featureRan = false;
  final handler = PaywallPresentationHandler()
    ..onError((_) {
      error = true;
    });

  await SuperwallService.instance.registerPlacement(
    placement,
    params: params,
    handler: handler,
    feature: () async {
      featureRan = true;
      await feature();
    },
  );

  if (featureRan) return GateResult.success;
  if (error) return GateResult.failed;
  return GateResult.declined;
}
