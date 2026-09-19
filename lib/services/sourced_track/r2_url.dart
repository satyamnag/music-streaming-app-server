import 'package:sangeet/collections/env.dart';

/// Builds the public Cloudflare R2 CDN URL for a music object from its
/// `storage_path` (the object key in the R2 bucket).
///
/// Example: storage_path `Niluvadu-Manasu.opus` with
/// `R2_BASE_URL=https://music.soulfulbhakti.com` →
/// `https://music.soulfulbhakti.com/Niluvadu-Manasu.opus`.
///
/// Returns null when `R2_BASE_URL` is not configured. Callers MUST treat null
/// as a hard failure: audio must never be served from Supabase Storage, because
/// signed-URL audio exhausted the Storage CDN (cached) egress quota.
String? r2StreamUrl(String storagePath) {
  final base = Env.r2BaseUrl.trim();
  if (base.isEmpty || storagePath.isEmpty) return null;
  final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$normalizedBase/$storagePath';
}
