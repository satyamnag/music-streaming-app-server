import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:sangeet/utils/platform.dart';

/// Centralized wrapper around the PostHog Flutter SDK.
///
/// Every PostHog call goes through this class so the SDK surface, the consent
/// rule, and the redaction rule live in exactly one place.
///
/// ## Two gates, both of which must be open before anything is sent
///
/// 1. **Configured** - `POSTHOG_API_KEY` is present in the build environment.
///    Empty by default (`lib/collections/env.dart`), so a build that has not
///    been given a token collects nothing and does not crash.
/// 2. **Consented** - the user turned on *Settings > Privacy > Share analytics*.
///    Consent is **opt-in and defaults to OFF** (`KVStoreService.analyticsConsent`).
///
/// Before consent the SDK is not merely opted out, it is never set up: no
/// anonymous distinct id is created, no lifecycle event is queued, no request is
/// made. That is why [initialize] returns early instead of calling `setup()`
/// with `config.optOut = true` - "installed but idle" is a weaker promise than
/// "never started", and it is much harder to prove.
///
/// ## Deliberate deviations from the SDK defaults
///
/// Each of these is a config value the SDK turns on by default and this app does
/// not want. They are set in [_ensureSetup] with the reason next to each one:
///
/// | Setting | SDK default | Here | Why |
/// | --- | --- | --- | --- |
/// | `capturePushNotificationSubscriptions` | `true` | `false` | The app pushes through OneSignal. Registering an FCM token with PostHog too would ship a second device identifier to a second vendor and give the device two push identities. |
/// | `capturePushNotificationOpened` | `true` | `false` | Notification-opened attribution belongs to OneSignal's own reporting here. |
/// | `sessionReplay` | `false` | `false` | Replay records the screen. Not enabled, and not planned without a separate, explicit consent. |
/// | `surveys` | `true` | `false` | Surveys cannot render without `PosthogObserver`, which this app does not install, so the setting would only enable flag polling for a feature that cannot appear. |
/// | `preloadFeatureFlags` | `true` | `false` | No feature flags are evaluated, so the startup `/flags` request would be collection with no reader. |
/// | `enableWindowsAndLinux` | `true` | `false` | Mobile-only analytics, matching the pre-existing Firebase scope. Desktop capture is experimental in the SDK and out of scope for this change. |
/// | `rageClickConfig.enabled` | `true` | `false` | Autocaptured rage clicks are not something this app asks for. |
/// | error tracking | all `false` | all `false` | Crashlytics already owns crash and error reporting; enabling PostHog's too would double-report every crash to two vendors. |
///
/// ## PII redaction, and its limit
///
/// [redact] runs as a `beforeSend` callback and strips identifying keys from
/// every event captured through this service. The limit is documented by the SDK
/// and is not something this wrapper can work around: `beforeSend` **only** sees
/// events captured from Dart (`capture`, `screen`, `captureException`). Native
/// events - application lifecycle, the `$set` from `identify`, feature flags,
/// replay, surveys - never pass through it.
///
/// So redaction is the second line of defence, not the first. The first is that
/// [identify] sends a user id and nothing else: no email, no name, no username.
class PostHogService {
  PostHogService._internal();

  static final PostHogService instance = PostHogService._internal();

  bool _configured = false;
  bool _consented = false;
  String _projectToken = '';
  String _host = '';

  /// Whether `Posthog().setup()` has completed successfully.
  bool get isConfigured => _configured;

  /// Whether the user has opted in to analytics.
  bool get hasConsent => _consented;

  /// Whether an event captured right now would actually be sent. Every public
  /// method below guards on this.
  bool get isCapturing => _configured && _consented;

  /// Whether the SDK may be set up on this platform.
  ///
  /// Android and iOS only, matching the pre-existing Firebase scope: the web
  /// build needs a separate posthog-js snippet, and desktop capture is
  /// experimental in the SDK and not configured here. Overridable in tests,
  /// which run on the host (Windows/Linux) where [kIsMobile] is always false.
  @visibleForTesting
  bool Function() isSupportedPlatform = () => kIsMobile;

  /// Restores the pre-[initialize] state. Test-only: the service is a singleton
  /// for the life of the process, so tests that share it need a way back to a
  /// fresh install.
  @visibleForTesting
  void resetForTesting() {
    _configured = false;
    _consented = false;
    _projectToken = '';
    _host = '';
  }

