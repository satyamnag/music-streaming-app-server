import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:sangeet/provider/metadata_plugin/utils/family_paginated.dart';

class MetadataPluginSearchPlaylistsNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SangeetSimplePlaylistObject,
        String> {
  MetadataPluginSearchPlaylistsNotifier() : super();

  @override
  fetch(offset, limit) async {
    if (arg.isEmpty) {
      // Empty search: show the developer-curated default playlists (the whole
      // catalog, artist playlists and month playlists) so the playlists tab is
      // never empty.
      final ownerPlaylists =
          await ref.read(ownerPlaylistsProvider.future);
      return SangeetPaginationResponseObject<SangeetSimplePlaylistObject>(
        limit: limit,
        nextOffset: null,
        total: ownerPlaylists.length,
        items: ownerPlaylists,
        hasMore: false,
      );
    }

    final res = await (await metadataPlugin).search.playlists(
          arg,
          offset: offset,
          limit: limit,
        );

    return res;
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginSearchPlaylistsProvider =
    AutoDisposeAsyncNotifierProviderFamily<
        MetadataPluginSearchPlaylistsNotifier,
        SangeetPaginationResponseObject<SangeetSimplePlaylistObject>,
        String>(
  () => MetadataPluginSearchPlaylistsNotifier(),
);
