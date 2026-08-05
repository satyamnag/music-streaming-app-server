import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/metadata/endpoints/hetu_converter.dart';

class MetadataPluginSearchEndpoint {
  final Hetu hetu;
  MetadataPluginSearchEndpoint(this.hetu);

  HTInstance get hetuMetadataSearch =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("search")
          as HTInstance;

  List<String> get chips {
    return (hetuMetadataSearch.memberGet("chips") as List).cast<String>();
  }

  Future<SangeetSearchResponseObject> all(String query) async {
    // An empty query returns the full catalog (all songs) — the server lists
    // every track when no search term is given.
    final raw = await hetuMetadataSearch.invoke(
      "all",
      positionalArgs: [query],
    );

    return SangeetSearchResponseObject.fromJson(hetuToMap(raw));
  }

  Future<SangeetPaginationResponseObject<SangeetSimpleAlbumObject>> albums(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SangeetPaginationResponseObject<SangeetSimpleAlbumObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "albums",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<SangeetSimpleAlbumObject>.fromJson(
      hetuToMap(raw),
      (json) => SangeetSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetFullArtistObject>> artists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SangeetPaginationResponseObject<SangeetFullArtistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "artists",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<SangeetFullArtistObject>.fromJson(
      hetuToMap(raw),
      (json) => SangeetFullArtistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetSimplePlaylistObject>>
      playlists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SangeetPaginationResponseObject<SangeetSimplePlaylistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "playlists",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<
        SangeetSimplePlaylistObject>.fromJson(
      hetuToMap(raw),
      (json) => SangeetSimplePlaylistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetFullTrackObject>> tracks(
    String query, {
    int? limit,
    int? offset,
  }) async {
    // An empty query returns the full catalog (all songs) — the server lists
    // every track when no search term is given.
    final raw = await hetuMetadataSearch.invoke(
      "tracks",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<SangeetFullTrackObject>.fromJson(
      hetuToMap(raw),
      (json) => SangeetFullTrackObject.fromJson(json.cast<String, dynamic>()),
    );
  }
}
