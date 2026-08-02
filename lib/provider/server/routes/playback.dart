import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio_lib;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/audio_player/state.dart';

import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/server/active_track_sources.dart';
import 'package:sangeet/provider/server/routes/supabase_data.dart';
import 'package:sangeet/provider/server/sourced_track_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_encryption/audio_encryption.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:sangeet/services/sourced_track/sourced_track.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void _log(String msg) {
  print('[SANGEET] $msg');
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

/// Detects the codec container of decrypted audio bytes.
String _sniffContentType(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x4F && // 'O'
      bytes[1] == 0x67 && // 'g'
      bytes[2] == 0x67 && // 'g'
      bytes[3] == 0x53) {
    return 'audio/ogg';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0x49 && // 'I'
      bytes[1] == 0x44 && // 'D'
      bytes[2] == 0x33) {
    return 'audio/mpeg';
  }
  if (bytes.isNotEmpty && bytes[0] == 0xFF) {
    return 'audio/mpeg';
  }
  return 'audio/ogg';
}

class ServerPlaybackRoutes {
  final Ref ref;
  AudioPlayerState get playlist => ref.read(audioPlayerProvider);
  final Dio dio;

  ServerPlaybackRoutes(this.ref) : dio = Dio();

  Future<SourcedTrack?> _getSourcedTrack(
    Request request,
    String trackId,
  ) async {
    _log('_getSourcedTrack: trackId=$trackId, playlist.tracks=${playlist.tracks.length}');

    try {
      // firstWhere throws StateError if no match (Dart docs), use firstWhereOrNull
      final track = playlist.tracks.firstWhereOrNull(
        (element) => element.id == trackId,
      );
      if (track == null) {
        _log('_getSourcedTrack: track $trackId NOT in playlist state, resolving from Supabase');
        return _resolveFromSupabase(trackId);
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
      return sourcedTrack;
    } catch (e, stack) {
      _log('_getSourcedTrack ERROR: $e');
      _log('_getSourcedTrack STACK: $stack');
      AppLogger.reportError(e, stack);
      return null;
    }
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
      );

      final sourcedTrack = await SourcedTrack.fetchFromTrack(
        query: fullTrack,
        ref: ref,
      );
      _log('_resolveFromSupabase: url=${sourcedTrack.url}');
      return sourcedTrack;
    } catch (e) {
      _log('_resolveFromSupabase ERROR: $e');
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

    String url = track.url ??
        await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling()
            .then((track) => track.url!);

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

    String url = track.url ??
        await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling()
            .then((track) => track.url!);

    // Forward only safe headers — omit Range/Accept-Encoding that could
    // cause truncated responses or decoding issues on the device
    final safeHeaders = <String, dynamic>{
      "user-agent": _randomUserAgent,
      "Cache-Control": "max-age=3600",
      "Connection": "keep-alive",
      "host": Uri.parse(url).host,
    };
    for (final key in ['if-range', 'if-modified-since', 'if-none-match']) {
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

      url = sourcedTrack.url!;

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

  /// @head('/stream/<trackId>')
  Future<Response> headStreamTrackId(Request request, String trackId) async {
    try {
      if (await AudioEncryptionService.hasEncryptedFile(trackId)) {
        return Response(
          200,
          headers: {
            'content-type': 'audio/ogg',
            'accept-ranges': 'bytes',
          },
        );
      }

      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final res = await streamTrackInformation(
        request,
        sourcedTrack,
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
      if (await AudioEncryptionService.hasEncryptedFile(trackId)) {
        final bytes = await AudioEncryptionService.decryptFile(trackId);
        return Response(
          200,
          body: bytes,
          headers: {
            'content-type': _sniffContentType(bytes),
            'accept-ranges': 'bytes',
          },
        );
      }

      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final res = await streamTrack(
        request,
        sourcedTrack,
        request.headers,
      );

      // Build clean streaming headers. We intentionally do NOT forward the
      // upstream content-length or connection headers: shelf streams the body
      // with chunked transfer encoding, and forwarding a stale content-length
      // (or upstream connection/set-cookie headers) makes mpv stall after the
      // first buffered chunk.
      final contentType = res.headers.value('content-type') ?? 'audio/ogg';
      final streamHeaders = <String, String>{
        'content-type': contentType,
        'accept-ranges': 'bytes',
      };

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
