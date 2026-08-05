import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:sangeet/provider/metadata_plugin/utils/family_paginated.dart';

class MetadataPluginSearchTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SangeetFullTrackObject,
        String> {
  MetadataPluginSearchTracksNotifier() : super();

  @override
  fetch(offset, limit) async {
    // An empty query returns the full catalog (the server lists all songs),
    // so the search screen always shows every song until the user types.
    final tracks = await (await metadataPlugin).search.tracks(
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

final metadataPluginSearchTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginSearchTracksNotifier,
        SangeetPaginationResponseObject<SangeetFullTrackObject>, String>(
  () => MetadataPluginSearchTracksNotifier(),
);
