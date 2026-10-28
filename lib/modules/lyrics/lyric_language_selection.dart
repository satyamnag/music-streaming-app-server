/// Which lyric languages are shown at once, and how their lines line up.
///
/// This mirrors the Soulful Bhakti web app's lyrics panel (`components/
/// LyricsPanel.tsx`), which offers the five languages as a MULTI-select: a
/// listener can read one, two, three or all of them together, and every one of
/// them is painted in its own colour.
///
/// The rules live here, pure and tested, rather than inside a widget, because
/// each one is a way the screen can go wrong:
///
///  * `activeLanguages` - what to DRAW. The reader's selection intersected with
///    what the current tab actually has text for, falling back to the first
///    available language so a tab is never blank while it has any text.
///  * `toggle` - what a chip press does. It must never remove the last visible
///    language, because that would empty the screen.
///  * `buildPlainLyricRows` - the plain sheet is per language whole text, so the
///    languages have to be aligned LINE BY LINE to be stacked like the web app's
///    does. Blank rows are kept so stanza breaks survive.
library;

class LyricLanguageSelection {
  LyricLanguageSelection._();

  /// The languages to draw for one tab, in display order.
  ///
  /// [available] is what the tab has text for, in display order; [selected] is
  /// the reader's set. Returns their intersection, or the FIRST available
  /// language when the intersection is empty (the reader picked only languages
  /// this tab does not have). Empty only when [available] is empty.
  static List<String> activeLanguages({
    required List<String> available,
    required Set<String> selected,
  }) {
    final picked = <String>[
      for (final language in available)
        if (selected.contains(language)) language,
    ];
    if (picked.isNotEmpty) return picked;
    return available.isEmpty ? const <String>[] : <String>[available.first];
  }

  /// The selection after pressing the chip for [language].
  ///
  /// Never removes the last language that [available] can show: pressing the
  /// only shown chip leaves the screen as it is instead of blanking it. This is
  /// the web app's "keep at least one language selected" rule.
  static Set<String> toggle({
    required Set<String> selected,
    required String language,
    required List<String> available,
  }) {
    final next = <String>{...selected};
    if (!next.contains(language)) {
      next.add(language);
      return next;
    }

    final stillShown = <String>[
      for (final other in available)
        if (other != language && next.contains(other)) other,
    ];
    // Removing this one would leave the tab with nothing to show.
    if (stillShown.isEmpty) return next;

    next.remove(language);
    return next;
  }
}

/// One row of the plain-lyrics sheet: the same lyric line in each shown
/// language, plus the row it should be interpreted as when it is markup.
class PlainLyricRow {
  /// The text the markup rules are applied to - the first non-empty line in
  /// display order (the Telugu column when it is shown, which is where authors
  /// put `{Heading}`).
  final String primary;

  /// Non-empty lines by language key, for the languages this row has text for.
  final Map<String, String> texts;

  /// True when no shown language has text on this line - a stanza break.
  final bool isBlank;

  const PlainLyricRow({
    required this.primary,
    required this.texts,
    required this.isBlank,
  });
}

/// Aligns the per-language plain texts into rows, one per lyric line.
///
/// [textByLanguage] holds each language's whole plain text; [languages] gives
/// display order. Languages whose line counts differ are padded out with empties,
/// so line N of one language always sits beside line N of another - the same
/// alignment the web app builds from `plain_lyrics*`.
///
/// Fully empty rows are RETURNED rather than dropped so the caller can render
/// them as stanza spacing; dropping them (as the web app does) would silently
/// flatten the breaks the admin wrote.
List<PlainLyricRow> buildPlainLyricRows({
  required List<String> languages,
  required Map<String, String> textByLanguage,
}) {
  final linesByLanguage = <String, List<String>>{};
  for (final language in languages) {
    final raw = textByLanguage[language] ?? '';
    // A language with no text at all contributes nothing. Skipping it keeps a
    // sheet that has no lyrics from producing one blank row.
    if (raw.trim().isEmpty) continue;
    linesByLanguage[language] = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .toList();
  }
  if (linesByLanguage.isEmpty) return const <PlainLyricRow>[];

  var lineCount = 0;
  for (final lines in linesByLanguage.values) {
    if (lines.length > lineCount) lineCount = lines.length;
  }

  final rows = <PlainLyricRow>[];
  for (var index = 0; index < lineCount; index++) {
    final texts = <String, String>{};
    var primary = '';
    for (final language in languages) {
      final lines = linesByLanguage[language]!;
      final text = index < lines.length ? lines[index].trim() : '';
      if (text.isEmpty) continue;
      texts[language] = text;
      if (primary.isEmpty) primary = text;
    }
    rows.add(
      PlainLyricRow(
        primary: primary,
        texts: texts,
        isBlank: texts.isEmpty,
      ),
    );
  }

  // Trailing blank rows come from the final newline of the stored text, not from
  // spacing the author wrote: drop them so the sheet does not end in an empty gap.
  while (rows.isNotEmpty && rows.last.isBlank) {
    rows.removeLast();
  }
  return rows;
}
