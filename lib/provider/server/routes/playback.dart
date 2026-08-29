import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio_lib;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/audio_player/state.dart';

import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/server/active_track_sources.dart';
import 'package:sangeet/provider/server/routes/supabase_data.dart';
import 'package:sangeet/provider/server/sourced_track_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:sangeet/services/sourced_track/r2_url.dart';
import 'package:sangeet/services/sourced_track/sourced_track.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void _log(String msg) {
  print('[SANGEET] $msg');
}

/// In-memory cache for resolved sourced tracks. Keyed by trackId, maps to
/// the resolved [SourcedTrack]. This prevents mpv's HEAD + GET + retry
/// requests from hitting Supabase 3-4× per track (saving ~2-3 seconds per
/// track switch). The cache is cleared when the playlist changes.
final Map<String, SourcedTrack> _sourcedTrackCache = {};
final Map<String, DateTime> _sourcedTrackFetchAt = {};

/// How long a resolved stream URL is considered fresh. Signed URLs from
/// Supabase expire (~1h) and the upstream cache is 30 min; re-resolving after
/// 20 min guarantees the URL used on a retry/re-open is still valid, so a song
/// cannot get stuck on an expired URL in low-network conditions.
const Duration _streamUrlMaxAge = Duration(minutes: 20);

void _cacheSourcedTrack(String trackId, SourcedTrack track) {
  _sourcedTrackCache[trackId] = track;
  _sourcedTrackFetchAt[trackId] = DateTime.now();
}

void clearSourcedTrackCache() {
  _sourcedTrackCache.clear();
  _sourcedTrackFetchAt.clear();
}

final _deviceClients = Set.unmodifiable({
  YoutubeApiClient.ios,
  YoutubeApiClient.android,
  YoutubeApiClient.mweb,
  YoutubeApiClient.safari,
});

String? get _randomUserAgent => _deviceClients
    .elementAt(
      Random().nextInt(_deviceClients.length),
    )
    .payload["context"]["client"]["userAgent"];

class ServerPlaybackRoutes {
  final Ref ref;
  AudioPlayerState get playlist => ref.read(audioPlayerProvider);
  final Dio dio;

  ServerPlaybackRoutes(this.ref) : dio = Dio();

  Future<SourcedTrack?> _getSourcedTrack(
    Request request,
    String trackId,
  ) async {
    // Return cached result if available — mpv sends HEAD, GET, and retries,
    // so without caching we hit Supabase 3-4× per track (~2-3s wasted each).
    // A cached URL older than [_streamUrlMaxAge] is treated as a miss so a
    // stale/expired URL is re-resolved fresh on retry.
    final cached = _sourcedTrackCache[trackId];
    final fetchedAt = _sourcedTrackFetchAt[trackId];
    if (cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _streamUrlMaxAge) {
      _log('_getSourcedTrack: cache hit for $trackId');
      return cached;
    }
    if (cached != null) {
      _log('_getSourcedTrack: cached URL stale for $trackId, re-resolving...');
    }

    _log('_getSourcedTrack: trackId=$trackId, playlist.tracks=${playlist.tracks.length}');

    // Fast path: resolve the stream URL directly from Supabase. This avoids
    // the metadata-plugin bytecode interpreter entirely, which keeps playback
    // fast and immune to plugin/bytecode incompatibilities.
    try {
      final direct = await _resolveStreamFromSupabase(trackId);
      if (direct != null) {
        _log('_getSourcedTrack: resolved directly from the music source');
        _cacheSourcedTrack(trackId, direct);
        return direct;
      }
    } catch (e) {
      _log('_getSourcedTrack: direct music source resolve failed: $e');
    }

    try {
      // firstWhere throws StateError if no match (Dart docs), use firstWhereOrNull
      final track = playlist.tracks.firstWhereOrNull(
        (element) => element.id == trackId,
      );
      if (track == null) {
        _log('_getSourcedTrack: track $trackId NOT in playlist state, resolving from the music source');
        final result = await _resolveFromSupabase(trackId);
        if (result != null) _cacheSourcedTrack(trackId, result);
        return result;
      }
      _log('_getSourcedTrack: found track ${track.name} in playlist state');

      // Use activeTrackSourcesProvider which already calls sourcedTrackProvider
      // internally — this avoids duplicate matches()+streams() calls
      final fullTrack = track as SangeetFullTrackObject;
      SourcedTrack? sourcedTrack;

      try {
        final activeSourcedTrack = await ref.read(activeTrackSourcesProvider.future);
        if (activeSourcedTrack?.track.id == track.id) {
          sourcedTrack = activeSourcedTrack?.source;
          _log('_getSourcedTrack: reused from active source');
        }
      } catch (_) {}

      if (sourcedTrack == null) {
        // Fallback: resolve directly from plugin
        final audioSource = await ref.read(audioSourcePluginProvider.future);
        if (audioSource != null) {
          final matches = await audioSource.audioSource.matches(fullTrack);
          if (matches.isNotEmpty) {
            final manifest = await audioSource.audioSource.streams(matches.first);
            sourcedTrack = SourcedTrack(
              ref: ref,
              siblings: matches.skip(1).toList(),
              info: matches.first,
              source: '',
              sources: manifest,
              query: fullTrack,
            );
          }
        }
      }
      _log('_getSourcedTrack: sourcedTrack url=${sourcedTrack?.url}');
      if (sourcedTrack != null) _cacheSourcedTrack(trackId, sourcedTrack);
      return sourcedTrack;
    } catch (e, stack) {
      _log('_getSourcedTrack ERROR: $e');
      _log('_getSourcedTrack STACK: $stack');
      AppLogger.reportError(e, stack);
      return null;
    }
  }

