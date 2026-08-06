import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:sangeet/provider/metadata_plugin/utils/family_paginated.dart';

class MetadataPluginSearchArtistsNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SangeetFullArtistObject,
        String> {
  MetadataPluginSearchArtistsNotifier() : super();

  @override
  fetch(offset, limit) async {
    if (arg.isEmpty) {
      // Empty search: show every artist in the catalog so the Artists tab is
      // never empty (tapping an artist opens their full profile + songs).
      final artists = await ref.read(libraryArtistsProvider.future);
      return SangeetPaginationResponseObject<SangeetFullArtistObject>(
        limit: limit,
        nextOffset: null,
        total: artists.length,
        items: artists,
        hasMore: false,
      );
    }

    final res = await (await metadataPlugin).search.artists(
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

final metadataPluginSearchArtistsProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginSearchArtistsNotifier,
        SangeetPaginationResponseObject<SangeetFullArtistObject>, String>(
  () => MetadataPluginSearchArtistsNotifier(),
);
