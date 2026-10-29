import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/auth/clerk_auth_view.dart';
import 'package:sangeet/modules/auth/profile_plan_status.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/services/onesignal_service.dart';

/// The Profile screen (the fourth bottom-nav tab), laid out as the reference
/// design shows it:
///
///   * the listener's avatar, name and email;
///   * an ACCOUNT group with Settings and Notifications;
///   * the subscription card (plan, `CURRENT PLAN` badge, Upgrade to Pro);
///   * an ACCOUNT ACTIONS group with Sign out and Delete account.
///
/// It replaces the profile *popup* that used to hang off the home header's
/// avatar: everything the popup did — sign in, sign out, delete the account,
/// open Settings, opt into push, show the plan — lives here now, on a screen
/// with room for it, and the home header no longer opens a dialog.
///
/// ## Signed-out state
/// The same screen, with the identity block reduced to the generic avatar, a
/// one-line explanation and a Sign in button, and without the ACCOUNT ACTIONS
/// group (there is no session to end). Settings, the plan card and the
/// notification switch stay available, exactly as they were in the popup.
///
/// ## What the reference shows that this cannot
/// The reference has a camera badge on the avatar and an "Edit profile" pill.
/// The Clerk Google session exposes no profile-update bridge (`ClerkBridge.kt`
/// has setPublishableKey / getState / signInWithGoogle / signOut /
/// deleteAccount only), and a button that cannot change anything would be a lie
/// on a live screen - so neither is drawn. See docs/PROFILE-SCREEN.md.
@RoutePage()
class ProfilePage extends HookConsumerWidget {
  static const name = "profile";

  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    final clerkAuth = ref.watch(clerkAuthProvider);
    final state = clerkAuth.valueOrNull ?? const ClerkAuthState();
    final isSignedIn = state.signedIn;