  /// Resolves a playable stream URL directly from Supabase for the given
  /// track, bypassing the metadata-plugin bytecode interpreter.
  ///
  /// This is the fastest and most reliable path: it reads the track's storage
  /// path, generates a signed URL from the `music` bucket, and builds a
  /// [SourcedTrack] whose stream points straight at that URL.
  Future<SourcedTrack?> _resolveStreamFromSupabase(
    String trackId, {
    bool karaoke = false,
  }) async {
    final supabase = ref.read(supabaseClientProvider);

    final row = await supabase
        .from('tracks')
        .select(
            'id,title,artist_names,duration,thumbnail,storage_path,karaoke_storage_path,status')
        .eq('id', trackId)
        .maybeSingle();

    if (row == null) {
      _log('_resolveStreamFromMusicSource: no row for $trackId');
      return null;
    }

    // Use the karaoke file when requested and one exists; otherwise fall back
    // to the original so we never break the default playback path.
    final karaokePath = row['karaoke_storage_path']?.toString();
    final originalPath = row['storage_path']?.toString();
    if (karaoke && (karaokePath == null || karaokePath.isEmpty)) {
      _log('_resolveStreamFromMusicSource: no karaoke file for $trackId');
      return null;
    }
    final storagePath = karaoke ? karaokePath! : originalPath;
    if (storagePath == null || storagePath.isEmpty) {
      _log('_resolveStreamFromMusicSource: no storage_path for $trackId');
      return null;
    }
    final ext = storagePath.split('.').last.toLowerCase();
    final fmt = ext == 'm4a' ? 'mp4' : ext == 'weba' ? 'webm' : ext;

    // Stream from the Cloudflare R2 public CDN (zero egress). Fall back to a
    // Supabase signed URL only when R2 is not configured.
    final r2 = r2StreamUrl(storagePath);
    final signedUrl = r2 ??
        await supabase.storage
            .from('music')
            .createSignedUrl(storagePath, 3600);

    final rawArtists = row['artist_names'] as List<dynamic>?;
    final artists = rawArtists
            ?.map((name) => SangeetSimpleArtistObject(
                  id: name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
                  name: name.toString(),
                  externalUri: '',
                ))
            .toList() ??
        [];

    final fullTrack = SangeetFullTrackObject(
      id: row['id'].toString(),
      name: row['title']?.toString() ?? 'Unknown',
      externalUri: '',
      artists: artists,
      album: SangeetSimpleAlbumObject(
        id: 'album-${row['id']}',
        name: row['title']?.toString() ?? 'Unknown',
        externalUri: '',
        artists: artists,
        albumType: SangeetAlbumType.single,
        images: row['thumbnail'] != null
            ? [
                SangeetImageObject(
                  url: row['thumbnail'].toString(),
                  width: 300,
                  height: 300,
                ),
              ]
            : [],
      ),
      durationMs: ((row['duration'] ?? 0) * 1000).toInt(),
      isrc: '',
      explicit: false,
      status: (row['status'] ?? 'free').toString(),
    );

    final match = SangeetAudioSourceMatchObject(
      id: row['id'].toString(),
      title: fullTrack.name,
      artists: artists.map((a) => a.name).toList(),
      duration: Duration(milliseconds: fullTrack.durationMs),
      thumbnail: row['thumbnail']?.toString(),
      externalUri: '',
    );

    final stream = SangeetAudioSourceStreamObject(
      url: signedUrl,
      container: fmt,
      type: SangeetMediaCompressionType.lossy,
      codec: fmt == 'opus' ? 'opus' : fmt == 'mp3' ? 'mp3' : fmt,
      bitrate: fmt == 'opus' ? 96000 : 128000,
    );

    return SourcedTrack(
      ref: ref,
      query: fullTrack,
      info: match,
      source: 'supabase',
      sources: [stream],
      siblings: [],
    );
  }

