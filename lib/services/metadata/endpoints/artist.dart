import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sangeet/models/metadata/metadata.dart';

class MetadataPluginArtistEndpoint {
  final Hetu hetu;
  MetadataPluginArtistEndpoint(this.hetu);

  HTInstance get hetuMetadataArtist =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("artist")
          as HTInstance;

  Future<SangeetFullArtistObject> getArtist(String id) async {
    final raw = await hetuMetadataArtist
        .invoke("getArtist", positionalArgs: [id]) as Map;

    return SangeetFullArtistObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetFullTrackObject>> topTracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataArtist.invoke(
      "topTracks",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SangeetPaginationResponseObject<SangeetFullTrackObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) => SangeetFullTrackObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetSimpleAlbumObject>> albums(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataArtist.invoke(
      "albums",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SangeetPaginationResponseObject<SangeetSimpleAlbumObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) => SangeetSimpleAlbumObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<void> save(List<String> ids) async {
    await hetuMetadataArtist.invoke(
      "save",
      positionalArgs: [ids],
    );
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataArtist.invoke(
      "unsave",
      positionalArgs: [ids],
    );
  }

  Future<SangeetPaginationResponseObject<SangeetFullArtistObject>> related(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataArtist.invoke(
      "related",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit ?? 20,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SangeetPaginationResponseObject<SangeetFullArtistObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) => SangeetFullArtistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }
}
