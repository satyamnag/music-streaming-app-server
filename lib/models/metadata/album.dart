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
    @Default('free') String status,
    String? recordLabel,
    List<String>? genres,
    /// Admin-configurable card box background color (`#rrggbb`), or null to
    /// keep the app's default theme color.
    String? cardBgColor,
    /// Admin-configurable card text color (`#rrggbb`), or null for the default.
    String? cardTextColor,
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
    @Default('free') String status,
    String? releaseDate,
    /// Admin-configurable card box background color (`#rrggbb`), or null to
    /// keep the app's default theme color.
    String? cardBgColor,
    /// Admin-configurable card text color (`#rrggbb`), or null for the default.
    String? cardTextColor,
  }) = _SangeetSimpleAlbumObject;

  factory SangeetSimpleAlbumObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetSimpleAlbumObjectFromJson(json);
}
