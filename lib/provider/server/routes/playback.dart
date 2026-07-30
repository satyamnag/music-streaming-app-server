import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart';
import 'package:shelf/shelf.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/models/parser/range_headers.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/audio_player/state.dart';

import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/server/sourced_track_provider.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:sangeet/services/sourced_track/sourced_track.dart';
import 'package:sangeet/utils/service_utils.dart';
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

class ServerPlaybackRoutes {
  static const _maxCacheSize = 500 * 1024 * 1024; // 500 MB limit
  static const _xorKey = [0x4B, 0x68, 0x61, 0x6B, 0x74, 0x69, 0x53, 0x42];

  static Uint8List _xorTransform(Uint8List data) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ _xorKey[i % _xorKey.length];
    }
    return result;
  }

  final Ref ref;
  UserPreferences get userPreferences => ref.read(userPreferencesProvider);
  AudioPlayerState get playlist => ref.read(audioPlayerProvider);
  final Dio dio;

  ServerPlaybackRoutes(this.ref) : dio = Dio();

  Future<String> _getTrackCacheFilePath(SourcedTrack track) async {
    return join(
      await UserPreferencesNotifier.getMusicCacheDir(),
      ServiceUtils.sanitizeFilename(
        '${track.query.name} - ${track.query.artists.map((d) => d.name).join(",")} (${track.info.id}).${track.qualityPreset!.getFileExtension()}',
      ),
    );
  }

  Future<void> _evictCacheIfNeeded() async {
    if (!userPreferences.cacheMusic) return;
    final cacheDir = Directory(await UserPreferencesNotifier.getMusicCacheDir());
    if (!await cacheDir.exists()) return;

    final files = <FileSystemEntity>[];
    await for (final entity in cacheDir.list()) {
      files.add(entity);
    }

    // Calculate total size
    int totalSize = 0;
    for (final f in files) {
      if (f is File) totalSize += await f.length();
    }

    if (totalSize <= _maxCacheSize) return;

    // Sort by last modified (oldest first) and delete until under limit
    files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in files) {
      if (totalSize <= _maxCacheSize) break;
      if (f is File) {
        final len = await f.length();
        await f.delete();
        totalSize -= len;
      }
    }
  }

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
        _log('_getSourcedTrack: track $trackId NOT in playlist state');
        return null;
      }
      _log('_getSourcedTrack: found track ${track.name} in playlist state');

      // Resolve stream URL directly from the audio source plugin,
      // bypassing sourcedTrackProvider to avoid Riverpod rebuild races
      final fullTrack = track as SangeetFullTrackObject;
      final audioSource = await ref.read(audioSourcePluginProvider.future);
      SourcedTrack? sourcedTrack;
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
      _log('_getSourcedTrack: sourcedTrack url=${sourcedTrack?.url}');
      return sourcedTrack;
    } catch (e, stack) {
      _log('_getSourcedTrack ERROR: $e');
      _log('_getSourcedTrack STACK: $stack');
      AppLogger.reportError(e, stack);
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

    final trackCacheFile = File(await _getTrackCacheFilePath(track));

    if (await trackCacheFile.exists() && userPreferences.cacheMusic) {
      final fileLength = await trackCacheFile.length();

      return dio_lib.Response(
        statusCode: 200,
        headers: Headers.fromMap({
          "content-type": ["audio/${track.qualityPreset!.name}"],
          "content-length": ["$fileLength"],
          "accept-ranges": ["bytes"],
          "content-range": ["bytes 0-$fileLength/$fileLength"],
        }),
        requestOptions: RequestOptions(path: request.requestedUri.toString()),
      );
    }

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

    final trackCacheFile = File(await _getTrackCacheFilePath(track));

    if (await trackCacheFile.exists() && userPreferences.cacheMusic) {
      final encrypted = await trackCacheFile.readAsBytes();
      final bytes = _xorTransform(Uint8List.fromList(encrypted));
      final cachedFileLength = bytes.length;

      return dio_lib.Response<Uint8List>(
        statusCode: 200,
        headers: Headers.fromMap({
          "content-type": ["audio/${track.qualityPreset!.name}"],
          "content-length": ["${cachedFileLength - 1}"],
          "accept-ranges": ["bytes"],
          "content-range": [
            "bytes 0-${cachedFileLength - 1}/$cachedFileLength"
          ],
          "connection": ["close"],
        }),
        requestOptions: RequestOptions(path: request.requestedUri.toString()),
        data: bytes,
      );
    }

    String url = track.url ??
        await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling()
            .then((track) => track.url!);

    final options = Options(
      headers: {
        ...headers,
        "user-agent": _randomUserAgent,
        "Cache-Control": "max-age=3600",
        "Connection": "keep-alive",
        "host": Uri.parse(url).host,
      },
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

    if (!userPreferences.cacheMusic) {
      return res;
    }

    final resStream = res.data!.stream.asBroadcastStream();

    final trackPartialCacheFile = File("${trackCacheFile.path}.part");
    if (!await trackPartialCacheFile.exists()) {
      await trackPartialCacheFile.create(recursive: true);
    }

    // Write the stream to the file based on the range
    final partialCacheFileSink =
        trackPartialCacheFile.openWrite(mode: FileMode.writeOnlyAppend);
    final contentRange = res.headers.value("content-range") != null
        ? ContentRangeHeader.parse(res.headers.value("content-range") ?? "")
        : ContentRangeHeader(0, 0, 0);

    bool retried = false;
    resStream.listen(
      (data) {
        partialCacheFileSink.add(data);
      },
      onError: (e, stack) async {
        await partialCacheFileSink.close();
        // On stream error (e.g. expired signed URL), retry once with fresh URL
        if (!retried) {
          retried = true;
          AppLogger.log.i('Stream error, retrying with fresh URL: $e');
          try {
            final freshTrack = await ref
                .read(sourcedTrackProvider(track.query).notifier)
                .refreshStreamingUrl();
            if (freshTrack.url != null) {
              url = freshTrack.url!;
              options.headers?['host'] = Uri.parse(url).host;
              final retryRes = await dio.get<ResponseBody>(url, options: options);
              final retryStream = retryRes.data!.stream;
              retryStream.listen(
                (data) => partialCacheFileSink.add(data),
                onDone: () async {
                  await partialCacheFileSink.close();
                  final fileLength = await trackPartialCacheFile.length();
                  if (fileLength == contentRange.total) {
                    await trackPartialCacheFile.rename(trackCacheFile.path);
                    try {
                      final rawBytes = await trackCacheFile.readAsBytes();
                      await trackCacheFile.writeAsBytes(_xorTransform(Uint8List.fromList(rawBytes)));
                    } catch (_) {}
                  }
                },
                cancelOnError: true,
              );
              return;
            }
          } catch (_) {}
        }
      },
      onDone: () async {
        await partialCacheFileSink.close();

        final fileLength = await trackPartialCacheFile.length();
        if (fileLength != contentRange.total) return;

        await trackPartialCacheFile.rename(trackCacheFile.path);

        // Encrypt cached file to prevent playback outside the app
        try {
          final rawBytes = await trackCacheFile.readAsBytes();
          await trackCacheFile.writeAsBytes(_xorTransform(Uint8List.fromList(rawBytes)));
        } catch (_) {}

        if (track.qualityPreset!.getFileExtension() == "weba") return;

        final imageBytes = await ServiceUtils.downloadImage(
          track.query.album.images.asUrlString(
            placeholder: ImagePlaceholder.albumArt,
            index: 1,
          ),
        );

        await MetadataGod.writeMetadata(
          file: trackCacheFile.path,
          metadata: track.query.toMetadata(
            imageBytes: imageBytes,
            fileLength: fileLength,
          ),
        ).catchError((e, stackTrace) {
          AppLogger.reportError(e, stackTrace);
        });

        // Evict old cache files if total exceeds 500 MB limit
        await _evictCacheIfNeeded();
      },
      cancelOnError: true,
    );

    res.data?.stream =
        resStream; // To avoid Stream has been already listened to exception
    return res;
  }

  /// @head('/stream/<trackId>')
  Future<Response> headStreamTrackId(Request request, String trackId) async {
    try {
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
      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final res = await streamTrack(
        request,
        sourcedTrack,
        request.headers,
      );

      if (res.data is ResponseBody) {
        return Response(
          res.statusCode!,
          body: (res.data as ResponseBody).stream,
          headers: res.headers.map,
        );
      }

      return Response(
        res.statusCode!,
        body: res.data,
        headers: res.headers.map,
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
