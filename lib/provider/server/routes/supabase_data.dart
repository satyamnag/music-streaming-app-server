import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:supabase/supabase.dart';
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/services/sourced_track/r2_url.dart';

final supabaseClientProvider = Provider((ref) {
  return SupabaseClient(
    Env.supabaseUrl,
    Env.supabaseAnonKey,
    headers: {'X-Client-Info': 'sangeet-dart-server@1.0.0'},
  );
});

const _defaultUser = {
  'id': 'supabase',
  'name': 'Songs',
  'images': [],
  'externalUri': '',
};

/// Artist whose auto-generated per-artist playlist is not shown. It is the
/// studio/artist behind every track, so a dedicated playlist adds no value.
const _hiddenArtistName = 'Dr. Sri Ramakantha Rao Chakalakonda';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats a "YYYY-MM" key as "Month, YY" (e.g. "2026-08" -> "August, 26").
String _monthPlaylistName(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) return key;
  final year = parts[0];
  return '${_monthNames[month - 1]}, ${year.length >= 2 ? year.substring(year.length - 2) : year}';
}

/// Returns a "YYYY-MM" key derived from an ISO `created_at` string.
String monthsKey(String iso) {
  return iso.length >= 7 ? iso.substring(0, 7) : iso;
}

/// Stable, URL-safe album identifier derived from the album name so every
/// track that belongs to the same album shares the same id (this is what lets
/// the home "Albums" section group songs by album).
String _albumId(String albumName) {
  final trimmed = albumName.trim();
  if (trimmed.isEmpty) return 'album-unknown';
  final slug = trimmed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'album-unknown' : 'album-$slug';
}

Map<String, dynamic> _trackToJson(Map<String, dynamic> t) {
  final rawArtists = t['artist_names'] as List<dynamic>?;
  final artists = rawArtists
          ?.map((name) => {
                'id': name
                    .toString()
                    .toLowerCase()
                    .replaceAll(RegExp(r'\s+'), '-'),
                'name': name,
                'externalUri': '',
                'images': null,
              })
          .toList() ??
      [];
  final releaseDate = t['created_at']?.toString();
  final albumRaw = t['album']?.toString().trim() ?? '';
  final albumName =
      albumRaw.isNotEmpty ? albumRaw : (t['title'] ?? '').toString();
  return {
    'id': t['id'],
    'name': t['title'],
    'externalUri': '',
    'artists': artists,
    'status': t['status'] ?? 'free',
    'language': t['language'],
    'album': {
      'id': _albumId(albumName),
      'name': albumName,
      'externalUri': '',
      'artists': artists,
      'images': t['thumbnail'] != null
          ? [
              {'url': t['thumbnail'], 'width': 300, 'height': 300}
            ]
          : [],
      'albumType': 'album',
      'releaseDate': releaseDate,
    },
    'durationMs': (t['duration'] ?? 0) * 1000,
    'isrc': '',
    'explicit': false,
  };
}

class ServerSupabaseDataRoutes {
  final Ref ref;
  ServerSupabaseDataRoutes(this.ref);

  Future<SupabaseClient> get _supabase async {
    try {
      return ref.read(supabaseClientProvider);
    } catch (e) {
      // Lazy fallback if provider fails
      return SupabaseClient(
        Env.supabaseUrl,
        Env.supabaseAnonKey,
        headers: {'X-Client-Info': 'sangeet-dart-server@1.0.0'},
      );
    }
  }

