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
/// Deliberately NOT dimmed. An earlier revision laid a three-stop black scrim
/// (up to 55% opacity) over the artwork so the header text stayed legible on a
/// bright photo. On screen that read as a grey wash across the top of the home
/// page rather than as artwork, and the fix belongs to the HEADER, not to the
/// image: the header draws its own text shadows (see `HomeHeader`), which keep
/// white text readable over any wallpaper without dimming a single pixel of it.
/// [home_wallpaper_test.dart] asserts there is no overlay layer here, so the
/// scrim cannot quietly come back.
///
/// Deliberately NON-interactive: it is wrapped in an `IgnorePointer` so it can
/// never swallow a tap meant for a card or the carousel beneath it.
///
/// Its HEIGHT is [heightFor], and the caller anchors it to the top of the home
/// header at exactly that height. It used to be painted with `Positioned.fill`,
/// which stretched the artwork behind the carousel too and made it as tall as the
/// header and the carousel together — around 273dp, a third of the screen, which
/// crowded the shelves below it. The widget's own height is the band; only the
/// caller decides how much of the page it covers.
class HomeWallpaper extends StatelessWidget {
  /// Display shape of the band, as width : height. 8:3 is 2:1 reduced to 0.75 of
  /// its height — the band was taking 34% of the viewport and crowding the
  /// shelves, so it is now exactly three quarters of the height it used to be at
  /// the same width. 135dp on a 360dp-wide phone.
  static const double bandAspectRatio = 8 / 3;

  /// Never let the band take more than this share of the viewport height, so a
  /// short or landscape-oriented viewport still shows content below it.
  ///
  /// 0.34 scaled by the same 0.75 as [bandAspectRatio]: both terms of
  /// [heightFor] move together, so the band is three quarters of its old height
  /// on EVERY viewport, not just the ones wide enough for the ratio to decide.
  static const double maxHeightFraction = 0.34 * 0.75;

  /// Height the band occupies in a viewport of [size].
  ///
  /// Width-derived so the band keeps [bandAspectRatio] on every phone, capped by
  /// [maxHeightFraction] so it can never crowd out the content beneath it.
  ///
  /// The home screen uses this as its scrolling header's `expandedHeight`, so
  /// the band and the header row above it leave the screen together.
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
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Expand so the band fills whatever box it is given — the scrolling
      // header's flexible space on the home screen, or a plain box in a test —
      // instead of taking its size from the image's intrinsic dimensions.
      child: SizedBox.expand(
        child: UniversalImage(path: url, fit: BoxFit.cover),
      ),
    );
  }
}
