import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/services/analytics/firebase_analytics_service.dart';
import 'package:sangeet/services/analytics/posthog_service.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';

/// Analytics consent: the first-run disclosure, and the two decisions behind it.
///
/// ## Why this exists
///
/// Play's User Data policy (Prominent Disclosure & Consent) requires that an
/// app which collects personal data:
///
///  * shows the disclosure **in the normal usage of the app**, and *"not require
///    the user to navigate into a menu or settings"*;
///  * obtains consent through **"affirmative user action"**, granted *"before
///    your app can begin to collect"*;
///  * does **not** treat navigating away (back button, tapping outside) as
///    consent.
///
/// The app's only consent control used to be the toggle in Settings → Privacy. It
/// is still there for withdrawing consent, but a toggle inside a menu cannot be
/// the *initial* disclosure, so this dialog now asks once, on first run, and
/// nothing is collected until it is answered.
///
/// Collection is already closed by default: `PostHogService.initialize` returns
/// early without consent, and `FirebaseAnalyticsService.applyConsent` sets
/// `setAnalyticsCollectionEnabled(false)` at startup. This class only flips those
/// gates once.
class AnalyticsConsent {
  AnalyticsConsent._();

  /// Whether the listener has already been asked (either answer).
  static bool get hasDecided => KVStoreService.analyticsConsentDecided;

  /// Whether analytics is currently allowed.
  static bool get isGranted => PostHogService.instance.hasConsent;

  /// Records that the question has been answered, so it is never asked twice.
  static Future<void> markDecided() async {
    try {
      await KVStoreService.setAnalyticsConsentDecided(true);
    } catch (_) {
      // Losing the flag only means the dialog may appear again; it must never
      // block the decision that was just made.
    }
  }

  /// The listener pressed "Allow analytics".
  static Future<void> grant() async {
    await PostHogService.instance.setConsent(true);
    await FirebaseAnalyticsService.instance.applyConsent(true);
    await markDecided();
  }

  /// The listener pressed "Not now".
  ///
  /// Written explicitly rather than "left as default", so a grant that survives
  /// from an older install cannot outlive a deliberate decline, and so Google
  /// Analytics for Firebase is told the same thing.
  static Future<void> decline() async {
    await PostHogService.instance.setConsent(false);
    await FirebaseAnalyticsService.instance.applyConsent(false);
    await markDecided();
  }

  /// Shows the first-run disclosure, once, if it has never been answered.
  ///
  /// Safe to call from any build method: it no-ops once decided, and it never
  /// opens more than one dialog because the flag is checked before showing.
  static Future<void> promptIfNeeded(BuildContext context) async {
    if (hasDecided) return;
    await showAnalyticsConsentDialog(context);
  }
}

/// Opens the disclosure dialog. Returns when it closes.
///
/// Deliberately **not** dismissible by tapping outside, and [PopScope] keeps the
/// system back gesture from closing it: Play requires an affirmative action, so
/// the only ways out are the two explicit answers.
Future<void> showAnalyticsConsentDialog(
  BuildContext context, {
  Future<void> Function()? onAllow,
  Future<void> Function()? onDecline,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AnalyticsConsentDialog(
      onAllow: () async {
        await (onAllow ?? AnalyticsConsent.grant)();
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      },
      onDecline: () async {
        await (onDecline ?? AnalyticsConsent.decline)();
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      },
    ),
  );
}

/// The disclosure itself.
///
/// The wording follows the format Play recommends
/// ("[app] collects [type of data] to enable [feature], [in what scenario]"), and
/// names the two facts a listener cannot guess: that events carry their account
/// id, and that Google Analytics for Firebase may read the advertising id.
class AnalyticsConsentDialog extends StatelessWidget {
  const AnalyticsConsentDialog({
    super.key,
    required this.onAllow,
    required this.onDecline,
  });

  final Future<void> Function() onAllow;
  final Future<void> Function() onDecline;

  static const String title = 'Help improve Soulful Bhakti?';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget para(String text) => Text(
          text,
          style: theme.typography.small.copyWith(
            color: theme.colorScheme.mutedForeground,
            height: 1.45,
          ),
        );

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text(title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            para(
              'Soulful Bhakti collects anonymous usage analytics — app opens, '
              'the screens and features you use, the tracks you play, and crash '
              'reports — to understand which features are used and to fix '
              'problems quickly.',
            ),
            Gap(10 * theme.scaling),
            para(
              'These events carry your account ID so usage can be joined across '
              'sessions. Google Analytics for Firebase may also read your '
              "device's advertising ID for measurement. Your data is never sold "
              'and never shared with advertisers.',
            ),
            Gap(10 * theme.scaling),
            para(
              'You can turn this off at any time in Settings → Privacy. '
              'Declining keeps the app fully usable.',
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('analytics_consent_decline'),
            onPressed: onDecline,
            child: const Text('Not now'),
          ),
          Button.primary(
            key: const Key('analytics_consent_allow'),
            onPressed: onAllow,
            child: const Text('Allow analytics'),
          ),
        ],
      ),
    );
  }
}
