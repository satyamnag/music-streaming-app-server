import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/metadata_plugin/core/auth.dart';
import 'package:sangeet/provider/metadata_plugin/utils/paginated.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cacheKey = 'cache_browse_sections';
const _cacheMaxAge = Duration(hours: 1);

class MetadataPluginBrowseSectionsNotifier
    extends PaginatedAsyncNotifier<SangeetBrowseSectionObject<Object>> {
  @override
  Future<SangeetPaginationResponseObject<SangeetBrowseSectionObject<Object>>>
      fetch(
    int offset,
    int limit,
  ) async {
    if (offset > 0) {
      return await (await metadataPlugin).browse.sections(
            limit: limit,
            offset: offset,
          );
    }

    final cached = await _loadCached();
    if (cached != null) return cached;

    final result = await (await metadataPlugin).browse.sections(
          limit: limit,
          offset: offset,
        );

    await _saveToCache(result);
    return result;
  }

  @override
  build() async {
    ref.watch(metadataPluginAuthenticatedProvider);

    final cached = await _loadCached();
    if (cached != null) {
      _refreshInBackground();
      return cached;
    }

    return await fetch(0, 20);
  }

  Future<void> _refreshInBackground() async {
    try {
      final result = await (await metadataPlugin).browse.sections(
            limit: 20,
            offset: 0,
          );
      await _saveToCache(result);
    } catch (_) {}
  }

  Future<SangeetPaginationResponseObject<SangeetBrowseSectionObject<Object>>?>
      _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return null;

    final entry = jsonDecode(cached) as Map<String, dynamic>;
    final age = DateTime.now().difference(DateTime.parse(entry['_cachedAt'] as String));
    if (age > _cacheMaxAge) return null;

    return SangeetPaginationResponseObject<
        SangeetBrowseSectionObject<Object>>.fromJson(
      entry,
      (json) =>
          SangeetBrowseSectionObject<Object>.fromJson(json as Map<String, dynamic>, (itemJson) {
        final item = itemJson as Map<String, dynamic>;
        if (item['owner'] != null) {
          return SangeetSimplePlaylistObject.fromJson(item.cast<String, dynamic>());
        }
        if (item['artists'] != null) {
          return SangeetSimpleAlbumObject.fromJson(item.cast<String, dynamic>());
        }
        return SangeetFullArtistObject.fromJson(item.cast<String, dynamic>());
      }),
    );
  }

  Future<void> _saveToCache(
    SangeetPaginationResponseObject<SangeetBrowseSectionObject<Object>> data,
  ) async {
    final json = data.toJson(
      (section) => section.toJson(
        (item) => (item as dynamic).toJson(),
      ),
    );
    json['_cachedAt'] = DateTime.now().toIso8601String();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(json));
  }
}

final metadataPluginBrowseSectionsProvider = AsyncNotifierProvider<
    MetadataPluginBrowseSectionsNotifier,
    SangeetPaginationResponseObject<SangeetBrowseSectionObject<Object>>>(
  () => MetadataPluginBrowseSectionsNotifier(),
);
