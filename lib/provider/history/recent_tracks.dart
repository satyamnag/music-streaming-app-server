import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/services/logger/logger.dart';

/// Recently played **tracks** (distinct by track id, newest occurrence first),
/// limited to 10. Built on the existing `history_table` and exposed as an
/// auto-updating watch so the home "Recently played" row stays live as the
/// user listens. Mirrors the query style in `recent.dart` (playlists/albums).
class RecentlyPlayedTracksNotifier
    extends AsyncNotifier<List<SangeetTrackObject>> {
  @override
  build() async {
    final database = ref.watch(databaseProvider);

    final query = database.customSelect(
      '''
      WITH RankedHistory AS (
        SELECT *,
          ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY created_at DESC) AS rn
        FROM history_table
        WHERE type = 'track'
      )
      SELECT data
      FROM RankedHistory
      WHERE rn = 1
      ORDER BY created_at DESC
      LIMIT 10
      ''',
      readsFrom: {database.historyTable},
    );

    final subscription = query.watch().listen((event) async {
      try {
        final items = event
            .map((row) => jsonDecode(row.read<String>('data'))
                as Map<String, dynamic>)
            .map((d) => SangeetTrackObject.fromJson(d))
            .toList();
        state = AsyncData(items);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });

    ref.onDispose(() => subscription.cancel());

    final rows = await query.get();
    return rows
        .map((row) =>
            jsonDecode(row.read<String>('data')) as Map<String, dynamic>)
        .map((d) => SangeetTrackObject.fromJson(d))
        .toList();
  }
}

final recentlyPlayedTracksProvider = AsyncNotifierProvider<
    RecentlyPlayedTracksNotifier, List<SangeetTrackObject>>(
  () => RecentlyPlayedTracksNotifier(),
);