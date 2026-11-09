// Tests for the music-banner classification used by the language-variant
// renderer.
//
// Run: node test/music-banner.test.mjs
//
// The spellings below are the ones that actually occur in the catalogue:
//   * `{{Music}}` / `{{ Music }}` - the canonical author marker;
//   * `♪ Music ♪`                 - the catalogue's note-glyph spelling;
//   * `♪ <telugu label> ♪`        - what the owner's editor writes, which a
//                                   translation column can never carry.

import assert from 'node:assert/strict'
import { MUSIC_LABEL } from '../libs/autoSyncLyrics.mjs'
import { isVariantBanner, variantBannerText } from '../libs/musicBanner.mjs'

const NOTE = '\u266A' // ♪
const TELUGU_LABEL = '\u0C38\u0C02\u0C17\u0C40\u0C24\u0C02' // music, in Telugu

let passed = 0
let failed = 0
const tests = []
const test = (name, fn) => tests.push([name, fn])

// --- the canonical double-brace marker, quoted verbatim --------------------

test('{{Music}} is a banner and is quoted verbatim', () => {
  assert.equal(variantBannerText('{{Music}}'), '{{Music}}')
})

test('{{ Music }} keeps the author spacing', () => {
  assert.equal(variantBannerText('{{ Music }}'), '{{ Music }}')
})

test('a braced label with note glyphs inside is quoted verbatim', () => {
  const line = `{{${NOTE} Music ${NOTE}}}`
  assert.equal(variantBannerText(line), line)
})

test('an empty {{}} stays a banner row, unchanged', () => {
  // The apps treat an empty inner label as an ordinary line, but this renderer
  // has always mirrored the marker, and changing that is not in scope.
  assert.equal(variantBannerText('{{}}'), '{{}}')
})

// --- the note-glyph marker -------------------------------------------------

test('a Latin label in note glyphs is quoted verbatim', () => {
  const line = `${NOTE} Music ${NOTE}`
  assert.equal(variantBannerText(line), line)
})

test('surrounding whitespace is tolerated', () => {
  const line = `  ${NOTE}  Music  ${NOTE}  `
  assert.equal(variantBannerText(line), `${NOTE}  Music  ${NOTE}`)
})

test('a Telugu label is replaced by the canonical banner', () => {
  assert.equal(variantBannerText(`${NOTE} ${TELUGU_LABEL} ${NOTE}`), MUSIC_LABEL)
  assert.equal(MUSIC_LABEL, '{{Music}}')
})

test('the substituted banner honours a caller-supplied label', () => {
  assert.equal(variantBannerText(`${NOTE} ${TELUGU_LABEL} ${NOTE}`, '{{Music2}}'), '{{Music2}}')
})

// --- things that must NOT be treated as banners ---------------------------

test('an ordinary sung line is not a banner', () => {
  assert.equal(variantBannerText('Pattabhi Ramuni Padamulu Pattoro,'), null)
  assert.equal(isVariantBanner('Pattabhi Ramuni Padamulu Pattoro,'), false)
})

test('a single leading note is not a banner', () => {
  assert.equal(variantBannerText(`${NOTE} Music`), null)
})

test('a single trailing note is not a banner', () => {
  assert.equal(variantBannerText(`Music ${NOTE}`), null)
})

test('a line with a note in the middle is not a banner', () => {
  assert.equal(variantBannerText(`Oh ${NOTE} Music ${NOTE} please`), null)
})

test('a sung line that merely ends in a note is not a banner', () => {
  assert.equal(variantBannerText(`Jai Jai Rama ${NOTE}`), null)
})

test('blank and whitespace-only lines are not banners', () => {
  assert.equal(variantBannerText(''), null)
  assert.equal(variantBannerText('   '), null)
  assert.equal(variantBannerText(null), null)
  assert.equal(variantBannerText(undefined), null)
})

test('an empty note pair is not a banner', () => {
  assert.equal(variantBannerText(`${NOTE} ${NOTE}`), null)
})

test('a Telugu lyric line is not a banner', () => {
  assert.equal(variantBannerText(`${NOTE} ${TELUGU_LABEL}`), null)
})

// --- run -------------------------------------------------------------------

for (const [name, fn] of tests) {
  try {
    fn()
    passed += 1
  } catch (e) {
    failed += 1
    console.error(`FAIL  ${name}`)
    console.error(`      ${e.message}`)
  }
}
console.log(`music-banner: ${passed} passed, ${failed} failed`)
process.exit(failed ? 1 : 0)
