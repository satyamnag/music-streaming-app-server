import 'package:sangeet/collections/env.dart';

/// Builds the public Cloudflare R2 CDN URL for a music object from its
/// `storage_path` (the object key in the R2 bucket).
///
/// Example: storage_path `Niluvadu-Manasu.opus` with
/// `R2_BASE_URL=https://music.soulfulbhakti.com` →
/// `https://music.soulfulbhakti.com/Niluvadu-Manasu.opus`.
///
/// Each path segment is percent-encoded. Object keys are uploaded using their
/// original filenames, and this catalogue's filenames contain spaces and other
/// reserved characters (e.g. "Maa Inti Daivama.opus"). An unencoded space makes
/// the URL invalid — some clients silently repair it and others fail — so
/// encoding is required for playback to be reliable for every track rather than
/// only the ones with simple names.
///
/// Returns null when `R2_BASE_URL` is not configured. Callers MUST treat null
/// as a hard failure: audio must never be served from Supabase Storage, because
/// signed-URL audio exhausted the Storage CDN (cached) egress quota.
String? r2StreamUrl(String storagePath) {
  final base = Env.r2BaseUrl.trim();
  if (storagePath.isEmpty) return null;
  if (base.isEmpty) return null;
  final normalizedBase =
      base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$normalizedBase/${encodeObjectKey(storagePath)}';
}

/// Percent-encodes an object key for use in a URL path, segment by segment.
///
/// Slashes are preserved as path separators (keys may contain folders) while
/// every other reserved character — space, `+`, `&`, `#`, `?` — is encoded so
/// the URL addresses exactly the object that was uploaded.
///
/// [Uri.encodeComponent] already leaves a few sub-delimiters unescaped
/// (`-`, `_`, `.`, `!`, `~`, `*`, `'`, `(`, `)`); those are legal in a path
/// segment, so no extra handling is needed.
String encodeObjectKey(String storagePath) =>
    storagePath.split('/').map(Uri.encodeComponent).join('/');
