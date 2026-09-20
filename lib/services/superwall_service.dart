import 'dart:async';

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
///
/// ## Unconfigured behaviour
///
/// The API key is optional (it comes from the build environment). When it is
/// absent, `configure()` does nothing and the native SDK is never initialised.
/// Calling into Superwall in that state throws a native
/// `IllegalStateException: Superwall has not been initialized or configured.`
/// on a background isolate - which is fatal and kills the app.
///
/// So **every** method below checks [isConfigured] first and degrades safely:
/// reads return empty/false values and streams emit nothing. Losing monetisation
/// until the key is supplied is far better than crashing on launch.
class SuperwallService {
  SuperwallService._internal();

  static final SuperwallService instance = SuperwallService._internal();

  bool _isConfigured = false;

  /// Whether the SDK has been initialised with a non-empty API key.
  ///
  /// Callers may use this to skip Superwall-dependent UI entirely.
  bool get isConfigured => _isConfigured;

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
  /// Use a stable, non-guessable ID - never an email.
  Future<void> identify(String userId) async {
    if (!_isConfigured) return;
    await Superwall.shared.identify(userId);
  }

  /// Clears the on-device identity and paywall assignments on logout.
  Future<void> reset() async {
    if (!_isConfigured) return;
    await Superwall.shared.reset();
  }

  /// Registers a placement to gate access to a premium feature. Superwall
  /// remotely decides whether a paywall is shown; if the user has access,
  /// [feature] runs immediately.
  ///
  /// When unconfigured there is no paywall to show, so the feature is allowed
  /// through immediately: the app must stay usable without monetisation.
  Future<void> registerPlacement(
    String placement, {
    Map<String, Object>? params,
    PaywallPresentationHandler? handler,
    Future<void> Function()? feature,
  }) async {
    if (!_isConfigured) {
      if (feature != null) await feature();
      return;
    }
    await Superwall.shared.registerPlacement(
      placement,
      params: params,
      handler: handler,
      feature: feature,
    );
  }

  /// Stream of the user's subscription status (active / inactive / unknown).
  ///
  /// Emits nothing while unconfigured rather than throwing, so listeners that
  /// attach before [configure] runs cannot bring the app down.
  Stream<SubscriptionStatus> get subscriptionStatus {
    if (!_isConfigured) return const Stream<SubscriptionStatus>.empty();
    return Superwall.shared.subscriptionStatus;
  }

  /// Stream that emits whenever the customer info changes (e.g. right after a
  /// purchase/restore completes), so UI showing plan details can refresh
  /// immediately instead of relying on stale cached data.
  Stream<CustomerInfo> get customerInfoStream {
    if (!_isConfigured) return const Stream<CustomerInfo>.empty();
    return Superwall.shared.customerInfoStream;
  }

  /// Sets custom user attributes for audience targeting / personalization.
  Future<void> setUserAttributes(Map<String, Object> attributes) async {
    if (!_isConfigured) return;
    await Superwall.shared.setUserAttributes(attributes);
  }

  /// Returns the entitlements the current user is entitled to.
  ///
  /// A non-subscriber is represented by empty entitlement sets, matching what
  /// the SDK reports for a user with no purchases.
  Future<Entitlements> getEntitlements() async {
    if (!_isConfigured) {
      return Entitlements(
        active: const {},
        inactive: const {},
        all: const {},
        web: const {},
      );
    }
    return Superwall.shared.getEntitlements();
  }

  /// Returns the latest customer information, including active subscriptions
  /// and entitlements (used to show plan name, duration, start/end dates).
  ///
  /// An empty [CustomerInfo] is returned while unconfigured; callers already
  /// treat "no subscription" as the default state.
  Future<CustomerInfo> getCustomerInfo() async {
    if (!_isConfigured) {
      return CustomerInfo(
        subscriptions: const [],
        nonSubscriptions: const [],
        entitlements: const [],
        userId: '',
      );
    }
    return Superwall.shared.getCustomerInfo();
  }

  /// Passes an incoming deep link to Superwall so the `deepLink_open`
  /// standard placement fires with the URL's components as parameters.
  /// Campaign rules on the dashboard decide which paywall to show - no app
  /// update required when adding/changing paywall deep links.
  Future<void> handleDeepLink(Uri url) async {
    if (!_isConfigured) return;
    await Superwall.shared.handleDeepLink(url);
  }
}
