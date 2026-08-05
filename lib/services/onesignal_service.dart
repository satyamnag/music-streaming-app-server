import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Centralized wrapper around the OneSignal Flutter SDK.
///
/// All OneSignal interactions in the app MUST go through this class so the
/// SDK surface is isolated in one place (easier to test, update, and audit).
/// Follows the OneSignal Flutter integration guide: initialized once at app
/// startup, push permission is ONLY requested from the "Got it" action of the
/// integration-complete dialog (never at launch).
class OneSignalService {
  OneSignalService._internal();

  static final OneSignalService instance = OneSignalService._internal();

  bool _isInitialized = false;

  /// A real, server-assigned push subscription ID is non-empty and does not
  /// start with the SDK's `local-` placeholder (which is assigned before the
  /// device registers with OneSignal's servers).
  static bool isRegisteredId(String? id) =>
      id != null && id.isNotEmpty && !id.startsWith('local-');

  /// Initializes the OneSignal SDK. Safe to call multiple times; only the
  /// first call performs initialization.
  Future<void> initialize(String appId) async {
    if (_isInitialized || appId.isEmpty) return;
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    await OneSignal.initialize(appId);
    _isInitialized = true;
  }

  /// Opts the user into push notifications. Does not necessarily prompt for
  /// permission — the permission request is handled by [requestPermission].
  Future<void> optIn() async {
    await OneSignal.User.pushSubscription.optIn();
  }

  /// Current push subscription ID, or null if not yet assigned.
  String? get pushSubscriptionId => OneSignal.User.pushSubscription.id;

  /// Registers a listener that fires whenever the push subscription changes
  /// (e.g. a real server-assigned ID arrives). The listener is retained by the
  /// caller — the SDK stores observers weakly.
  void addPushSubscriptionObserver(OnPushSubscriptionChangeObserver observer) {
    OneSignal.User.pushSubscription.addObserver(observer);
  }

  /// Requests push notification permission. This is the ONLY place the app may
  /// prompt for permission (per the OneSignal integration guide).
  Future<bool> requestPermission() {
    return OneSignal.Notifications.requestPermission(false);
  }

  /// Associates the current user with an external identifier (e.g. the Clerk
  /// user id) for cross-device messaging.
  Future<void> login(String externalId) => OneSignal.login(externalId);

  /// Removes the external identifier association.
  Future<void> logout() => OneSignal.logout();

  /// Subscribes an email address on the current user.
  Future<void> setEmail(String email) => OneSignal.User.addEmail(email);

  /// Subscribes an SMS number on the current user.
  Future<void> setSms(String smsNumber) => OneSignal.User.addSms(smsNumber);

  /// Sets a tag on the current user.
  Future<void> setTag(String key, dynamic value) =>
      OneSignal.User.addTagWithKey(key, value);

  /// Adds a trigger that can control in-app message display.
  Future<void> addInAppMessageTrigger(String key, String value) =>
      OneSignal.InAppMessages.addTrigger(key, value);
}
