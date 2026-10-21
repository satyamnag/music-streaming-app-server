import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:sangeet/collections/routes.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/services/logger/logger.dart';

/// Routes `sangeet://` deep links to the matching screen.
///
/// Three sources produce these links, and they arrive at very different times:
///
///  * a push notification tap (`OneSignal.Notifications.addClickListener`),
///  * an in-app message button (`InAppMessageClickEvent.result.url`),
///  * an OS-delivered link, already handled for paywalls by
///    `useSuperwallDeepLinks`.
///
/// The cold-start case is why this is a class with a queue rather than a plain
/// function. When a notification tap *launches* the app, the click listener
/// fires before `rootNavigatorKey` has a context, so there is no router to push
/// onto yet. A link that cannot be delivered is held and replayed by
/// [flushPending] once the first frame is up. Without that queue the very first
/// tap after launch — the case the whole feature exists for — would be dropped
/// silently, and the app would just open on Home.
///
/// Only `sangeet://track/<id>` is routed. `AlbumRoute` additionally requires a
/// hydrated album object (see `AlbumRouteArgs.album`), so an album link cannot
/// be served from an id alone; it is logged rather than routed to a wrong
/// screen.
class AppDeepLinkRouter {
  AppDeepLinkRouter._internal();

  static final AppDeepLinkRouter instance = AppDeepLinkRouter._internal();

  /// A link that arrived before the navigator existed (cold start).
  Uri? _pending;

  /// Routes [uri], or queues it when the navigator is not ready yet.
  void handle(Uri uri) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      // Cold start: no navigator to push onto. Hold the link and let
      // flushPending deliver it once the first frame is up.
      _pending = uri;
      AppLogger.log.d('Deep link queued until the router is ready: $uri');
      return;
    }
    _navigate(context, uri);
  }

  /// Replays a link queued by a cold start. Safe to call repeatedly; a link is
  /// only cleared once it has actually been delivered.
  void flushPending() {
    final pending = _pending;
    if (pending == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    _pending = null;
    _navigate(context, pending);
  }

  void _navigate(BuildContext context, Uri uri) {
    // `sangeet://track/<id>` parses as host `track` with path `/id`, so the
    // scheme's first segment lives in `host`, not `pathSegments`.
    final segments = uri.host.isEmpty
        ? uri.pathSegments
        : <String>[uri.host, ...uri.pathSegments];

    if (segments.length < 2 || segments[1].isEmpty) {
      AppLogger.log.w('Deep link ignored (unrecognised shape): $uri');
      return;
    }

    switch (segments[0]) {
      case 'track':
        context.navigateTo(TrackRoute(trackId: segments[1]));
      default:
        AppLogger.log.w('Deep link ignored (unknown target): $uri');
    }
  }
}
