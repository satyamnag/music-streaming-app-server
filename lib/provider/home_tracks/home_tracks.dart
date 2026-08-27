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

/// An album on the home screen: the album object plus the tracks grouped under
/// it (by album name), so tapping the card can play exactly that album.
typedef HomeAlbum = ({SangeetSimpleAlbumObject album, List<SangeetTrackObject> tracks});

/// A language grouping on the home screen: the language name (e.g. "Telugu")
/// plus the tracks tagged with that language, so tapping the card plays the
/// language's songs.
typedef HomeLanguageGroup = ({String language, List<SangeetTrackObject> tracks});

/// The two home screen track sections:
///  - [newestArrivals]: every track, newest first (by album release date).
///  - [topTrending]: tracks ranked by how often they've been played on this
///    device (listening history), newest plays first as a tie-breaker.
///  - [albums]: the catalog grouped into albums (by album name), each album's
///    cover taken from its most played song.
///  - [languages]: the catalog grouped into one component per language
///    (e.g. "Telugu Songs"), each with that language's tracks.
class HomeSections {
  final List<SangeetTrackObject> newestArrivals;
  final List<SangeetTrackObject> topTrending;
  final List<HomeAlbum> albums;
  final List<HomeLanguageGroup> languages;

  const HomeSections({
    required this.newestArrivals,
    required this.topTrending,
    required this.albums,
    required this.languages,
  });
}

/// Global per-track play counts from the local server (`song_plays` table).
/// Shared by the home sections (Top Trending ordering, album covers) and the
/// playlists row (most played song's cover). Empty map on failure.
final globalPlayCountsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  return _fetchGlobalPlayCounts(ref);
});

/// Fetches the admin-created albums (name + cover + assigned tracks) from the
/// local server. These are shown alongside the auto-grouped albums under the
/// home "Albums" component. Returns an empty list on any failure so the home
/// screen never breaks.
final homeAdminAlbumsProvider =
    FutureProvider<List<HomeAlbum>>((ref) async {
  try {
    await ref.watch(serverProvider.future);
    await SangeetMedia.ensurePortReady();
    final response = await globalDio.get(
      'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/admin-albums',
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {'accept': 'application/json'},
      ),
    );
    if (response.statusCode != 200) return const [];
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? []);
    final result = <HomeAlbum>[];
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);
      final name = (item['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final id = (item['id'] ?? '').toString();
      final album = SangeetSimpleAlbumObject(
        id: id,
        name: name,
        externalUri: '',
        artists: const [],
        images: (item['images'] as List<dynamic>? ?? const [])
            .map((e) => SangeetImageObject.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        albumType: SangeetAlbumType.album,
        releaseDate: null,
      );
      final albumTracks = (item['tracks'] as List<dynamic>? ?? const [])
          .map((e) => SangeetTrackObject.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      result.add((album: album, tracks: albumTracks));
    }
    return result;
  } catch (_) {
    return const [];
  }
});