  /// Whether this binary was compiled with the verification define set.
  ///
  /// Overridable in tests only: in a real build this is the compile-time
  /// constant `POSTHOG_VERIFY_OPTIN`, which no shipping workflow passes.
  @visibleForTesting
  bool Function() isVerificationDefineSet =
      () => const bool.fromEnvironment('POSTHOG_VERIFY_OPTIN');

  /// Whether this binary is a debug build.
  @visibleForTesting
  bool Function() isDebugBuild = () => kDebugMode;

  /// Whether this build should grant analytics consent by itself, for
  /// installation verification.
  ///
  /// TWO independent gates, and a shipping build fails both:
  ///
  /// 1. `POSTHOG_VERIFY_OPTIN` must be set at **compile time**
  ///    (`--dart-define=POSTHOG_VERIFY_OPTIN=true`). Because it is a compile-time
  ///    constant it cannot be switched on at runtime by remote config, by a
  ///    stored preference, or by a tampered device.
  /// 2. The binary must be a **debug** build. Even if the define were added to a
  ///    release pipeline by mistake, a release binary refuses.
  ///
  /// Not a product feature: it exists so the analytics pipeline can be verified
  /// end to end against a real PostHog project. See docs/POSTHOG.md.
  @visibleForTesting
  bool isVerificationOptInRequested() =>
      isVerificationDefineSet() && isDebugBuild();

  /// Grants consent programmatically for an installation-verification build.
  ///
  /// Goes through the same [setConsent] the Settings toggle uses, so the stored
  /// value and every downstream effect are identical to a user tapping the
  /// switch - the only difference is who initiates it. Returns whether this call
  /// is what granted consent.
  ///
  /// A no-op unless [isVerificationOptInRequested], so in every shipping build
  /// this returns `false` and changes nothing.
  Future<bool> verifyOptInIfRequested() async {
    if (!isVerificationOptInRequested()) return false;

    _warn(
      'POSTHOG_VERIFY_OPTIN is set in a debug build: granting analytics consent '
      'for installation verification. This must never appear in a release.',
    );
    await setConsent(true);
    return true;
  }

  /// Reads the stored consent decision and sets the SDK up **only** if the user
  /// has already opted in. Safe to call once at startup; never throws.
  ///
  /// [KVStoreService.initialize] must have completed first - [KVStoreService]
  /// reads the decision from SharedPreferences, which cannot be opened earlier
  /// than the rest of the app's local storage.
  Future<void> initialize({
    required String projectToken,
    required String host,
  }) async {
    _projectToken = projectToken.trim();
    _host = host.trim();
    _consented = KVStoreService.analyticsConsent;
    if (!_consented) return;
    await _ensureSetup();
  }

  /// Records the user's consent decision and applies it immediately.
  ///
  /// Opting in sets the SDK up on first use (and opts back in on later calls);
  /// opting out stops all future sending and clears the local analytics
  /// identity, so re-opting in later starts a new anonymous id rather than
  /// resuming the old one.
  ///
  /// The decision is persisted before anything else, so a failure in the SDK
  /// call cannot leave the UI and the stored preference disagreeing.
  Future<void> setConsent(bool granted) async {
    _consented = granted;

    try {
      await KVStoreService.setAnalyticsConsent(granted);
    } catch (e, stack) {
      // The preference is the durable half of the decision, so losing it is
      // worth reporting - but it must not stop the in-memory state above from
      // taking effect for this session.
      _report(e, stack, 'posthog: persist consent');
    }

    if (granted) {
      await _ensureSetup();
      if (!_configured) return;
      try {
        await Posthog().optIn();
      } catch (e, stack) {
        _report(e, stack, 'posthog: optIn');
      }
      return;
    }

    if (!_configured) return;
    try {
      // Order matters: stop sending first, then clear the identity. `reset()`
      // rotates the distinct id, and doing it while still opted in would let a
      // final event carry the identity the user just asked us to drop.
      await Posthog().optOut();
      await Posthog().reset();
    } catch (e, stack) {
      _report(e, stack, 'posthog: optOut');
    }
  }

