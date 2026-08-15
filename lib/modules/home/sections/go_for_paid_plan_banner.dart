import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

/// A promotional banner shown at the top of the home screen for free users:
/// "Go for Paid Plan".
///
/// Tapping it guides the user through the sign-in (if not signed in) and then
/// presents the Superwall paywall with the monthly (₹120) and yearly (₹1,200)
/// plans. Hidden for users who already have an active subscription.
class GoForPaidPlanBanner extends HookConsumerWidget {
  const GoForPaidPlanBanner({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final isPremium = PremiumAccess.isPremiumUser(ref);
    final busy = useState(false);

    if (isPremium) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: GestureDetector(
          onTap: busy.value
              ? null
              : () async {
                  busy.value = true;
                  try {
                    await PremiumAccess.promptForPaidPlan(context, ref);
                  } finally {
                    if (context.mounted) busy.value = false;
                  }
                },
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9C4D5B), Color(0xFF6E2730)],
              ),
              borderRadius: theme.borderRadiusLg,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6E2730).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 22,
                  color: Colors.white,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Go for Paid Plan',
                        style: theme.typography.base.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Unlock every song — monthly ₹120 / yearly ₹1,200',
                        style: theme.typography.small.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy.value)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    SangeetIcons.angleRight,
                    size: 18,
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
