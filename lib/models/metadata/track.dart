part of 'metadata.dart';

@freezed
class SangeetTrackObject with _$SangeetTrackObject {
  factory SangeetTrackObject.local({
    required String id,
    required String name,
    required String externalUri,
    @Default([]) List<SangeetSimpleArtistObject> artists,
    required SangeetSimpleAlbumObject album,
    required int durationMs,
    required String path,
  }) = SangeetLocalTrackObject;

  factory SangeetTrackObject.full({
    required String id,
    required String name,
    required String externalUri,
    @Default([]) List<SangeetSimpleArtistObject> artists,
    required SangeetSimpleAlbumObject album,
    required int durationMs,
    required String isrc,
    required bool explicit,
    @Default('free') String status,
  }) = SangeetFullTrackObject;

  factory SangeetTrackObject.localTrackFromFile(
    File file, {
    Metadata? metadata,
    String? art,
  }) {
    return SangeetLocalTrackObject(
      id: file.absolute.path,
      name: metadata?.title ?? basenameWithoutExtension(file.path),
      externalUri: "file://${file.absolute.path}",
      artists: metadata?.artist?.split(",").map((a) {
            return SangeetSimpleArtistObject(
              id: a.trim(),
              name: a.trim(),
              externalUri: "file://${file.absolute.path}",
            );
          }).toList() ??
          [
            SangeetSimpleArtistObject(
              id: "unknown",
              name: "Unknown Artist",
              externalUri: "file://${file.absolute.path}",
            ),
          ],
      album: SangeetSimpleAlbumObject(
        albumType: SangeetAlbumType.album,
        id: metadata?.album ?? "unknown",
        name: metadata?.album ?? "Unknown Album",
        externalUri: "file://${file.absolute.path}",
        artists: [
          SangeetSimpleArtistObject(
            id: metadata?.albumArtist ?? "unknown",
            name: metadata?.albumArtist ?? "Unknown Artist",
            externalUri: "file://${file.absolute.path}",
          ),
        ],
        releaseDate:
            metadata?.year != null ? "${metadata!.year}-01-01" : "1970-01-01",
        images: [
          if (art != null)
            SangeetImageObject(
              url: art,
              width: 300,
              height: 300,
            ),
        ],
      ),
      durationMs: metadata?.durationMs?.toInt() ?? 0,
      path: file.path,
    );
  }

  factory SangeetTrackObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetTrackObjectFromJson(
        json.containsKey("path")
            ? {...json, "runtimeType": "local"}
            : {...json, "runtimeType": "full"},
      );
}

extension AsMediaListSangeetTrackObject on Iterable<SangeetTrackObject> {
  List<SangeetMedia> asMediaList() {
    return map((track) => SangeetMedia(track)).toList();
  }
}

extension ToMetadataSangeetFullTrackObject on SangeetFullTrackObject {
  Metadata toMetadata({
    required int fileLength,
    Uint8List? imageBytes,
    String? mimeType,
  }) {
    return Metadata(
      title: name,
      artist: artists.map((a) => a.name).join(", "),
      album: album.name,
      albumArtist: artists.map((a) => a.name).join(", "),
      year: album.releaseDate == null
          ? 1970
          : DateTime.tryParse(album.releaseDate!)?.year ??
              int.tryParse(album.releaseDate!) ??
              1970,
      durationMs: durationMs.toDouble(),
      fileSize: BigInt.from(fileLength),
      picture: imageBytes != null
          ? Picture(
              data: imageBytes,
              mimeType: mimeType ??
                  lookupMimeType("", headerBytes: imageBytes) ??
                  "image/jpeg",
            )
          : null,
    );
  }
}
