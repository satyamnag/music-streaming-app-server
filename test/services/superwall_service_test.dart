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

  test('registerPlacement still runs the feature while unconfigured', () async {
    var ran = false;
    await SuperwallService.instance.registerPlacement(
      'premium_gate',
      feature: () async => ran = true,
    );
    expect(ran, isTrue,
        reason: 'without a paywall the app must stay usable, so the feature runs');
  });
}
