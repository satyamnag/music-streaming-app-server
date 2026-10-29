import 'package:sangeet/modules/notifications/app_notification.dart';

/// What tapping an inbox row does.
///
/// Two jobs, in this order, and split out of the widget so both are testable
/// without a widget tree or a router:
///   1. the entry is marked READ — opening it is what "seen" means; and
///   2. the link the notification carried is followed, so a tapped push takes
///      the user where it points (the same router the SDK click handler uses).
///
/// A missing, blank or unparseable link is not an error: the row still gets
/// marked read, and nothing navigates.
void handleNotificationTap(
  AppNotification entry, {
  required void Function(String id) markRead,
  required void Function(Uri uri) openLink,
}) {
  markRead(entry.id);
  final raw = entry.deepLink?.trim() ?? '';
  if (raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null) return;
  openLink(uri);
}
