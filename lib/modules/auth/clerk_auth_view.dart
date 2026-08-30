import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';

/// Google sign-in auth view, rendered as a polished modal popup dialog that
/// overlays the app.
///
/// Flow:
///  1. tap "Continue with Google"
///  2. the native Clerk SDK opens Google's account chooser
///  3. pick an account -> signed in (new users are signed up automatically)
///
/// UX highlights:
///  - inline error feedback with destructive styling (real failures only)
///  - canceling the Google flow (BACK / closing the Custom Tab) closes the
///    dialog cleanly with no error message
///  - loading spinner on the button while the request is in flight
///  - safe against double-submits and unmounted-context use
class ClerkAuthView extends HookConsumerWidget {
  const ClerkAuthView({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(clerkAuthProvider);

    // If Clerk does not initialize within a reasonable window (e.g. the Clerk
    // Native API is disabled in the dashboard, or the SDK cannot reach its
    // servers), stop showing an endless loading spinner and surface a clear,
    // actionable error instead.
    final timedOut = useState(false);
    useEffect(() {
      if (auth.isLoading || (auth.value?.initialized ?? false)) {
        timedOut.value = false;
        return null;
      }
      final timer = Timer(const Duration(seconds: 8), () {
        timedOut.value = true;
      });
      return timer.cancel;
    }, [auth.isLoading, auth.value?.initialized]);

    Widget body;
    if (auth.isLoading) {
      body = _StatusBox(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    } else {
      final state = auth.value ?? const ClerkAuthState();
      if (!state.initialized && !timedOut.value) {
        body = _StatusBox(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        );
      } else if (!state.initialized) {
        // Clerk failed to initialize — explain the issue instead of spinning.
        body = SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Color(0xFF9C4D5B),
              ),
              const Gap(12),
              Text(
                'Sign-in is temporarily unavailable.',
                textAlign: TextAlign.center,
                style: theme.typography.base.copyWith(
                  color: theme.colorScheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(6),
              Text(
                'Please make sure Clerk Native API is enabled and try again.',
                textAlign: TextAlign.center,
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const Gap(16),
              SizedBox(
                width: double.infinity,
                child: Button.primary(
                  onPressed: () {
                    timedOut.value = false;
                    ref.invalidate(clerkAuthProvider);
                  },
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        );
      } else if (state.signedIn) {
        body = SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 64,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9C4D5B), Color(0xFF6E2730)],
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Color(0xFFFFFFFF),
                    size: 32,
                  ),
                ),
              ),
              const Gap(16),
              Text(
                context.l10n.signed_in_as(
                  (state.email?.isNotEmpty ?? false)
                      ? state.email!
                      : (state.userId ?? ''),
                ),
                textAlign: TextAlign.center,
                style: theme.typography.large.copyWith(
                  color: theme.colorScheme.foreground,
                ),
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                child: Button.destructive(
                  onPressed: () async {
                    await ref.read(clerkAuthProvider.notifier).signOut();
                    ref.invalidate(clerkAuthProvider);
                  },
                  child: Text(context.l10n.sign_out),
                ),
              ),
            ],
          ),
        );
      } else {
        body = const _GoogleSignInView();
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ModalContainer(
          filled: true,
          fillColor: theme.colorScheme.popover,
          borderRadius: theme.borderRadiusXxl,
          borderWidth: 1,
          borderColor: theme.colorScheme.muted,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/branding/sangeet-logo.png',
                      height: 28,
                      width: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Gap(10),
                  Text(
                    'Soulful Bhakti',
                    style: theme.typography.h3.copyWith(
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                ],
              ),
              const Gap(16),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// A fixed-size box used to center a status indicator (e.g. spinner) inside
/// the dialog while Clerk is initializing.
class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 180,
      child: Center(child: child),
    );
  }
}

/// Google-only sign-in view: a single "Continue with Google" button that
/// launches the native Clerk OAuth flow (Google account chooser). No email,
/// name or OTP is ever collected — picking an account is all that is needed.
class _GoogleSignInView extends HookConsumerWidget {
  const _GoogleSignInView();

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final submitting = useState(false);
    final error = useState<String?>(null);
    var requestInFlight = false;

    void clearError() {
      if (error.value != null) error.value = null;
    }

    Future<void> continueWithGoogle() async {
      if (requestInFlight) return;
      requestInFlight = true;
      submitting.value = true;
      clearError();
      try {
        final outcome =
            await ref.read(clerkAuthProvider.notifier).signInWithGoogle();
        if (!context.mounted) return;
        switch (outcome) {
          case AuthResultSuccess():
            ref.invalidate(clerkAuthProvider);
            // Signed in successfully — close the login popup smoothly.
            if (context.mounted) {
              Navigator.of(context).maybePop();
            }
          case AuthResultCancelled():
            // The user dismissed the Google flow (BACK / closed the Custom
            // Tab) — no error to show, just close the dialog cleanly.
            if (context.mounted) {
              Navigator.of(context).maybePop();
            }
          case AuthResultFailure(:final message):
            error.value = message;
        }
      } catch (_) {
        if (context.mounted) error.value = 'Something went wrong. Please try again.';
      } finally {
        submitting.value = false;
        requestInFlight = false;
      }
    }

    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                SangeetIcons.login,
                size: 16,
                color: Color(0xFF9C4D5B),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  'Sign in with your Google account to get started.',
                  textAlign: TextAlign.left,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: Button.outline(
              onPressed: submitting.value ? null : continueWithGoogle,
              child: submitting.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/images/logos/google-g.svg',
                          width: 20,
                          height: 20,
                        ),
                        const Gap(12),
                        const Text('Continue with Google'),
                      ],
                    ),
            ),
          ),
          if (error.value != null) ...[
            const Gap(10),
            _InlineError(text: error.value!),
          ],
        ],
      ),
    );
  }
}

/// Renders a friendly inline error message with destructive styling.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.destructive.withValues(alpha: 0.08),
        borderRadius: theme.borderRadiusMd,
        border: Border.all(
          color: theme.colorScheme.destructive.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: theme.colorScheme.destructive,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              text,
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
