import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/components/image/universal_image.dart';

/// The admin-managed home-screen wallpaper, drawn behind the home content.
///
/// Two things keep the UI readable over an arbitrary photo:
///  - `BoxFit.cover` fills the screen without letterboxing, so any phone
///    aspect is covered (the server enforces a portrait 9:16 upload, and a
///    small crop on a taller phone is invisible on a background).
///  - A scrim is layered on top of the image: stronger at the top and bottom
///    (where the header text and the mini player sit) and lighter in the
///    middle, so both ends stay legible whatever the artwork's brightness.
///
/// Deliberately NON-interactive: it is wrapped in an `IgnorePointer` so it can
/// never swallow a tap meant for a card or the carousel beneath it.
class HomeWallpaper extends ConsumerWidget {
  /// The wallpaper image URL. Never empty — the caller only renders this
  /// widget when a wallpaper is actually configured.
  final String url;

  const HomeWallpaper({super.key, required this.url});

  @override
  Widget build(BuildContext context, ref) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          UniversalImage(path: url, fit: BoxFit.cover),
          // Scrim. The top band protects the header row, the bottom band
          // protects the mini player, and the middle stays clearer so the
          // artwork is still visible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8C000000),
                  Color(0x40000000),
                  Color(0x26000000),
                  Color(0x59000000),
                  Color(0x8C000000),
                ],
                stops: [0.0, 0.18, 0.45, 0.78, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
