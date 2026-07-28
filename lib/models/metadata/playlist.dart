part of 'metadata.dart';

@freezed
class SangeetFullPlaylistObject with _$SangeetFullPlaylistObject {
  factory SangeetFullPlaylistObject({
    required String id,
    required String name,
    required String description,
    required String externalUri,
    required SangeetUserObject owner,
    @Default([]) List<SangeetImageObject> images,
    @Default([]) List<SangeetUserObject> collaborators,
    @Default(false) bool collaborative,
    @Default(false) bool public,
  }) = _SangeetFullPlaylistObject;

  factory SangeetFullPlaylistObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetFullPlaylistObjectFromJson(json);
}

@freezed
class SangeetSimplePlaylistObject with _$SangeetSimplePlaylistObject {
  factory SangeetSimplePlaylistObject({
    required String id,
    required String name,
    required String description,
    required String externalUri,
    required SangeetUserObject owner,
    @Default([]) List<SangeetImageObject> images,
  }) = _SangeetSimplePlaylistObject;

  factory SangeetSimplePlaylistObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetSimplePlaylistObjectFromJson(json);
}
