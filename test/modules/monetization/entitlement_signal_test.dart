import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/entitlement/entitlement_service.dart';

/// Unit tests for the Razorpay (web) entitlement gate.
///
/// These cover the ONLY decisions that grant premium access from the web rail,
/// so a regression here is caught without a device, a network, or a real
/// subscription. The HTTP call itself is deliberately not tested here (it is a
/// thin wrapper); what matters is that no stale/absent claim can unlock audio.
///
/// Run: flutter test test/modules/monetization/entitlement_signal_test.dart
void main() {
  final now = DateTime.utc(2026, 11, 8, 12, 0, 0);

  group('entitlementIsActive', () {
    test('a fresh, active, non-expired answer grants access', () {
      expect(
        entitlementIsActive(
          active: true,
          checkedAt: now,
          currentEnd: now.add(const Duration(days: 20)),
          now: now,
        ),
        isTrue,
      );
    });

    test('an inactive answer never grants access', () {
      expect(
        entitlementIsActive(
          active: false,
          checkedAt: now,
          currentEnd: now.add(const Duration(days: 20)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a claim that was never verified is rejected', () {
      // Writing `active = true` without a server answer must not unlock.
      expect(
        entitlementIsActive(
          active: true,
          checkedAt: null,
          currentEnd: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('an answer older than maxAge is rejected', () {
      expect(
        entitlementIsActive(
          active: true,
          checkedAt: now.subtract(const Duration(hours: 2)),
          currentEnd: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('an answer exactly at maxAge is still accepted', () {
      expect(
        entitlementIsActive(
          active: true,
          checkedAt: now.subtract(EntitlementSignal.maxAge),
          currentEnd: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('a paid period that already ended is rejected even if checked recently',
        () {
      expect(
        entitlementIsActive(
          active: true,
          checkedAt: now,
          currentEnd: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a missing current_end is treated as open-ended', () {
      expect(
        entitlementIsActive(
          active: true,
          checkedAt: now,
          currentEnd: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('a custom maxAge is honoured', () {
      expect(
        entitlementIsActive(
          active: true,
          checkedAt: now.subtract(const Duration(minutes: 5)),
          currentEnd: null,
          now: now,
          maxAge: const Duration(minutes: 1),
        ),
        isFalse,
      );
    });
  });

  group('entitlementFromJson', () {
    test('parses the documented response', () {
      final snapshot = entitlementFromJson({
        'active': true,
        'plan': 'yearly',
        'current_end': '2026-12-31T00:00:00.000Z',
        'status': 'active',
        'source': 'razorpay',
      });
      expect(snapshot, isNotNull);
      expect(snapshot!.active, isTrue);
      expect(snapshot.plan, 'yearly');
      expect(snapshot.currentEnd, DateTime.utc(2026, 12, 31));
    });

    test('non-object payloads are rejected', () {
      expect(entitlementFromJson(null), isNull);
      expect(entitlementFromJson('ok'), isNull);
      expect(entitlementFromJson([1, 2, 3]), isNull);
    });

    test('only the literal true is accepted', () {
      expect(entitlementFromJson({'active': 'true'})!.active, isFalse);
      expect(entitlementFromJson({'active': 1})!.active, isFalse);
      expect(entitlementFromJson(<String, dynamic>{})!.active, isFalse);
    });

    test('blank plan and unparseable dates become null', () {
      final snapshot = entitlementFromJson({
        'active': true,
        'plan': '',
        'current_end': 'not-a-date',
      })!;
      expect(snapshot.plan, isNull);
      expect(snapshot.currentEnd, isNull);
    });
  });

  group('EntitlementSignal', () {
    tearDown(EntitlementSignal.reset);

    test('starts inactive', () {
      EntitlementSignal.reset();
      expect(EntitlementSignal.isActive, isFalse);
    });

    test('update then reset', () {
      EntitlementSignal.update(
        active: true,
        plan: 'monthly',
        currentEnd: DateTime.now().add(const Duration(days: 30)),
      );
      expect(EntitlementSignal.isActive, isTrue);
      expect(EntitlementSignal.plan, 'monthly');

      EntitlementSignal.reset();
      expect(EntitlementSignal.isActive, isFalse);
      expect(EntitlementSignal.plan, isNull);
      expect(EntitlementSignal.checkedAt, isNull);
    });

    test('an update for a non-subscriber clears the claim', () {
      EntitlementSignal.update(active: true);
      EntitlementSignal.update(active: false);
      expect(EntitlementSignal.isActive, isFalse);
    });
  });
}
