import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The app's wordmark: "Soulful Bhakti", styled as a display lockup.
///
/// ## Why this is styled rather than set in a custom face
/// The brand name was previously drawn in Dancing Script. That family never
/// rendered on a real device — on two phones, two Android versions, in both
/// debug and release it silently fell back to the platform sans-serif, while
/// every unit test passed, because `flutter_test` renders a real face only when
/// the bytes are pushed in through `FontLoader` and therefore never exercises
/// the engine's own bundled-font lookup.
///
/// The custom face has now been removed entirely. Rather than depend on a font
/// that may or may not load, the wordmark is built from properties that cannot
/// fail to apply: weight, size, letter-spacing, colour and shadow. It uses the
/// same default face as the rest of the app, so it renders identically
/// everywhere by construction.
///
/// ## The treatment
/// A classic editorial lockup rather than a single run of text:
///
///  * **weight contrast** — "Soulful" in a light weight against "Bhakti" in a
///    heavy one. This is what carries the "designed" feel that a script face
///    was doing before: two weights of the same family read as deliberate
///    typography, where one weight reads as plain text;
///  * **a gold gradient fill** on the heavy word, matching the logo's own gold,
///    so the wordmark picks up the brand's palette instead of being flat white;
///  * **tight tracking on the light word and looser tracking on the heavy one**,
///    which opens the lockup without inserting a visible gap;
///  * **a soft shadow**, which is what keeps it legible over the wallpaper.
///
/// Every property here is a standard `TextStyle` field, so there is no asset,
/// no family lookup and nothing that can silently fall back.
class BrandWordmark extends StatelessWidget {
  /// Height of the capital letters, in logical pixels at scale == 1.
  ///
  /// 24 keeps the lockup the same optical height in the header row as the 26px
  /// single-weight text it replaces, while leaving room for the two weights to
  /// read as distinct.
  final double fontSize;

  /// Colour for the light word ("Soulful").
  ///
  /// The caller passes white over a wallpaper and the theme foreground on the
  /// plain page, exactly as the surrounding header icons do — the wordmark must
  /// never be the one element that is unreadable in a given state.
  final Color color;

  /// Shadow applied to both words so the lockup survives a busy wallpaper.
  final List<Shadow> shadows;

  /// When false the gold gradient is skipped and both words use [color].
  ///
  /// On the plain page surface (no wallpaper) the gradient is still applied —
  /// it is the brand colour, not a legibility device — but a caller that wants
  /// a flat mark can turn it off.
  final bool gradient;

  const BrandWordmark({
    super.key,
    this.fontSize = 24,
    required this.color,
    this.shadows = const <Shadow>[],
    this.gradient = true,
  });

  /// The gold used for the heavy word, taken from the logo's own artwork.
  static const Color goldLight = Color(0xFFF2C14E);
  static const Color goldDeep = Color(0xFFC9822A);

  @override
  Widget build(BuildContext context) {
    // Weight contrast is the whole idea, so the two halves are separate spans.
    // A single `Text` with one style cannot express it.
    final light = TextStyle(
      fontSize: fontSize,
      // Light, not regular: the contrast against the heavy word is the effect.
      fontWeight: FontWeight.w300,
      // Slightly tight, so the light word reads as a unit rather than drifting.
      letterSpacing: -0.2,
      height: 1.1,
      color: color,
      shadows: shadows,
    );

    final heavy = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      // Opened up a little: a very heavy weight at this size looks cramped
      // without it, and the extra tracking is what makes the lockup feel set
      // rather than merely bold.
      letterSpacing: 0.3,
      height: 1.1,
      color: gradient ? null : color,
      shadows: shadows,
    );

    // The gradient is applied ONLY to the heavy word, so the light word keeps
    // the caller's colour. A `ShaderMask` over the whole lockup would repaint
    // both words in gold and lose the contrast the treatment depends on - which
    // is also why the two halves cannot be one `Text`.
    final heavyWidget = gradient
        ? ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[goldLight, goldDeep],
            ).createShader(bounds),
            child: Text(
              'Bhakti',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: heavy,
            ),
          )
        : Text(
            'Bhakti',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: heavy,
          );

    // A Row rather than a single rich-text span, so each half can carry its own
    // paint (a plain colour on one side, a gradient shader on the other).
    //
    // Wrapped in a `FittedBox(scaleDown)` because a Row does NOT shrink the way a
    // single `Text` does: at a large size on a narrow phone the lockup overflowed
    // by 79dp, which the splash screen has no surrounding FittedBox to absorb.
    // `scaleDown` leaves the mark at its natural size whenever it fits and only
    // scales it down when it cannot - so a caller that ALSO wraps it (the home
    // header does) still scales exactly once, to the same result.
    //
    // `Baseline` alignment keeps the two weights sitting on a shared baseline;
    // without it the differing metrics of w300 and w900 visibly misalign.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Soulful',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: light,
          ),
          // A space between the words, as its own span so the two texts stay
          // separate widgets. Sized in em so it tracks the font size.
          SizedBox(width: fontSize * 0.28),
          heavyWidget,
        ],
      ),
    );
  }
}
