// The bell's UNSEEN COUNT is a requirement in its own right ("identifiable
// number of unseen notifications"), and it cannot be checked on a device whose
// inbox happens to be empty — which is exactly the state the manual device pass
// left it in. So it is asserted here against the real widget.
//
// Covers: the count renders, it disappears at zero, and it is capped so a large
// backlog cannot blow the badge out of the header.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sangeet/components/notifications/notification_bell.dart';
import 'package:sangeet/modules/notifications/app_notification.dart';
import 'package:sangeet/modules/notifications/notifications_store.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

Widget _harness(NotificationsStore store, Widget child) {
  return ProviderScope(
    overrides: [notificationsStoreProvider.overrideWithValue(store)],
    child: Theme(
      data: ThemeData(
        radius: .5,
        iconTheme: const IconThemeProperties(),
        colorScheme: BhaktiColorSchemes.lightMaroon(),
        surfaceOpacity: .8,
        surfaceBlur: 10,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800)),
          child: Align(
            alignment: Alignment.topLeft,
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<NotificationsStore> _storeWith(int unread, {int read = 0}) async {
  final store = NotificationsStore.forTesting();
  for (var i = 0; i < unread; i++) {
    await store.add(
      AppNotification(
        id: 'unread-$i',
        kind: AppNotificationKind.push,
        title: 'Push $i',
        receivedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
      ),
    );
  }
  for (var i = 0; i < read; i++) {
    await store.add(
      AppNotification(
        id: 'read-$i',
        kind: AppNotificationKind.push,
        title: 'Read $i',
        receivedAt: DateTime(2026, 1, 2).add(Duration(minutes: i)),
      ),
    );
    await store.markRead('read-$i');
  }
  return store;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the bell shows the number of unseen notifications',
      (tester) async {
    final store = await _storeWith(3);
    await tester.pumpWidget(_harness(store, const NotificationBell()));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget,
        reason: 'the requirement is an identifiable count, not a bare dot');
  });

  testWidgets('read entries are not counted', (tester) async {
    final store = await _storeWith(2, read: 5);
    await tester.pumpWidget(_harness(store, const NotificationBell()));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('7'), findsNothing,
        reason: 'only UNSEEN entries count toward the badge');
  });

  testWidgets('an empty inbox shows no badge at all', (tester) async {
    final store = await _storeWith(0);
    await tester.pumpWidget(_harness(store, const NotificationBell()));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing,
        reason: 'a "0" badge is noise; the bell alone is the empty state');
    expect(find.byType(NotificationBell), findsOneWidget);
  });

  testWidgets('the count is capped at 99+', (tester) async {
    final store = await _storeWith(120);
    await tester.pumpWidget(_harness(store, const NotificationBell()));
    await tester.pumpAndSettle();

    expect(find.text('99+'), findsOneWidget,
        reason: 'a three-digit count would overflow the badge and the header');
  });
}
