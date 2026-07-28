import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/metadata_plugin/utils/common.dart';
import 'package:sangeet/provider/metadata_plugin/utils/family_paginated.dart';

class MetadataPluginSearchAlbumsNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SangeetSimpleAlbumObject,
        String> {
  MetadataPluginSearchAlbumsNotifier() : super();

  @override
  fetch(offset, limit) async {
    if (arg.isEmpty) {
      return SangeetPaginationResponseObject<SangeetSimpleAlbumObject>(
        limit: limit,
        nextOffset: null,
        total: 0,
        items: [],
        hasMore: false,
      );
    }

    final res = await (await metadataPlugin).search.albums(
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

final metadataPluginSearchAlbumsProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginSearchAlbumsNotifier,
        SangeetPaginationResponseObject<SangeetSimpleAlbumObject>, String>(
  () => MetadataPluginSearchAlbumsNotifier(),
);
