import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A short vintage/classical banner used for a Synced Lyrics line that the
/// author wrapped in double curly braces, e.g. `{{Music}}`.
///
/// Composition, horizontally centred on one thin row:
/// `ornament -> ♪ -> Music -> ♪ -> ornament`
///
/// Styling is intentionally traditional (wedding-invitation / classical music
/// programme) rather than modern-minimal: a very light cream band, a serif
/// face and a muted gold/brown ink. It is deliberately short — a section
/// divider rather than a header.
class LyricsMusicBanner extends StatelessWidget {
  /// The word shown between the notes. Defaults to "Music".
  final String label;

  const LyricsMusicBanner({super.key, this.label = 'Music'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    const creamBand = Color(0xFFFAF7ED);
    const mutedGold = Color(0xFF8B6F3E);

    // Serif face for the classical feel; falls back to the platform serif when
    // the named family is unavailable (e.g. on a bare Android image).
    final labelStyle = TextStyle(
      fontFamily: 'serif',
      fontFamilyFallback: const ['Georgia', 'Times New Roman', 'Noto Serif'],
      fontSize: 15 * scale,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: mutedGold,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * scale, horizontal: 8 * scale),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8 * scale, horizontal: 12 * scale),
        decoration: BoxDecoration(
          color: creamBand,
          borderRadius: BorderRadius.circular(6 * scale),
          border: Border.all(color: mutedGold.withValues(alpha: 0.30), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _Flourish(color: mutedGold, mirrored: false),
            Gap(8 * scale),
            _note(mutedGold, scale),
            Gap(8 * scale),
            Text(label, style: labelStyle, textAlign: TextAlign.center),
            Gap(8 * scale),
            _note(mutedGold, scale),
            Gap(8 * scale),
            const _Flourish(color: mutedGold, mirrored: true),
          ],
        ),
      ),
    );
  }

  Widget _note(Color color, double scale) => Text(
        '\u266A', // ♪
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 16 * scale,
          color: color,
        ),
      );
}

/// A symmetrical ornamental flourish: a small tapered line ending in a curled
/// scroll, drawn with shapes so no image asset is required.
class _Flourish extends StatelessWidget {
  final Color color;

  /// When true the flourish is mirrored (the curl points the other way), so the
  /// right-hand ornament is a true mirror of the left.
  final bool mirrored;

  const _Flourish({required this.color, required this.mirrored});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer curl.
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1),
            shape: BoxShape.circle,
          ),
        ),
        // Tapered stem.
        Container(
          width: 14,
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: color.withValues(alpha: 0.8),
        ),
        // Inner diamond.
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );

    if (!mirrored) return row;
    // Mirroring keeps the composition perfectly symmetrical around the label.
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
      child: row,
    );
  }
}
