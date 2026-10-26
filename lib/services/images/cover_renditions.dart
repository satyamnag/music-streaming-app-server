import 'package:sangeet/collections/env.dart';

/// Cover art rendition selection.
///
/// Covers are stored once at 1024x1024. The Android UI draws them far smaller:
/// grid cards, list rows, search results and the media notification all fit
/// inside ~512 px, and only the full player screen is allowed to use the 1024
/// original.
///
/// The 512 renditions are produced once by the "Cover Variants (512x512 WebP)"
/// GitHub Actions workflow and stored next to the untouched original:
///
///   Supabase object : .../storage/v1/object/public/thumbnails/<name>
///   512 rendition   : .../storage/v1/object/public/thumbnails/variants/512/<name>
///
/// Album covers are served from the R2 CDN but their renditions live in the same
/// Supabase folder, so this helper maps either source to the rendition and
/// leaves everything else (avatars, placeholders, local files) untouched.
///
/// Nothing here changes layout or styling - it only picks the URL an
/// [ImageProvider] is created from.
class CoverRendition {
  const CoverRendition._();

  /// Grid cards, list rows, search results, media notification.
  static const int card = 512;

  /// Full player screen: the untouched 1024 original.
  static const int hero = 1024;

  /// The size every cover is stored at; asking for it means "use the original",
  /// so no rendition request is made.
  static const int original = 1024;

  /// The Supabase Storage bucket that holds covers and their renditions.
  static const String bucket = 'thumbnails';

  /// R2 CDN host that serves album covers today.
  static const String r2HostSuffix = 'soulfulbhakti.com';

  /// Returns the URL for [url] at the requested rendition size.
  ///
  /// Returns [url] unchanged when:
  ///  * it is not an absolute http(s) URL (asset, file, memory image),
  ///  * it is not a cover from the Supabase `thumbnails` bucket or the R2 CDN
  ///    (avatars, third-party placeholders),
  ///  * it already points at the requested rendition.
  static String urlFor(String url, {int pixels = card}) {
    if (url.isEmpty) return url;
    // The original is the largest stored copy; there is no rendition above it.
    if (pixels >= original) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;
    if (uri.scheme != 'https' && uri.scheme != 'http') return url;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return url;
    final name = segments.last;
    if (name.isEmpty) return url;

    final fromBucket = segments.contains(bucket) &&
        segments.contains('object') &&
        segments.contains('public');
    final fromR2 = uri.host.endsWith(r2HostSuffix) &&
        segments.length >= 2 &&
        segments.first == 'images';
    if (!fromBucket && !fromR2) return url;

    // Already a rendition of this (or any) size: leave it alone.
    final variantsIndex = segments.indexOf('variants');
    if (variantsIndex >= 0) {
      final current = variantsIndex + 1 < segments.length
          ? segments[variantsIndex + 1]
          : null;
      if (current == '$pixels') return url;
    }

    final base = Env.supabaseUrl.replaceAll(RegExp(r'/+$'), '');
    // `pathSegments` is percent-decoded, so re-encode: object keys contain spaces
    // and non-ASCII bytes that must reach the server escaped.
    final encodedName = Uri.encodeComponent(name);
    return '$base/storage/v1/object/public/$bucket/variants/$pixels/$encodedName';
  }
}
