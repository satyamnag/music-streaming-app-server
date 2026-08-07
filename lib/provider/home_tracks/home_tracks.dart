import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/provider/server/server.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';
import 'package:sangeet/services/sourced_track/direct_supabase.dart';
/// Fetches all tracks from the Supabase `tracks` table via the local server
/// so the home screen always shows every song regardless of player state.
///
/// Uses the shared [globalDio] instance (connection reuse + consistent
/// defaults) and keeps the resolved value cached for the lifetime of the
/// session so tab switches do not trigger redundant refetches. Callers can
/// force a fresh fetch by invalidating this provider (e.g. pull-to-refresh).
final homeTracksProvider =
    FutureProvider<List<SangeetTrackObject>>((ref) async {
  await ref.watch(serverProvider.future);
  await SangeetMedia.ensurePortReady();

  final response = await globalDio.get(
    'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/tracks',
    options: Options(
      validateStatus: (status) => status != null && status < 500,
      headers: {'accept': 'application/json'},
    ),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to fetch tracks: ${response.statusCode}');
  }

  final data = response.data as Map<String, dynamic>;
  final items = (data['items'] as List<dynamic>? ?? [])
      .map((e) =>
          SangeetTrackObject.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  ref.keepAlive();
  return items;
});

/// Pre-warms the stream URLs for the home tracks in the background so that
/// tapping a song starts playback almost instantly (the signed URL is already
/// resolved and cached). Fire-and-forget: failures are ignored — playback
/// still works via the on-demand resolver in the playback server.
final prewarmHomeStreamsProvider =
    FutureProvider<List<bool>>((ref) async {
  final tracks = await ref.watch(homeTracksProvider.future);
  final results = <bool>[];
  for (final track in tracks) {
    if (track is! SangeetFullTrackObject) continue;
    // Do not pre-warm paid tracks for free users (they are locked).
    if (track.status == 'paid' && !PremiumAccess.isPremiumUser(ref)) continue;
    final stream = await resolveDirectSupabaseStream(ref, track);
    results.add(stream != null);
  }
  return results;
});

/// The two home screen track sections:
///  - [newestArrivals]: every track, newest first (by album release date).
///  - [topTrending]: tracks ranked by how often they've been played on this
///    device (listening history), newest plays first as a tie-breaker.
class HomeSections {
  final List<SangeetTrackObject> newestArrivals;
  final List<SangeetTrackObject> topTrending;

  const HomeSections({
    required this.newestArrivals,
    required this.topTrending,
  });
}

/// Builds the "Newest Arrivals" and "Top Trending" track lists shown on the
/// home screen. Both are derived from the same full catalog ([homeTracksProvider]):
///  - Newest Arrivals is the catalog sorted by release date, newest first.
///  - Top Trending is the catalog ordered by global play counts (every user's
///    plays recorded in the shared `song_plays` table), newest plays first as
///    a tie-breaker.
final homeSectionsProvider =
    FutureProvider<HomeSections>((ref) async {
  final tracks = await ref.watch(homeTracksProvider.future);

  final newestArrivals = [...tracks]..sort((a, b) {
      final aDate = DateTime.tryParse(a.album.releaseDate ?? '');
      final bDate = DateTime.tryParse(b.album.releaseDate ?? '');
      final cmp = (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

  final playCounts = await _fetchGlobalPlayCounts(ref);

  final topTrending = [...tracks]..sort((a, b) {
      final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

  ref.keepAlive();
  return HomeSections(
    newestArrivals: newestArrivals,
    topTrending: topTrending,
  );
});

/// Fetches the global per-track play counts from the local server, which reads
/// the shared `song_plays` table. Returns an empty map if the backend isn't
/// ready or the table doesn't exist yet, so the UI always degrades gracefully.
Future<Map<String, int>> _fetchGlobalPlayCounts(Ref ref) async {
  try {
    await SangeetMedia.ensurePortReady();
    final response = await globalDio.get(
      'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/plays/trending',
      options: Options(
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode != 200) return const {};
    final data = response.data as Map<String, dynamic>;
    final raw = data['counts'] as Map<String, dynamic>? ?? const {};
    return raw.map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0));
  } catch (_) {
    return const {};
  }
}
