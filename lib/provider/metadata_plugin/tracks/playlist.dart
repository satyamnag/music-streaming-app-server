import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';

class MetadataPluginPlaylistTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SangeetFullTrackObject,
        String> {
  MetadataPluginPlaylistTracksNotifier() : super();

  @override
  fetch(offset, limit) async {
    final tracks = await (await metadataPlugin).playlist.tracks(
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

final metadataPluginPlaylistTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginPlaylistTracksNotifier,
        SangeetPaginationResponseObject<SangeetFullTrackObject>, String>(
  () => MetadataPluginPlaylistTracksNotifier(),
);
