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
//
// The Telugu label arrives in BOTH spellings, because the owner's editor writes
// the marker one way and the banner's own glyphs the other:
//
//   * `♪ సంగీతం ♪`        - the bare note-glyph form;
//   * `{{ ♪ సంగీతం ♪ }}`  - the same label INSIDE double braces, which is what
//                           the editor emits once the author wraps the banner.
//
// The braced form used to be quoted verbatim on the strength of "double braces
// are always the canonical marker". That holds for `{{Music}}`, but a braced
// label may itself be Telugu, and quoting it verbatim put Telugu script into the
// English columns - the renderer's guard then refused to write at all. Both
// spellings are therefore classified by the SAME rule: the LABEL decides, not
// the wrapper. Braces are stripped, note glyphs are stripped, and if what is
// left is Telugu the cue becomes the variant banner.
//
// WHICH TEXT THE VARIANT COLUMN GETS
// ----------------------------------
// The owner asked, in as many words, that the English columns carry `{{ Music }}`
// (with the spaces) where the Telugu carries `{{ సంగీతం }}`. That is now the
// default for a variant column and is deliberately NOT the same constant as the
// Telugu author marker `MUSIC_LABEL` (`{{Music}}`): `MUSIC_LABEL` is what the
// author types in the Telugu column and what the write gates look for, while
// `VARIANT_MUSIC_LABEL` is the banner a translation/transliteration column
// emits. Both apps render either spelling as the same "♪ Music ♪" banner, so the
// two constants never have to agree.
// ============================================================================

/**
 * The banner a translation/transliteration column emits for a music cue.
 *
 * `{{ Music }}` - the owner's requested spelling, spaces included. Kept separate
 * from the Telugu author marker `MUSIC_LABEL` (`{{Music}}`) so that the Telugu
 * column is never rewritten by a variant render.
 */
export const VARIANT_MUSIC_LABEL = '{{ Music }}'

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
 * The label inside a banner, with its wrapper removed: the double braces and any
 * note glyphs. `{{ ♪ సంగీతం ♪ }}` and `♪ సంగీతం ♪` both yield `సంగీతం`.
 */
function bannerLabel(line) {
  return String(line)
    .replace(/^\{\{/, '')
    .replace(/\}\}$/, '')
    .replace(/\u266A/g, '')
    .trim()
}

/**
 * The text a banner cue should carry in a language-variant column.
 *
 * @param   {string} text        the cue's text, as stored (trimmed or not)
 * @param   {string} [musicLabel] the banner to substitute for a localized label
 * @returns {string|null}        the text to emit, or `null` when the line is not
 *                               a banner at all
 */
export function variantBannerText(text, musicLabel = VARIANT_MUSIC_LABEL) {
  const line = String(text ?? '').trim()
  if (!line) return null

  // `{{...}}` is quoted verbatim - an author who writes `{{♪ Music ♪}}` gets that
  // label on the banner - UNLESS the label is Telugu, which no translation or
  // transliteration column can carry. See "THE RULE" above.
  if (BRACED_BANNER.test(line)) {
    return TELUGU_SCRIPT.test(bannerLabel(line)) ? String(musicLabel) : line
  }

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
