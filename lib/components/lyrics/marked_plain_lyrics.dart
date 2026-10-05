import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/modules/lyrics/lyrics_markup.dart';
import 'package:sangeet/components/lyrics/lyrics_ornament_divider.dart';

/// Renders plain lyrics one line at a time so a line the author wrapped in single
/// braces (`{Pallavi}`) is drawn as an ornament divider while every other line
/// stays ordinary centred text.
///
/// Shared by BOTH plain-lyrics surfaces — the standalone lyrics page and the
/// player's Plain tab — because they must never disagree about what counts as a
/// heading. They used to: the player's tab printed `{Pallavi}` verbatim, so the
/// same song showed a divider on one screen and raw braces on the other.
class MarkedPlainLyrics extends StatelessWidget {
  /// The whole plain-lyrics text, newline separated.
  final String lyrics;

  /// Style for the sung lines. Headings are styled by [LyricsOrnamentDivider].
  final TextStyle style;

  const MarkedPlainLyrics({
    super.key,
    required this.lyrics,
    required this.style,
  });

  /// True when [lyrics] holds at least one `{...}` heading.
  ///
  /// Callers use this to keep the cheaper single [SelectableText] — which stays
  /// selectable as a whole and avoids per-line layout — for the overwhelming
  /// majority of songs that have no headings at all.
  static bool hasMarks(String lyrics) => lyrics
      .split('\n')
      .map(parseMarkedLyricsLine)
      .any((line) => line.mark == LyricsLineMark.heading);

  @override
  Widget build(BuildContext context) {
    final lines = lyrics.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          if (parseMarkedLyricsLine(line).mark == LyricsLineMark.heading)
            LyricsOrnamentDivider(label: parseMarkedLyricsLine(line).label)
          else
            SelectableText(
              line,
              textAlign: TextAlign.center,
              style: style,
            ),
      ],
    );
  }
}
