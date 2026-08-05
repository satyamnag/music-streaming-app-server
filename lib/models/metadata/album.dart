part of 'metadata.dart';

enum SangeetAlbumType {
  album,
  single,
  compilation,
}

extension FormattedAlbumType on SangeetAlbumType {
  String get formatted => name.replaceFirst(name[0], name[0].toUpperCase());
}

@freezed
class SangeetFullAlbumObject with _$SangeetFullAlbumObject {
  factory SangeetFullAlbumObject({
    required String id,
    required String name,
    required List<SangeetSimpleArtistObject> artists,
    @Default([]) List<SangeetImageObject> images,
    required String releaseDate,
    required String externalUri,
    required int totalTracks,
    required SangeetAlbumType albumType,
    String? recordLabel,
    List<String>? genres,
  }) = _SangeetFullAlbumObject;

  factory SangeetFullAlbumObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetFullAlbumObjectFromJson(json);
}

@freezed
class SangeetSimpleAlbumObject with _$SangeetSimpleAlbumObject {
  factory SangeetSimpleAlbumObject({
    required String id,
    required String name,
    required String externalUri,
    required List<SangeetSimpleArtistObject> artists,
    @Default([]) List<SangeetImageObject> images,
    required SangeetAlbumType albumType,
    String? releaseDate,
  }) = _SangeetSimpleAlbumObject;

  factory SangeetSimpleAlbumObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetSimpleAlbumObjectFromJson(json);
}