  /// Global per-track play counts from the shared `song_plays` table.
  /// Returns an empty map when the table isn't reachable so the UI always
  /// degrades gracefully (covers fall back to the first available track).
  Future<Map<String, int>> _playCounts() async {
    try {
      final sb = await _supabase;
      final rows = await sb.from('song_plays').select('track_id');
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['track_id']?.toString();
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

  /// Returns a cover image for a playlist/album: the thumbnail of its most
  /// played track (per [playCounts]). Falls back to the first track that has
  /// a thumbnail, or null when no track has one.
  List<Map<String, dynamic>> _coverImagesFor(
    List<Map<String, dynamic>> tracks,
    Map<String, int> playCounts,
  ) {
    if (tracks.isEmpty) return const [];
    final withThumb = tracks.where((t) => t['thumbnail'] != null).toList();
    if (withThumb.isEmpty) return const [];
    withThumb.sort((a, b) {
      final cmp = (playCounts[b['id']?.toString()] ?? 0)
          .compareTo(playCounts[a['id']?.toString()] ?? 0);
      if (cmp != 0) return cmp;
      return a['title'].toString().compareTo(b['title'].toString());
    });
    final best = withThumb.first;
    return [
      {'url': best['thumbnail'], 'width': 300, 'height': 300},
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchAllTracks({int limit = 100}) async {
    final sb = await _supabase;
    final raw = await sb
        .from('tracks')
        .select()
        .order('created_at', ascending: true)
        .limit(limit);
    return (raw as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// GET /supabase/tracks
  Future<Response> getTracks(Request request) async {
    try {
      final tracks = await _fetchAllTracks(limit: 100);
      final items = tracks.map(_trackToJson).toList();
      return Response.ok(
        jsonEncode({
          'items': items,
          'limit': 100,
          'nextOffset': null,
          'total': items.length,
          'hasMore': false,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/lyrics/<id>
  ///
  /// Returns the plain lyrics and synced (LRC) lyrics stored for a track in the
  /// tracks table: `{lyrics: string|null, synced_lyrics: string|null}`.
  /// The lyrics provider prefers these server-provided lyrics and falls back
  /// to LRCLib only when they are absent.
  Future<Response> getLyrics(Request request, String id) async {
    try {
      final sb = await _supabase;
      final raw = await sb
          .from('tracks')
          .select('lyrics,synced_lyrics')
          .eq('id', id)
          .maybeSingle();
      if (raw == null) {
        return Response.notFound('{"error":"Track not found"}');
      }
      return Response.ok(
        jsonEncode({
          'lyrics': raw['lyrics'] as String?,
          'synced_lyrics': raw['synced_lyrics'] as String?,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/plays
  ///
  /// Records a play for a track so "Top Trending" reflects global listening
  /// across all users. Body: `{track_id}`. Uses the SECURITY DEFINER
  /// `record_play` RPC so anonymous clients can record plays without a session.
  Future<Response> recordPlay(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final trackId =
          (data['track_id'] ?? data['trackId'] ?? '').toString().trim();
      if (trackId.isEmpty) {
        return Response.badRequest(body: '{"error":"track_id required"}');
      }
      final sb = await _supabase;
      await sb.rpc('record_play', params: {'track_id': trackId});
      return Response.ok('{"status":"ok"}');
    } catch (e) {
      // Never fail playback because of analytics.
      return Response.ok('{"status":"ok","skipped":true}');
    }
  }

  /// GET /supabase/plays/trending
  ///
  /// Returns the global play count for every track: `{counts: {track_id: n}}`.
  Future<Response> getPlayCounts(Request request) async {
    try {
      final counts = await _playCounts();
      return Response.ok(
        jsonEncode({'counts': counts}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.ok(jsonEncode({'counts': <String, int>{}}));
    }
  }

  /// GET /supabase/search
  ///
  /// Search the tracks catalog. Behaviour:
  ///  - `q` non-empty: filter by title / artist (`ilike`).
  ///  - `q` empty: return the full catalog (so an empty search lists all
  ///    songs instead of showing nothing).
  ///  - `limit` (default 100, max 500) controls the page size.
  ///  - `tracks=true` / `all=true` select the response shape (list vs object).
  Future<Response> search(Request request) async {
    try {
      final uri = request.requestedUri;
      final q = (uri.queryParameters['q'] ?? '').trim();
      final allMode = uri.queryParameters['all'] == 'true';
      final tracksMode = uri.queryParameters['tracks'] == 'true';
      final limit = (int.tryParse(uri.queryParameters['limit'] ?? '') ?? 100)
          .clamp(1, 500);

      final sb = await _supabase;
      PostgrestList raw;
      if (q.isNotEmpty) {
        final pattern = '%$q%';
        raw = await sb
            .from('tracks')
            .select()
            .or('title.ilike.$pattern,artist_names_text.ilike.$pattern')
            .order('created_at', ascending: true)
            .limit(limit);
      } else {
        raw = await sb
            .from('tracks')
            .select()
            .order('created_at', ascending: true)
            .limit(limit);
      }
      final data = raw.cast<Map<String, dynamic>>();

      final matchItems = data
          .map((t) => {
                'id': t['id'],
                'title': t['title'],
                'artists': t['artist_names'],
                'duration': (t['duration'] ?? 0) * 1000000,
                'thumbnail': t['thumbnail'],
                'status': t['status'] ?? 'free',
                'externalUri': '',
              })
          .toList();

      final fullTracks = data.map(_trackToJson).toList();

      if (allMode) {
        return Response.ok(
          jsonEncode({
            'tracks': fullTracks,
            'albums': [],
            'artists': [],
            // No prebuilt/owner playlists: search results never include them.
            'playlists': [],
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      if (tracksMode) {
        // Return a plain JSON array: the Supabase plugin's `tracks()` wraps the
        // response body directly as `items: response.data`, so the body must be
        // the list itself (not an `{items: [...]}` envelope).
        return Response.ok(
          jsonEncode(fullTracks),
          headers: {'content-type': 'application/json'},
        );
      }
      return Response.ok(jsonEncode(matchItems),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/stream/<id>
  Future<Response> getStreamUrl(Request request, String id) async {
    try {
      final sb = await _supabase;
      final raw = await sb
          .from('tracks')
          .select('storage_path,status')
          .eq('id', id)
          .single();
      // Paid tracks are locked for free users — refuse to hand out a stream
      // URL even if a client bypasses the UI.
      if (raw['status'] == 'paid' && !PremiumAccess.isPremiumUser(ref)) {
        return Response.forbidden(
            '{"error":"This track requires a premium subscription"}');
      }
      final storagePath = raw['storage_path'] as String;
      final ext = storagePath.split('.').last.toLowerCase();
      final fmt = ext == 'm4a'
          ? 'mp4'
          : ext == 'weba'
              ? 'webm'
              : ext;

      // Stream from the Cloudflare R2 public CDN (zero egress). Fall back to a
      // Supabase signed URL only when R2 is not configured.
      final r2 = r2StreamUrl(storagePath);
      final url = r2 ??
          await sb.storage.from('music').createSignedUrl(storagePath, 3600);
      return Response.ok(
        jsonEncode({
          'url': url,
          'container': fmt,
          'type': 'lossy',
          'codec': fmt == 'opus'
              ? 'opus'
              : fmt == 'mp3'
                  ? 'mp3'
                  : fmt,
          'bitrate': fmt == 'opus' ? 96000 : 128000,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/browse/sections
  Future<Response> getBrowseSections(Request request) async {
    try {
      final tracks = await _fetchAllTracks(limit: 100);
      final sections = tracks.map((t) {
        final rawArtists = t['artist_names'] as List<dynamic>?;
        final artists = rawArtists
                ?.map((name) => {
                      'id': name
                          .toString()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), '-'),
                      'name': name,
                      'externalUri': '',
                      'images': null,
                    })
                .toList() ??
            [];
        return {
          'id': 'section-${t['id']}',
          'title': t['title'],
          'externalUri': '',
          'browseMore': false,
          'items': [
            {
              'id': 'album-${t['id']}',
              'name': t['title'],
              'externalUri': '',
              'artists': artists,
              'images': t['thumbnail'] != null
                  ? [
                      {'url': t['thumbnail'], 'width': 300, 'height': 300}
                    ]
                  : [],
              'albumType': 'single',
              'releaseDate': null,
            }
          ],
        };
      }).toList();
      return Response.ok(
        jsonEncode({
          'items': sections,
          'limit': 100,
          'nextOffset': null,
          'total': sections.length,
          'hasMore': false,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/browse/sections/<id>/items
  Future<Response> getBrowseSectionItems(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 100);
      final items = [
        {
          'id': 'supabase-all-tracks',
          'name': 'All Songs',
          'description': '${tracks.length} tracks',
          'externalUri': '',
          'owner': _defaultUser,
          'images': tracks.isNotEmpty && tracks.first['thumbnail'] != null
              ? [
                  {
                    'url': tracks.first['thumbnail'],
                    'width': 300,
                    'height': 300
                  }
                ]
              : [],
        }
      ];
      return Response.ok(
        jsonEncode({
          'items': items,
          'limit': 50,
          'nextOffset': null,
          'total': items.length,
          'hasMore': false
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/tracks/<id>
  Future<Response> getTrack(Request request, String id) async {
    try {
      final sb = await _supabase;
      final raw = await sb.from('tracks').select().eq('id', id).single();
      return Response.ok(
        jsonEncode(_trackToJson(raw)),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/playlists/<id>
  ///
  /// Returns a single playlist. Supports:
  ///  - owner playlists: `supabase-all-tracks` (the whole catalog) and
  ///    per-artist playlists `artist-<slug>` ("<Artist> — all songs").
  ///  - local user playlists: `local-<id>` (stored in the on-device drift DB).
  Future<Response> getPlaylist(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);
      if (id.startsWith('local-')) {
        final db = ref.read(databaseProvider);
        final row = await (db.select(db.localPlaylistsTable)
              ..where((t) => t.id.equals(id.substring('local-'.length))))
            .getSingleOrNull();
        if (row == null) return Response.notFound('{"error":"Not found"}');
        final songRows = await (db.select(db.localPlaylistSongsTable)
              ..where((t) => t.playlistId.equals(row.id)))
            .get();
        final songTracks = tracks
            .where((t) => songRows.any((s) => s.trackId == t['id'].toString()))
            .toList();
        final playCounts = await _playCounts();
        return Response.ok(
          jsonEncode({
            'id': id,
            'name': row.name,
            'description': row.description,
            'externalUri': '',
            'owner': _defaultUser,
            'images': _coverImagesFor(songTracks, playCounts),
            'totalTracks': songRows.length,
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final isArtistPlaylist = id.startsWith('artist-');
      final rawArtistName = isArtistPlaylist
          ? id.substring('artist-'.length).replaceAll('-', ' ')
          : null;
      final artistName = rawArtistName?.toLowerCase();
      if (rawArtistName != null &&
          rawArtistName.toLowerCase() == _hiddenArtistName.toLowerCase()) {
        return Response.notFound('{"error":"Not found"}');
      }
      final isMonthPlaylist = id.startsWith('month-');
      final monthKey = isMonthPlaylist ? id.substring('month-'.length) : null;

      List<Map<String, dynamic>> filtered;
      if (monthKey != null) {
        filtered = tracks.where((t) {
          final created = t['created_at']?.toString();
          return created != null && monthsKey(created) == monthKey;
        }).toList();
        final name = _monthPlaylistName(monthKey);
        final playCounts = await _playCounts();
        return Response.ok(
          jsonEncode({
            'id': id,
            'name': name,
            'description': '${filtered.length} tracks',
            'externalUri': '',
            'owner': _defaultUser,
            'images': _coverImagesFor(filtered, playCounts),
            'totalTracks': filtered.length,
          }),
          headers: {'content-type': 'application/json'},
        );
      } else {
        filtered = artistName == null
            ? tracks
            : tracks.where((t) {
                final names = (t['artist_names'] as List<dynamic>?)
                        ?.map((e) => e.toString().toLowerCase())
                        .toList() ??
                    const [];
                return names.any((n) => n.contains(artistName));
              }).toList();
      }

      final name = id == 'supabase-all-tracks'
          ? 'All Songs'
          : (rawArtistName ?? 'All Songs');
      final playCounts = await _playCounts();
      return Response.ok(
        jsonEncode({
          'id': id,
          'name': name,
          'description': '${filtered.length} tracks',
          'externalUri': '',
          'owner': _defaultUser,
          'images': _coverImagesFor(filtered, playCounts),
          'totalTracks': filtered.length,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/playlists/<id>/tracks
  Future<Response> getPlaylistTracks(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);

      if (id.startsWith('local-')) {
        final db = ref.read(databaseProvider);
        final row = await (db.select(db.localPlaylistsTable)
              ..where((t) => t.id.equals(id.substring('local-'.length))))
            .getSingleOrNull();
        if (row == null) return Response.notFound('{"error":"Not found"}');
        final songRows = await (db.select(db.localPlaylistSongsTable)
              ..where((t) => t.playlistId.equals(row.id))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
        final items = <Map<String, dynamic>>[];
        for (final song in songRows) {
          final track = tracks
              .where((t) => t['id'].toString() == song.trackId)
              .firstOrNull;
          if (track != null) items.add(_trackToJson(track));
        }
        return Response.ok(
          jsonEncode({
            'items': items,
            'limit': 500,
            'nextOffset': null,
            'total': items.length,
            'hasMore': false
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final isArtistPlaylist = id.startsWith('artist-');
      final rawArtistName = isArtistPlaylist
          ? id.substring('artist-'.length).replaceAll('-', ' ')
          : null;
      final artistName = rawArtistName?.toLowerCase();
      if (rawArtistName != null &&
          rawArtistName.toLowerCase() == _hiddenArtistName.toLowerCase()) {
        return Response.notFound('{"error":"Not found"}');
      }
      final isMonthPlaylist = id.startsWith('month-');
      final monthKey = isMonthPlaylist ? id.substring('month-'.length) : null;

      final filtered = monthKey != null
          ? tracks.where((t) {
              final created = t['created_at']?.toString();
              return created != null && monthsKey(created) == monthKey;
            }).toList()
          : (artistName == null
              ? tracks
              : tracks.where((t) {
                  final names = (t['artist_names'] as List<dynamic>?)
                          ?.map((e) => e.toString().toLowerCase())
                          .toList() ??
                      const [];
                  return names.any((n) => n.contains(artistName));
                }).toList());
      final items = filtered.map(_trackToJson).toList();
      return Response.ok(
        jsonEncode({
          'items': items,
          'limit': 500,
          'nextOffset': null,
          'total': items.length,
          'hasMore': false
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/albums/<id>
  ///
  /// Returns a single album grouped by album name (or by language for the
  /// auto-generated "All <Language> Songs" albums), with the cover taken from
  /// its most played track. `id` is the album slug (e.g.
  /// `album-madhava-manohara` or `album-language-telugu`).
  Future<Response> getAlbum(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);

      // Language albums: id `album-language-<lang>` -> all tracks of that lang.
      if (id.startsWith('album-language-')) {
        final lang = id
            .substring('album-language-'.length)
            .replaceAll('-', ' ')
            .trim();
        final langTracks = tracks
            .where((t) =>
                (t['language']?.toString().trim() ?? '').toLowerCase() ==
                lang.toLowerCase())
            .toList();
        if (langTracks.isEmpty) {
          return Response.notFound('{"error":"Album not found"}');
        }
        final first = langTracks.first;
        final rawArtists = first['artist_names'] as List<dynamic>?;
        final artists = rawArtists
                ?.map((name) => {
                      'id': name
                          .toString()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), '-'),
                      'name': name,
                      'externalUri': '',
                      'images': null,
                    })
                .toList() ??
            [];
        final playCounts = await _playCounts();
        return Response.ok(
          jsonEncode({
            'id': id,
            'name': 'All ${first['language']} Songs',
            'artists': artists,
            'images': _coverImagesFor(langTracks, playCounts),
            'releaseDate': null,
            'externalUri': '',
            'totalTracks': langTracks.length,
            'albumType': 'album',
            'recordLabel': null,
            'genres': [],
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final albumTracks = tracks.where((t) {
        final name = t['album']?.toString().trim();
        final albumName = name != null && name.isNotEmpty
            ? name
            : (t['title']?.toString() ?? '');
        return albumName.isNotEmpty && _albumId(albumName) == id;
      }).toList();
      if (albumTracks.isEmpty) {
        return Response.notFound('{"error":"Album not found"}');
      }
      final first = albumTracks.first;
      final rawArtists = first['artist_names'] as List<dynamic>?;
      final artists = rawArtists
              ?.map((name) => {
                    'id': name
                        .toString()
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), '-'),
                    'name': name,
                    'externalUri': '',
                    'images': null,
                  })
              .toList() ??
          [];
      final playCounts = await _playCounts();
      return Response.ok(
        jsonEncode({
          'id': id,
          'name': first['album']?.toString().trim().isNotEmpty == true
              ? first['album']
              : first['title'],
          'artists': artists,
          'images': _coverImagesFor(albumTracks, playCounts),
          'releaseDate': null,
          'externalUri': '',
          'totalTracks': albumTracks.length,
          'albumType': 'album',
          'recordLabel': null,
          'genres': [],
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/albums/<id>/tracks
  ///
  /// Returns the tracks that belong to the given album (grouped by album name,
  /// or by language for the auto-generated "All <Language> Songs" albums).
  Future<Response> getAlbumTracks(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);

      // Admin-created album (public.albums uuid): return the tracks explicitly
      // assigned to it via tracks.album_id.
      if (!id.startsWith('album-')) {
        final adminItems = tracks
            .where((t) => t['album_id']?.toString() == id)
            .map(_trackToJson)
            .toList();
        return Response.ok(
          jsonEncode({
            'items': adminItems,
            'limit': 500,
            'nextOffset': null,
            'total': adminItems.length,
            'hasMore': false
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Language albums: id `album-language-<lang>` -> all tracks of that lang.
      if (id.startsWith('album-language-')) {
        final lang = id
            .substring('album-language-'.length)
            .replaceAll('-', ' ')
            .trim();
        final items = tracks
            .where((t) =>
                (t['language']?.toString().trim() ?? '').toLowerCase() ==
                lang.toLowerCase())
            .map(_trackToJson)
            .toList();
        return Response.ok(
          jsonEncode({
            'items': items,
            'limit': 500,
            'nextOffset': null,
            'total': items.length,
            'hasMore': false
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final items = tracks
          .where((t) {
            final name = t['album']?.toString().trim();
            final albumName = name != null && name.isNotEmpty
                ? name
                : (t['title']?.toString() ?? '');
            return albumName.isNotEmpty && _albumId(albumName) == id;
          })
          .map(_trackToJson)
          .toList();
      return Response.ok(
        jsonEncode({
          'items': items,
          'limit': 500,
          'nextOffset': null,
          'total': items.length,
          'hasMore': false
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/albums
  ///
  /// Returns the catalog grouped into albums (by album name). Each album's
  /// cover is the thumbnail of its most played track, so the home "Albums"
  /// section shows the art users actually listen to. Sorted by play count
  /// (most played first), then name.
  Future<Response> getAlbums(Request request) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);
      final playCounts = await _playCounts();

      final byAlbum = <String, List<Map<String, dynamic>>>{};
      for (final t in tracks) {
        final name = t['album']?.toString().trim().isNotEmpty == true
            ? t['album'].toString().trim()
            : t['title'].toString();
        byAlbum.putIfAbsent(name, () => []).add(t);
      }

      final albums = byAlbum.entries.map((entry) {
        final albumTracks = entry.value;
        final first = albumTracks.first;
        final rawArtists = first['artist_names'] as List<dynamic>?;
        final artists = rawArtists
                ?.map((name) => {
                      'id': name
                          .toString()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), '-'),
                      'name': name,
                      'externalUri': '',
                      'images': null,
                    })
                .toList() ??
            [];
        final totalPlays = albumTracks.fold<int>(
          0,
          (sum, t) => sum + (playCounts[t['id']?.toString()] ?? 0),
        );
        return {
          'id': _albumId(entry.key),
          'name': entry.key,
          'externalUri': '',
          'artists': artists,
          'images': _coverImagesFor(albumTracks, playCounts),
          'albumType': 'album',
          'releaseDate': null,
          'totalTracks': albumTracks.length,
          'totalPlays': totalPlays,
        };
      }).toList();

      // Language albums: "All Telugu Songs", "All Kannada Songs", ... Each
      // groups every track tagged with that language (untagged tracks are
      // skipped). Cover is the most played track of that language.
      final byLanguage = <String, List<Map<String, dynamic>>>{};
      for (final t in tracks) {
        final lang = t['language']?.toString().trim();
        if (lang == null || lang.isEmpty) continue;
        byLanguage.putIfAbsent(lang, () => []).add(t);
      }
      for (final entry in byLanguage.entries) {
        final langTracks = entry.value;
        final first = langTracks.first;
        final rawArtists = first['artist_names'] as List<dynamic>?;
        final artists = rawArtists
                ?.map((name) => {
                      'id': name
                          .toString()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), '-'),
                      'name': name,
                      'externalUri': '',
                      'images': null,
                    })
                .toList() ??
            [];
        final totalPlays = langTracks.fold<int>(
          0,
          (sum, t) => sum + (playCounts[t['id']?.toString()] ?? 0),
        );
        final langKey = entry.key.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
        albums.add({
          'id': 'album-language-$langKey',
          'name': 'All ${entry.key} Songs',
          'externalUri': '',
          'artists': artists,
          'images': _coverImagesFor(langTracks, playCounts),
          'albumType': 'album',
          'releaseDate': null,
          'totalTracks': langTracks.length,
          'totalPlays': totalPlays,
        });
      }

      albums.sort((a, b) {
        final cmp = (b['totalPlays'] as int).compareTo(a['totalPlays'] as int);
        if (cmp != 0) return cmp;
        return a['name'].toString().compareTo(b['name'].toString());
      });

      return Response.ok(
        jsonEncode({
          'items': albums,
          'limit': 500,
          'nextOffset': null,
          'total': albums.length,
          'hasMore': false,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/artists/<id>
  Future<Response> getArtist(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);
      final name = id.replaceAll('-', ' ');
      final matched = tracks.where((t) {
        final names = (t['artist_names'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        return names.contains(name) ||
            names.any((n) => n.toLowerCase().contains(name.toLowerCase()));
      }).toList();
      final first = matched.isNotEmpty ? matched.first : null;
      return Response.ok(
        jsonEncode({
          'id': id,
          'name': first?['artist_names'] is List &&
                  (first!['artist_names'] as List).isNotEmpty
              ? (first['artist_names'] as List).first.toString()
              : name,
          'externalUri': '',
          'images': first?['thumbnail'] != null
              ? [
                  {'url': first!['thumbnail'], 'width': 300, 'height': 300}
                ]
              : [],
          'genres': null,
          'followers': null,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/artists/<id>/top-tracks
  Future<Response> getArtistTopTracks(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);
      final name = id.replaceAll('-', ' ');
      final matched = tracks.where((t) {
        final names = (t['artist_names'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        return names.contains(name) ||
            names.any((n) => n.toLowerCase().contains(name.toLowerCase()));
      }).toList();
      final items = matched.map(_trackToJson).toList();
      return Response.ok(
        jsonEncode({
          'items': items,
          'limit': 500,
          'nextOffset': null,
          'total': items.length,
          'hasMore': false
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/users/me
  Future<Response> getUserMe(Request request) async {
    return Response.ok(jsonEncode(_defaultUser),
        headers: {'content-type': 'application/json'});
  }

  /// GET /supabase/liked-songs/supabase
  ///
  /// Returns the tracks the user liked on this device (stored in the local
  /// drift DB). The app works without a Supabase account, so likes are kept
  /// on-device and served through the local stream server.
  Future<Response> getLikedSongs(Request request) async {
    try {
      final db = ref.read(databaseProvider);
      final rows = await (db.select(db.localLikedSongsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      if (rows.isEmpty) {
        return Response.ok(jsonEncode(const []),
            headers: {'content-type': 'application/json'});
      }
      final tracks = await _fetchAllTracks(limit: 500);
      final items = <Map<String, dynamic>>[];
      for (final row in rows) {
        final track =
            tracks.where((t) => t['id'].toString() == row.trackId).firstOrNull;
        if (track != null) items.add(_trackToJson(track));
      }
      return Response.ok(
        jsonEncode(items),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/liked-songs
  ///
  /// Records a liked track locally. Body: `{track_id}`.
  Future<Response> addLikedSong(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final trackId =
          (data['track_id'] ?? data['trackId'] ?? '').toString().trim();
      if (trackId.isEmpty) {
        return Response.badRequest(body: '{"error":"track_id required"}');
      }
      final db = ref.read(databaseProvider);
      final existing = await (db.select(db.localLikedSongsTable)
            ..where((t) => t.trackId.equals(trackId)))
          .getSingleOrNull();
      if (existing == null) {
        await db.into(db.localLikedSongsTable).insert(
              LocalLikedSongsTableCompanion.insert(trackId: trackId),
            );
      }
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// DELETE /supabase/liked-songs/<trackId>
  Future<Response> removeLikedSong(Request request, String trackId) async {
    try {
      final db = ref.read(databaseProvider);
      await (db.delete(db.localLikedSongsTable)
            ..where((t) => t.trackId.equals(trackId)))
          .go();
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/user-playlists
  ///
  /// Returns the playlists created by the user on this device (stored in the
  /// local drift DB). Each playlist's cover is the most played song inside it.
  Future<Response> getUserPlaylists(Request request) async {
    try {
      final db = ref.read(databaseProvider);
      final rows = await db.select(db.localPlaylistsTable).get();
      final tracks = await _fetchAllTracks(limit: 500);
      final playCounts = await _playCounts();
      final items = <Map<String, dynamic>>[];
      for (final row in rows) {
        final songs = await (db.select(db.localPlaylistSongsTable)
              ..where((t) => t.playlistId.equals(row.id)))
            .get();
        final songTracks = tracks
            .where((t) => songs.any((s) => s.trackId == t['id'].toString()))
            .toList();
        items.add({
          'id': 'local-${row.id}',
          'name': row.name,
          'description': '${songs.length} songs',
          'externalUri': '',
          'owner': _defaultUser,
          'images': _coverImagesFor(songTracks, playCounts),
          'totalTracks': songs.length,
        });
      }
      return Response.ok(
        jsonEncode({
          'items': items,
          'limit': 500,
          'nextOffset': null,
          'total': items.length,
          'hasMore': false
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/admin-albums
  ///
  /// Returns the admin-created albums (name + cover) with their assigned
  /// tracks, so the home "Albums" component can show them and clicking one
  /// plays its tracks first-to-last.
  Future<Response> getAdminAlbums(Request request) async {
    try {
      final sb = await _supabase;
      final albums = await sb.from('albums').select('*').order('created_at', ascending: true);
      final allTracks = await sb.from('tracks').select('*').order('created_at', ascending: true);

      final byAlbum = <String, List<Map<String, dynamic>>>{};
      for (final t in allTracks) {
        final albumId = t['album_id']?.toString();
        if (albumId == null || albumId.isEmpty) continue;
        (byAlbum[albumId] = byAlbum[albumId] ?? []).add(_trackToJson(t));
      }

      final items = albums.map((a) {
        final cover = a['cover_url']?.toString();
        return {
          'id': a['id'].toString(),
          'name': a['name']?.toString() ?? '',
          'externalUri': '',
          'artists': const <dynamic>[],
          'images': cover != null
              ? [
                  {'url': cover, 'width': 300, 'height': 300}
                ]
              : const [],
          'albumType': 'album',
          'releaseDate': null,
          'tracks': byAlbum[a['id'].toString()] ?? const [],
        };
      }).toList();

      return Response.ok(
        jsonEncode({'items': items}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/api/playlists
  ///
  /// Creates a user playlist in the local drift DB. Body: `{name, description}`.
  Future<Response> createUserPlaylist(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final name = (data['name'] ?? data['title'] ?? '').toString().trim();
      if (name.isEmpty) {
        return Response.badRequest(body: '{"error":"name required"}');
      }
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final db = ref.read(databaseProvider);
      await db.into(db.localPlaylistsTable).insert(
            LocalPlaylistsTableCompanion.insert(
              id: id,
              name: name,
              description: Value((data['description'] ?? '').toString()),
            ),
          );
      return Response(
        201,
        body: jsonEncode({
          'id': 'local-$id',
          'name': name,
          'description': (data['description'] ?? '').toString(),
          'externalUri': '',
          'owner': _defaultUser,
          'images': const [],
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/api/playlists/<id>/songs
  ///
  /// Adds a track to a local user playlist. Body: `{track_id}`.
  Future<Response> addUserPlaylistSong(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final trackId = (data['track_id'] ?? '').toString();
      if (trackId.isEmpty) {
        return Response.badRequest(body: '{"error":"track_id required"}');
      }
      final playlistId = id.startsWith('local-') ? id.substring(6) : id;
      final db = ref.read(databaseProvider);
      final existing = await (db.select(db.localPlaylistSongsTable)
            ..where((t) =>
                t.playlistId.equals(playlistId) & t.trackId.equals(trackId)))
          .get();
      if (existing.isEmpty) {
        final count = await (db.select(db.localPlaylistSongsTable)
              ..where((t) => t.playlistId.equals(playlistId)))
            .get();
        await db.into(db.localPlaylistSongsTable).insert(
              LocalPlaylistSongsTableCompanion.insert(
                playlistId: playlistId,
                trackId: trackId,
                position: Value(count.length),
              ),
            );
      }
      return Response(201,
          body: '{"success":true}',
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// DELETE /supabase/api/playlists/<id>
  Future<Response> deleteUserPlaylist(Request request, String id) async {
    try {
      final playlistId = id.startsWith('local-') ? id.substring(6) : id;
      final db = ref.read(databaseProvider);
      await (db.delete(db.localPlaylistSongsTable)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();
      await (db.delete(db.localPlaylistsTable)
            ..where((t) => t.id.equals(playlistId)))
          .go();
      return Response.ok('{"success":true}',
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// DELETE /supabase/api/playlists/<playlistId>/songs/<trackId>
  Future<Response> removeUserPlaylistSong(
      Request request, String playlistId, String trackId) async {
    try {
      final pid = playlistId.startsWith('local-')
          ? playlistId.substring(6)
          : playlistId;
      final db = ref.read(databaseProvider);
      await (db.delete(db.localPlaylistSongsTable)
            ..where(
                (t) => t.playlistId.equals(pid) & t.trackId.equals(trackId)))
          .go();
      return Response.ok('{"success":true}',
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/artists
  ///
  /// Returns every artist in the catalog with the number of songs they have.
  Future<Response> getArtists(Request request) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);
      final byName = <String, int>{};
      final images = <String, String?>{};
      for (final t in tracks) {
        for (final name in (t['artist_names'] as List<dynamic>? ?? const [])) {
          final n = name.toString();
          byName[n] = (byName[n] ?? 0) + 1;
          images[n] ??= t['thumbnail']?.toString();
        }
      }
      final items = byName.entries.map((e) {
        return {
          'id': e.key.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
          'name': e.key,
          'externalUri': '',
          'images': images[e.key] != null
              ? [
                  {'url': images[e.key], 'width': 300, 'height': 300}
                ]
              : [],
          'genres': null,
          'followers': null,
          'songCount': e.value,
        };
      }).toList();
      return Response.ok(
        jsonEncode({
          'items': items,
          'limit': 500,
          'nextOffset': null,
          'total': items.length,
          'hasMore': false
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/referrals/<userId>/code
  ///
  /// Creates (on first use) and returns the signed-in user's referral code.
  /// The code is generated server-side by a SECURITY DEFINER RPC and is
  /// un-guessable; the same code is always returned for the same user.
  Future<Response> getReferralCode(Request request, String userId) async {
    try {
      final sb = await _supabase;
      final res = await sb
          .rpc('get_or_create_referral_code', params: {'p_user_id': userId});
      if (res.error != null) {
        return Response.internalServerError(
            body: '{"error":"${res.error!.message}"}');
      }
      return Response.ok(
        jsonEncode({'code': res.data}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/referrals/attribute
  ///
  /// Records that the (newly signed-in) user opened the app via a referral
  /// code. Body: `{code, referred_user_id}`. The RPC validates the code and
  /// rejects self-referral; a user can be attributed at most once.
  Future<Response> recordReferralAttribution(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final code = (data['code'] ?? '').toString().trim();
      final referredUserId =
          (data['referred_user_id'] ?? data['referredUserId'] ?? '')
              .toString()
              .trim();
      if (code.isEmpty || referredUserId.isEmpty) {
        return Response.badRequest(
            body: '{"error":"code and referred_user_id required"}');
      }
      final sb = await _supabase;
      final res = await sb.rpc(
        'record_referral_attribution',
        params: {'p_code': code, 'p_referred_user_id': referredUserId},
      );
      if (res.error != null) {
        return Response.internalServerError(
            body: '{"error":"${res.error!.message}"}');
      }
      return Response.ok(
        jsonEncode({'success': res.data}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/referrals/<userId>/summary
  ///
  /// Returns the signed-in user's referral earnings summary: their code,
  /// number of referred sign-ups, and pending/credited/total commission.
  Future<Response> getReferralSummary(Request request, String userId) async {
    try {
      final sb = await _supabase;
      final res =
          await sb.rpc('get_referral_summary', params: {'p_user_id': userId});
      if (res.error != null) {
        return Response.internalServerError(
            body: '{"error":"${res.error!.message}"}');
      }
      final rows = (res.data as List<dynamic>? ?? const []);
      final row =
          rows.isNotEmpty ? (rows.first as Map) : const <String, dynamic>{};
      return Response.ok(
        jsonEncode({
          'code': row['code'],
          'referralCount': row['referral_count'] ?? 0,
          'pendingAmount': row['pending_amount'] ?? 0,
          'creditedAmount': row['credited_amount'] ?? 0,
          'totalAmount': row['total_amount'] ?? 0,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/coupons/validate
  ///
  /// Validates an affiliate coupon code (attribution-only, no side effects).
  /// Body: `{code}`. Returns `{valid, affiliateName}`. The affiliate name is
  /// public display info only — never contact or payout details.
  Future<Response> validateCoupon(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final code = (data['code'] ?? '').toString().trim();
      if (code.isEmpty) {
        return Response.badRequest(body: '{"error":"code required"}');
      }
      final sb = await _supabase;
      final res = await sb.rpc(
        'validate_coupon',
        params: {'p_code': code},
      );
      if (res.error != null) {
        return Response.internalServerError(
            body: '{"error":"${res.error!.message}"}');
      }
      final rows = (res.data as List<dynamic>? ?? const []);
      final row =
          rows.isNotEmpty ? (rows.first as Map) : const <String, dynamic>{};
      return Response.ok(
        jsonEncode({
          'valid': row['valid'] ?? false,
          'affiliateName': row['affiliate_name'],
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/coupons/redeem
  ///
  /// Redeems an affiliate coupon code for a signed-in user. Body:
  /// `{code, user_id}`. The RPC validates the code atomically (status,
  /// expiry, redemption limit), increments the redemption count, and records
  /// the attribution ONCE per user. Returns `{status}` where status is one of:
  /// redeemed, already_redeemed, invalid, inactive, expired, limit_reached.
  Future<Response> redeemCoupon(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final code = (data['code'] ?? '').toString().trim();
      final userId = (data['user_id'] ?? data['userId'] ?? '')
          .toString()
          .trim();
      if (code.isEmpty || userId.isEmpty) {
        return Response.badRequest(
            body: '{"error":"code and user_id required"}');
      }
      final sb = await _supabase;
      final res = await sb.rpc(
        'redeem_coupon',
        params: {'p_code': code, 'p_user_id': userId},
      );
      if (res.error != null) {
        return Response.internalServerError(
            body: '{"error":"${res.error!.message}"}');
      }
      return Response.ok(
        jsonEncode({'status': res.data}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/referrers/bind
  ///
  /// Binds a signed-in user to an affiliate via a QR install-referrer code.
  /// Body: `{referrer_code, user_id}`. The RPC validates the code and records
  /// the immutable attribution ONCE per user. Returns `{status}` where status
  /// is one of: bound, already_bound, invalid.
  Future<Response> bindReferrer(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final code = (data['referrer_code'] ?? '').toString().trim();
      final userId = (data['user_id'] ?? data['userId'] ?? '')
          .toString()
          .trim();
      if (code.isEmpty || userId.isEmpty) {
        return Response.badRequest(
            body: '{"error":"referrer_code and user_id required"}');
      }
      final sb = await _supabase;
      final res = await sb.rpc(
        'bind_affiliate_referral',
        params: {'p_referrer_code': code, 'p_user_id': userId},
      );
      if (res.error != null) {
        return Response.internalServerError(
            body: '{"error":"${res.error!.message}"}');
      }
      return Response.ok(
        jsonEncode({'status': res.data}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }
}