  /// Associates events with a signed-in user (the Clerk user id).
  ///
  /// The id is the only thing sent. `identify()` also produces a native `$set`
  /// person event, which `beforeSend` cannot inspect, so passing an email or a
  /// display name here would put PII on PostHog's servers with no way to redact
  /// it. Callers must not add them.
  Future<void> identify(String userId) async {
    if (!isCapturing) return;
    final id = userId.trim();
    if (id.isEmpty) return;

    try {
      await Posthog().identify(userId: id);
    } catch (e, stack) {
      _report(e, stack, 'posthog: identify');
    }
  }

  /// Clears the local analytics identity (sign-out, account deletion).
  ///
  /// Runs whenever the SDK was set up, including while opted out, so that
  /// signing out cannot leave the next user on the device attached to the
  /// previous user's analytics identity.
  Future<void> reset() async {
    if (!_configured) return;

    try {
      await Posthog().reset();
    } catch (e, stack) {
      _report(e, stack, 'posthog: reset');
    }
  }

  /// Captures a custom event. Prefer the `[object] [verb]` naming convention
  /// the SDK recommends (`track played`, `playlist created`).
  ///
  /// [properties] must not contain personal data; [redact] strips the obvious
  /// keys, but the first rule is not to pass them.
  Future<void> capture(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    if (!isCapturing) return;
    final name = eventName.trim();
    if (name.isEmpty) return;

    try {
      await Posthog().capture(eventName: name, properties: properties);
    } catch (e, stack) {
      _report(e, stack, 'posthog: capture $name');
    }
  }

  /// Captures a screen view.
  ///
  /// Not wired to a navigator observer yet: `PosthogObserver` would need to be
  /// installed in the app's navigator list, and until a project token exists
  /// there is nothing to verify that against. Call sites that already know the
  /// screen name can call this directly.
  Future<void> screen(
    String screenName, {
    Map<String, Object>? properties,
  }) async {
    if (!isCapturing) return;
    final name = screenName.trim();
    if (name.isEmpty) return;

    try {
      await Posthog().screen(screenName: name, properties: properties);
    } catch (e, stack) {
      _report(e, stack, 'posthog: screen $name');
    }
  }

