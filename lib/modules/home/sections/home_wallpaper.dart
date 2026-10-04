import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/components/image/universal_image.dart';

/// The admin-managed home-screen wallpaper, drawn as a LANDSCAPE band across
/// the top of the home page.
///
/// It is deliberately NOT a full-screen background. The home content below the
/// header paints its own surface, so a full-screen image was only ever visible
/// as the strip behind the header — while the upload rule demanded a PORTRAIT
/// 9:16 file, which then had to be cropped to a landscape strip to fill it. The
/// band now matches what is actually shown, and the server accepts landscape
/// (anywhere from 1.3:1 to 3.2:1 — see `WALLPAPER_MIN_RATIO` in the server).
///
/// Two things keep the UI readable over an arbitrary photo:
///  - `BoxFit.cover` fills the band without letterboxing, so the small ratio
///    difference between the upload and [bandAspectRatio] is just an edge crop.
///  - A scrim is layered over it, strongest at the very top where the header
///    text sits, so the header stays legible whatever the artwork's brightness.
///
/// Deliberately NON-interactive: it is wrapped in an `IgnorePointer` so it can
/// never swallow a tap meant for a card or the carousel beneath it.
class HomeWallpaper extends ConsumerWidget {
  /// Display shape of the band, as width : height. 2:1 leaves room for the
  /// status bar plus the logo/tagline header row on a phone without pushing the
  /// first shelf off the fold.
  static const double bandAspectRatio = 2;

  /// Never let the band take more than this share of the viewport height, so a
  /// short or landscape-oriented viewport still shows content below it.
  static const double maxHeightFraction = 0.34;

  /// Height the band occupies in a viewport of [size].
  ///
  /// Width-derived so the band keeps [bandAspectRatio] on every phone, capped by
  /// [maxHeightFraction] so it can never crowd out the content beneath it.
  static double heightFor(Size size) {
    final byRatio = size.width / bandAspectRatio;
    final cap = size.height * maxHeightFraction;
    return byRatio < cap ? byRatio : cap;
  }

  /// The wallpaper image URL. Never empty — the caller only renders this
  /// widget when a wallpaper is actually configured.
  final String url;

  const HomeWallpaper({super.key, required this.url});

  @override
  Widget build(BuildContext context, ref) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: heightFor(MediaQuery.sizeOf(context)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            UniversalImage(path: url, fit: BoxFit.cover),
            // Scrim: darkest along the top edge where the header row sits,
            // easing off towards the bottom of the band so the artwork still
            // reads instead of being uniformly dimmed.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x8C000000),
                    Color(0x59000000),
                    Color(0x2E000000),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
