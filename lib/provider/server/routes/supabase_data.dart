import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:supabase/supabase.dart';
import 'package:sangeet/collections/env.dart';

final supabaseClientProvider = Provider((ref) {
  return SupabaseClient(
    Env.supabaseUrl,
    Env.supabaseServiceKey,
    headers: {'X-Client-Info': 'sangeet-dart-server@1.0.0'},
  );
});

const _defaultUser = {
  'id': 'supabase',
  'name': 'Supabase',
  'images': [],
  'externalUri': '',
};

Map<String, dynamic> _trackToJson(Map<String, dynamic> t) {
  final rawArtists = t['artist_names'] as List<dynamic>?;
  final artists = rawArtists
          ?.map((name) => {
                'id': name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
                'name': name,
                'externalUri': '',
                'images': null,
              })
          .toList() ?? [];
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
      'releaseDate': null,
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
        Env.supabaseServiceKey,
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

  /// GET /supabase/search
  Future<Response> search(Request request) async {
    try {
      final uri = request.requestedUri;
      final q = (uri.queryParameters['q'] ?? '').trim();
      final allMode = uri.queryParameters['all'] == 'true';
      final tracksMode = uri.queryParameters['tracks'] == 'true';

      if (q.isEmpty && !allMode) {
        return Response.ok('[]', headers: {'content-type': 'application/json'});
      }

      final sb = await _supabase;
      PostgrestList raw;
      if (q.isNotEmpty) {
        final pattern = '%$q%';
        raw = await sb
            .from('tracks')
            .select()
            .or('title.ilike.$pattern,artist_names_text.ilike.$pattern')
            .limit(30);
      } else {
        raw = await sb
            .from('tracks')
            .select()
            .limit(30);
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
            'tracks': fullTracks, 'albums': [], 'artists': [], 'playlists': [],
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      if (tracksMode) {
        return Response.ok(
          jsonEncode({
            'items': fullTracks, 'limit': 30, 'nextOffset': null,
            'total': fullTracks.length, 'hasMore': false,
          }),
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
  Future<Response> getPlaylist(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 100);
      return Response.ok(
        jsonEncode({
          'id': 'supabase-all-tracks',
          'name': 'Songs',
          'description': '${tracks.length} tracks',
          'externalUri': '',
          'owner': _defaultUser,
          'images': tracks.isNotEmpty && tracks.first['thumbnail'] != null
              ? [{'url': tracks.first['thumbnail'], 'width': 300, 'height': 300}]
              : [],
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
    return Response.ok(
      jsonEncode({
        'id': id, 'name': id.replaceAll('-', ' '),
        'externalUri': '', 'images': [], 'genres': null, 'followers': null,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  /// GET /supabase/artists/<id>/top-tracks
  Future<Response> getArtistTopTracks(Request request, String id) async {
    try {
      final tracks = await _fetchAllTracks(limit: 20);
      final items = tracks.map(_trackToJson).toList();
      return Response.ok(
        jsonEncode({'items': items, 'limit': 20, 'nextOffset': null, 'total': items.length, 'hasMore': false}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/auth/send-otp
  Future<Response> sendOtp(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final phone = body['phone'] as String?;
      if (phone == null || phone.isEmpty) {
        return Response.badRequest(body: '{"error":"Phone number required"}');
      }
      final sb = await _supabase;
      await sb.auth.signInWithOtp(phone: phone, channel: OtpChannel.sms);
      return Response.ok(jsonEncode({'success': true}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
  }

  /// POST /supabase/auth/verify-otp
  Future<Response> verifyOtp(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final phone = body['phone'] as String?;
      final token = body['token'] as String?;
      if (phone == null || token == null) {
        return Response.badRequest(body: '{"error":"Phone and token required"}');
      }
      final sb = await _supabase;
      final response = await sb.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      final session = response.session;
      return Response.ok(
        jsonEncode({
          'authenticated': session != null,
          'accessToken': session?.accessToken,
          'refreshToken': session?.refreshToken,
          'userId': session?.user.id,
          'phone': session?.user.phone,
        }),
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

  /// GET /supabase/user-profile/<userId>
  Future<Response> getUserProfile(Request request, String userId) async {
    try {
      final sb = await _supabase;
      final profile = await sb
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      return Response.ok(jsonEncode(profile), headers: {'content-type': 'application/json'});
    } catch (_) {
      return Response.ok(
        jsonEncode({'id': userId, 'full_name': null, 'avatar_url': null, 'billing_address': null, 'payment_method': null}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// POST /supabase/user-profile
  Future<Response> upsertUserProfile(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      if (body['id'] == null) {
        return Response.badRequest(body: '{"error":"id required"}');
      }
      final sb = await _supabase;
      final result = await sb.from('user_profiles').upsert(body).select().single();
      return Response.ok(jsonEncode(result), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: '{"error":"${e.toString()}"}');
    }
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
}
