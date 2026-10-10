import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/superwall_service.dart';

/// Regression tests for the launch crash caused by calling into Superwall
/// before it was configured.
///
/// The native SDK throws
/// `IllegalStateException: Superwall has not been initialized or configured.`
/// on a background isolate, which is fatal and killed the app on launch
/// whenever SUPERWALL_API_KEY was absent from the build.
///
/// These tests assert that every method is safe when unconfigured. They pass
/// without a Superwall API key and without the native SDK being initialised,
/// which is exactly the condition that used to crash.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an empty API key leaves the service unconfigured', () {
    SuperwallService.instance.configure('');
    expect(SuperwallService.instance.isConfigured, isFalse);
  });

  test('identify does not throw while unconfigured', () async {
    await SuperwallService.instance.identify('user_123');
  });

  test('reset does not throw while unconfigured', () async {
    await SuperwallService.instance.reset();
  });

  test('setUserAttributes does not throw while unconfigured', () async {
    await SuperwallService.instance.setUserAttributes({'plan': 'free'});
  });

  test('getCustomerInfo returns an empty result while unconfigured', () async {
    final info = await SuperwallService.instance.getCustomerInfo();
    expect(info.subscriptions, isEmpty);
    expect(info.nonSubscriptions, isEmpty);
    expect(info.entitlements, isEmpty);
  });

  test('getEntitlements returns empty sets while unconfigured', () async {
    final ent = await SuperwallService.instance.getEntitlements();
    expect(ent.active, isEmpty);
    expect(ent.all, isEmpty);
  });

  test('subscriptionStatus emits nothing while unconfigured', () async {
    final events = await SuperwallService.instance.subscriptionStatus.toList();
    expect(events, isEmpty);
  });

  test('customerInfoStream emits nothing while unconfigured', () async {
    final events = await SuperwallService.instance.customerInfoStream.toList();
    expect(events, isEmpty);
  });

  test('handleDeepLink does not throw while unconfigured', () async {
    await SuperwallService.instance.handleDeepLink(Uri.parse('app://x'));
  });

  test('registerPlacement does NOT run the feature while unconfigured',
      () async {
    // INVERTED. This test used to assert the opposite - that the gated feature
    // ran when the SDK had no API key - on the reasoning that "the app must stay
    // usable without monetisation".
    //
    // That assertion described a serious defect rather than a requirement. The
    // CI release `.env` has no SUPERWALL_API_KEY, so EVERY shipped build took
    // this path: a paid track played for anyone, with no paywall, because there
    // was no SDK to show one. "No paywall presented" is indistinguishable from
    // "user already entitled" from the outside, which is why it went unnoticed.
    //
    // A gate must fail CLOSED. The feature must NOT run, and the caller must be
    // able to tell why.
    var ran = false;

    await expectLater(
      SuperwallService.instance.registerPlacement(
        'premium_gate',
        feature: () async => ran = true,
      ),
      throwsA(isA<SuperwallNotConfiguredError>()),
      reason: 'an unconfigured SDK must refuse the placement, not grant it',
    );

    expect(
      ran,
      isFalse,
      reason: 'the gated feature must NOT run: granting it would give the paid '
          'catalogue away whenever the API key is missing',
    );
  });

  test('the unconfigured error names the placement and the missing key',
      () async {
    // The message is what turns a silent give-away into a diagnosable build
    // problem, so it must say which placement failed and what to add.
    try {
      await SuperwallService.instance.registerPlacement('paid_track_play');
      fail('expected SuperwallNotConfiguredError');
    } on SuperwallNotConfiguredError catch (e) {
      expect(e.placement, 'paid_track_play');
      expect(e.toString().contains('SUPERWALL_API_KEY'), isTrue,
          reason: 'the error must name the setting to fix');
      expect(e.toString().contains('NOT granted'), isTrue,
          reason: 'the error must state that access was refused');
    }
  });

  test('a placement with no feature callback still refuses while unconfigured',
      () async {
    // A caller that only wants the paywall (no feature) must not be silently
    // told everything is fine either.
    await expectLater(
      SuperwallService.instance.registerPlacement('premium_playback'),
      throwsA(isA<SuperwallNotConfiguredError>()),
    );
  });
}
