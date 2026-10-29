/// One entry in the in-app notification inbox.
///
/// The inbox exists because neither OneSignal nor its Flutter SDK exposes a
/// "notification history" or an "unread count": the SDK hands the app an event
/// when a push arrives in the foreground or is tapped, and a message id when an
/// in-app message is shown. Anything the user can browse later therefore has to
/// be recorded by the app itself, which is what this model stores.
///
/// [kind] separates the two OneSignal surfaces the screen shows together:
///   * [AppNotificationKind.push]  — a push notification (title/body/link).
///   * [AppNotificationKind.inApp] — an in-app message. The SDK's
///     `OSInAppMessage` carries ONLY `messageId` (see onesignal_flutter 5.5.2
///     `src/inappmessage.dart`), so an in-app entry has a generic title and the
///     message id as its detail; a click URL is recorded when the user taps it.
library;

/// Which OneSignal surface produced an entry.
enum AppNotificationKind {
  /// A push notification.
  push,

  /// A OneSignal in-app message.
  inApp,
}

/// A single inbox entry, persisted as JSON.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.deepLink,
    required this.receivedAt,
    this.read = false,
  });

  /// Stable identifier used to de-duplicate. For a push this is the OneSignal
  /// notification id; for an in-app message it is the message id (plus a
  /// timestamp, because the same message may legitimately be shown again).
  final String id;

  final AppNotificationKind kind;

  /// Headline shown in the list.
  final String title;

  /// Optional detail line.
  final String? body;

  /// Link the entry points at, when the payload carried one.
  final String? deepLink;

  /// When the app recorded it. Used for newest-first ordering.
  final DateTime receivedAt;

  /// Whether the user has seen it.
  final bool read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      deepLink: deepLink,
      receivedAt: receivedAt,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'kind': kind.name,
      'title': title,
      if (body != null) 'body': body,
      if (deepLink != null) 'deepLink': deepLink,
      'receivedAt': receivedAt.toIso8601String(),
      'read': read,
    };
  }

  /// Returns null for a malformed entry rather than throwing, so one corrupt
  /// row cannot lose the whole inbox.
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final receivedAt = DateTime.tryParse('${json['receivedAt']}');
    if (id is! String || id.isEmpty || title is! String || receivedAt == null) {
      return null;
    }
    final kindName = json['kind'];
    return AppNotification(
      id: id,
      kind: AppNotificationKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => AppNotificationKind.push,
      ),
      title: title,
      body: json['body'] is String ? json['body'] as String : null,
      deepLink: json['deepLink'] is String ? json['deepLink'] as String : null,
      receivedAt: receivedAt,
      read: json['read'] == true,
    );
  }
}
