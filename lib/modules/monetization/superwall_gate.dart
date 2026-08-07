import 'package:sangeet/services/superwall_service.dart';

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
  /// the monthly (₹99) and yearly (₹999) plans to free users.
  static const String premiumTrackPlay = 'paid_track_play';
}

/// Gates a premium feature behind a Superwall placement.
///
/// Superwall remotely decides whether a paywall is shown. If the user is
/// entitled (e.g. active subscription), [feature] runs immediately. If a
/// paywall is required, it is presented first and [feature] runs only after a
/// successful purchase (gated mode) — or not at all if the user declines.
Future<void> gateFeature({
  required String placement,
  Map<String, Object>? params,
  required Future<void> Function() feature,
}) {
  return SuperwallService.instance.registerPlacement(
    placement,
    params: params,
    feature: feature,
  );
}
