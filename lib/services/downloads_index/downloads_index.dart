import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/logger/logger.dart';

/// Metadata of a downloaded (encrypted) track, persisted in app-private
/// storage so the app can list and play its offline library without network.
class DownloadedTrack {
  final String trackId;
  final String name;
  final List<String> artists;
  final String albumName;
  final String albumImageUrl;
  final int durationMs;
  final DateTime downloadedAt;

  const DownloadedTrack({
    required this.trackId,
    required this.name,
    required this.artists,
    required this.albumName,
    required this.albumImageUrl,
    required this.durationMs,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'name': name,
        'artists': artists,
        'albumName': albumName,
        'albumImageUrl': albumImageUrl,
        'durationMs': durationMs,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) {
    return DownloadedTrack(
      trackId: json['trackId'] as String,
      name: json['name'] as String? ?? '',
      artists: (json['artists'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      albumName: json['albumName'] as String? ?? '',
      albumImageUrl: json['albumImageUrl'] as String? ?? '',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      downloadedAt: DateTime.tryParse(
            json['downloadedAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  /// Rebuilds a playable [SangeetFullTrackObject]. media_kit plays full
  /// tracks through the local server (`/stream/<trackId>`), which decrypts
  /// the local `.sbm` file — no network is required.
  SangeetFullTrackObject toTrackObject() {
    final artists = this
        .artists
        .map(
          (name) => SangeetSimpleArtistObject(
            id: name.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
            name: name,
            externalUri: '',
          ),
        )
        .toList();
    return SangeetFullTrackObject(
      id: trackId,
      name: name,
      externalUri: '',
      artists: artists,
      album: SangeetSimpleAlbumObject(
        id: 'album-$trackId',
        name: albumName,
        externalUri: '',
        artists: artists,
        albumType: SangeetAlbumType.single,
        images: albumImageUrl.isEmpty
            ? []
            : [
                SangeetImageObject(
                  url: albumImageUrl,
                  width: 300,
                  height: 300,
                ),
              ],
      ),
      durationMs: durationMs,
      isrc: '',
      explicit: false,
    );
  }
}

/// Persists the list of downloaded tracks as a JSON index next to the
/// encrypted `.sbm` files in app-private storage.
class DownloadsIndexService {
  static Future<File> get _indexFile async {
    final supportDir = await getApplicationSupportDirectory();
    return File(join(supportDir.path, 'downloads', 'index.json'));
  }

  static Future<List<DownloadedTrack>> load() async {
    try {
      final file = await _indexFile;
      if (!await file.exists()) return [];
      final data = jsonDecode(await file.readAsString());
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => DownloadedTrack.fromJson(e))
          .toList();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return [];
    }
  }

  static Future<void> save(List<DownloadedTrack> tracks) async {
    final file = await _indexFile;
    await file.writeAsString(
      jsonEncode(tracks.map((e) => e.toJson()).toList()),
    );
  }
}
