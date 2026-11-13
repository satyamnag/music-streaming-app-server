import 'package:flutter/material.dart' show ListTile;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonStyle;

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/settings/section_card_with_heading.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';

/// The ACCOUNT section of Settings: the irreversible action, in the place a
/// listener (and a Play reviewer) looks for it.
///
/// ## Why it moved here
///
/// Play's account-deletion requirement asks for a pathway that is *"prominent
/// (for example, within the account settings or a similar section)"*
/// (<https://support.google.com/googleplay/android-developer/answer/13327111>).
/// Settings → Account is literally the example the policy gives, so this is a
/// stronger placement than the Profile screen's action list — and it sits under
/// Privacy, where a listener goes when they are thinking about their data.
///
/// The row is the destructive card that was there before (icon, title, subtitle,
/// chevron) rather than a bare text link: the earlier link read as an afterthought
/// and, in the product's own words, looked unprofessional next to the card rows
/// above it. The confirmation dialog is unchanged — informed consent still comes
/// before the irreversible call.
class SettingsAccountSection extends HookConsumerWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleting = useState(false);

    Future<void> deleteAccount() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This will permanently delete your Soulful Bhakti account and '
            'all data associated with it. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            Button.destructive(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      isDeleting.value = true;
      try {
        final failure =
            await ref.read(clerkAuthProvider.notifier).deleteAccount();
        if (!context.mounted) return;
        if (failure != null) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text("Couldn't delete your account"),
              content: Text(failure),
              actions: [
                Button.primary(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
        ref.invalidate(clerkAuthProvider);
      } finally {
        if (context.mounted) isDeleting.value = false;
      }
    }

    return SectionCardWithHeading(
      heading: context.l10n.account,
      children: [
        ListTile(
          key: const Key('settings_delete_account'),
          leading: const Icon(SangeetIcons.trash),
          title: Text(
            'Delete account',
            style: TextStyle(color: Theme.of(context).colorScheme.destructive),
          ),
          subtitle: const Text('Permanently remove your account and data'),
          trailing: isDeleting.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(SangeetIcons.angleRight),
          // The whole row is the target, and ListTile's minimum height (56dp)
          // is already above the 48dp floor Play and WCAG ask for.
          onTap: isDeleting.value ? null : deleteAccount,
        ),
      ],
    );
  }
}
