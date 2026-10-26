import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/services/images/cover_renditions.dart';

class UniversalImage extends HookWidget {
  final String path;
  final double? height;
  final double? width;
  final double scale;
  final String? placeholder;
  final BoxFit? fit;

  /// Rendition size for cover art, in pixels.
  ///
  /// When set, a cover from the Supabase `thumbnails` bucket or the R2 CDN is
  /// fetched from its generated rendition instead of the 1024 original, and the
  /// image is decoded at that size at most. When null (the default) the widget
  /// behaves exactly as before and the original URL is used untouched.
  ///
  /// If the rendition is missing, the original URL is rendered instead, so a
  /// cover can never end up blank because of this.
  final int? coverPixels;
  const UniversalImage({
    required this.path,
    this.height,
    this.width,
    this.placeholder,
    this.fit,
    this.scale = 1,
    this.coverPixels,
    super.key,
  });

  static ImageProvider imageProvider(
    String path, {
    final double? height,
    final double? width,
    final double scale = 1,
    final int? coverPixels,
  }) {
    if (path.startsWith("http")) {
      final url = coverPixels == null
          ? path
          : CoverRendition.urlFor(path, pixels: coverPixels);
      return CachedNetworkImageProvider(
        url,
        maxHeight: (height ?? coverPixels?.toDouble())?.toInt(),
        maxWidth: (width ?? coverPixels?.toDouble())?.toInt(),
        cacheKey: url,
        scale: scale,
      );
    } else if (path.startsWith("assets/")) {
      return AssetImage(path);
    } else if (Uri.tryParse(path) != null) {
      return FileImage(File(path), scale: scale);
    }
    return MemoryImage(base64Decode(path), scale: scale);
  }

  @override
  Widget build(BuildContext context) {
    if (path.startsWith("http")) {
      final url = coverPixels == null
          ? path
          : CoverRendition.urlFor(path, pixels: coverPixels!);
      return FadeInImage(
        image: CachedNetworkImageProvider(
          url,
          maxHeight: (height ?? coverPixels?.toDouble())?.toInt(),
          maxWidth: (width ?? coverPixels?.toDouble())?.toInt(),
          cacheKey: url,
          scale: scale,
        ),
        height: height,
        width: width,
        placeholder: AssetImage(placeholder ?? Assets.images.placeholder.path),
        imageErrorBuilder: (context, error, stackTrace) {
          // The rendition is missing or failed: fall back to the untouched
          // original before giving up, so a cover is never blank because of the
          // rendition switch.
          if (url != path) {
            return UniversalImage(
              path: path,
              width: width,
              height: height,
              scale: scale,
              fit: fit,
              placeholder: placeholder,
            );
          }
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
        fit: fit,
      );
    } else if (Uri.tryParse(path) != null && !path.startsWith("assets")) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
      );
    } else if (path.startsWith("assets")) {
      return Image.asset(
        path,
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
      );
    }

    return Image.memory(
      base64Decode(path),
      width: width,
      height: height,
      cacheHeight: height?.toInt(),
      cacheWidth: width?.toInt(),
      scale: scale,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          placeholder ?? Assets.images.placeholder.path,
          width: width,
          height: height,
          cacheHeight: height?.toInt(),
          cacheWidth: width?.toInt(),
          scale: scale,
        );
      },
    );
  }
}
