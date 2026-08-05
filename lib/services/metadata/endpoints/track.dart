import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/metadata/endpoints/hetu_converter.dart';

class MetadataPluginTrackEndpoint {
  final Hetu hetu;
  MetadataPluginTrackEndpoint(this.hetu);

  HTInstance get hetuMetadataTrack =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("track")
          as HTInstance;

  Future<SangeetFullTrackObject> getTrack(String id) async {
    final raw = await hetuMetadataTrack.invoke(
      "getTrack",
      positionalArgs: [id],
    );

    return SangeetFullTrackObject.fromJson(
      hetuToMap(raw),
    );
  }

  Future<void> save(List<String> ids) async {
    await hetuMetadataTrack.invoke("save", positionalArgs: [ids]);
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataTrack.invoke("unsave", positionalArgs: [ids]);
  }

  Future<List<SangeetFullTrackObject>> radio(String id) async {
    final result = await hetuMetadataTrack.invoke(
      "radio",
      positionalArgs: [id],
    );

    return hetuToList(result)
        .map(
          (e) => SangeetFullTrackObject.fromJson(
            hetuToMap(e),
          ),
        )
        .toList();
  }
}
