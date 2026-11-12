// The rule behind the profile "YOUR SUBSCRIPTION" card.
//
// The reported defect: a listener who paid through Google Play could play every
// locked track (so the gate said premium) while the card said "Free plan /
// Upgrade to Pro". The card used to derive the plan from
// `CustomerInfo.subscriptions` — the LOCAL transaction list — while the gate
// reads Superwall's `subscriptionStatus`, which comes from ACTIVE ENTITLEMENTS.
// A purchase validated server-side (restored on a new install, renewed, or
// attached to the account) has an entitlement but no local transaction.
//
// These tests pin the precedence so the card can never contradict the gate:
// active transaction > active entitlement > subscriptionStatus > web rail, and
// "Free plan" only when every source says free.
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/auth/profile_plan_status.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

CustomerInfo _info({
  List<SubscriptionTransaction> subscriptions = const [],
  List<Entitlement> entitlements = const [],
}) =>
    CustomerInfo(
      subscriptions: subscriptions,
      nonSubscriptions: const [],
      entitlements: entitlements,
      userId: 'user_test',
    );

SubscriptionTransaction _tx({
  String productId = 'soulful_yearly',
  bool isActive = true,
  bool isRevoked = false,
  bool willRenew = true,
  DateTime? expirationDate,
}) =>
    SubscriptionTransaction(
      transactionId: 'tx_1',
      productId: productId,
      purchaseDate: DateTime.utc(2026, 12, 1),
      willRenew: willRenew,
      isRevoked: isRevoked,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: isActive,
      expirationDate: expirationDate ?? DateTime.utc(2027, 12, 1),
    );

PlanCardView _view({
  CustomerInfo? info,
  bool playActive = false,
  bool webActive = false,
  String? webPlan,
  DateTime? webEnd,
  bool loading = false,
  bool entitlementPending = false,
}) =>
    planCardView(
      info: info,
      playActive: playActive,
      webActive: webActive,
      webPlan: webPlan,
      webEnd: webEnd,
      loading: loading,
      entitlementPending: entitlementPending,
    );

void main() {
  group('the reported bug: paid on Google Play, card said "Free plan"', () {
    test('an active entitlement with NO local transaction is premium', () {
      final view = _view(
        info: _info(
          subscriptions: const [], // exactly the failing case
          entitlements: [
            Entitlement(
              id: 'premium',
              isActive: true,
              latestProductId: 'soulful_yearly',
              startsAt: DateTime.utc(2026, 11, 20),
              expiresAt: DateTime.utc(2027, 11, 20),
              willRenew: true,
              store: ProductStore.playStore,
            ),
          ],
        ),
        playActive: true,
      );

      expect(view.isPremium, isTrue);
      expect(view.planName, 'Yearly Plan');
      expect(view.detail, contains('2027-11-20'));
      expect(view.detail, contains('auto-renew on'));
    });

    test('the gate saying premium is enough, even with no CustomerInfo at all',
        () {
      final view = _view(info: null, playActive: true);

      expect(view.isPremium, isTrue);
      expect(view.isChecking, isFalse);
      expect(view.planName, 'Premium Plan');
      expect(view.detail, 'Active subscription');
    });

    test('an inactive entitlement is not premium', () {
      final view = _view(
        info: _info(
          entitlements: [Entitlement(id: 'premium', isActive: false)],
        ),
        playActive: false,
      );

      expect(view.isPremium, isFalse);
      expect(view.planName, 'Free plan');
    });
  });

  group('the richest source wins', () {
    test('an active local transaction names the plan from its product id', () {
      final view = _view(
        info: _info(
          subscriptions: [_tx(productId: 'soulful_monthly')],
          entitlements: [Entitlement(id: 'premium', isActive: true)],
        ),
        playActive: true,
      );

      expect(view.planName, 'Monthly Plan');
      expect(view.detail, contains('Started 2026-12-01'));
    });

    test('a revoked transaction is ignored', () {
      final view = _view(
        info: _info(subscriptions: [_tx(isRevoked: true)]),
      );

      expect(view.isPremium, isFalse);
    });

    test('a lifetime entitlement says so instead of inventing a date', () {
      final view = _view(
        info: _info(
          entitlements: [
            Entitlement(id: 'premium', isActive: true, isLifetime: true),
          ],
        ),
      );

      expect(view.isPremium, isTrue);
      expect(view.planName, 'Premium Plan');
      expect(view.detail, 'Lifetime access');
    });
  });

  group('the Razorpay/web rail still reads correctly', () {
    test('web-only access names the web plan and its end date', () {
      final view = _view(
        webActive: true,
        webPlan: 'yearly',
        webEnd: DateTime.utc(2027, 11, 9),
      );

      expect(view.isPremium, isTrue);
      expect(view.planName, 'Yearly Plan');
      expect(view.detail, 'Active until 2027-11-09');
    });

    test('a web purchase does not override a Play product name', () {
      final view = _view(
        info: _info(subscriptions: [_tx(productId: 'soulful_monthly')]),
        playActive: true,
        webActive: true,
        webPlan: 'yearly',
      );

      expect(view.planName, 'Monthly Plan');
    });
  });

  group('"Free plan" is only shown when every source says free', () {
    test('nothing active, nothing pending', () {
      final view = _view(info: _info());

      expect(view.isPremium, isFalse);
      expect(view.isChecking, isFalse);
      expect(view.planName, 'Free plan');
      expect(view.detail, 'Enjoy devotional music and bhakti playlists');
    });

    test('the first answer for a user is "checking", never "Free plan"', () {
      final view = _view(info: null, loading: true);

      expect(view.isChecking, isTrue);
      expect(view.isPremium, isFalse);
    });

    test('the web entitlement check counts as pending too', () {
      final view = _view(info: _info(), entitlementPending: true);

      expect(view.isChecking, isTrue);
    });

    test('a confirmed subscriber never shows the checking spinner', () {
      final view = _view(info: null, playActive: true, loading: true);

      expect(view.isChecking, isFalse);
      expect(view.isPremium, isTrue);
    });
  });
}
