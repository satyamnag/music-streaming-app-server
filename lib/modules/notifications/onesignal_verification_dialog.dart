import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart'
    hide showDialog, AlertDialog, TextButton;
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/services/onesignal_service.dart';

/// Shows a one-time welcome dialog when the device receives a real,
/// server-assigned push subscription ID.
///
/// For **free users** it is framed as a premium upsell that encourages opting
/// into the paid plan ("Go for Paid Plan" opens the sign-in → Superwall paywall
/// flow). Push permission is still requested from the primary button.
///
/// Per the OneSignal integration guide:
///  - Only a real ID (non-empty, not `local-`) counts as "registered".
///  - The dialog appears at most once per app session.
///  - Push permission is requested ONLY from the button — never at app launch.
class OneSignalVerificationDialog extends ConsumerStatefulWidget {
  const OneSignalVerificationDialog({super.key});

  @override
  ConsumerState<OneSignalVerificationDialog> createState() =>
      _OneSignalVerificationDialogState();
}

class _OneSignalVerificationDialogState
    extends ConsumerState<OneSignalVerificationDialog> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _setupObserver();
  }

  void _setupObserver() {
    final service = OneSignalService.instance;

    void maybeShow(String? id) {
      if (_shown) return;
      if (!OneSignalService.isRegisteredId(id)) return;
      _shown = true;
      // Defer to the next frame so the dialog can use a valid Navigator.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDialog();
      });
    }

    // Retain the observer on the State (the SDK stores observers weakly).
    service.addPushSubscriptionObserver((changes) {
      maybeShow(changes.current.id);
    });

    // Evaluate the current ID immediately — it may already be assigned.
    maybeShow(service.pushSubscriptionId);
  }

  Future<void> _showDialog() async {
    final isPremium = PremiumAccess.isPremiumUser(ref);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPremium
            ? 'Welcome to Soulful Bhakti Premium!'
            : 'Unlock Every Song'),
        content: Text(
          isPremium
              ? 'Thank you for subscribing! Enjoy every devotional song, '
                  'uninterrupted.'
              : 'Upgrade to Soulful Bhakti Premium for unlimited access to '
                  'every song, lyrics, and an uninterrupted listening '
                  'experience — monthly ₹120 or yearly ₹1,200.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Permission is requested here — the only place per the guide.
              OneSignalService.instance.requestPermission();
            },
            child: Text(isPremium ? 'Got it' : 'Not now'),
          ),
          if (!isPremium)
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                OneSignalService.instance.requestPermission();
                await PremiumAccess.promptForPaidPlan(dialogContext, ref);
              },
              child: const Text('Go for Paid Plan'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget is invisible; it only manages the observer + dialog.
    return const SizedBox.shrink();
  }
}
