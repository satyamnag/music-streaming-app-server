import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/modules/auth/clerk_auth_view.dart';
import 'package:sangeet/modules/auth/profile_plan_status.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';

/// Shows the signed-in user's Clerk profile (avatar, username, email) with a
/// sign-out action, or a sign-in prompt when the user is logged out.
///
///  - Logged in: avatar photo (when available), email, username and a
///    working "Sign Out" button that signs the user out of Clerk.
///  - Logged out: a generic avatar icon and a "Sign In" button. Tapping it
///    closes this dialog; the app's auth gate (main.dart) then shows the
///    email-OTP sign-in view automatically.
class ProfileDialog extends ConsumerWidget {
  const ProfileDialog({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final clerkAuth = ref.watch(clerkAuthProvider);
    final state = clerkAuth.value ?? const ClerkAuthState();
    final isSignedIn = state.signedIn;

    return AlertDialog(
      title: const Text('Profile'),
      content: SizedBox(
        width: 320,
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
              const Gap(16),
              Button.destructive(
                onPressed: () async {
                  await ref.read(clerkAuthProvider.notifier).signOut();
                  ref.invalidate(clerkAuthProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Sign Out'),
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
                  // Show the email-OTP sign-in as a modal popup dialog
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
    );
  }
}
