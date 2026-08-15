import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/provider/server/routes/supabase_data.dart';
import 'package:sangeet/services/sourced_track/r2_url.dart';

/// Resolves a playable stream URL directly from Supabase, bypassing the
/// metadata-plugin bytecode interpreter.
///
/// This is the fastest and most reliable path for both streaming and
/// downloads: it reads the track's storage path, generates a signed URL from
/// the `music` bucket, and returns a [SangeetAudioSourceStreamObject] that
/// points straight at that URL. The plugin's `audioSource.streams()` is only
/// used as a fallback when this path is unavailable.
Future<SangeetAudioSourceStreamObject?> resolveDirectSupabaseStream(
  Ref ref,
  SangeetFullTrackObject track,
) async {
  try {
    // Paid tracks are locked for free users — refuse to sign a stream URL.
    if (track.status == 'paid' && !PremiumAccess.isPremiumUser(ref)) {
      return null;
    }

    final supabase = ref.read(supabaseClientProvider);

    final row = await supabase
        .from('tracks')
        .select('id,storage_path')
        .eq('id', track.id)
        .maybeSingle();

    if (row == null || row['storage_path'] == null) {
      return null;
    }

    final storagePath = row['storage_path'].toString();
    final ext = storagePath.split('.').last.toLowerCase();
    final fmt = ext == 'm4a' ? 'mp4' : ext == 'weba' ? 'webm' : ext;

    // Stream from the Cloudflare R2 public CDN (zero egress). Fall back to a
    // Supabase signed URL only when R2 is not configured.
    final r2 = r2StreamUrl(storagePath);
    final url = r2 ??
        await supabase.storage.from('music').createSignedUrl(storagePath, 3600);

    return SangeetAudioSourceStreamObject(
      url: url,
      container: fmt,
      type: SangeetMediaCompressionType.lossy,
      codec: fmt == 'opus' ? 'opus' : fmt == 'mp3' ? 'mp3' : fmt,
      bitrate: fmt == 'opus' ? 96000 : 128000,
    );
  } catch (_) {
    return null;
  }
}
