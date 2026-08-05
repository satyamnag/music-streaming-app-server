import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/metadata/endpoints/hetu_converter.dart';

class MetadataPluginAlbumEndpoint {
  final Hetu hetu;
  MetadataPluginAlbumEndpoint(this.hetu);

  HTInstance get hetuMetadataAlbum =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("album")
          as HTInstance;

  Future<SangeetFullAlbumObject> getAlbum(String id) async {
    final raw = await hetuMetadataAlbum.invoke("getAlbum", positionalArgs: [id]);

    return SangeetFullAlbumObject.fromJson(
      hetuToMap(raw),
    );
  }

  Future<SangeetPaginationResponseObject<SangeetFullTrackObject>> tracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataAlbum.invoke(
      "tracks",
      positionalArgs: [id],
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

  Future<SangeetPaginationResponseObject<SangeetSimpleAlbumObject>> releases({
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataAlbum.invoke(
      "releases",
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

  Future<void> save(List<String> ids) async {
    await hetuMetadataAlbum.invoke(
      "save",
      positionalArgs: [ids],
    );
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataAlbum.invoke(
      "unsave",
      positionalArgs: [ids],
    );
  }
}