  /// Resolves a stream source for a track that is not in the current player
  /// playlist by fetching the track from Supabase directly. This makes the
  /// stream proxy work regardless of the audio player's playlist state.
  Future<SourcedTrack?> _resolveFromSupabase(String trackId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = await supabase
          .from('tracks')
          .select()
          .eq('id', trackId)
          .single();
      final rawArtists = data['artist_names'] as List<dynamic>?;
      final artists = rawArtists
              ?.map((name) => SangeetSimpleArtistObject(
                    id: name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
                    name: name.toString(),
                    externalUri: '',
                  ))
              .toList() ??
          [];

      final fullTrack = SangeetFullTrackObject(
        id: data['id'].toString(),
        name: data['title']?.toString() ?? 'Unknown',
        externalUri: '',
        artists: artists,
        album: SangeetSimpleAlbumObject(
          id: 'album-${data['id']}',
          name: data['title']?.toString() ?? 'Unknown',
          externalUri: '',
          artists: artists,
          albumType: SangeetAlbumType.single,
          images: data['thumbnail'] != null
              ? [
                  SangeetImageObject(
                    url: data['thumbnail'].toString(),
                    width: 300,
                    height: 300,
                  ),
                ]
              : [],
        ),
        durationMs: ((data['duration'] ?? 0) * 1000).toInt(),
        isrc: '',
        explicit: false,
        status: (data['status'] ?? 'free').toString(),
      );

      final sourcedTrack = await SourcedTrack.fetchFromTrack(
        query: fullTrack,
        ref: ref,
      );
      _log('_resolveFromMusicSource: url=${sourcedTrack.url}');
      return sourcedTrack;
    } catch (e) {
      _log('_resolveFromMusicSource ERROR: $e');
      return null;
    }
  }

  Future<dio_lib.Response> streamTrackInformation(
    Request request,
    SourcedTrack track,
  ) async {
    AppLogger.log.i(
      "HEAD request for track: ${track.query.name}\n"
      "Headers: ${request.headers}",
    );

    String url = track.url ?? '';
    if (url.isEmpty) {
      final direct = await _resolveStreamFromSupabase(track.query.id);
      if (direct != null && direct.url != null) {
        url = direct.url!;
        _cacheSourcedTrack(track.query.id, direct);
      }
    }
    if (url.isEmpty) {
      try {
        final swapped = await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling();
        if (swapped.url != null && swapped.url!.isNotEmpty) {
          url = swapped.url!;
        }
      } catch (e, stack) {
        _log('streamTrackInformation: sibling resolution failed: $e');
        AppLogger.reportError(e, stack);
      }
    }
    if (url.isEmpty) {
      throw StateError('No playable URL for track ${track.query.id}');
    }

    final options = Options(
      headers: {
        "user-agent": _randomUserAgent,
        "Cache-Control": "max-age=3600",
        "Connection": "keep-alive",
        "host": Uri.parse(url).host,
      },
      validateStatus: (status) => status != null && status < 500,
    );

    final res = await dio.head(url, options: options);

    return res;
  }

  Future<dio_lib.Response> streamTrack(
    Request request,
    SourcedTrack track,
    Map<String, dynamic> headers,
  ) async {
    AppLogger.log.i(
      "GET request for track: ${track.query.name}\n"
      "Headers: ${request.headers}",
    );

    // Resolve the playable URL. The track's own `url` getter can be null when
    // the audio-source plugin produced no sources for the user's quality
    // preset; in that case fall back to the direct Supabase signed URL, which
    // always works against the music bucket. Never crash on a null URL — that
    // would make the song skip/fail to play.
    String url = track.url ?? '';
    if (url.isEmpty) {
      final direct = await _resolveStreamFromSupabase(track.query.id);
      if (direct != null && direct.url != null) {
        url = direct.url!;
        _cacheSourcedTrack(track.query.id, direct);
      }
    }
    if (url.isEmpty) {
      try {
        final swapped = await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling();
        if (swapped.url != null && swapped.url!.isNotEmpty) {
          url = swapped.url!;
        }
      } catch (e, stack) {
        _log('streamTrack: sibling resolution failed: $e');
        AppLogger.reportError(e, stack);
      }
    }
    if (url.isEmpty) {
      throw StateError('No playable URL for track ${track.query.id}');
    }

    // Forward only safe headers — omit Accept-Encoding that could cause
    // truncated responses or decoding issues on the device. The Range header
    // IS forwarded so the audio player can seek/scrub efficiently (byte-range
    // requests from Supabase signed URLs return 206 with content-range).
    final safeHeaders = <String, dynamic>{
      "user-agent": _randomUserAgent,
      "Cache-Control": "max-age=3600",
      "Connection": "keep-alive",
      "host": Uri.parse(url).host,
    };
    for (final key in ['range', 'if-range', 'if-modified-since', 'if-none-match']) {
      if (headers[key] != null) safeHeaders[key] = headers[key];
    }

    final options = Options(
      headers: safeHeaders,
      responseType: ResponseType.stream,
      validateStatus: (status) => status != null && status < 500,
    );

    final contentLengthRes = await Future<dio_lib.Response?>.value(
      dio.head(
        url,
        options: options.copyWith(responseType: ResponseType.bytes),
      ),
    ).catchError((e, stack) async {
      AppLogger.reportError(e, stack);

      final sourcedTrack = await ref
          .read(sourcedTrackProvider(track.query).notifier)
          .refreshStreamingUrl();

      if (sourcedTrack.url != null && sourcedTrack.url!.isNotEmpty) {
        url = sourcedTrack.url!;
      } else {
        final direct = await _resolveStreamFromSupabase(track.query.id);
        if (direct != null && direct.url != null) {
          url = direct.url!;
          _cacheSourcedTrack(track.query.id, direct);
        }
      }

      return dio.head(url, options: options);
    });

    // Redirect to m3u8 link directly as it handles range requests internally
    if (contentLengthRes?.headers.value("content-type") ==
        "application/vnd.apple.mpegurl") {
      return dio_lib.Response<Uint8List>(
        statusCode: 301,
        statusMessage: "M3U8 Redirect",
        headers: Headers.fromMap({
          "location": [url],
          "content-type": ["application/vnd.apple.mpegurl"],
        }),
        requestOptions: RequestOptions(path: request.requestedUri.toString()),
        isRedirect: true,
      );
    }

    final res = await dio.get<ResponseBody>(url, options: options);

    AppLogger.log.i(
      "Response for track: ${track.query.name}\n"
      "Status Code: ${res.statusCode}\n"
      "Headers: ${res.headers.map}",
    );

    return res;
  }

  /// Returns the [SourcedTrack] to stream for a request, honouring the
  /// `?variant=karaoke` query param (resolves the karaoke file when present;
  /// falls back to the original otherwise so nothing breaks).
  Future<SourcedTrack?> _sourcedTrackForVariant(
    Request request,
    String trackId,
    SourcedTrack? fallback,
  ) async {
    if (request.url.queryParameters['variant'] == 'karaoke') {
      final karaoke = await _resolveStreamFromSupabase(trackId, karaoke: true);
      if (karaoke != null) return karaoke;
    }
    return fallback;
  }

  /// @head('/stream/<trackId>')
  Future<Response> headStreamTrackId(Request request, String trackId) async {
    try {
      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final stream = await _sourcedTrackForVariant(request, trackId, sourcedTrack);
      if (stream == null) {
        return Response.notFound("Karaoke track not found");
      }

      // Paid tracks are locked for free users — refuse to stream even if a
      // client bypasses the UI and hits the local stream endpoint directly.
      final status = stream.query.status;
      if (status == 'paid' && !PremiumAccess.isPremiumUser(ref)) {
        return Response.forbidden("This track requires a premium subscription");
      }

      final res = await streamTrackInformation(
        request,
        stream,
      );

      return Response(
        res.statusCode!,
        headers: res.headers.map,
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Response.internalServerError();
    }
  }

  /// @get('/stream/<trackId>')
  Future<Response> getStreamTrackId(Request request, String trackId) async {
    try {
      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final stream = await _sourcedTrackForVariant(request, trackId, sourcedTrack);
      if (stream == null) {
        return Response.notFound("Karaoke track not found");
      }

      // Paid tracks are locked for free users — refuse to stream even if a
      // client bypasses the UI and hits the local stream endpoint directly.
      final status = stream.query.status;
      if (status == 'paid' && !PremiumAccess.isPremiumUser(ref)) {
        return Response.forbidden("This track requires a premium subscription");
      }

      final res = await streamTrack(
        request,
        stream,
        request.headers,
      );

      // Build clean streaming headers. We intentionally do NOT forward the
      // upstream content-length or connection headers for full (200) bodies:
      // shelf streams with chunked transfer encoding, and a stale
      // content-length (or upstream connection/set-cookie headers) makes mpv
      // stall after the first buffered chunk.
      //
      // For partial (206) responses we MUST pass through content-range and
      // content-length so the audio player can seek/scrub: the upstream signed
      // URL returns `content-range: bytes start-end/total`, and without it the
      // player cannot map a byte offset to a time position.
      final contentType = res.headers.value('content-type') ?? 'audio/ogg';
      final streamHeaders = <String, String>{
        'content-type': contentType,
        'accept-ranges': 'bytes',
      };

      if (res.statusCode == 206) {
        final contentRange = res.headers.value('content-range');
        final contentLength = res.headers.value('content-length');
        if (contentRange != null) streamHeaders['content-range'] = contentRange;
        if (contentLength != null) streamHeaders['content-length'] = contentLength;
      }

      if (res.data is ResponseBody) {
        return Response(
          res.statusCode!,
          body: (res.data as ResponseBody).stream,
          headers: streamHeaders,
        );
      }

      return Response(
        res.statusCode!,
        body: res.data,
        headers: streamHeaders,
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Response.internalServerError();
    }
  }

  /// @get('/playback/toggle-playback')
  Future<Response> togglePlayback(Request request) async {
    audioPlayer.isPlaying
        ? await audioPlayer.pause()
        : await audioPlayer.resume();

    return Response.ok("Playback toggled");
  }

  /// @get('/playback/previous')
  Future<Response> previousTrack(Request request) async {
    await audioPlayer.skipToPrevious();
    return Response.ok("Previous track");
  }

  /// @get('/playback/next')
  Future<Response> nextTrack(Request request) async {
    await audioPlayer.skipToNext();
    return Response.ok("Next track");
  }
}

final serverPlaybackRoutesProvider =
    Provider((ref) => ServerPlaybackRoutes(ref));