  /// Captures a non-fatal exception.
  ///
  /// Crashlytics remains the crash reporter; this is for errors the app handles
  /// itself and wants counted.
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) async {
    if (!isCapturing) return;

    try {
      await Posthog().captureException(
        error: error,
        stackTrace: stackTrace,
        properties: properties,
      );
    } catch (e, stack) {
      _report(e, stack, 'posthog: captureException');
    }
  }

  /// Sends anything queued immediately.
  ///
  /// The SDK flushes on its own (every 30s or 20 events), so this is only for
  /// moments where waiting would lose the tail of a session.
  Future<void> flush() async {
    if (!isCapturing) return;

    try {
      await Posthog().flush();
    } catch (e, stack) {
      _report(e, stack, 'posthog: flush');
    }
  }

  /// Sets the SDK up if it is not set up yet. Never throws: a failure here
  /// leaves [isConfigured] false, which turns every other method into a no-op.
  Future<void> _ensureSetup() async {
    if (_configured) return;

    // `posthog_flutter` is wired for Android and iOS in this app. Desktop and
    // web are not configured (no native AUTO_INIT entry, no web snippet), so
    // setting up there would be a request the platform cannot serve.
    if (!isSupportedPlatform()) return;

    // Env-gated: no token means no SDK, exactly like ONESIGNAL_APP_ID. The SDK
    // itself also refuses a blank token, but returning here keeps a missing
    // token out of the "setup threw" log path.
    if (_projectToken.isEmpty) {
      _warn(
        'POSTHOG_API_KEY is empty; PostHog is not initialised. Add it to .env '
        '(CI: the AWS Secrets Manager secret posthog/api-key).',
      );
      return;
    }

    try {
      final config = PostHogConfig(_projectToken);
      // A blank host falls back to https://us.i.posthog.com inside the setter.
      config.host = _host;

      // See the table in the class comment for why each of these is set.
      config.enableWindowsAndLinux = false;
      config.sessionReplay = false;
      config.surveys = false;
      config.preloadFeatureFlags = false;
      config.capturePushNotificationSubscriptions = false;
      config.capturePushNotificationOpened = false;
      config.rageClickConfig.enabled = false;
      config.beforeSend = [redact];

      // Verbose SDK logs, but ONLY in a build that exists to be verified. This
      // is what turns "no events arrived" into a readable logcat: the SDK prints
      // what it queued, what it flushed, and what the server answered. Gated by
      // the same two conditions as the verification harness itself, so no
      // shipping build can enable it.
      config.debug = isVerificationOptInRequested();

      await Posthog().setup(config);
      _configured = true;
    } catch (e, stack) {
      _report(e, stack, 'posthog: setup');
    }
  }

  /// Property keys that are always stripped, matched on the **whole** key
  /// (case-insensitively).
  ///
  /// Whole-key matching is what keeps this from eating legitimate properties:
  /// `screen_name`, `track_name` and `artist_name` are not `name`, so they
  /// survive, while a bare `name` or `username` does not.
  @visibleForTesting
  static const Set<String> redactedKeys = {
    'name',
    'first_name',
    'last_name',
    'full_name',
    'display_name',
    'username',
    'user_name',
    'email',
    'e_mail',
    'user_email',
    'phone',
    'phone_number',
    'mobile',
    'address',
    'street',
    'city',
    'zip',
    'postal_code',
    'password',
    'auth_token',
    'access_token',
    'refresh_token',
    'api_key',
    'apikey',
    'secret',
    'token',
    'authorization',
    'query',
    'search_query',
    'search_term',
    'birthday',
    'date_of_birth',
    'ip',
    'ip_address',
    'aadhaar',
    'pan',
    'gstin',
  };

  /// Fragments that mark a key as identifying wherever they appear.
  ///
  /// Deliberately short and unambiguous. `name` is **not** here on purpose: as a
  /// fragment it would match `screen_name`, `track_name` and `artist_name`,
  /// which are exactly the properties analytics needs.
  @visibleForTesting
  static const List<String> redactedKeyFragments = [
    'email',
    'phone',
    'password',
    'secret',
    'aadhaar',
    'gstin',
  ];

  /// `beforeSend` callback: strips identifying properties, then keeps the event.
  ///
  /// Returns a possibly modified event rather than `null` - dropping whole
  /// events here would silently distort funnels, and the keys are what carry
  /// the personal data.
  @visibleForTesting
  static PostHogEvent? redact(PostHogEvent event) {
    _redactMap(event.properties);
    _redactMap(event.userProperties);
    _redactMap(event.userPropertiesSetOnce);
    return event;
  }

  static void _redactMap(Map<String, Object>? properties) {
    if (properties == null || properties.isEmpty) return;
    final sensitive = properties.keys.where(isSensitiveKey).toList();
    for (final key in sensitive) {
      properties.remove(key);
    }
  }

  /// Whether [key] names a property that must never leave the device.
  @visibleForTesting
  static bool isSensitiveKey(String key) {
    final normalised = key.toLowerCase();
    if (redactedKeys.contains(normalised)) return true;
    return redactedKeyFragments.any(normalised.contains);
  }

  /// Reports a contained failure without ever throwing itself.
  ///
  /// Every call site is inside a `catch` block, so a throw from the reporter
  /// would undo the containment it exists to provide: an SDK hiccup would become
  /// an unhandled error in the settings toggle or at startup.
  ///
  /// Two distinct mechanisms have to be handled here, both found by this
  /// service's own tests:
  ///
  /// 1. `AppLogger.log` is a `late final` assigned by `AppLogger.initialize()`,
  ///    so touching it before that runs (unit tests, a background isolate)
  ///    throws `LateInitializationError`.
  /// 2. `AppLogger.reportError` is `async`, so that throw does not happen at the
  ///    call site - it is delivered on the returned Future, where a synchronous
  ///    `try`/`catch` cannot see it. Hence `.catchError` rather than a try block.
  static void _report(Object error, StackTrace stack, String context) {
    // The error being reported is non-fatal by construction, so swallowing a
    // failure to report it is correct: there is nothing left to escalate to.
    AppLogger.reportError(error, stack, context).catchError((_) {});
  }

  /// Logs a warning without ever throwing.
  ///
  /// `Logger.w` is synchronous and `AppLogger.log` throws on access before
  /// initialization, so a plain try block is enough here - unlike [_report].
  static void _warn(String message) {
    try {
      AppLogger.log.w(message);
    } catch (_) {
      // Logger unavailable - the caller's behaviour is unaffected either way.
    }
  }
}
