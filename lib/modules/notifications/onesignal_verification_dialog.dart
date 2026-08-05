import 'package:flutter/material.dart';
import 'package:sangeet/services/onesignal_service.dart';

/// Shows the OneSignal "integration complete" dialog exactly once when the
/// device receives a real, server-assigned push subscription ID.
///
/// Per the OneSignal integration guide:
///  - Only a real ID (non-empty, not `local-`) counts as "registered".
///  - The dialog appears at most once per app session.
///  - Push permission is requested ONLY from the "Got it" button — never at
///    app launch.
class OneSignalVerificationDialog extends StatefulWidget {
  const OneSignalVerificationDialog({super.key});

  @override
  State<OneSignalVerificationDialog> createState() =>
      _OneSignalVerificationDialogState();
}

class _OneSignalVerificationDialogState extends State<OneSignalVerificationDialog> {
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your OneSignal SDK integration is complete!'),
        content: const Text(
          'You can now send Push Notifications & In-App Messages through '
          'OneSignal. Tap below to enable push notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Permission is requested here — the only place per the guide.
              OneSignalService.instance.requestPermission();
            },
            child: const Text('Got it'),
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
