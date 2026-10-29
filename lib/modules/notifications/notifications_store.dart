import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sangeet/modules/notifications/app_notification.dart';

/// The app's notification inbox: a small, newest-first list of the OneSignal
/// pushes and in-app messages this device has seen, with a read flag.
///
/// Why the app keeps this itself: the OneSignal Flutter SDK (5.5.2) exposes no
/// notification-history API and no unread count. It reports an arrival/click
/// event, and for in-app messages only a message id. A browsable inbox and the
/// unseen badge therefore have to be built on top of those events.
///
/// Storage is `shared_preferences`, not drift: the payload is tiny, bounded by
/// [maxEntries], and never queried — a table would add a migration for no gain.
///
/// A single instance plus a [ValueNotifier] is deliberate. Events arrive from
/// `main.dart` listeners that hold no `WidgetRef`, so writing must not depend on
/// a widget tree; widgets subscribe through the notifier instead.
class NotificationsStore {
  NotificationsStore._();

  /// An isolated instance for tests: the app uses [instance], but a test needs
  /// its own unloaded store to exercise restore-from-disk.
  @visibleForTesting
  NotificationsStore.forTesting();

  static final NotificationsStore instance = NotificationsStore._();

  /// Key holding the JSON-encoded list.
  static const String storageKey = 'sb_notifications_v1';

  /// Hard cap so the prefs value cannot grow without bound.
  static const int maxEntries = 100;

  /// The current inbox, newest first.
  final ValueNotifier<List<AppNotification>> items =
      ValueNotifier<List<AppNotification>>(const <AppNotification>[]);

  bool _loaded = false;

  /// Reads the persisted inbox once. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = <AppNotification>[];
      for (final entry in decoded) {
        if (entry is Map) {
          final parsed = AppNotification.fromJson(
            entry.cast<String, dynamic>(),
          );
          if (parsed != null) restored.add(parsed);
        }
      }
      items.value = List<AppNotification>.unmodifiable(restored);
    } catch (_) {
      // A corrupt or unreadable inbox must never stop the app from starting.
    }
  }

  /// Number of entries the user has not opened yet.
  int get unreadCount => items.value.where((n) => !n.read).length;

  /// Records [incoming] at the top, de-duplicating by id.
  ///
  /// An entry that is already in the inbox keeps its read flag: the same push
  /// can arrive twice (foreground arrival, then the tap event), and re-adding it
  /// must not mark something the user already read as unseen again.
  Future<void> add(AppNotification incoming) async {
    AppNotification? existing;
    for (final n in items.value) {
      if (n.id == incoming.id) {
        existing = n;
        break;
      }
    }
    final merged =
        existing == null ? incoming : incoming.copyWith(read: existing.read);
    final next = <AppNotification>[
      merged,
      ...items.value.where((n) => n.id != incoming.id),
    ];
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    items.value = List<AppNotification>.unmodifiable(next);
    await _persist();
  }

  /// Marks one entry read.
  Future<void> markRead(String id) async {
    if (!items.value.any((n) => n.id == id && !n.read)) return;
    items.value = List<AppNotification>.unmodifiable(
      items.value.map((n) => n.id == id ? n.copyWith(read: true) : n),
    );
    await _persist();
  }

  /// Marks everything read — the screen's "Mark all read" action.
  Future<void> markAllRead() async {
    if (items.value.every((n) => n.read)) return;
    items.value = List<AppNotification>.unmodifiable(
      items.value.map((n) => n.copyWith(read: true)),
    );
    await _persist();
  }

  /// Clears the inbox (exposed for tests and a future "clear all").
  Future<void> clear() async {
    items.value = const <AppNotification>[];
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode(items.value.map((n) => n.toJson()).toList()),
      );
    } catch (_) {
      // Persisting is best-effort: the in-memory inbox stays usable.
    }
  }
}

/// The inbox, for widgets.
final notificationsStoreProvider = Provider<NotificationsStore>(
  (ref) => NotificationsStore.instance,
);
