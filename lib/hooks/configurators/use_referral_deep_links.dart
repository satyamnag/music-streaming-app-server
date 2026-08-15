import 'package:app_links/app_links.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sangeet/provider/referral/referral_provider.dart';

/// Captures referral codes from shared deep links and stores them pending
/// attribution.
///
/// Referral links use the app's `sangeet://referral?code=XXX` scheme (and also
/// accept `https://...?ref=XXX`). When such a link is opened:
///   - the code is persisted via [ReferralNotifier.storePendingReferralCode],
///   - the next time a signed-in user's [referralProvider] state is built, the
///     server records the attribution (once) and the pending code is cleared.
///
/// Works for both cold starts (`getInitialLink`) and warm launches
/// (`uriLinkStream`). Non-referral links are ignored so Superwall deep links
/// continue to work untouched.
void useReferralDeepLinks() {
  useEffect(() {
    final appLinks = AppLinks();

    void handle(Uri? uri) {
      if (uri == null) return;
      final code = parseReferralCode(uri);
      if (code == null || code.isEmpty) return;
      ReferralNotifier.storePendingReferralCode(code);
    }

    appLinks.getInitialLink().then(handle);
    final sub = appLinks.uriLinkStream.listen(handle);
    return sub.cancel;
  }, []);
}
