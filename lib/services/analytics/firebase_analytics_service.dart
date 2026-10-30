import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:sangeet/services/logger/logger.dart';

/// Google Analytics for Firebase, held to the app's own analytics decision.
///
/// ## Why this wrapper exists
/// GA4 is built in because the Play Console "Advertising ID" declaration is
/// answered **Yes**: GA4 is the component that reads the advertising identifier
/// (for measurement and attribution only — the manifest turns personalized
/// advertising off with
/// `google_analytics_default_allow_ad_personalization_signals=false`).
///
/// Collection is **off until the listener says otherwise**. Two documented
/// switches make that true from the very first frame, so there is no window in
/// which events could be sent before consent:
///
///  1. `<meta-data android:name="firebase_analytics_collection_enabled"
///     android:value="false" />` in `AndroidManifest.xml` — Google's documented
///     way to "temporarily disable collection, such as to get end-user consent
///     before collecting data"
///     (<https://firebase.google.com/docs/analytics/android/configure-data-collection>);
///  2. [applyConsent], which calls `setAnalyticsCollectionEnabled` — the method
///     the same page names for re-enabling collection once consent is given.
///
/// Everything is best-effort: a failure here can never break the app, and a
/// build without Firebase initialised (tests, desktop) is a safe no-op.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();

  static final FirebaseAnalyticsService instance = FirebaseAnalyticsService._();

  bool _lastApplied = false;

  /// The decision most recently pushed to GA4 (for diagnostics/tests).
  bool get lastApplied => _lastApplied;

  /// Applies [granted] — the same switch that drives PostHog
  /// (`Settings → Privacy → Share analytics`) — to Google Analytics.
  ///
  /// A no-op when Firebase has not been initialised, which is the case in unit
  /// tests and on platforms without a Firebase app.
  Future<void> applyConsent(bool granted) async {
    if (Firebase.apps.isEmpty) {
      _lastApplied = granted;
      return;
    }
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(granted);
      _lastApplied = granted;
    } catch (e, stack) {
      AppLogger.reportError(e, stack, 'analytics: GA4 consent');
    }
  }
}
