import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';

class MetadataPluginAlbumTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SangeetFullTrackObject,
        String> {
  MetadataPluginAlbumTracksNotifier() : super();

  @override
  fetch(offset, limit) async {
    // Resolve the album's tracks from the on-device Supabase local server
    // first. This covers the admin-created albums and the auto-grouped albums
    // shown on the home screen (their ids are Supabase album uuids or album
    // slugs). When the local server has no such album, fall back to the
    // metadata plugin so albums saved from a real metadata source keep working
    // exactly as before.
    try {
      await SangeetMedia.ensurePortReady();
      final response = await globalDio.get(
        'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/albums/$arg/tracks',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {'accept': 'application/json'},
        ),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>? ?? const []);
        if (items.isNotEmpty) {
          return SangeetPaginationResponseObject<SangeetFullTrackObject>
              .fromJson(
            data,
            (json) =>
                SangeetFullTrackObject.fromJson(json.cast<String, dynamic>()),
          );
        }
      }
    } catch (_) {
      // Local server unavailable — fall through to the metadata plugin.
    }

    final tracks = await (await metadataPlugin).album.tracks(
          arg,
          offset: offset,
          limit: limit,
        );

    return tracks;
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginAlbumTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginAlbumTracksNotifier,
        SangeetPaginationResponseObject<SangeetFullTrackObject>, String>(
  () => MetadataPluginAlbumTracksNotifier(),
);
