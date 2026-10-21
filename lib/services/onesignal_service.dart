import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Centralized wrapper around the OneSignal Flutter SDK.
///
/// All OneSignal interactions in the app MUST go through this class so the
/// SDK surface is isolated in one place (easier to test, update, and audit).
/// Follows the OneSignal Flutter integration guide: initialized once at app
/// startup; push permission is requested from an explicit user action (after
/// sign-in and from the profile popup), never silently at launch.
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
  /// prompt for permission. With [fallbackToSettings] the user is sent to the
  /// system notification settings after a denial, giving a re-enable path
  /// instead of a permanent silent drop.
  Future<bool> requestPermission({bool fallbackToSettings = false}) {
    return OneSignal.Notifications.requestPermission(fallbackToSettings);
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

  /// Removes a trigger, so a message keyed on it stops being eligible.
  Future<void> removeInAppMessageTrigger(String key) =>
      OneSignal.InAppMessages.removeTrigger(key);

  /// Pauses or resumes in-app message display for the whole app. Used to keep
  /// a message from covering the player while audio is running.
  Future<void> setInAppMessagesPaused(bool paused) =>
      OneSignal.InAppMessages.paused(paused);

  /// Fires when the user taps a push notification or one of its action
  /// buttons. The notification's custom payload is on
  /// [OSNotificationClickEvent.notification]`additionalData`; an explicit
  /// link is on `event.result.url`.
  ///
  /// Registered once at startup. The SDK keeps this listener for the process
  /// lifetime, so there is no matching remove call here.
  void addNotificationClickListener(OnNotificationClickListener listener) {
    OneSignal.Notifications.addClickListener(listener);
  }

  /// Fires when a notification arrives while the app is in the foreground,
  /// before it is shown. The handler may call `event.preventDefault()` to keep
  /// it out of the shade, or `event.notification.display()` to show it later.
  void addForegroundWillDisplayListener(
    OnNotificationWillDisplayListener listener,
  ) {
    OneSignal.Notifications.addForegroundWillDisplayListener(listener);
  }

  /// Fires when a user taps a button or image inside an in-app message. The
  /// action's identifier and link are on `event.result` (`actionId`, `url`).
  void addInAppMessageClickListener(OnClickInAppMessageListener listener) {
    OneSignal.InAppMessages.addClickListener(listener);
  }

  /// Registers the four in-app message lifecycle listeners. Each is optional;
  /// pass only the ones the caller needs.
  ///
  /// The SDK stores these separately (not as one listener object), which is why
  /// this wrapper exists rather than exposing four methods.
  void addInAppMessageLifecycleListeners({
    OnWillDisplayInAppMessageListener? onWillDisplay,
    OnDidDisplayInAppMessageListener? onDidDisplay,
    OnWillDismissInAppMessageListener? onWillDismiss,
    OnDidDismissInAppMessageListener? onDidDismiss,
  }) {
    if (onWillDisplay != null) {
      OneSignal.InAppMessages.addWillDisplayListener(onWillDisplay);
    }
    if (onDidDisplay != null) {
      OneSignal.InAppMessages.addDidDisplayListener(onDidDisplay);
    }
    if (onWillDismiss != null) {
      OneSignal.InAppMessages.addWillDismissListener(onWillDismiss);
    }
    if (onDidDismiss != null) {
      OneSignal.InAppMessages.addDidDismissListener(onDidDismiss);
    }
  }
}
