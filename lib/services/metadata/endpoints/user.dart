import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/metadata/endpoints/hetu_converter.dart';

class MetadataPluginUserEndpoint {
  final Hetu hetu;
  MetadataPluginUserEndpoint(this.hetu);

  HTInstance get hetuMetadataUser =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("user")
          as HTInstance;

  Future<SangeetUserObject> me() async {
    final raw = await hetuMetadataUser.invoke("me");

    return SangeetUserObject.fromJson(
      hetuToMap(raw),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetFullTrackObject>> savedTracks({
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataUser.invoke(
      "savedTracks",
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<SangeetFullTrackObject>.fromJson(
      hetuToMap(raw),
      (Map json) =>
          SangeetFullTrackObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetSimplePlaylistObject>>
      savedPlaylists({
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataUser.invoke(
      "savedPlaylists",
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<
        SangeetSimplePlaylistObject>.fromJson(
      hetuToMap(raw),
      (Map json) =>
          SangeetSimplePlaylistObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetSimpleAlbumObject>>
      savedAlbums({
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataUser.invoke(
      "savedAlbums",
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<SangeetSimpleAlbumObject>.fromJson(
      hetuToMap(raw),
      (Map json) =>
          SangeetSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetFullArtistObject>>
      savedArtists({
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataUser.invoke(
      "savedArtists",
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    );

    return SangeetPaginationResponseObject<SangeetFullArtistObject>.fromJson(
      hetuToMap(raw),
      (Map json) =>
          SangeetFullArtistObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<bool> isSavedPlaylist(String playlistId) async {
    return await hetuMetadataUser.invoke(
      "isSavedPlaylist",
      positionalArgs: [playlistId],
    ) as bool;
  }

  Future<List<bool>> isSavedTracks(List<String> ids) async {
    final values = await hetuMetadataUser.invoke(
      "isSavedTracks",
      positionalArgs: [ids],
    );
    return (values as List).cast<bool>();
  }

  Future<List<bool>> isSavedAlbums(List<String> ids) async {
    final values = await hetuMetadataUser.invoke(
      "isSavedAlbums",
      positionalArgs: [ids],
    ) as List;
    return values.cast<bool>();
  }

  Future<List<bool>> isSavedArtists(List<String> ids) async {
    final values = await hetuMetadataUser.invoke(
      "isSavedArtists",
      positionalArgs: [ids],
    ) as List;

    return values.cast<bool>();
  }
}
