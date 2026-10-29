import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/modules/notifications/app_notification.dart';
import 'package:sangeet/modules/notifications/notifications_store.dart';

/// The bell in the home header: opens the notifications screen and shows how
/// many entries are still unseen.
///
/// The count is the app's own (see [NotificationsStore]) because OneSignal
/// exposes no unread count. It is capped visually at "99+".
class NotificationBell extends HookConsumerWidget {
  final Color? color;
  final List<Shadow>? shadows;

  const NotificationBell({super.key, this.color, this.shadows});

  @override
  Widget build(BuildContext context, ref) {
    final store = ref.watch(notificationsStoreProvider);

    useEffect(() {
      store.ensureLoaded();
      return null;
    }, [store]);

    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: store.items,
      builder: (context, entries, _) {
        final unread = entries.where((n) => !n.read).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.ghost(
              icon: Icon(
                Icons.notifications_none,
                size: 20,
                color: color,
                shadows: shadows,
              ),
              onPressed: () {
                context.navigateTo(const NotificationsRoute());
              },
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 3,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(8),
                      // A hairline ring keeps the badge legible on a photo
                      // wallpaper, which a bare red dot is not.
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
