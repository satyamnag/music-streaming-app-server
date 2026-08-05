import 'package:flutter/material.dart'
    show Icons, TextInputAction, ValueChanged, Color, EdgeInsets;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';

/// Passwordless **email OTP** auth view, rendered as a polished modal popup
/// dialog that overlays the app.
///
/// Flow:
///  1. enter the email address
///  2. tap "Send code" -> an OTP is sent
///  3. enter the OTP -> tap "Verify" -> signed in
///
/// UX highlights:
///  - inline email validation (required + format)
///  - inline error feedback with destructive styling
///  - loading spinners on action buttons while a request is in flight
///  - auto-focus on the active input field
///  - keyboard "submit" action triggers the primary action
///  - animated transition between the email and OTP steps
///  - safe against double-submits and unmounted-context use
class ClerkAuthView extends HookConsumerWidget {
  const ClerkAuthView({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(clerkAuthProvider);

    Widget body;
    if (auth.isLoading) {
      body = _StatusBox(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    } else {
      final state = auth.value ?? const ClerkAuthState();
      if (!state.initialized) {
        body = _StatusBox(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
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
                context.l10n.signed_in_as(state.userId ?? ''),
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
        body = const _OtpSignInView();
      }
    }

    return AlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            SangeetIcons.music,
            size: 22,
            color: Color(0xFF9C4D5B),
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
      content: body,
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

class _OtpSignInView extends HookConsumerWidget {
  const _OtpSignInView();

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final otpSent = useState(false);
    final submitting = useState(false);
    final error = useState<String?>(null);

    final identifier = useTextEditingController();
    final code = useTextEditingController();
    useValueListenable(identifier);
    useValueListenable(code);

    final emailFocus = useFocusNode();
    final codeFocus = useFocusNode();
    var requestInFlight = false;

    void clearError() {
      if (error.value != null) error.value = null;
    }

    String? validateEmail(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return 'Please enter your email address';
      }
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(trimmed)) {
        return 'Please enter a valid email address';
      }
      return null;
    }

    String? validateCode(String value) {
      if (value.trim().length < 4) {
        return 'Please enter the code sent to your email';
      }
      return null;
    }

    Future<void> sendCode() async {
      final emailError = validateEmail(identifier.text);
      if (emailError != null) {
        error.value = emailError;
        emailFocus.requestFocus();
        return;
      }
      if (requestInFlight) return;
      requestInFlight = true;
      clearError();
      submitting.value = true;
      try {
        final failure = await ref.read(clerkAuthProvider.notifier).sendOtp(
              identifier: identifier.text.trim(),
            );
        if (!context.mounted) return;
        if (failure != null) {
          error.value = failure;
        } else {
          otpSent.value = true;
          codeFocus.requestFocus();
          showToast(
            context: context,
            location: ToastLocation.bottomCenter,
            dismissible: true,
            builder: (context, overlay) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.popover,
                borderRadius: theme.borderRadiusLg,
                border: Border.all(color: theme.colorScheme.muted),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2E7D32),
                    size: 20,
                  ),
                  const Gap(10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code sent',
                          style: theme.typography.base.copyWith(
                            color: theme.colorScheme.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Check your email for the one-time code.',
                          style: theme.typography.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Button.text(
                    onPressed: overlay.close,
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) error.value = 'Something went wrong. Please try again.';
      } finally {
        submitting.value = false;
        requestInFlight = false;
      }
    }

    Future<void> verifyCode() async {
      final codeError = validateCode(code.text);
      if (codeError != null) {
        error.value = codeError;
        codeFocus.requestFocus();
        return;
      }
      if (requestInFlight) return;
      requestInFlight = true;
      clearError();
      submitting.value = true;
      try {
        final failure = await ref.read(clerkAuthProvider.notifier).verifyOtp(
              code: code.text.trim(),
            );
        if (!context.mounted) return;
        if (failure != null) {
          error.value = failure;
        } else {
          ref.invalidate(clerkAuthProvider);
        }
      } catch (_) {
        if (context.mounted) error.value = 'Something went wrong. Please try again.';
      } finally {
        submitting.value = false;
        requestInFlight = false;
      }
    }

    void goBackToEmail() {
      otpSent.value = false;
      clearError();
      emailFocus.requestFocus();
    }

    return SizedBox(
      width: 340,
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: otpSent.value
              ? _buildOtpStep(
                  theme: theme,
                  l10n: l10n,
                  controller: code,
                  focusNode: codeFocus,
                  submitting: submitting.value,
                  error: error.value,
                  onChanged: (_) => clearError(),
                  onSubmit: verifyCode,
                  onVerify: verifyCode,
                  onBack: goBackToEmail,
                )
              : _buildEmailStep(
                  theme: theme,
                  l10n: l10n,
                  controller: identifier,
                  focusNode: emailFocus,
                  submitting: submitting.value,
                  error: error.value,
                  onChanged: (_) => clearError(),
                  onSubmit: sendCode,
                  onSend: sendCode,
                ),
        ),
      ),
    );
  }

  Widget _buildEmailStep({
    required ThemeData theme,
    required AppLocalizations l10n,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool submitting,
    required String? error,
    required ValueChanged<String> onChanged,
    required VoidCallback onSubmit,
    required VoidCallback onSend,
  }) {
    return Column(
      key: const ValueKey('otp-email-step'),
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
                l10n.sign_in_with_otp,
                textAlign: TextAlign.left,
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        const Gap(16),
        FormField<dynamic>(
          key: const FormKey<dynamic>('otp-identifier'),
          label: Text(l10n.email),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            placeholder: const Text('you@example.com'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        if (error != null) ...[
          const Gap(10),
          _InlineError(text: error),
        ],
        const Gap(16),
        Button.primary(
          enabled: !submitting && controller.text.trim().isNotEmpty,
          onPressed: onSend,
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.send_code),
        ),
      ],
    );
  }

  Widget _buildOtpStep({
    required ThemeData theme,
    required AppLocalizations l10n,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool submitting,
    required String? error,
    required ValueChanged<String> onChanged,
    required VoidCallback onSubmit,
    required VoidCallback onVerify,
    required VoidCallback onBack,
  }) {
    return Column(
      key: const ValueKey('otp-code-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 16,
              color: Color(0xFF9C4D5B),
            ),
            const Gap(8),
            Expanded(
              child: Text(
                l10n.enter_otp_sent,
                textAlign: TextAlign.left,
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        const Gap(16),
        FormField<dynamic>(
          key: const FormKey<dynamic>('otp-code'),
          label: Text(l10n.verification_code),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            placeholder: Text(l10n.verification_code_hint),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        if (error != null) ...[
          const Gap(10),
          _InlineError(text: error),
        ],
        const Gap(16),
        Button.primary(
          enabled: !submitting && controller.text.trim().isNotEmpty,
          onPressed: onVerify,
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.verify),
        ),
        const Gap(4),
        Button.text(
          onPressed: submitting ? null : onBack,
          child: Text(l10n.change_identifier),
        ),
      ],
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
