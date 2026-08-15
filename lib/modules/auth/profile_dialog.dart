import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/modules/auth/clerk_auth_view.dart';
import 'package:sangeet/modules/auth/profile_plan_status.dart';
import 'package:sangeet/modules/referral/share_and_earn.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';

/// Shows the signed-in user's Clerk profile (avatar, username, email) with a
/// sign-out action, or a sign-in prompt when the user is logged out.
///
///  - Logged in: avatar photo (when available), email, username and a
///    working "Sign Out" button. Sign-out asks for confirmation first; if the
///    native call fails, the dialog stays open and an inline error is shown.
///  - Logged out: a generic avatar icon and a "Sign In" button. Tapping it
///    opens the Google-only [ClerkAuthView] dialog.
class ProfileDialog extends ConsumerWidget {
  const ProfileDialog({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final clerkAuth = ref.watch(clerkAuthProvider);
    final state = clerkAuth.value ?? const ClerkAuthState();
    final isSignedIn = state.signedIn;

    // Holds the sign-out error (if any) so the dialog stays open on failure.
    final signOutError = ValueNotifier<String?>(null);

    Future<void> signOut() async {
      // Confirmation step — the user must explicitly confirm before the
      // native session is destroyed.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will be signed out of Soulful Bhakti. Signed-in '
            'features (like your paid plan) will be locked until you sign in '
            'again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            Button.destructive(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      signOutError.value = null;
      final failure = await ref.read(clerkAuthProvider.notifier).signOut();
      if (!context.mounted) return;
      if (failure != null) {
        // Keep the dialog open and surface the error inline.
        signOutError.value = failure;
        return;
      }
      ref.invalidate(clerkAuthProvider);
      if (context.mounted) Navigator.pop(context);
    }

    return AlertDialog(
      title: const Text('Profile'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: (isSignedIn && state.imageUrl != null)
                    ? UniversalImage(
                        path: state.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        SangeetIcons.user,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
              ),
              const Gap(12),
              if (isSignedIn) ...[
                if (state.username != null && state.username!.isNotEmpty) ...[
                  Text(
                    state.username!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(4),
                ],
                if (state.email != null)
                  Text(
                    state.email!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                const Gap(16),
                // Show the paid plan status (plan name, duration, start/end
                // dates) for signed-in users, read from Superwall CustomerInfo.
                const ProfilePlanStatus(),
                const Gap(12),
                // Referral / affiliate program: personal code, share link and
                // tracked commission (server-side, track-first).
                const ShareAndEarn(),
                const Gap(16),
                ValueListenableBuilder<String?>(
                  valueListenable: signOutError,
                  builder: (context, error, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.destructive
                                .withValues(alpha: 0.08),
                            borderRadius: theme.borderRadiusMd,
                            border: Border.all(
                              color: theme.colorScheme.destructive
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            error,
                            style: theme.typography.small.copyWith(
                              color: theme.colorScheme.destructive,
                            ),
                          ),
                        ),
                        const Gap(12),
                      ],
                      Button.destructive(
                        onPressed: signOut,
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  'Sign in to access your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const Gap(16),
                Button.primary(
                  onPressed: () {
                    // Show the Google-only sign-in as a modal popup dialog
                    // instead of a full-screen route.
                    Navigator.of(context).pop();
                    showDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => const ClerkAuthView(),
                    );
                  },
                  child: const Text('Sign In'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
