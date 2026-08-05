import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:supabase/supabase.dart';
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/provider/database/database.dart';

final supabaseClientProvider = Provider((ref) {
  return SupabaseClient(
    Env.supabaseUrl,
    Env.supabaseAnonKey,
    headers: {'X-Client-Info': 'sangeet-dart-server@1.0.0'},
  );
});

const _defaultUser = {
  'id': 'supabase',
  'name': 'Supabase',
  'images': [],
  'externalUri': '',
};

/// Returns a "YYYY-MM" key derived from an ISO `created_at` string.
String monthsKey(String iso) {
  return iso.length >= 7 ? iso.substring(0, 7) : iso;
}

Map<String, dynamic> _trackToJson(Map<String, dynamic> t) {  final rawArtists = t['artist_names'] as List<dynamic>?;
  final artists = rawArtists
          ?.map((name) => {
                'id': name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
                'name': name,
                'externalUri': '',
                'images': null,
              })
          .toList() ?? [];
  final releaseDate = t['created_at']?.toString();
  return {
    'id': t['id'],
    'name': t['title'],
    'externalUri': '',
    'artists': artists,
    'album': {
      'id': 'album-${t['id']}',
      'name': t['title'],
      'externalUri': '',
      'artists': artists,
      'images': t['thumbnail'] != null
          ? [{'url': t['thumbnail'], 'width': 300, 'height': 300}]
          : [],
      'albumType': 'single',
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
          'items': items, 'limit': 100, 'nextOffset': null,
          'total': items.length, 'hasMore': false,
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
      final data = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
      final trackId = (data['track_id'] ?? data['trackId'] ?? '').toString().trim();
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
      final sb = await _supabase;
      final rows = await sb
          .from('song_plays')
          .select('track_id');
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['track_id']?.toString();
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
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

      final matchItems = data.map((t) => {
            'id': t['id'],
            'title': t['title'],
            'artists': t['artist_names'],
            'duration': (t['duration'] ?? 0) * 1000000,
            'thumbnail': t['thumbnail'],
            'externalUri': '',
          }).toList();

      final fullTracks = data.map(_trackToJson).toList();

      if (allMode) {
        return Response.ok(
          jsonEncode({
            'tracks': fullTracks,
            'albums': [],
            'artists': [],
            'playlists': await _buildOwnerPlaylists(data),
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
      return Response.ok(jsonEncode(matchItems), headers: {'content-type': 'application/json'});
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
          .select('storage_path')
          .eq('id', id)
          .single();
      final storagePath = raw['storage_path'] as String;
      final ext = storagePath.split('.').last.toLowerCase();
      final fmt = ext == 'm4a' ? 'mp4' : ext == 'weba' ? 'webm' : ext;

      final signedUrl = await sb.storage.from('music').createSignedUrl(storagePath, 3600);
      return Response.ok(
        jsonEncode({
          'url': signedUrl,
          'container': fmt,
          'type': 'lossy',
          'codec': fmt == 'opus' ? 'opus' : fmt == 'mp3' ? 'mp3' : fmt,
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
                      'id': name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
                      'name': name, 'externalUri': '', 'images': null,
                    })
                .toList() ?? [];
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
                  ? [{'url': t['thumbnail'], 'width': 300, 'height': 300}]
                  : [],
              'albumType': 'single',
              'releaseDate': null,
            }
          ],
        };
      }).toList();
      return Response.ok(
        jsonEncode({
          'items': sections, 'limit': 100, 'nextOffset': null,
          'total': sections.length, 'hasMore': false,
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
          'name': 'Songs',
          'description': '${tracks.length} tracks',
          'externalUri': '',
          'owner': _defaultUser,
          'images': tracks.isNotEmpty && tracks.first['thumbnail'] != null
              ? [{'url': tracks.first['thumbnail'], 'width': 300, 'height': 300}]
              : [],
        }
      ];
      return Response.ok(
        jsonEncode({'items': items, 'limit': 50, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
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
        return Response.ok(
          jsonEncode({
            'id': id,
            'name': row.name,
            'description': row.description,
            'externalUri': '',
            'owner': _defaultUser,
            'images': [],
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
      final isMonthPlaylist = id.startsWith('month-');
      final monthKey = isMonthPlaylist
          ? id.substring('month-'.length)
          : null;

      List<Map<String, dynamic>> filtered;
      if (monthKey != null) {
        const monthNames = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December',
        ];
        final parts = monthKey.split('-');
        final monthName = parts.length == 2
            ? monthNames[(int.parse(parts[1]) - 1).clamp(0, 11)]
            : monthKey;
        filtered = tracks.where((t) {
          final created = t['created_at']?.toString();
          return created != null && monthsKey(created) == monthKey;
        }).toList();
        final name = monthName;
        return Response.ok(
          jsonEncode({
            'id': id,
            'name': name,
            'description': '${filtered.length} tracks',
            'externalUri': '',
            'owner': _defaultUser,
            'images': filtered.isNotEmpty && filtered.first['thumbnail'] != null
                ? [{'url': filtered.first['thumbnail'], 'width': 300, 'height': 300}]
                : [],
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
          ? 'Songs'
          : (rawArtistName ?? 'Songs');
      return Response.ok(
        jsonEncode({
          'id': id,
          'name': name,
          'description': '${filtered.length} tracks',
          'externalUri': '',
          'owner': _defaultUser,
          'images': filtered.isNotEmpty && filtered.first['thumbnail'] != null
              ? [{'url': filtered.first['thumbnail'], 'width': 300, 'height': 300}]
              : [],
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
          jsonEncode({'items': items, 'limit': 500, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
          headers: {'content-type': 'application/json'},
        );
      }

      final isArtistPlaylist = id.startsWith('artist-');
      final rawArtistName = isArtistPlaylist
          ? id.substring('artist-'.length).replaceAll('-', ' ')
          : null;
      final artistName = rawArtistName?.toLowerCase();
      final isMonthPlaylist = id.startsWith('month-');
      final monthKey = isMonthPlaylist
          ? id.substring('month-'.length)
          : null;

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
        jsonEncode({'items': items, 'limit': 500, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/albums/<id>
  Future<Response> getAlbum(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 1);
      if (tracks.isEmpty) return Response.notFound('{"error":"Not found"}');
      final t = tracks.first;
      final rawArtists = t['artist_names'] as List<dynamic>?;
      final artists = rawArtists
              ?.map((name) => {
                    'id': name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
                    'name': name, 'externalUri': '', 'images': null,
                  })
              .toList() ?? [];
      return Response.ok(
        jsonEncode({
          'id': id, 'name': id, 'artists': artists,
          'images': t['thumbnail'] != null
              ? [{'url': t['thumbnail'], 'width': 300, 'height': 300}]
              : [],
          'releaseDate': null, 'externalUri': '', 'totalTracks': 0,
          'albumType': 'album', 'recordLabel': null, 'genres': [],
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/albums/<id>/tracks
  Future<Response> getAlbumTracks(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 100);
      final items = tracks.map(_trackToJson).toList();
      return Response.ok(
        jsonEncode({'items': items, 'limit': 100, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
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
              ? [{'url': first!['thumbnail'], 'width': 300, 'height': 300}]
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
        jsonEncode({'items': items, 'limit': 500, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/users/me
  Future<Response> getUserMe(Request request) async {
    return Response.ok(jsonEncode(_defaultUser), headers: {'content-type': 'application/json'});
  }

  /// GET /supabase/liked-songs/supabase
  Future<Response> getLikedSongs(Request request) async {
    try {
      final tracks = await _fetchAllTracks(limit: 100);
      return Response.ok(jsonEncode(tracks), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// GET /supabase/owner-playlists
  ///
  /// Returns the playlists made by the developer/owner: the full catalog
  /// ("Songs") plus one playlist per artist ("<Artist> — all songs"). Each
  /// playlist shows the artist name and the number of songs it contains.
  Future<Response> getOwnerPlaylists(Request request) async {
    try {
      final tracks = await _fetchAllTracks(limit: 500);
      final items = await _buildOwnerPlaylists(tracks);

      return Response.ok(
        jsonEncode({'items': items, 'limit': 500, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// Builds the developer-curated "default" playlists from the track catalog:
  ///  - "Songs": the whole catalog.
  ///  - One playlist per artist ("By <Artist>"), with the artist's songs.
  ///  - One playlist per upload month ("August", "September", ...).
  Future<List<Map<String, dynamic>>> _buildOwnerPlaylists(
    List<Map<String, dynamic>> tracks,
  ) async {
    final items = <Map<String, dynamic>>[];

    items.add({
      'id': 'supabase-all-tracks',
      'name': 'Songs',
      'description': '${tracks.length} tracks',
      'externalUri': '',
      'owner': _defaultUser,
      'images': tracks.isNotEmpty && tracks.first['thumbnail'] != null
          ? [{'url': tracks.first['thumbnail'], 'width': 300, 'height': 300}]
          : [],
      'totalTracks': tracks.length,
    });

    final artistNames = <String>[];
    for (final t in tracks) {
      for (final name in (t['artist_names'] as List<dynamic>? ?? const [])) {
        final n = name.toString();
        if (!artistNames.contains(n)) artistNames.add(n);
      }
    }
    for (final name in artistNames) {
      final slug = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      final count = tracks.where((t) {
        final names = (t['artist_names'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        return names.contains(name);
      }).length;
      final first = tracks.firstWhereOrNull((t) {
        final names = (t['artist_names'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        return names.contains(name);
      });
      items.add({
        'id': 'artist-$slug',
        'name': name,
        'description': '$count songs',
        'externalUri': '',
        'owner': _defaultUser,
        'images': first != null && first['thumbnail'] != null
            ? [{'url': first['thumbnail'], 'width': 300, 'height': 300}]
            : [],
        'totalTracks': count,
      });
    }

    // Month playlists: segregate songs by the month they were uploaded,
    // e.g. "September", "October", "November", "December", "January"...
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final months = <String, List<Map<String, dynamic>>>{};
    for (final t in tracks) {
      final created = t['created_at']?.toString();
      if (created == null || created.isEmpty) continue;
      final monthIndex = int.tryParse(created.substring(5, 7)) ?? -1;
      if (monthIndex < 1 || monthIndex > 12) continue;
      final key = monthsKey(created);
      months.putIfAbsent(key, () => []).add(t);
    }
    for (final entry in months.entries) {
      final parts = entry.key.split('-'); // "2026-09"
      final monthName = monthNames[int.parse(parts[1]) - 1];
      final first = entry.value.first;
      items.add({
        'id': 'month-${entry.key}',
        'name': monthName,
        'description': '${entry.value.length} songs',
        'externalUri': '',
        'owner': _defaultUser,
        'images': first['thumbnail'] != null
            ? [{'url': first['thumbnail'], 'width': 300, 'height': 300}]
            : [],
        'totalTracks': entry.value.length,
      });
    }

    return items;
  }

  /// GET /supabase/user-playlists
  ///
  /// Returns the playlists created by the user on this device (stored in the
  /// local drift DB).
  Future<Response> getUserPlaylists(Request request) async {
    try {
      final db = ref.read(databaseProvider);
      final rows = await db.select(db.localPlaylistsTable).get();
      final items = <Map<String, dynamic>>[];
      for (final row in rows) {
        final songs = await (db.select(db.localPlaylistSongsTable)
              ..where((t) => t.playlistId.equals(row.id)))
            .get();
        items.add({
          'id': 'local-${row.id}',
          'name': row.name,
          'description': row.description,
          'externalUri': '',
          'owner': _defaultUser,
          'images': const [],
          'totalTracks': songs.length,
        });
      }
      return Response.ok(
        jsonEncode({'items': items, 'limit': 500, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
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
      final data = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
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
      final data = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
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
      return Response(201, body: '{"success":true}', headers: {'content-type': 'application/json'});
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
      return Response.ok('{"success":true}', headers: {'content-type': 'application/json'});
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
            ..where((t) =>
                t.playlistId.equals(pid) & t.trackId.equals(trackId)))
          .go();
      return Response.ok('{"success":true}', headers: {'content-type': 'application/json'});
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
              ? [{'url': images[e.key], 'width': 300, 'height': 300}]
              : [],
          'genres': null,
          'followers': null,
          'songCount': e.value,
        };
      }).toList();
      return Response.ok(
        jsonEncode({'items': items, 'limit': 500, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }
}
