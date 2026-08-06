import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sangeet/services/superwall_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Listens to the Superwall subscription status stream and exposes the current
/// status so the UI can react to plan changes (e.g. show premium features).
enum SuperwallSubscriptionStatus {
  unknown,
  active,
  inactive,
}

SuperwallSubscriptionStatus useSuperwallSubscriptionStatus() {
  final status = useState(SuperwallSubscriptionStatus.unknown);

  useEffect(() {
    late final StreamSubscription<SubscriptionStatus> sub;
    sub = SuperwallService.instance.subscriptionStatus.listen((value) {
      status.value = switch (value) {
        SubscriptionStatusActive() => SuperwallSubscriptionStatus.active,
        SubscriptionStatusInactive() => SuperwallSubscriptionStatus.inactive,
        SubscriptionStatusUnknown() => SuperwallSubscriptionStatus.unknown,
      };
    });
    return sub.cancel;
  }, []);

  return status.value;
}