/// Builds the "Newest Arrivals", "Top Trending" and "Albums" lists shown on
/// the home screen. All three are derived from the same full catalog
/// ([homeTracksProvider]):
///  - Newest Arrivals is the catalog sorted by release date, newest first.
///  - Top Trending is the catalog ordered by global play counts (every user's
///    plays recorded in the shared `song_plays` table), newest plays first as
///    a tie-breaker.
///  - Albums is the catalog grouped by album name (so songs that share an
///    album name land in the same album, named after that album), sorted by
///    total play count (most played first). Each album's cover image is the
///    thumbnail of its most played song.
final homeSectionsProvider =
    FutureProvider<HomeSections>((ref) async {
  final tracks = await ref.watch(homeTracksProvider.future);
  final playCounts = await ref.watch(globalPlayCountsProvider.future);

  final newestArrivals = [...tracks]..sort((a, b) {
      // Featured songs (admin-arranged) always come first.
      final aF = a is SangeetFullTrackObject ? a.featuredOrder : null;
      final bF = b is SangeetFullTrackObject ? b.featuredOrder : null;
      if (aF != null || bF != null) {
        if (aF != null && bF != null) {
          if (aF != bF) return aF.compareTo(bF);
        } else {
          return aF != null ? -1 : 1;
        }
      }
      final aDate = DateTime.tryParse(a.album.releaseDate ?? '');
      final bDate = DateTime.tryParse(b.album.releaseDate ?? '');
      final cmp = (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

  final topTrending = [...tracks]..sort((a, b) {
      final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

  final albums = _buildAlbums(tracks, playCounts);
  // Merge admin-created albums (with covers) ahead of the auto-grouped ones.
  final adminAlbums = await ref.watch(homeAdminAlbumsProvider.future);
  final languages = _buildLanguageGroups(tracks, playCounts);

  // Deduplicate the merged album list by album name. Admin-created albums
  // (which carry the real album cover) come first, so when tracks are also
  // auto-grouped under the same album name the duplicate card (whose cover is
  // just a song thumbnail) is dropped instead of being shown twice.
  final mergedAlbums = <HomeAlbum>[];
  final seen = <String>{};
  for (final a in [...adminAlbums, ...albums]) {
    final key = a.album.name.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    mergedAlbums.add(a);
  }

  ref.keepAlive();
  return HomeSections(
    newestArrivals: newestArrivals,
    topTrending: topTrending,
    albums: mergedAlbums,
    languages: languages,
  );
});

/// Groups [tracks] into albums by album name. For each album:
///  - the album object is named after the album name,
///  - the cover image is the thumbnail of the most played song in it,
///  - albums are sorted by total play count (most played first), then name.
List<HomeAlbum> _buildAlbums(
  List<SangeetTrackObject> tracks,
  Map<String, int> playCounts,
) {
  final byName = <String, List<SangeetTrackObject>>{};
  for (final track in tracks) {
    final albumName = track.album.name.trim().isNotEmpty
        ? track.album.name
        : track.name;
    byName.putIfAbsent(albumName, () => []).add(track);
  }

  final albums = byName.entries.map((entry) {
    final albumTracks = entry.value;
    final totalPlays = albumTracks.fold<int>(
      0,
      (sum, t) => sum + (playCounts[t.id] ?? 0),
    );

    // Pick the most played track to source the cover (thumbnails are stored
    // per-track; the album art shown is the art of its most played song).
    final sortedByPlays = [...albumTracks]..sort((a, b) {
        final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
    final coverTrack = sortedByPlays.first;

    final artists = <String, SangeetSimpleArtistObject>{};
    for (final t in albumTracks) {
      for (final artist in t.artists) {
        artists[artist.id] = artist;
      }
    }

    return (
      totalPlays: totalPlays,
      album: SangeetSimpleAlbumObject(
        id: coverTrack.album.id,
        name: entry.key,
        externalUri: coverTrack.album.externalUri,
        artists: artists.values.toList(),
        images: coverTrack.album.images,
        albumType: SangeetAlbumType.album,
        releaseDate: coverTrack.album.releaseDate,
      ),
      tracks: albumTracks,
    );
  }).toList();

  // Language groups are exposed as their own home components ("<Lang> Songs"),
  // not as albums, so they are intentionally NOT added to [albums].

  albums.sort((a, b) {
    final cmp = b.totalPlays.compareTo(a.totalPlays);
    if (cmp != 0) return cmp;
    return a.album.name.compareTo(b.album.name);
  });

  return albums
      .map((e) => (album: e.album, tracks: e.tracks))
      .toList();
}

/// Groups [tracks] into one component per language, named "<Language> Songs"
/// (e.g. "Telugu Songs"). Each group carries that language's tracks sorted by
/// total play count (most played first), then name. Tracks without a
/// `language` are ignored. Sort is by total play count (most played first).
List<HomeLanguageGroup> _buildLanguageGroups(
  List<SangeetTrackObject> tracks,
  Map<String, int> playCounts,
) {
  final byLanguage = <String, List<SangeetTrackObject>>{};
  for (final track in tracks) {
    final lang = track is SangeetFullTrackObject
        ? track.language?.trim()
        : null;
    if (lang == null || lang.isEmpty) continue;
    byLanguage.putIfAbsent(lang, () => []).add(track);
  }

  final groups = byLanguage.entries.map((entry) {
    final langTracks = [...entry.value]..sort((a, b) {
        final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
    return (language: entry.key, tracks: langTracks);
  }).toList();

  groups.sort((a, b) {
    final aPlays = a.tracks.fold<int>(
        0, (sum, t) => sum + (playCounts[t.id] ?? 0));
    final bPlays = b.tracks.fold<int>(
        0, (sum, t) => sum + (playCounts[t.id] ?? 0));
    final cmp = bPlays.compareTo(aPlays);
    if (cmp != 0) return cmp;
    return a.language.compareTo(b.language);
  });

  return groups;
}

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
