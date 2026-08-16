import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/auth/clerk_auth_view.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/provider/coupon/coupon_provider.dart';

/// Persistent (non-popup) entry point for applying an affiliate coupon code.
///
/// Shown in the profile dialog while the user has not yet applied a coupon.
/// Tapping it opens the same [CouponEntry] popup. Once a coupon is
/// successfully applied it shows the applied state instead (immutable).
class CouponStatusTile extends ConsumerWidget {
  const CouponStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coupon = ref.watch(couponProvider);
    final state = coupon.value ?? const CouponState();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.4),
        borderRadius: theme.borderRadiusMd,
        border: Border.all(color: theme.colorScheme.muted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                state.redeemed
                    ? SangeetIcons.done
                    : SangeetIcons.couponTag,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const Gap(8),
              Text(
                state.redeemed ? 'Coupon applied' : 'Have a coupon code?',
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(6),
          if (state.redeemed)
            Text(
              state.affiliateName != null
                  ? 'You are supporting ${state.affiliateName}.'
                  : 'Your coupon has been applied.',
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            )
          else
            Text(
              'Enter a code you received from a creator to support them '
              'when you subscribe.',
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          if (!state.redeemed) ...[
            const Gap(8),
            Button.primary(
              onPressed: () => CouponEntry.prompt(context, ref),
              child: const Text('Enter code'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Minimal affiliate coupon entry — a small "Have a coupon code?" affordance
/// shown to free users in the premium gating flow.
///
/// Affiliate marketing (coupon issuance, tracking, payouts) happens entirely
/// OUTSIDE the app. This is the only in-app surface: the user types a code
/// they received from an affiliate, the server validates + records the
/// attribution once, and the affiliate earns a commission when the user later
/// subscribes. Redemption is immutable (one code per user).
class CouponEntry extends HookConsumerWidget {
  const CouponEntry({super.key});

  /// Shows the coupon entry dialog. Returns true if a coupon was applied.
  static Future<bool> prompt(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CouponEntry(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coupon = ref.watch(couponProvider);
    final state = coupon.value ?? const CouponState();
    final controller = useTextEditingController();
    final error = useState<String?>(null);
    final busy = useState(false);

    return AlertDialog(
      title: const Text('Have a coupon code?'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.redeemed
                  ? (state.affiliateName != null
                      ? 'You are already supporting '
                          '${state.affiliateName}. Thank you!'
                      : 'You have already applied a coupon.')
                  : 'Enter the code you received from a creator or '
                      'affiliate. Applying it supports them when you '
                      'subscribe.',
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const Gap(12),
            if (state.redeemed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: theme.borderRadiusMd,
                ),
                child: Text(
                  state.code ?? '',
                  style: theme.typography.base.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              )
            else ...[
              TextField(
                controller: controller,
                enabled: !busy.value,
                placeholder: const Text('e.g. BHAKTI25'),
                onSubmitted: (value) {
                  if (busy.value) return;
                  _apply(context, ref, controller, error, busy);
                },
              ),
              if (error.value != null) ...[
                const Gap(8),
                Text(
                  error.value!,
                  style: theme.typography.xSmall.copyWith(
                    color: theme.colorScheme.destructive,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        Button.text(
          onPressed: busy.value
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        if (!state.redeemed)
          Button.primary(
            onPressed: busy.value
                ? null
                : () => _apply(context, ref, controller, error, busy),
            child: busy.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Apply'),
          ),
      ],
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    ValueNotifier<String?> error,
    ValueNotifier<bool> busy,
  ) async {
    error.value = null;
    final code = controller.text.trim();
    if (code.isEmpty) {
      error.value = 'Please enter a coupon code.';
      return;
    }

    // Applying a coupon records attribution against the signed-in Clerk user,
    // so a sign-in is required. If the user is not signed in, prompt them
    // first (same Google-only dialog used everywhere in the app).
    var auth = ref.read(clerkAuthProvider).valueOrNull;
    if (auth?.signedIn != true) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const ClerkAuthView(),
      );
      auth = ref.read(clerkAuthProvider).valueOrNull;
      if (auth?.signedIn != true) {
        error.value = 'Please sign in to apply a coupon.';
        return;
      }
    }

    busy.value = true;
    try {
      final message = await ref.read(couponProvider.notifier).redeem(code);
      if (context.mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(content: Text(message)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      if (context.mounted) busy.value = false;
    }
  }
}
