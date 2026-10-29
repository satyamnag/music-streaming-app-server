import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Whether this build reports in-app message activity to logcat.
///
/// A compile-time constant, so a normal build costs nothing: the `[OSDIAG]`
/// lines collapse to a `false` check. Only a build compiled with
/// `--dart-define=ONESIGNAL_VERIFY=true` (a verification build - the release
/// workflow refuses nothing here, so such an artifact must not be uploaded to
/// Play) turns on the SDK's verbose log and the lifecycle reporting.
const bool oneSignalVerifyEnabled = bool.fromEnvironment('ONESIGNAL_VERIFY');

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

  /// Whether [initialize] has completed. The in-app-message and trigger
  /// methods below are no-ops until then: the SDK has no app context before
  /// init, and calling into it would throw inside a widget build path.
  bool get isInitialized => _isInitialized;

  /// A real, server-assigned push subscription ID is non-empty and does not
  /// start with the SDK's `local-` placeholder (which is assigned before the
  /// device registers with OneSignal's servers).
  static bool isRegisteredId(String? id) =>
      id != null && id.isNotEmpty && !id.startsWith('local-');

  /// Initializes the OneSignal SDK. Safe to call multiple times; only the
  /// first call performs initialization.
  Future<void> initialize(String appId) async {
    if (_isInitialized || appId.isEmpty) return;
    OneSignal.Debug.setLogLevel(
      oneSignalVerifyEnabled ? OSLogLevel.verbose : OSLogLevel.warn,
    );
    await OneSignal.initialize(appId);
    _isInitialized = true;
    if (oneSignalVerifyEnabled) {
      // Proof from the device that the SDK came up: a verification run greps
      // logcat for this line.
      debugPrint('[OSDIAG] sdk_initialized app_id_suffix=${appId.substring(appId.length - 4)}');
    }
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

  /// Whether the app currently has push-notification permission.
  ///
  /// Reads the SDK's cached answer (`OneSignal.Notifications.permission`, which
  /// the plugin documents as "whether this app has push notification
  /// permission" and keeps in step with the OS through its own permission
  /// observer), so the profile screen's switch can show the REAL state instead
  /// of a local guess that survives a trip to the system settings.
  bool get hasPushPermission => OneSignal.Notifications.permission;

  /// Fires whenever the push-notification permission changes — including a
  /// change made outside the app in the system settings. The caller keeps the
  /// observer alive; [removePermissionObserver] unregisters it.
  void addPermissionObserver(OnNotificationPermissionChangeObserver observer) {
    OneSignal.Notifications.addPermissionObserver(observer);
  }

  /// Unregisters an observer added by [addPermissionObserver].
  void removePermissionObserver(
    OnNotificationPermissionChangeObserver observer,
  ) {
    OneSignal.Notifications.removePermissionObserver(observer);
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
  ///
  /// A no-op before [initialize]: the SDK has no app context yet, and a trigger
  /// set early would be discarded.
  Future<void> addInAppMessageTrigger(String key, String value) async {
    if (!_isInitialized) return;
    await OneSignal.InAppMessages.addTrigger(key, value);
    if (oneSignalVerifyEnabled) {
      debugPrint('[OSDIAG] iam_trigger_set $key=$value');
    }
  }

  /// Removes a trigger, so a message keyed on it stops being eligible.
  Future<void> removeInAppMessageTrigger(String key) async {
    if (!_isInitialized) return;
    await OneSignal.InAppMessages.removeTrigger(key);
    if (oneSignalVerifyEnabled) {
      debugPrint('[OSDIAG] iam_trigger_removed $key');
    }
  }

  /// Pauses or resumes in-app message display for the whole app. Used to keep
  /// a message from covering the player while audio is running.
  ///
  /// The SDK persists this flag itself, so it survives navigation; it does NOT
  /// survive a process restart, which is why `main()` re-applies it from the
  /// player's own state at startup.
  Future<void> setInAppMessagesPaused(bool paused) async {
    if (!_isInitialized) return;
    await OneSignal.InAppMessages.paused(paused);
    if (oneSignalVerifyEnabled) {
      debugPrint('[OSDIAG] iam_paused=${paused ? 'true' : 'false'}');
    }
  }

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
    if (!_isInitialized) return;
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
    if (!_isInitialized) return;
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
