/// Parsing rules for author-marked lyric lines.
///
/// The admin can wrap a lyric line in braces to turn it into a decorative
/// element instead of a sung line:
///
///  * `{Pallavi}` in **plain** lyrics  -> an ornament divider (section heading).
///  * `{{Music}}` in **synced** lyrics -> a "♪ Music ♪" banner.
///  * `♪ Music ♪` in **synced** lyrics -> the same banner, because that is the
///    spelling the banner renders and the one the catalogue actually stores.
///
/// The rules live here, in one place, so the plain and synced renderers can
/// never disagree about what counts as a marked line. The same rules are
/// mirrored by the web app (libs/lyricsMarkup.ts).
library;

/// Matches a whole line wrapped in double braces: `{{ ... }}`.
///
/// Written so the inner text may itself contain single braces (`{{a {b} c}}`
/// is still a banner) while a single-braced line is not matched.
final RegExp _doubleBraceLine = RegExp(r'^\s*\{\{\s*(.*?)\s*\}\}\s*$');

/// Matches a whole line wrapped in single braces: `{ ... }`, excluding the
/// double-brace form (which is checked first by callers).
final RegExp _singleBraceLine = RegExp(r'^\s*\{\s*([^{}]*?)\s*\}\s*$');

/// Matches a whole line whose label is wrapped in note glyphs: `♪ Music ♪`.
///
/// This is the banner written out in the glyphs the banner itself renders, so it
/// means exactly what `{{Music}}` means. It exists because that spelling is the
/// one authors actually used: both synced songs in the catalogue store the cue
/// text `♪ Music ♪`, and without this rule the marker they typed is rendered as
/// an ordinary sung line — which reads as "the double-brace formula does not
/// work", even though the parser handles `{{...}}` correctly.
///
/// Deliberately narrow: the line must START and END with a note and hold no other
/// note, so a sung line that merely mentions one is never swallowed as a banner.
final RegExp _noteWrappedLine =
    RegExp('^\\s*\u266A\\s*([^\u266A]+?)\\s*\u266A\\s*\$');

/// The kind of decorative line an author wrote, if any.
enum LyricsLineMark {
  /// A plain sung line (or blank line) — render normally.
  none,

  /// `{Heading}` — an ornament divider (plain lyrics).
  heading,

  /// `{{Music}}` — a "♪ Music ♪" banner (synced lyrics).
  banner,
}

/// The parsed meaning of one raw lyric line.
class LyricsMarkedLine {
  final LyricsLineMark mark;

  /// Inner text with braces and surrounding whitespace removed. Empty for
  /// [LyricsLineMark.none].
  final String label;

  /// The original line, unchanged.
  final String raw;

  const LyricsMarkedLine({
    required this.mark,
    required this.label,
    required this.raw,
  });

  bool get isMarked => mark != LyricsLineMark.none;
}

/// Classifies one raw lyric line.
///
/// Double braces take precedence, so `{{Music}}` is always a banner and never
/// an ornament heading. A single-braced line whose inner text is empty
/// (`{}`) is treated as an ordinary line rather than an empty pill. A line that
/// is the banner's own `♪ Music ♪` spelling is a banner too — see
/// [_noteWrappedLine].
LyricsMarkedLine parseMarkedLyricsLine(String raw) {
  final banner = _doubleBraceLine.firstMatch(raw);
  if (banner != null) {
    final label = (banner.group(1) ?? '').trim();
    if (label.isNotEmpty) {
      return LyricsMarkedLine(
        mark: LyricsLineMark.banner,
        label: label,
        raw: raw,
      );
    }
    return LyricsMarkedLine(mark: LyricsLineMark.none, label: '', raw: raw);
  }

  final heading = _singleBraceLine.firstMatch(raw);
  if (heading != null) {
    final label = (heading.group(1) ?? '').trim();
    if (label.isNotEmpty) {
      return LyricsMarkedLine(
        mark: LyricsLineMark.heading,
        label: label,
        raw: raw,
      );
    }
  }

  final noteWrapped = _noteWrappedLine.firstMatch(raw);
  if (noteWrapped != null) {
    final label = (noteWrapped.group(1) ?? '').trim();
    if (label.isNotEmpty) {
      return LyricsMarkedLine(
        mark: LyricsLineMark.banner,
        label: label,
        raw: raw,
      );
    }
  }

  return LyricsMarkedLine(mark: LyricsLineMark.none, label: '', raw: raw);
}

/// True when [raw] is a `{{...}}` banner line (used by the synced renderer).
bool isBannerLine(String raw) =>
    parseMarkedLyricsLine(raw).mark == LyricsLineMark.banner;

/// True when [raw] is a `{...}` ornament heading (used by the plain renderer).
bool isHeadingLine(String raw) =>
    parseMarkedLyricsLine(raw).mark == LyricsLineMark.heading;
