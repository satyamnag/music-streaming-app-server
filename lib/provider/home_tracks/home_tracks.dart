import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/server/server.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

/// Fetches all tracks from the Supabase `tracks` table via the local server
/// so the home screen always shows every song regardless of player state.
final homeTracksProvider = FutureProvider<List<SangeetTrackObject>>((ref) async {
  await ref.watch(serverProvider.future);
  await SangeetMedia.ensurePortReady();

  final dio = Dio();
  final response = await dio.get(
    'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/tracks',
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to fetch tracks: ${response.statusCode}');
  }

  final data = response.data as Map<String, dynamic>;
  final items = (data['items'] as List<dynamic>? ?? [])
      .map((e) => SangeetTrackObject.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  return items;
});
