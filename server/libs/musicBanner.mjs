// ============================================================================
// Music-banner classification for the language-variant renderer.
//
// WHY THIS EXISTS
// ---------------
// A synced-lyrics cue that is not sung is a music banner. The apps accept TWO
// spellings for it, and they are interchangeable by design:
//
//   * `{{Music}}`       - the canonical author marker (see MUSIC_LABEL);
//   * `♪ ... ♪`         - the banner written in the glyphs the banner itself
//                         renders. Both parsers accept it:
//                           lib/modules/lyrics/lyrics_markup.dart
//                           (libs/lyricsMarkup.ts in the web app)
//                         because "that is the spelling the catalogue actually
//                         stores" (quoted from the Android parser).
//
// `render-variant-sync.mjs` used to recognise ONLY `{{...}}`. A Telugu column
// that writes its banners as `♪ సంగీతం ♪` - which the owner's editor does -
// therefore produced cues that matched no plain line, fell through to the
// "unmapped" fallback and put TELUGU TEXT into the English columns. The
// renderer's own guard caught it ("cue(s) still contain Telugu script") and
// refused to write, which is correct but blocks a legitimate column.
//
// THE RULE
// --------
// A banner is mirrored into the target column verbatim, so an author's label
// survives (`♪ Music ♪` stays `♪ Music ♪`). The one thing a translation or
// transliteration column can never carry is Telugu script, so a banner whose
// label IS Telugu is replaced by the canonical `{{Music}}`, which both apps
// render as the same "Music" banner.
// ============================================================================

import { MUSIC_LABEL } from './autoSyncLyrics.mjs'

/** A whole line wrapped in double braces: `{{...}}`, `{{ Music }}`, `{{♪ ♪}}`. */
const BRACED_BANNER = /^\{\{[\s\S]*\}\}$/

/**
 * A whole line wrapped in the banner's own note glyphs: `♪ label ♪`.
 *
 * Deliberately as narrow as the apps' rule: the line must START and END with a
 * note and contain no other note, so a sung line that merely mentions one is
 * never swallowed as a banner.
 */
const NOTE_GLYPH_BANNER = /^\s*\u266A\s*([^\u266A]+?)\s*\u266A\s*$/

/** Telugu block - the one script a translation/transliteration column must not carry. */
const TELUGU_SCRIPT = /[\u0C00-\u0C7F]/

/**
 * The text a banner cue should carry in a language-variant column.
 *
 * @param   {string} text        the cue's text, as stored (trimmed or not)
 * @param   {string} [musicLabel] the canonical banner to substitute
 * @returns {string|null}        the text to emit, or `null` when the line is not
 *                               a banner at all
 */
export function variantBannerText(text, musicLabel = MUSIC_LABEL) {
  const line = String(text ?? '').trim()
  if (!line) return null

  // `{{...}}` is quoted verbatim, exactly as before this module existed: an
  // author who writes `{{♪ Music ♪}}` gets that label on the banner.
  if (BRACED_BANNER.test(line)) return line

  const note = NOTE_GLYPH_BANNER.exec(line)
  if (!note) return null
  const label = String(note[1] ?? '').trim()
  if (!label) return null
  return TELUGU_SCRIPT.test(label) ? String(musicLabel) : line
}

/** True when the line is a music banner in either accepted spelling. */
export function isVariantBanner(text) {
  return variantBannerText(text) !== null
}
