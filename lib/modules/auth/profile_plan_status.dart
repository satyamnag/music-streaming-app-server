import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/premium/paid_crown_badge.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/services/entitlement/entitlement_service.dart';
import 'package:sangeet/services/superwall_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Exact Google Play Console product ids for the two subscription plans.
/// Matched first so plan names never depend on a keyword heuristic.
const String kMonthlyProductId = 'soulful_monthly';
const String kYearlyProductId = 'soulful_yearly';

String _fmtDate(DateTime? d) {
  if (d == null) return '-';
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

bool _isYearly(String productId) =>
    productId == kYearlyProductId ||
    productId.toLowerCase().contains('year') ||
    productId.toLowerCase().contains('annual') ||
    productId.toLowerCase().contains('12');

bool _isMonthly(String productId) =>
    productId == kMonthlyProductId || productId.toLowerCase().contains('month');

/// Human name for a store product id ("soulful_yearly" -> "Yearly Plan").
String planNameFor(String productId) {
  if (_isYearly(productId)) return 'Yearly Plan';
  if (_isMonthly(productId)) return 'Monthly Plan';
  return productId;
}

/// Everything the "YOUR SUBSCRIPTION" card needs to draw, decided in one pure
/// function so the rule can be unit-tested without Superwall or a device.
///
/// ## Why this exists (the bug it fixes)
///
/// The card used to derive the plan from `CustomerInfo.subscriptions` ONLY —
/// the *local transaction list*. The playback gate
/// (`PremiumAccess.isPremiumUser`) reads `subscriptionStatus`, which Superwall
/// derives from the user's **active entitlements**. Those two are not the same
/// list: a Google Play subscriber whose purchase was validated server-side
/// (recovered on a new install, renewed, or attached to an existing account)
/// can hold an active entitlement while `subscriptions` is empty.
///
/// The result was exactly what the owner reported: locked tracks unlocked, but
/// the card said "Free plan / Upgrade to Pro". A card must never contradict the
/// gate that actually decides playback, so the precedence here is:
///
///   1. an active `SubscriptionTransaction`   — richest detail (dates, renewal);
///   2. an active `Entitlement`               — what actually grants access;
///   3. Superwall's `subscriptionStatus`      — the gate's own field;
///   4. the server-verified Razorpay/web answer.
///
/// Free is therefore only shown when **every** source says free.
class PlanCardView {
  const PlanCardView({
    required this.isPremium,
    required this.isChecking,
    required this.planName,
    required this.detail,
  });

  /// Whether the listener holds a paid plan on EITHER rail.
  final bool isPremium;

  /// Whether an answer is still outstanding: the card shows a spinner instead
  /// of a plan name, so a paying user never sees "Free plan" first.
  final bool isChecking;

  /// Plan title, e.g. "Yearly Plan", or "Free plan".
  final String planName;

  /// One muted line of detail under the title.
  final String detail;
}

/// The card's decision rule. Pure: no clocks, no channels, no providers.
///
/// [signedIn] is NOT optional on purpose. Superwall keeps a status for the
/// ANONYMOUS device user too, so a fresh install with nobody signed in reports
/// `subscriptionStatus.isActive` — measured on a real phone, where the card read
/// "Premium Plan" above "You are not signed in". The playback gate never had
/// that hole: `PremiumAccess.isPremiumUser` is
/// `signedIn && (...)`. The card applies the same AND here, in one place, so no
/// future source can be added without it.
PlanCardView planCardView({
  required bool signedIn,
  required CustomerInfo? info,
  required bool playActive,
  required bool webActive,
  required String? webPlan,
  required DateTime? webEnd,
  required bool loading,
  required bool entitlementPending,
}) {
  // Nobody is premium while signed out — same rule as the gate that decides
  // whether a paid track actually plays.
  if (!signedIn) {
    return const PlanCardView(
      isPremium: false,
      isChecking: false,
      planName: 'Free plan',
      detail: 'Enjoy devotional music and bhakti playlists',
    );
  }

  SubscriptionTransaction? activeSub;
  for (final sub in info?.subscriptions ?? const <SubscriptionTransaction>[]) {
    if (sub.isActive && !sub.isRevoked) {
      activeSub = sub;
      break;
    }
  }

  Entitlement? activeEntitlement;
  for (final ent in info?.entitlements ?? const <Entitlement>[]) {
    if (ent.isActive) {
      activeEntitlement = ent;
      break;
    }
  }

  final isPremium =
      activeSub != null || activeEntitlement != null || playActive || webActive;

  // Only the web rail is active: it is the one answer that carries a plan slug
  // and an end date without Superwall's involvement.
  final webOnly = activeSub == null &&
      activeEntitlement == null &&
      !playActive &&
      webActive;

  final String planName;
  final String detail;

  if (activeSub != null) {
    planName = planNameFor(activeSub.productId);
    final start = _fmtDate(activeSub.purchaseDate);
    final end = activeSub.expirationDate != null
        ? _fmtDate(activeSub.expirationDate)
        : (activeSub.willRenew ? 'renews automatically' : '-');
    final renew =
        activeSub.willRenew ? ' · auto-renew on' : ' · auto-renew off';
    detail = 'Started $start · valid until $end$renew';
  } else if (activeEntitlement != null) {
    // The entitlement's own product id is the most specific name available.
    planName = activeEntitlement.latestProductId != null
        ? planNameFor(activeEntitlement.latestProductId!)
        : 'Premium Plan';
    if (activeEntitlement.expiresAt != null) {
      final start = activeEntitlement.startsAt != null
          ? _fmtDate(activeEntitlement.startsAt)
          : '-';
      final renew =
          activeEntitlement.willRenew == true ? ' · auto-renew on' : '';
      detail =
          'Started $start · valid until ${_fmtDate(activeEntitlement.expiresAt)}$renew';
    } else if (activeEntitlement.isLifetime == true) {
      detail = 'Lifetime access';
    } else {
      detail = 'Active subscription';
    }
  } else if (playActive) {
    // The gate says premium but Superwall has not handed us the detail yet.
    planName = 'Premium Plan';
    detail = 'Active subscription';
  } else if (webOnly) {
    planName = planNameFor(webPlan ?? 'yearly');
    detail = webEnd != null
        ? 'Active until ${_fmtDate(webEnd)}'
        : 'Active subscription';
  } else {
    planName = 'Free plan';
    detail = 'Enjoy devotional music and bhakti playlists';
  }

  return PlanCardView(
    isPremium: isPremium,
    isChecking: !isPremium && (loading || entitlementPending),
    planName: planName,
    detail: detail,
  );
}

/// The "YOUR SUBSCRIPTION" card on the profile screen.
///
/// Shows the listener's real plan, exactly as the reference design lays it out:
/// a tinted card with the section label, the plan name beside a `CURRENT PLAN`
/// badge, one line of description and — on the free plan — a full-width
/// "Upgrade to Pro" button.
///
/// **The card must agree with the playback gate.** Both rails are read here
/// through [planCardView], whose precedence is documented on that function; the
/// Play verdict comes from [PremiumAccess.isPlaySubscriptionActive], the same
/// field `isPremiumUser` uses, so the two cannot disagree again.
class ProfilePlanStatus extends HookConsumerWidget {
  const ProfilePlanStatus({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final customerInfo = useState<CustomerInfo?>(null);
    final loading = useState(true);
    // The gate's own Play verdict, seeded from [PremiumAccess] and kept current
    // by the same stream that feeds it, so the card can never contradict the
    // gate that decides whether a paid track plays.
    final playActive = useState<bool>(PremiumAccess.isPlaySubscriptionActive);

    useEffect(() {
      var active = true;
      StreamSubscription<CustomerInfo>? infoSub;
      StreamSubscription<SubscriptionStatus>? statusSub;

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
      infoSub = SuperwallService.instance.customerInfoStream.listen((info) {
        if (!active || !context.mounted) return;
        customerInfo.value = info;
        loading.value = false;
      });

      // The gate's signal. `CustomerInfo` alone is not enough: it lists LOCAL
      // transactions, while access comes from entitlements / subscriptionStatus
      // (see planCardView).
      statusSub = SuperwallService.instance.subscriptionStatus.listen((status) {
        if (!active || !context.mounted) return;
        playActive.value = status.isActive;
      });

      return () {
        active = false;
        infoSub?.cancel();
        statusSub?.cancel();
      };
    }, []);

    final view = planCardView(
      // The gate's own sign-in test, so the card cannot claim a plan for the
      // anonymous device user Superwall also keeps a status for.
      signedIn: PremiumAccess.isSignedIn(ref),
      info: customerInfo.value,
      playActive: playActive.value,
      webActive: EntitlementSignal.isActive,
      webPlan: EntitlementSignal.plan,
      webEnd: EntitlementSignal.currentEnd,
      loading: loading.value,
      entitlementPending: EntitlementSignal.isPending,
    );

    final primary = theme.colorScheme.primary;

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
          // "Checking" while an answer for this user is still outstanding, so a
          // paying user never sees "Free plan" first. isPending is bounded at
          // 45 s, so it can never become a permanent spinner.
          if (view.isChecking)
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
                  view.planName,
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
              view.detail,
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            if (!view.isPremium) ...[
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
