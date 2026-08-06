import 'package:app_links/app_links.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sangeet/services/superwall_service.dart';

/// Listens for incoming deep links and forwards them to Superwall so the
/// `deepLink_open` standard placement can present paywalls configured in the
/// Superwall Dashboard (no app update needed when adding/changing paywall
/// deep links).
void useSuperwallDeepLinks() {
  useEffect(() {
    final appLinks = AppLinks();
    // Handle the initial link, if the app was launched via a deep link.
    appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        SuperwallService.instance.handleDeepLink(uri);
      }
    });
    // Handle subsequent links while the app is running.
    final sub = appLinks.uriLinkStream.listen((uri) {
      SuperwallService.instance.handleDeepLink(uri);
    });
    return sub.cancel;
  }, []);
}
