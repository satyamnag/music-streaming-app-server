import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/provider/referral/referral_provider.dart';

/// "Share & Earn" section shown in the profile dialog for signed-in users.
///
/// Displays the user's referral code, a share button, a small earnings
/// summary, and the program terms. Commission is tracked server-side from
/// verified purchases; payout rails are not implemented yet (track-first).
class ShareAndEarn extends ConsumerWidget {
  const ShareAndEarn({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final referral = ref.watch(referralProvider);
    final state = referral.value ?? const ReferralState();
    final code = state.code;

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
                SangeetIcons.share,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const Gap(8),
              Text(
                'Share & Earn',
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(8),
          if (referral.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (code == null) ...[
            Text(
              'Sign in to get your personal referral link.',
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ] else ...[
            _CodeRow(code: code),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: Button.primary(
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Listen to Soulful Bhakti — devotional music. '
                              'Use my code $code: ${referralShareLink(code)}',
                        ),
                      );
                    },
                    child: const Text('Share Link'),
                  ),
                ),
                const Gap(8),
                IconButton.ghost(
                  size: ButtonSize.small,
                  icon: const Icon(SangeetIcons.clipboard, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showToast(
                      context: context,
                      builder: (context, overlay) => const SurfaceCard(
                        child: Basic(content: Text('Code copied')),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Gap(10),
            _EarningsRow(
              label: 'Earned',
              value: '₹${state.totalAmount.toStringAsFixed(2)}',
            ),
            _EarningsRow(
              label: 'Referred',
              value: '${state.referralCount}',
            ),
            const Gap(8),
            Text(
              'Earn commission when someone you refer buys a subscription. '
              'Commission is tracked automatically after a successful purchase.',
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const Gap(4),
            Button.text(
              onPressed: () => _showTerms(context),
              child: const Text('View program terms'),
            ),
          ],
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Referral Program Terms'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Text(
              'Share your personal link and earn a commission when a new '
              'user you referred purchases a Soulful Bhakti subscription.\n\n'
              '• You must be signed in to generate a referral link.\n'
              '• You earn when a referred user completes a real, paid '
              'subscription (free trials and promotional offers do not '
              'qualify).\n'
              '• Commission is a fixed percentage of the plan price, set per '
              'plan, and is recorded automatically after a verified purchase.\n'
              '• A user can be attributed to one referrer only — the first '
              'valid referral link they opened before signing up.\n'
              '• Self-referral is not allowed.\n'
              '• Commission earnings are tracked in your account; payout '
              'processing is not yet available.\n'
              '• Abusive or fraudulent activity (fake accounts, self-referral, '
              'or incentivized reviews) will forfeit commissions and may '
              'result in suspension.\n\n'
              'These terms may change at any time. Continued use of the '
              'referral program after changes constitutes acceptance.',
              style: theme.typography.base,
            ),
          ),
        ),
        actions: [
          Button.primary(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final String code;
  const _CodeRow({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: theme.borderRadiusMd,
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              style: theme.typography.base.copyWith(
                color: theme.colorScheme.foreground,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            'Your code',
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  final String label;
  final String value;
  const _EarningsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          Text(
            value,
            style: theme.typography.small.copyWith(
              color: theme.colorScheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
