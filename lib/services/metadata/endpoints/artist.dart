import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/metadata/endpoints/hetu_converter.dart';

class MetadataPluginArtistEndpoint {
  final Hetu hetu;
  MetadataPluginArtistEndpoint(this.hetu);

  HTInstance get hetuMetadataArtist =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("artist")
          as HTInstance;

  Future<SangeetFullArtistObject> getArtist(String id) async {
    final raw = await hetuMetadataArtist.invoke(
      "getArtist",
      positionalArgs: [id],
    );

    return SangeetFullArtistObject.fromJson(
      hetuToMap(raw),
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
    );

    return SangeetPaginationResponseObject<SangeetFullTrackObject>.fromJson(
      hetuToMap(raw),
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
    );

    return SangeetPaginationResponseObject<SangeetSimpleAlbumObject>.fromJson(
      hetuToMap(raw),
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
    );

    return SangeetPaginationResponseObject<SangeetFullArtistObject>.fromJson(
      hetuToMap(raw),
      (Map json) => SangeetFullArtistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }
}
