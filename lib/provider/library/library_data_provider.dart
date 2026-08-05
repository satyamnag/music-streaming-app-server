import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/server/server.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';

/// Fetches data from the local stream server for the library screens.
///
/// The Supabase metadata plugin does not expose the developer's curated
/// playlists or the on-device user playlists (its `savedPlaylists` returns
/// empty), so these screens read directly from the local server, matching the
/// home screen pattern.

Uri _libraryUri(String path) {
  final port = SangeetMedia.serverPort;
  return Uri.parse('http://127.0.0.1:$port$path');
}

Future<dynamic> _getJson(Ref ref, String path) async {
  await ref.watch(serverProvider.future);
  await SangeetMedia.ensurePortReady();
  final response = await globalDio.get(
    _libraryUri(path).toString(),
    options: Options(
      validateStatus: (status) => status != null && status < 500,
      headers: {'accept': 'application/json'},
    ),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to fetch $path: ${response.statusCode}');
  }
  return response.data;
}

/// Playlists made by the developer/owner: the whole catalog ("Songs") plus one
/// playlist per artist, each showing the artist name and song count.
final ownerPlaylistsProvider =
    FutureProvider<List<SangeetSimplePlaylistObject>>((ref) async {
  final data = await _getJson(ref, '/supabase/owner-playlists');
  final items = (data['items'] as List<dynamic>? ?? [])
      .map((e) => SangeetSimplePlaylistObject.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
  ref.keepAlive();
  return items;
});

/// Playlists created by the user on this device (stored in the local drift DB).
final userPlaylistsProvider =
    FutureProvider<List<SangeetSimplePlaylistObject>>((ref) async {
  final data = await _getJson(ref, '/supabase/user-playlists');
  final items = (data['items'] as List<dynamic>? ?? [])
      .map((e) => SangeetSimplePlaylistObject.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
  return items;
});

/// Every artist in the catalog with the number of songs they have.
final libraryArtistsProvider =
    FutureProvider<List<SangeetFullArtistObject>>((ref) async {
  final data = await _getJson(ref, '/supabase/artists');
  final items = (data['items'] as List<dynamic>? ?? [])
      .map((e) => SangeetFullArtistObject.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
  ref.keepAlive();
  return items;
});

/// Creates a user playlist in the local drift DB and refreshes the list.
Future<void> createUserPlaylist({
  required String name,
  String description = '',
}) async {
  await SangeetMedia.ensurePortReady();
  final port = SangeetMedia.serverPort;
  await globalDio.post(
    'http://127.0.0.1:$port/supabase/api/playlists',
    data: {'name': name, 'description': description},
    options: Options(
      validateStatus: (status) => status != null && status < 500,
      headers: {'content-type': 'application/json'},
    ),
  );
}

/// Adds a track to a user playlist in the local drift DB.
Future<void> addTrackToUserPlaylist(
  String playlistId,
  String trackId,
) async {
  await SangeetMedia.ensurePortReady();
  final port = SangeetMedia.serverPort;
  await globalDio.post(
    'http://127.0.0.1:$port/supabase/api/playlists/$playlistId/songs',
    data: {'track_id': trackId},
    options: Options(
      validateStatus: (status) => status != null && status < 500,
      headers: {'content-type': 'application/json'},
    ),
  );
}

/// Removes a track from a user playlist in the local drift DB.
Future<void> removeTrackFromUserPlaylist(
  String playlistId,
  String trackId,
) async {
  await SangeetMedia.ensurePortReady();
  final port = SangeetMedia.serverPort;
  await globalDio.delete(
    'http://127.0.0.1:$port/supabase/api/playlists/$playlistId/songs/$trackId',
    options: Options(validateStatus: (status) => status != null && status < 500),
  );
}

/// Deletes a user playlist from the local drift DB.
Future<void> deleteUserPlaylist(String playlistId) async {
  await SangeetMedia.ensurePortReady();
  final port = SangeetMedia.serverPort;
  await globalDio.delete(
    'http://127.0.0.1:$port/supabase/api/playlists/$playlistId',
    options: Options(validateStatus: (status) => status != null && status < 500),
  );
}
