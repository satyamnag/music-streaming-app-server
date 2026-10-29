import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/modules/notifications/app_notification.dart';
import 'package:sangeet/modules/notifications/notifications_store.dart';

/// The dedicated notifications screen.
///
/// One newest-first feed of BOTH OneSignal surfaces the app records — push
/// notifications and in-app messages — with unread marking and a "mark all
/// read" action. Reached from the bell in the home header, which carries the
/// unseen count.
///
/// The list is local because the SDK offers no history API: see
/// [NotificationsStore] for why.
@RoutePage()
class NotificationsScreen extends HookConsumerWidget {
  const NotificationsScreen({super.key});

  static const name = "notifications";

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final store = ref.watch(notificationsStoreProvider);

    useEffect(() {
      store.ensureLoaded();
      return null;
    }, [store]);

    return Scaffold(
      headers: [
        TitleBar(
          leading: const [BackButton()],
          title: const Text('Notifications'),
        ),
      ],
      child: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: store.items,
        builder: (context, entries, _) {
          final unread = entries.where((e) => !e.read).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          unread == 0
                              ? 'You are all caught up'
                              : '$unread unseen',
                          style: theme.typography.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                      Button.text(
                        onPressed: unread == 0 ? null : store.markAllRead,
                        child: const Text('Mark all read'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyState(theme: theme)
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: theme.colorScheme.border.withValues(alpha: .4),
                        ),
                        itemBuilder: (context, index) => _NotificationTile(
                          entry: entries[index],
                          theme: theme,
                          onTap: () => store.markRead(entries[index].id),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 40,
              color: theme.colorScheme.mutedForeground,
            ),
            const Gap(12),
            Text(
              'No notifications yet',
              style: theme.typography.p.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const Gap(4),
            Text(
              'Push notifications and in-app messages from Soulful Bhakti '
              'will appear here.',
              textAlign: TextAlign.center,
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One inbox row: kind icon, headline, detail, relative age and an unread dot.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.entry,
    required this.theme,
    required this.onTap,
  });

  final AppNotification entry;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPush = entry.kind == AppNotificationKind.push;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: entry.read ? null : theme.colorScheme.primary.withValues(alpha: .04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isPush
                    ? Icons.notifications_none
                    : Icons.chat_bubble_outline,
                size: 22,
                color: isPush
                    ? theme.colorScheme.primary
                    : theme.colorScheme.mutedForeground,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.p.copyWith(
                            fontWeight:
                                entry.read ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const Gap(8),
                      Text(
                        _relativeAge(entry.receivedAt),
                        style: theme.typography.xSmall.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  if (entry.body != null && entry.body!.trim().isNotEmpty) ...[
                    const Gap(2),
                    Text(
                      entry.body!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!entry.read) ...[
              const Gap(10),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "now" / "5m" / "3h" / "2d", falling back to a date after a week.
String _relativeAge(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(at);
  if (diff.isNegative || diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final d = at.toLocal();
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}
