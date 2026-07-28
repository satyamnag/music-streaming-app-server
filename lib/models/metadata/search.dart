part of 'metadata.dart';

@freezed
class SangeetSearchResponseObject with _$SangeetSearchResponseObject {
  factory SangeetSearchResponseObject({
    required List<SangeetSimpleAlbumObject> albums,
    required List<SangeetFullArtistObject> artists,
    required List<SangeetSimplePlaylistObject> playlists,
    required List<SangeetFullTrackObject> tracks,
  }) = _SangeetSearchResponseObject;

  factory SangeetSearchResponseObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetSearchResponseObjectFromJson(json);
}
