import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sangeet/services/app_deep_link_router.dart';

/// Replays a OneSignal deep link that arrived before the router existed.
///
/// When a notification tap *launches* the app, the OneSignal click listener
/// fires during startup while `rootNavigatorKey` still has no context, so there
/// is nothing to navigate with. [AppDeepLinkRouter] queues that link; this hook
/// delivers it once the first frame is on screen.
///
/// The flush is deliberately deferred by one frame rather than run during
/// build: pushing a route mid-build would mutate the navigator while it is
/// still assembling its initial stack.
void useOneSignalDeepLinks() {
  useEffect(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppDeepLinkRouter.instance.flushPending();
    });
    return null;
  }, []);
}
