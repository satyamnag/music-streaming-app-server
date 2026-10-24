import 'package:flutter/material.dart' show ListTile;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonStyle;
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/settings/section_card_with_heading.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/services/analytics/posthog_service.dart';
import 'package:sangeet/services/logger/logger.dart';

/// Privacy section: the user's control over product analytics.
///
/// The toggle is the only place consent is granted, and it is the source of
/// truth for [PostHogService.setConsent]. Collection is opt-in, so a fresh
/// install shows this switch OFF and sends nothing until it is turned on.
///
/// It is shown even when the build carries no PostHog token (`isConfigured` is
/// false): the preference is recorded either way, so a later release that adds
/// the token cannot start collecting from users who never saw the choice.
///
/// Opting in also back-fills the analytics identity when the user is already
/// signed in - see the comment on the switch handler.
class SettingsPrivacySection extends HookConsumerWidget {
  const SettingsPrivacySection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    // Seeded from the service, which reads the stored decision at startup
    // (main.dart calls PostHogService.initialize before the first frame).
    final consent = useState(PostHogService.instance.hasConsent);

    return SectionCardWithHeading(
      heading: context.l10n.privacy,
      children: [
        ListTile(
          leading: const Icon(SangeetIcons.chart),
          title: Text(context.l10n.share_analytics),
          subtitle: Text(context.l10n.share_analytics_description),
          trailing: Switch(
            value: consent.value,
            onChanged: (granted) async {
              // Optimistic: the switch must not lag behind the tap while the
              // preference is written. setConsent persists first and reports its
              // own failures, so the worst case is a logged write error, not a
              // switch that disagrees with what was stored.
              consent.value = granted;
              try {
                await PostHogService.instance.setConsent(granted);

                // Consent can be granted long after sign-in (this toggle is
                // reachable at any time), and the auth notifier only syncs
                // identity when the auth state *changes*. Without this, a user
                // who signed in before opting in would stay anonymous until
                // their next sign-in, and their events would be attributed to
                // the wrong person.
                if (granted) {
                  final auth = ref.read(clerkAuthProvider).value;
                  final userId = auth?.userId;
                  if (auth?.signedIn == true && userId != null) {
                    await PostHogService.instance.identify(userId);
                  }
                }
              } catch (e, stack) {
                AppLogger.reportError(e, stack, 'settings: analytics consent');
              }
            },
          ),
        ),
      ],
    );
  }
}
