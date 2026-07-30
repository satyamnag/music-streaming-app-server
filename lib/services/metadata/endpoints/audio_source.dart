import 'dart:convert';

import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetadataPluginAudioSourceEndpoint {
  final Hetu hetu;
  MetadataPluginAudioSourceEndpoint(this.hetu);

  HTInstance get hetuMetadataAudioSource =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("audioSource")
          as HTInstance;

  List<SangeetAudioSourceContainerPreset> get supportedPresets {
    final raw = hetuMetadataAudioSource.memberGet("supportedPresets") as List;
    return raw
        .map((e) => SangeetAudioSourceContainerPreset.fromJson(
              (e as HTStruct).toJson(),
            ))
        .toList();
  }

  Future<List<SangeetAudioSourceMatchObject>> matches(
    SangeetFullTrackObject track,
  ) async {
    final raw = await hetuMetadataAudioSource
        .invoke("matches", positionalArgs: [track.toJson()]) as List;

    return raw
        .map((e) => SangeetAudioSourceMatchObject.fromJson(e))
        .toList();
  }

  Future<List<SangeetAudioSourceStreamObject>> streams(
    SangeetAudioSourceMatchObject match,
  ) async {
    // Check local cache for signed URL (cached for 1 hour matching Supabase expiry)
    final cacheKey = 'stream_url_${match.id}';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      final entry = jsonDecode(cached) as Map<String, dynamic>;
      final expires = DateTime.parse(entry['_expires'] as String);
      if (expires.isAfter(DateTime.now())) {
        final list = entry['streams'] as List;
        return list
            .map((e) => SangeetAudioSourceStreamObject.fromJson(
                e as Map<String, dynamic>))
            .toList();
      }
    }

    // Fetch from network via Hetu plugin
    final raw = await hetuMetadataAudioSource
        .invoke("streams", positionalArgs: [match.toJson()]) as List;

    final result = raw
        .map((e) => SangeetAudioSourceStreamObject.fromJson(e))
        .toList();

    // Cache the signed URL for 1 hour
    await prefs.setString(
      cacheKey,
      jsonEncode({
        'streams': result.map((s) => s.toJson()).toList(),
        '_expires':
            DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      }),
    );

    return result;
  }
}
