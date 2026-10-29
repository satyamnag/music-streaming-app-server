// Tapping an inbox row must do BOTH things the screen promises: mark the entry
// read, and follow the link the notification carried.
//
// The link half is easy to get wrong in a way nothing else notices — a tap that
// silently only marks read looks perfectly fine in the UI.
import 'package:flutter_test/flutter_test.dart';

import 'package:sangeet/modules/notifications/app_notification.dart';
import 'package:sangeet/modules/notifications/notification_actions.dart';

AppNotification _entry({String? link}) => AppNotification(
      id: 'notif-1',
      kind: AppNotificationKind.push,
      title: 'A push',
      deepLink: link,
      receivedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('a tap always marks the entry read', () {
    final marked = <String>[];
    final opened = <Uri>[];

    handleNotificationTap(
      _entry(link: 'soulfulbhakti://album/42'),
      markRead: marked.add,
      openLink: opened.add,
    );

    expect(marked, ['notif-1']);
  });

  test('a tap follows the link the notification carried', () {
    final opened = <Uri>[];

    handleNotificationTap(
      _entry(link: 'soulfulbhakti://album/42'),
      markRead: (_) {},
      openLink: opened.add,
    );

    expect(opened.length, 1);
    expect(opened.single.scheme, 'soulfulbhakti');
    expect(opened.single.host, 'album');
    expect(opened.single.path, '/42');
  });

  test('a missing or blank link navigates nowhere but still marks read', () {
    for (final link in <String?>[null, '', '   ']) {
      final marked = <String>[];
      final opened = <Uri>[];

      handleNotificationTap(
        _entry(link: link),
        markRead: marked.add,
        openLink: opened.add,
      );

      expect(marked, ['notif-1'], reason: 'link: ${link ?? 'null'}');
      expect(opened, isEmpty, reason: 'link: ${link ?? 'null'}');
    }
  });

  test('an in-app message with no link still behaves like a normal row', () {
    final marked = <String>[];
    final opened = <Uri>[];

    handleNotificationTap(
      AppNotification(
        id: 'iam-1',
        kind: AppNotificationKind.inApp,
        title: 'In-app message',
        receivedAt: DateTime(2026, 1, 1),
      ),
      markRead: marked.add,
      openLink: opened.add,
    );

    expect(marked, ['iam-1']);
    expect(opened, isEmpty);
  });
}
