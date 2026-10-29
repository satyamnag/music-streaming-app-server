// Tests the notifications inbox: the model's JSON, and the store's ordering,
// de-duplication, read marking and persistence.
//
// The inbox exists because the OneSignal SDK exposes no notification history
// and no unread count, so this app-side behaviour IS the feature — if the store
// drops entries, re-marks read ones unseen, or fails to restore, the bell and
// the screen are wrong and nothing else catches it.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sangeet/modules/notifications/app_notification.dart';
import 'package:sangeet/modules/notifications/notifications_store.dart';

AppNotification _push(
  String id, {
  DateTime? at,
  String title = 'A push',
  String? body,
  String? link,
  bool read = false,
}) {
  return AppNotification(
    id: id,
    kind: AppNotificationKind.push,
    title: title,
    body: body,
    deepLink: link,
    receivedAt: at ?? DateTime(2026, 1, 1, 12),
    read: read,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('the model survives a JSON round trip', () {
    test('every field comes back', () {
      final original = AppNotification(
        id: 'n1',
        kind: AppNotificationKind.inApp,
        title: 'In-app message',
        body: 'hello',
        deepLink: 'soulfulbhakti://track/1',
        receivedAt: DateTime(2026, 2, 3, 4, 5, 6),
        read: true,
      );
      final restored = AppNotification.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, 'n1');
      expect(restored.kind, AppNotificationKind.inApp);
      expect(restored.title, 'In-app message');
      expect(restored.body, 'hello');
      expect(restored.deepLink, 'soulfulbhakti://track/1');
      expect(restored.receivedAt, original.receivedAt);
      expect(restored.read, isTrue);
    });

    test('a malformed entry is dropped, not thrown', () {
      expect(AppNotification.fromJson(<String, dynamic>{}), isNull);
      expect(
        AppNotification.fromJson(<String, dynamic>{'id': 'x', 'title': 'y'}),
        isNull,
        reason: 'a missing timestamp must not produce a half-valid entry',
      );
    });
  });

  group('the store', () {
    test('keeps entries newest first', () async {
      final store = NotificationsStore.forTesting();
      await store.add(_push('a', at: DateTime(2026, 1, 1)));
      await store.add(_push('b', at: DateTime(2026, 1, 2)));
      await store.add(_push('c', at: DateTime(2026, 1, 3)));
      expect(store.items.value.map((n) => n.id).toList(), ['c', 'b', 'a']);
    });

    test('de-duplicates by id and PRESERVES the read flag', () async {
      final store = NotificationsStore.forTesting();
      await store.add(_push('a'));
      await store.markRead('a');
      expect(store.unreadCount, 0);

      // The same push arriving again (foreground arrival, then the tap) must not
      // become unseen again.
      await store.add(_push('a', title: 'Same push, second event'));
      expect(store.items.value.length, 1);
      expect(store.items.value.single.read, isTrue);
      expect(store.items.value.single.title, 'Same push, second event');
      expect(store.unreadCount, 0);
    });

    test('counts only unread entries', () async {
      final store = NotificationsStore.forTesting();
      await store.add(_push('a'));
      await store.add(_push('b'));
      await store.add(_push('c'));
      expect(store.unreadCount, 3);
      await store.markRead('b');
      expect(store.unreadCount, 2);
      await store.markAllRead();
      expect(store.unreadCount, 0);
    });

    test('is capped so the prefs value cannot grow without bound', () async {
      final store = NotificationsStore.forTesting();
      for (var i = 0; i < NotificationsStore.maxEntries + 5; i++) {
        await store.add(_push('n$i', at: DateTime(2026, 1, 1).add(Duration(minutes: i))));
      }
      expect(store.items.value.length, NotificationsStore.maxEntries);
      expect(store.items.value.first.id, 'n${NotificationsStore.maxEntries + 4}',
          reason: 'the newest entries are the ones kept');
    });

    test('persists and restores, including the read flag', () async {
      final writer = NotificationsStore.forTesting();
      await writer.add(_push('kept', title: 'Remember me'));
      await writer.add(_push('read-one'));
      await writer.markRead('read-one');
      expect(SharedPreferences.getInstance(), completion(isNotNull));

      final reader = NotificationsStore.forTesting();
      await reader.ensureLoaded();
      expect(reader.items.value.length, 2);
      expect(reader.items.value.map((n) => n.id), containsAll(<String>['kept', 'read-one']));
      expect(reader.unreadCount, 1,
          reason: 'exactly one of the two was read before restart');
    });

    test('an empty store loads empty and does not throw', () async {
      final store = NotificationsStore.forTesting();
      await store.ensureLoaded();
      expect(store.items.value, isEmpty);
      expect(store.unreadCount, 0);
    });
  });
}
