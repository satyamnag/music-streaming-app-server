import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Centralized wrapper around the Superwall Flutter SDK.
///
/// All Superwall interactions go through this class so the SDK surface is
/// isolated in one place. Uses the **default** purchase path (no
/// PurchaseController): Superwall manages purchases, restoration, and
/// subscription tracking automatically.
///
/// Integration checklist:
///  - configured once at app launch with the public API key
///  - `identify()` on user sign-in, `reset()` on logout (wired to Clerk auth)
///  - `registerPlacement()` for feature gating (premium paywalls)
///  - `subscriptionStatus` stream for reacting to plan changes
///  - `setUserAttributes()` for audience targeting
class SuperwallService {
  SuperwallService._internal();

  static final SuperwallService instance = SuperwallService._internal();

  bool _isConfigured = false;

  /// Configures the Superwall SDK at app launch. Safe to call multiple times.
  void configure(String apiKey) {
    if (_isConfigured || apiKey.isEmpty) return;
    final options = SuperwallOptions();
    options.paywalls.shouldPreload = true;
    // Android: let the un-hashed appUserId flow through Google Play's
    // obfuscatedExternalAccountId (per the official guide).
    options.passIdentifiersToPlayStore = true;
    Superwall.configure(apiKey, options: options);
    _isConfigured = true;
  }

  /// Associates the current user with an external identifier (Clerk user id).
  /// Use a stable, non-guessable ID — never an email.
  Future<void> identify(String userId) => Superwall.shared.identify(userId);

  /// Clears the on-device identity and paywall assignments on logout.
  Future<void> reset() => Superwall.shared.reset();

  /// Registers a placement to gate access to a premium feature. Superwall
  /// remotely decides whether a paywall is shown; if the user has access,
  /// [feature] runs immediately.
  Future<void> registerPlacement(
    String placement, {
    Map<String, Object>? params,
    Future<void> Function()? feature,
  }) {
    return Superwall.shared.registerPlacement(
      placement,
      params: params,
      feature: feature,
    );
  }

  /// Stream of the user's subscription status (active / inactive / unknown).
  Stream<SubscriptionStatus> get subscriptionStatus =>
      Superwall.shared.subscriptionStatus;

  /// Sets custom user attributes for audience targeting / personalization.
  Future<void> setUserAttributes(Map<String, Object> attributes) =>
      Superwall.shared.setUserAttributes(attributes);

  /// Returns the entitlements the current user is entitled to.
  Future<Entitlements> getEntitlements() => Superwall.shared.getEntitlements();

  /// Returns the latest customer information, including active subscriptions
  /// and entitlements (used to show plan name, duration, start/end dates).
  Future<CustomerInfo> getCustomerInfo() =>
      Superwall.shared.getCustomerInfo();

  /// Passes an incoming deep link to Superwall so the `deepLink_open`
  /// standard placement fires with the URL's components as parameters.
  /// Campaign rules on the dashboard decide which paywall to show — no app
  /// update required when adding/changing paywall deep links.
  Future<void> handleDeepLink(Uri url) => Superwall.shared.handleDeepLink(url);
}