    return PopScope(
      // Same convention as the Library and My Bhakti tabs: back returns to the
      // home screen rather than leaving the app from a bottom-bar tab.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            TitleBar(
              automaticallyImplyLeading: false,
              // Centred, exactly like the Library and My Bhakti tabs: without a
              // Centre the title hugs the leading edge (and clips), and a back
              // chevron would have to invent a destination on a bottom-nav tab.
              title: Center(
                child: Text(
                  context.l10n.profile,
                  style: theme.typography.h4,
                ),
              ),
            ),
          ],
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16 * scale,
                    8 * scale,
                    16 * scale,
                    0,
                  ),
                  child: _IdentityHeader(
                    state: state,
                    isSignedIn: isSignedIn,
                    onSignIn: () => showDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => const ClerkAuthView(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16 * scale,
                    0,
                    16 * scale,
                    // The floating mini player + nav bar cover the bottom of the
                    // body; this is the measured reserve every scrolling screen
                    // uses, so the last row is never hidden behind it.
                    context.bottomPlayerReserve,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('ACCOUNT'),
                      _ProfileRow(
                        icon: SangeetIcons.settings,
                        title: context.l10n.settings,
                        subtitle: 'Manage your app preferences',
                        onTap: () {
                          context.navigateTo(const SettingsRoute());
                        },
                      ),
                      Gap(10 * scale),
                      // The plan card owns its own tinted background, matching
                      // the reference's highlighted block.
                      const ProfilePlanStatus(),
                      Gap(10 * scale),
                      const _NotificationRow(),
                      if (isSignedIn) ...[
                        Gap(18 * scale),
                        const Divider(),
                        const _SectionLabel('ACCOUNT ACTIONS'),
                        const _AccountActions(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar + name + email (signed in) or avatar + explanation + Sign in button
/// (signed out).
class _IdentityHeader extends StatelessWidget {
  final ClerkAuthState state;
  final bool isSignedIn;
  final VoidCallback onSignIn;

  const _IdentityHeader({
    required this.state,
    required this.isSignedIn,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final primary = theme.colorScheme.primary;
    final avatarUrl = state.imageUrl;

    return Column(
      children: [
        Gap(6 * scale),
        Container(
          width: 96 * scale,
          height: 96 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.10),
            border: Border.all(
              color: primary.withValues(alpha: 0.35),
              width: 2 * scale,
            ),
          ),
          child: ClipOval(
            child: (isSignedIn && avatarUrl != null && avatarUrl.isNotEmpty)
                ? UniversalImage(
                    path: avatarUrl,
                    fit: BoxFit.cover,
                  )
                : Icon(
                    SangeetIcons.user,
                    size: 44 * scale,
                    color: primary,
                  ),
          ),
        ),
        Gap(14 * scale),
        Text(
          isSignedIn
              ? (state.displayName ?? 'Soulful Bhakti listener')
              : 'You are not signed in',
          textAlign: TextAlign.center,
          style: theme.typography.h4.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.foreground,
          ),
        ),
        Gap(4 * scale),
        if (isSignedIn && state.email != null && state.email!.isNotEmpty)
          Text(
            state.email!,
            textAlign: TextAlign.center,
            style: theme.typography.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          )
        else if (!isSignedIn) ...[
          Text(
            'Sign in to access your account',
            textAlign: TextAlign.center,
            style: theme.typography.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          Gap(14 * scale),
          Button.primary(
            onPressed: onSignIn,
            child: const Text('Sign in'),
          ),
        ],
        Gap(6 * scale),
      ],
    );
  }
}

/// One uppercase group heading ("ACCOUNT", "ACCOUNT ACTIONS").
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    return Padding(
      padding: EdgeInsets.only(top: 20 * scale, bottom: 10 * scale),
      child: Text(
        text,
        style: theme.typography.xSmall.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

/// A card row: leading tinted icon chip, title, optional subtitle, and a
/// trailing chevron. [danger] switches the whole row to the destructive colour
/// (the Delete-account row in the reference).
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _ProfileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final accent =
        danger ? theme.colorScheme.destructive : theme.colorScheme.primary;

    final row = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: danger
            ? theme.colorScheme.destructive.withValues(alpha: 0.06)
            : theme.colorScheme.card,
        borderRadius: theme.borderRadiusLg,
        border: Border.all(
          color: danger
              ? theme.colorScheme.destructive.withValues(alpha: 0.25)
              : theme.colorScheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40 * scale,
            height: 40 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
            ),
            child: Icon(icon, size: 20 * scale, color: accent),
          ),
          Gap(12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.typography.base.copyWith(
                    fontWeight: FontWeight.w600,
                    color: danger
                        ? theme.colorScheme.destructive
                        : theme.colorScheme.foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  Gap(2 * scale),
                  Text(
                    subtitle!,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Gap(8 * scale),
          trailing ??
              Icon(
                SangeetIcons.angleRight,
                size: 18 * scale,
                color: theme.colorScheme.mutedForeground,
              ),
        ],
      ),
    );

    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

/// Notifications row with a switch that reports the REAL permission.
///
/// Turning it on asks for permission (the only prompt in the app is
/// [OneSignalService.requestPermission]). Android offers no API to revoke it
/// from inside an app, so turning it off opens this app's system notification
/// settings instead of pretending to switch something off.
class _NotificationRow extends HookConsumerWidget {
  const _NotificationRow();

  @override
  Widget build(BuildContext context, ref) {
    final enabled = useState(OneSignalService.instance.hasPushPermission);

    useEffect(() {
      void observer(bool granted) => enabled.value = granted;
      OneSignalService.instance.addPermissionObserver(observer);
      return () {
        OneSignalService.instance.removePermissionObserver(observer);
      };
    }, []);

    return _ProfileRow(
      icon: SangeetIcons.ringtone,
      title: 'Notifications',
      subtitle: 'Stay updated with new bhajans and releases',
      onTap: () async {
        // Tapping the row does what the switch does: it asks for permission
        // when there is none, and otherwise explains where to turn it off.
        if (!enabled.value) {
          final granted = await OneSignalService.instance
              .requestPermission(fallbackToSettings: true);
          if (!context.mounted) return;
          enabled.value = granted;
          return;
        }
        await openAppSettings();
        if (!context.mounted) return;
        enabled.value = OneSignalService.instance.hasPushPermission;
        _showManagedElsewhereNotice(context);
      },
      trailing: Switch(
        value: enabled.value,
        onChanged: (value) async {
          if (value) {
            final granted = await OneSignalService.instance
                .requestPermission(fallbackToSettings: true);
            if (!context.mounted) return;
            enabled.value = granted;
            return;
          }
          // Off from inside the app is not possible on Android; send the user
          // to the one place that can do it.
          await openAppSettings();
          if (!context.mounted) return;
          enabled.value = OneSignalService.instance.hasPushPermission;
          _showManagedElsewhereNotice(context);
        },
      ),
    );
  }

  /// Explains why the switch cannot be turned off here, so the row never looks
  /// broken.
  void _showManagedElsewhereNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notifications are managed by Android'),
        content: const Text(
          'Turn Soulful Bhakti notifications off in the notification settings '
          'this screen just opened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// The ACCOUNT ACTIONS group: Sign out and Delete account, each behind the
/// same explicit confirmation the popup used.
class _AccountActions extends ConsumerWidget {
  const _AccountActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    Future<void> signOut() async {
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
      if (confirmed != true || !context.mounted) return;

      final failure = await ref.read(clerkAuthProvider.notifier).signOut();
      if (!context.mounted) return;
      if (failure != null) {
        _showError(context, failure);
        return;
      }
      ref.invalidate(clerkAuthProvider);
    }

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

      final failure =
          await ref.read(clerkAuthProvider.notifier).deleteAccount();
      if (!context.mounted) return;
      if (failure != null) {
        _showError(context, failure);
        return;
      }
      ref.invalidate(clerkAuthProvider);
    }

    return Column(
      children: [
        _ProfileRow(
          icon: SangeetIcons.logout,
          title: context.l10n.sign_out,
          onTap: signOut,
        ),
        Gap(10 * scale),
        _ProfileRow(
          icon: SangeetIcons.trash,
          title: 'Delete account',
          subtitle: 'Permanently remove your account and data',
          danger: true,
          onTap: deleteAccount,
        ),
      ],
    );
  }

  /// Surfaces a failed sign-out / delete, the same message the popup showed.
  /// The screen stays usable so the listener can retry.
  void _showError(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Something went wrong'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
