import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A devotional/classical section divider used for a Plain Lyrics line that the
/// author wrapped in single curly braces, e.g. `{Pallavi}`.
///
/// Structure (left to right), matching the intended visual hierarchy:
/// `ornament -> line -> title pill -> line -> ornament`
///
/// The look is deliberately warm and understated: a cream pill with dark brown
/// semibold text, hairline gold rules reaching the edges, and a small gold
/// diamond flourish on each side connecting the pill to its rule.
class LyricsOrnamentDivider extends StatelessWidget {
  /// The text shown inside the pill (the brace contents).
  final String label;

  const LyricsOrnamentDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    // Warm palette, chosen to read correctly on both the light lyric sheet and
    // the darker artwork-tinted background the lyrics page uses.
    const creamPill = Color(0xFFFAF3E0);
    const darkBrown = Color(0xFF5B4636);
    const goldLine = Color(0xFFC9A227);

    final labelStyle = theme.typography.small.copyWith(
      color: darkBrown,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 8 * scale),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left rule
          const Expanded(child: _GoldRule()),
          Gap(6 * scale),
          const _Flourish(color: goldLine),
          Gap(6 * scale),
          // Center pill
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 5 * scale,
              ),
              decoration: BoxDecoration(
                color: creamPill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: goldLine.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ),
          Gap(6 * scale),
          const _Flourish(color: goldLine),
          Gap(6 * scale),
          // Right rule
          const Expanded(child: _GoldRule()),
        ],
      ),
    );
  }
}

/// A hairline gold rule that fades toward the outer edge, so the divider feels
/// light rather than a hard full-width border.
class _GoldRule extends StatelessWidget {
  const _GoldRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x00C9A227),
            Color(0xFFC9A227),
          ],
        ),
      ),
    );
  }
}

/// A small gold diamond flourish with a dot on each side, drawn with plain
/// shapes so it needs no image asset and scales cleanly.
class _Flourish extends StatelessWidget {
  final Color color;

  const _Flourish({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(),
        const SizedBox(width: 2),
        _diamond(),
        const SizedBox(width: 2),
        _dot(),
      ],
    );
  }

  Widget _dot() => Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _diamond() => Transform.rotate(
        angle: 0.785398, // 45 degrees
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.2),
          ),
        ),
      );
}
