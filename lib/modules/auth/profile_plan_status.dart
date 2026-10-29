import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/premium/paid_crown_badge.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/services/superwall_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// The "YOUR SUBSCRIPTION" card on the profile screen.
///
/// Shows the listener's real plan, exactly as the reference design lays it out:
/// a tinted card with the section label, the plan name beside a `CURRENT PLAN`
/// badge, one line of description and — on the free plan — a full-width
/// "Upgrade to Pro" button.
///
/// The data is unchanged from the popup this replaced: [SuperwallService]'s
/// [CustomerInfo], whose active, non-revoked [SubscriptionTransaction] (when
/// there is one) supplies the plan name, the duration and the start/end dates.
/// The upgrade button runs the same [PremiumAccess.promptForPaidPlan] gate and
/// then re-reads the customer info, so a fresh purchase is reflected
/// immediately.
class ProfilePlanStatus extends HookConsumerWidget {
  const ProfilePlanStatus({super.key});

  /// Exact Google Play Console product ids for the two subscription plans.
  /// Matched first so plan names never depend on the keyword heuristic below.
  static const String monthlyProductId = 'soulful_monthly';
  static const String yearlyProductId = 'soulful_yearly';

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  bool _isYearly(String productId) =>
      productId == yearlyProductId ||
      productId.toLowerCase().contains('year') ||
      productId.toLowerCase().contains('annual') ||
      productId.toLowerCase().contains('12');

  bool _isMonthly(String productId) =>
      productId == monthlyProductId ||
      productId.toLowerCase().contains('month');

  String _planName(String productId) {
    if (_isYearly(productId)) {
      return 'Yearly Plan';
    }
    if (_isMonthly(productId)) {
      return 'Monthly Plan';
    }
    return productId;
  }

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final customerInfo = useState<CustomerInfo?>(null);
    final loading = useState(true);

    useEffect(() {
      var active = true;
      StreamSubscription<CustomerInfo>? sub;

      // Initial load: show the spinner until the first info arrives.
      SuperwallService.instance.getCustomerInfo().then((info) {
        if (!active || !context.mounted) return;
        customerInfo.value = info;
        loading.value = false;
      }).catchError((_) {
        if (active && context.mounted) loading.value = false;
      });

      // Refresh whenever customer info changes (e.g. immediately after a
      // checkout or restore completes anywhere in the app), so the plan name,
      // start date and expiry date always reflect the current subscription.
      sub = SuperwallService.instance.customerInfoStream.listen((info) {
        if (!active || !context.mounted) return;
        customerInfo.value = info;
        loading.value = false;
      });

      return () {
        active = false;
        sub?.cancel();
      };
    }, []);

    final info = customerInfo.value;
    SubscriptionTransaction? activeSub;
    if (info != null) {
      for (final sub in info.subscriptions) {
        if (sub.isActive && !sub.isRevoked) {
          activeSub = sub;
          break;
        }
      }
    }

    final primary = theme.colorScheme.primary;

    /// Detail lines for a PAID plan: the same facts the popup listed, as one
    /// muted sentence instead of a table, so the card keeps the reference's
    /// shape at both ends of the plan spectrum.
    String paidDetail(SubscriptionTransaction sub) {
      final start = _fmtDate(sub.purchaseDate);
      final end = sub.expirationDate != null
          ? _fmtDate(sub.expirationDate)
          : (sub.willRenew ? 'renews automatically' : '-');
      final renew = sub.willRenew ? ' · auto-renew on' : ' · auto-renew off';
      return 'Started $start · valid until $end$renew';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: theme.borderRadiusLg,
        border: Border.all(color: primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YOUR SUBSCRIPTION',
            style: theme.typography.xSmall.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: primary.withValues(alpha: 0.9),
            ),
          ),
          Gap(10 * scale),
          if (loading.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            // Plan name + the badge. One row, wrapping rather than clipping on
            // a narrow phone with a large system text scale.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10 * scale,
              runSpacing: 6 * scale,
              children: [
                Text(
                  activeSub != null ? _planName(activeSub.productId) : 'Free plan',
                  style: theme.typography.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground,
                  ),
                ),
                _CurrentPlanBadge(primary: primary),
              ],
            ),
            Gap(6 * scale),
            Text(
              activeSub != null
                  ? paidDetail(activeSub)
                  : 'Enjoy devotional music and bhakti playlists',
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            if (activeSub == null) ...[
              Gap(14 * scale),
              SizedBox(
                width: double.infinity,
                child: Button(
                  style: const ButtonStyle.primary(size: ButtonSize.normal),
                  onPressed: () async {
                    if (!context.mounted) return;
                    final purchased = await PremiumAccess.promptForPaidPlan(
                      context,
                      ref,
                    );
                    // Refresh the plan status after the paywall closes so a
                    // fresh purchase is reflected immediately.
                    if (!context.mounted || !purchased) return;
                    loading.value = true;
                    try {
                      final info =
                          await SuperwallService.instance.getCustomerInfo();
                      if (!context.mounted) return;
                      customerInfo.value = info;
                    } catch (_) {
                      // Keep the current state if the refresh fails.
                    } finally {
                      if (context.mounted) loading.value = false;
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PaidCrown(size: 16 * scale),
                      Gap(8 * scale),
                      const Text('Upgrade to Pro'),
                      const Spacer(),
                      Icon(
                        SangeetIcons.angleRight,
                        size: 16 * scale,
                        color: theme.colorScheme.primaryForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The small "CURRENT PLAN" pill beside the plan name.
class _CurrentPlanBadge extends StatelessWidget {
  final Color primary;
  const _CurrentPlanBadge({required this.primary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * scale,
        vertical: 3 * scale,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Text(
        'CURRENT PLAN',
        style: theme.typography.xSmall.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }
}
