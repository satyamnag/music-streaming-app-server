import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/services/superwall_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Displays the signed-in user's active subscription plan details inside the
/// profile dialog: plan name, duration, start date and end date.
///
/// Reads the latest [CustomerInfo] from Superwall. When the user has an active
/// subscription transaction, the plan/product id, purchase (start) date and
/// expiration (end) date are shown. Otherwise a "Free" status is shown.
class ProfilePlanStatus extends HookConsumerWidget {
  const ProfilePlanStatus({super.key});

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _planName(String productId) {
    final lower = productId.toLowerCase();
    if (lower.contains('year') || lower.contains('annual') || lower.contains('12')) {
      return 'Yearly Plan (₹999/yr)';
    }
    if (lower.contains('month')) {
      return 'Monthly Plan (₹99/mo)';
    }
    return productId;
  }

  String _durationLabel(String productId) {
    final lower = productId.toLowerCase();
    if (lower.contains('year') || lower.contains('annual') || lower.contains('12')) {
      return '1 year';
    }
    if (lower.contains('month')) {
      return '1 month';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final customerInfo = useState<CustomerInfo?>(null);
    final loading = useState(true);

    useEffect(() {
      SuperwallService.instance.getCustomerInfo().then((info) {
        if (!context.mounted) return;
        customerInfo.value = info;
        loading.value = false;
      }).catchError((_) {
        if (context.mounted) loading.value = false;
      });
      return null;
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
          Text(
            'Subscription',
            style: theme.typography.small.copyWith(
              color: theme.colorScheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          if (loading.value)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (activeSub != null) ...[
            _Row(label: 'Plan', value: _planName(activeSub.productId)),
            _Row(label: 'Duration', value: _durationLabel(activeSub.productId)),
            _Row(label: 'Start Date', value: _fmtDate(activeSub.purchaseDate)),
            _Row(
              label: 'End Date',
              value: _fmtDate(activeSub.expirationDate),
            ),
            _Row(
              label: 'Auto-renew',
              value: activeSub.willRenew ? 'On' : 'Off',
            ),
          ] else
            Text(
              'Free plan',
              style: theme.typography.base.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

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
            style: theme.typography.small.copyWith(
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
