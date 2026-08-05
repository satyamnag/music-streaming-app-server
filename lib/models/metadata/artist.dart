part of 'metadata.dart';

@freezed
class SangeetFullArtistObject with _$SangeetFullArtistObject {
  factory SangeetFullArtistObject({
    required String id,
    required String name,
    required String externalUri,
    @Default([]) List<SangeetImageObject> images,
    List<String>? genres,
    int? followers,
    int? songCount,
  }) = _SangeetFullArtistObject;

  factory SangeetFullArtistObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetFullArtistObjectFromJson(json);
}

@freezed
class SangeetSimpleArtistObject with _$SangeetSimpleArtistObject {
  factory SangeetSimpleArtistObject({
    required String id,
    required String name,
    required String externalUri,
    List<SangeetImageObject>? images,
  }) = _SangeetSimpleArtistObject;

  factory SangeetSimpleArtistObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetSimpleArtistObjectFromJson(json);
}

extension SangeetFullArtistObjectAsString on List<SangeetFullArtistObject> {
  String asString() {
    return map((e) => e.name).join(", ");
  }
}

extension SangeetSimpleArtistObjectAsString on List<SangeetSimpleArtistObject> {
  String asString() {
    return map((e) => e.name).join(", ");
  }
}
