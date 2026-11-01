// Unit tests for libs/autoSyncLyrics.mjs.
//
// Run: node test/auto-sync-lyrics.test.mjs
//
// The critical property under test is NOT "does it align a clean transcript".
// It is "does it REFUSE when the transcript does not belong to these lyrics" —
// because the failure mode that actually hurts is a plausible-looking timing
// written against the wrong audio file.

import assert from 'node:assert/strict'
import {
  alignLyrics,
  alignLines,
  buildSrtForVariant,
  classifyLine,
  fillUnsungTimings,
  formatLrcTime,
  formatSrtTime,
  isMarkupLine,
  isTelugu,
  normaliseWord,
  parseTimecode,
  parseTimedLyrics,
  splitLyricLines,
  wordSimilarity,
  buildKeyterms,
  MAX_KEYTERMS,
  ingestAcousticRepeats,
  buildSyncCues,
  MIN_MATCH_RATE,
  WORD_MATCH_THRESHOLD,
} from '../libs/autoSyncLyrics.mjs'

let passed = 0
let failed = 0
const tests = []
const test = (name, fn) => tests.push([name, fn])

function eq(actual, expected, msg) {
  assert.deepEqual(actual, expected, msg)
}

// ---------------------------------------------------------------------------
// Normalisation / classification
// ---------------------------------------------------------------------------

test('normaliseWord strips punctuation but keeps Telugu combining marks', () => {
  eq(normaliseWord('నిలువదు,'), 'నిలువదు')
  eq(normaliseWord('  Hello!  '), 'hello')
  // A vowel sign is a combining mark and must survive: dropping it would make
  // two genuinely different Telugu words compare equal.
  assert.notEqual(normaliseWord('కా'), normaliseWord('క'))
})

test('wordSimilarity separates distinct Telugu words that share a first letter', () => {
  // These real pairs all begin with the same letter in migrations/002_lyrics.sql.
  // A first-letter key would score each pair 1.0 and collapse the alignment;
  // this is the regression guard for that exact bug.
  assert.ok(wordSimilarity('నిముషము', 'నిలువదు') < WORD_MATCH_THRESHOLD)
  assert.ok(wordSimilarity('కాంక్షలతో', 'కల్ల') < WORD_MATCH_THRESHOLD)
  assert.ok(wordSimilarity('కేశవా', 'కల్ల') < WORD_MATCH_THRESHOLD)
  eq(wordSimilarity('నిముషము', 'నిలువదు'), 0)
})

test('wordSimilarity scores a truncated/partial word as a match', () => {
  // Singing routinely splits a long word across beats.
  assert.ok(wordSimilarity('నిముషము', 'నిముష') >= WORD_MATCH_THRESHOLD)
  assert.ok(wordSimilarity('కాంక్షలతో', 'కాంక్షల') >= WORD_MATCH_THRESHOLD)
})

test('wordSimilarity is exactly 1 for identical words', () => {
  eq(wordSimilarity('నిలువదు', 'నిలువదు'), 1)
  eq(wordSimilarity('నిలువదు,', 'నిలువదు'), 1)
  eq(wordSimilarity('abc', 'xyz'), 0)
  eq(wordSimilarity('', 'abc'), 0)
})

test('isTelugu detects the Telugu block', () => {
  assert.equal(isTelugu('నిలువదు'), true)
  assert.equal(isTelugu('hello'), false)
  assert.equal(isTelugu(''), false)
})

test('classifyLine distinguishes markup from sung text', () => {
  eq(classifyLine(''), 'empty')
  eq(classifyLine('   '), 'empty')
  eq(classifyLine('{Pallavi}'), 'section')
  eq(classifyLine('{{Music}}'), 'music')
  eq(classifyLine('నిలువదు మనసు'), 'lyric')
  eq(classifyLine('{Section one}'), 'section')
})

test('isMarkupLine matches the real repo markup forms', () => {
  assert.equal(isMarkupLine('{Pallavi}'), true)
  assert.equal(isMarkupLine('{{Music}}'), true)
  assert.equal(isMarkupLine('plain text'), false)
})

test('splitLyricLines preserves blank separator lines and index positions', () => {
  const lines = splitLyricLines('a\n\nb')
  eq(lines, ['a', '', 'b'])
  eq(lines.length, 3)
})

// ---------------------------------------------------------------------------
// Timecode round-tripping — must agree with admin.html's own helpers
// ---------------------------------------------------------------------------

test('formatLrcTime matches admin.html formatLrcTime', () => {
  eq(formatLrcTime(0), '00:00.00')
  eq(formatLrcTime(5.8), '00:05.80')
  eq(formatLrcTime(83.4), '01:23.40')
  eq(formatLrcTime(-5), '00:00.00')
})

test('parseTimecode handles LRC, SRT and bare MM:SS', () => {
  eq(parseTimecode('01:23.40'), 83.4)
  eq(parseTimecode('00:00:05,800'), 5.8)
  eq(parseTimecode('01:23'), 83)
  eq(parseTimecode('nonsense'), null)
})

test('formatSrtTime emits the shape the admin SRT validator accepts', () => {
  eq(formatSrtTime(0), '00:00:00,000')
  eq(formatSrtTime(5.8), '00:00:05,800')
  eq(formatSrtTime(3725.123), '01:02:05,123')
})

test('LRC time round-trips through parse -> format -> parse', () => {
  for (const secs of [0, 1.4, 5.8, 83.4, 150.05]) {
    const tag = formatLrcTime(secs)
    assert.equal(parseTimecode(tag), secs, `round-trip failed for ${secs}`)
  }
})

// ---------------------------------------------------------------------------
// DP alignment
// ---------------------------------------------------------------------------

test('alignLines matches an exact sequence', () => {
  // One word per line keeps the optimal path unique. (With multi-word lines,
  // several paths can score identically — e.g. line0 could claim "b" instead
  // of "a" — so a strict pair-by-pair expectation would be over-specified.)
  const { pairs } = alignLines([['a'], ['b'], ['c']], ['a', 'b', 'c'])
  eq(pairs, [{ line: 0, word: 0 }, { line: 1, word: 1 }, { line: 2, word: 2 }])
})

test('alignLines claims every word of a multi-word line', () => {
  const { pairs } = alignLines([['a', 'b']], ['a', 'b'])
  const words = pairs.filter((p) => p.line === 0).map((p) => p.word).sort()
  eq(words, [0, 1])
})

test('alignLines skips a hallucinated word without shifting later lines', () => {
  const { pairs } = alignLines([['a'], ['b']], ['a', 'zzz', 'b'])
  const lineOf = (lineNo) => pairs.filter((p) => p.line === lineNo).map((p) => p.word)
  eq(lineOf(0), [0])
  eq(lineOf(1), [2])
})

test('alignLines leaves an unheard line unmatched rather than mis-keying it', () => {
  const { pairs } = alignLines([['a'], ['never-sung'], ['c']], ['a', 'c'])
  const lineOf = (lineNo) => pairs.filter((p) => p.line === lineNo).map((p) => p.word)
  eq(lineOf(0), [0])
  eq(lineOf(1), [])
  eq(lineOf(2), [1])
})

test('alignLines tolerates a lyric word split across two transcript words', () => {
  // Line 0 "abcd" is heard as "ab" + "cd": syllable-bigram similarity should
  // still key both fragments to line 0.
  const { pairs } = alignLines([['abcd']], ['ab', 'cd'])
  eq(pairs.filter((p) => p.line === 0).map((p) => p.word).sort(), [0, 1])
})

// ---------------------------------------------------------------------------
// The safety property: refuse on the wrong audio
// ---------------------------------------------------------------------------

const PLAIN_TE = [
  'నిలువదు మనసు నిముషము నీ పైన,',
  'కల్ల జగతి పై కాంక్షలతో కేశవా!',
].join('\n')

/** Build a Deepgram-shaped word list from `[word, start, end]` triples. */
const words = (triples, confidence = 0.95) =>
  triples.map(([word, start, end]) => ({ word, start, end, confidence }))

test('alignLyrics places a small clean transcript', () => {
  const result = alignLyrics({
    plainLyrics: PLAIN_TE,
    words: words([
      ['నిలువదు', 5.8, 6.2], ['మనసు', 6.2, 6.6], ['నిముషము', 6.6, 7.1],
      ['నీ', 7.1, 7.3], ['పైన', 7.3, 7.7],
      ['కల్ల', 9.7, 10.0], ['జగతి', 10.0, 10.4], ['పై', 10.4, 10.6],
      ['కాంక్షలతో', 10.6, 11.1], ['కేశవా', 11.1, 11.6],
    ]),
    audioDuration: 160,
  })
  assert.equal(result.ok, true, `expected ok, got ${result.reason}`)
  assert.equal(result.matchRate, 1)
  assert.equal(result.lines.length, 2)
  assert.equal(result.lines[0].startSeconds, 5.8)
  assert.equal(result.lines[1].startSeconds, 9.7)
})

test('alignLyrics REJECTS a transcript of unrelated speech (wrong audio file)', () => {
  const result = alignLyrics({
    plainLyrics: PLAIN_TE,
    words: words([
      ['the', 1.0, 1.3], ['quarterly', 1.3, 1.8], ['revenue', 1.8, 2.2],
      ['was', 2.2, 2.4], ['better', 2.4, 2.8], ['than', 2.8, 3.0],
      ['expected', 3.0, 3.5], ['this', 3.5, 3.7], ['morning', 3.7, 4.1],
    ]),
    audioDuration: 160,
  })
  assert.equal(result.ok, false)
  assert.equal(result.reason, 'transcript_mismatch')
  assert.ok(result.matchRate < MIN_MATCH_RATE, `matchRate ${result.matchRate} should be below floor`)
})

test('alignLyrics REJECTS when the transcript is empty', () => {
  const result = alignLyrics({ plainLyrics: PLAIN_TE, words: [], audioDuration: 160 })
  assert.equal(result.ok, false)
  assert.equal(result.reason, 'no_transcript_words')
})

test('alignLyrics REJECTS when there are no lyric lines to align', () => {
  const result = alignLyrics({ plainLyrics: '', words: words([['a', 0, 1]]), audioDuration: 10 })
  assert.equal(result.ok, false)
  assert.equal(result.reason, 'no_lyric_lines')
})

test('alignLyrics REJECTS when a sung line could not be placed at all', () => {
  // Line 2 is real sung text the model never heard. Four lines are placed and
  // one is not, so the match rate stays above the floor (4/5 = 0.8) and ONLY
  // the unplaced-line check can catch this — which is exactly the gap this
  // test exists to pin down. (With a lower rate the mismatch gate fires first,
  // which would let this specific bug hide behind a different reason.)
  const result = alignLyrics({
    plainLyrics: ['నిలువదు మనసు', 'కల్ల జగతి', 'కాంక్షలతో కేశవా', 'పరుగిడు నా మనసు', 'పరతత్వ మెరుగదు'].join('\n'),
    words: words([
      ['నిలువదు', 1, 2], ['మనసు', 2, 3],
      ['కల్ల', 3, 4], ['జగతి', 4, 5],
      ['పరుగిడు', 7, 8], ['నా', 8, 9], ['మనసు', 9, 10],
      ['పరతత్వ', 10, 11], ['మెరుగదు', 11, 12],
    ]),
    audioDuration: 160,
  })
  assert.ok(result.matchRate >= MIN_MATCH_RATE, `matchRate ${result.matchRate} should clear the floor`)
  assert.equal(result.ok, false)
  assert.equal(result.reason, 'unplaced_lines')
  eq(result.buildableLineCount, 4)
  eq(result.lines.length, 5)
})

test('alignLyrics REJECTS a transcript too incomplete to trust', () => {
  // Only 2 of 3 lines heard: the mismatch gate fires before the unplaced gate.
  const result = alignLyrics({
    plainLyrics: ['నిలువదు మనసు', 'కల్ల జగతి', 'కాంక్షలతో కేశవా'].join('\n'),
    words: words([
      ['నిలువదు', 1, 2], ['మనసు', 2, 3],
      ['కాంక్షలతో', 10, 11], ['కేశవా', 11, 12],
    ]),
    audioDuration: 160,
  })
  assert.equal(result.ok, false)
  assert.equal(result.reason, 'transcript_mismatch')
})

test('alignLyrics REJECTS low-confidence ASR even when alignment matches', () => {
  const result = alignLyrics({
    plainLyrics: PLAIN_TE,
    words: words([
      ['నిలువదు', 5.8, 6.2], ['మనసు', 6.2, 6.6], ['నిముషము', 6.6, 7.1],
      ['నీ', 7.1, 7.3], ['పైన', 7.3, 7.7],
      ['కల్ల', 9.7, 10.0], ['జగతి', 10.0, 10.4], ['పై', 10.4, 10.6],
      ['కాంక్షలతో', 10.6, 11.1], ['కేశవా', 11.1, 11.6],
    ], 0.2),
    audioDuration: 160,
  })
  assert.equal(result.ok, false)
  assert.equal(result.reason, 'below_confidence_floor')
})

test('alignLyrics flags a line placed before the previous line ended', () => {
  const overlap = alignLyrics({
    plainLyrics: PLAIN_TE,
    words: words([
      ['నిలువదు', 5.8, 9.0], ['మనసు', 9.0, 9.2], ['నిముషము', 9.2, 9.4],
      ['నీ', 9.4, 9.5], ['పైన', 9.5, 9.6],
      // Second line starts INSIDE the first line's span.
      ['కల్ల', 8.9, 9.1], ['జగతి', 9.1, 9.3], ['పై', 9.3, 9.4],
      ['కాంక్షలతో', 9.4, 9.5], ['కేశవా', 9.5, 9.6],
    ]),
    audioDuration: 160,
  })
  // Non-monotonic timings must never be reported as fully confident.
  assert.ok(overlap.overallConfidence < 1)
})

// ---------------------------------------------------------------------------
// SRT rendering
// ---------------------------------------------------------------------------

test('buildSrtForVariant holds each cue until the next line starts', () => {
  const srt = buildSrtForVariant('one\ntwo', [10, 20], 2)
  const blocks = srt.trim().split('\n\n')
  eq(blocks.length, 2)
  // Cue 1 spans 10s -> 20s (the next line's start), not a fixed duration.
  assert.ok(blocks[0].includes('00:00:10,000 --> 00:00:20,000'))
  assert.ok(blocks[0].includes('one'))
  // Final cue gets a bounded fallback end rather than running to infinity.
  assert.ok(blocks[1].includes('00:00:20,000 --> 00:00:21,500'))
})

test('buildSrtForVariant skips sections but keeps {{Music}} banners', () => {
  const srt = buildSrtForVariant('{Pallavi}\n{{Music}}\nsung line', [0, 1, 2], 3)
  assert.ok(!srt.includes('{Pallavi}'))
  assert.ok(srt.includes('{{Music}}'))
  assert.ok(srt.includes('sung line'))
})

test('buildSrtForVariant omits lines with no timing instead of inventing one', () => {
  const srt = buildSrtForVariant('one\ntwo\nthree', [10, null, 30], 3)
  assert.ok(!srt.includes('two'))
  assert.ok(srt.includes('one') && srt.includes('three'))
})

test('buildSrtForVariant keeps an unparallel variant aligned to the timeline', () => {
  // Variant has fewer lines than the main column: the tail must not shift up.
  const srt = buildSrtForVariant('only-one', [10, 20], 2)
  const blocks = srt.trim().split('\n\n')
  eq(blocks.length, 1)
  assert.ok(blocks[0].includes('only-one'))
})

test('the rendered SRT passes the admin.html isValidSrt() contract', () => {
  // Mirror of isValidSrt() in admin.html, including its >= 2 non-blank lines rule.
  const isValidSrt = (text) => {
    const blocks = String(text || '').replace(/\r/g, '').trim().split(/\n\s*\n/).filter((b) => b.trim())
    if (!blocks.length) return true
    const cue = /^\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}\s*-->\s*\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}/
    return blocks.every((block) => {
      const lines = block.split('\n').filter((l) => l.trim())
      if (lines.length < 2) return false
      if (/^\d+$/.test(lines[0].trim())) lines.shift()
      return cue.test(lines[0]) && lines.length >= 2
    })
  }
  const srt = buildSrtForVariant('నిలువదు మనసు\n\nకల్ల జగతి', [5.8, 9.7], 3)
  assert.equal(isValidSrt(srt), true, `admin validator rejected:\n${srt}`)
})

// ---------------------------------------------------------------------------
// Unsung-line timing fill
// ---------------------------------------------------------------------------

test('fillUnsungTimings interpolates between placed neighbours', () => {
  eq(fillUnsungTimings([10, null, 20]), [10, 15, 20])
})

test('fillUnsungTimings leads and trails sanely', () => {
  eq(fillUnsungTimings([null, 10]), [9.9, 10])
  eq(fillUnsungTimings([10, null]), [10, 10.1])
  eq(fillUnsungTimings([null, null]), [null, null])
})

// ---------------------------------------------------------------------------
// Existing-timing detection (drives the "never overwrite verified work" rule)
// ---------------------------------------------------------------------------

test('parseTimedLyrics reads LRC', () => {
  const out = parseTimedLyrics('[00:05.80]line one\n[00:09.70]line two')
  eq(out.length, 2)
  eq(out[0].time, 5.8)
  eq(out[0].text, 'line one')
})

test('parseTimedLyrics reads SRT', () => {
  const out = parseTimedLyrics('1\n00:00:05,800 --> 00:00:09,700\nline one\n\n2\n00:00:09,700 --> 00:00:12,000\nline two')
  eq(out.length, 2)
  eq(out[0].time, 5.8)
  eq(out[0].text, 'line one')
  eq(out[1].text, 'line two')
})

test('parseTimedLyrics ignores LRC metadata headers', () => {
  eq(parseTimedLyrics('[ar:Unknown]\n[ti:Niluvadu Manasu]\n[00:05.80]real line').length, 1)
})

test('parseTimedLyrics returns nothing for untimed markup-only content', () => {
  eq(parseTimedLyrics('plain text with no timestamps'), [])
  eq(parseTimedLyrics(''), [])
})

// ---------------------------------------------------------------------------
// Deepgram keyterm extraction
// ---------------------------------------------------------------------------

// Telugu words written as escape sequences on purpose: keyterm extraction must
// be encoding-safe and this keeps the fixture independent of how the test file
// is saved. "నిలువదు" -> \u0c28\u0c3f\u0c32\u0c41\u0c35... etc.
const TE_NILUVADU = '\u0C28\u0C3F\u0C32\u0C41\u0C35\u0C26\u0C41' // నిలువదు
const TE_MANASU = '\u0C2E\u0C28\u0C38\u0C41' // మనసు
const TE_NA = '\u0C28\u0C3E' // నా
const TE_NI = '\u0C28\u0C40' // నీ

test('buildKeyterms returns normalised, deduped, plain tokens only', () => {
  // Two words, a {Section} heading (which is markup, ignored), a duplicate, and
  // punctuation that must be stripped rather than becoming a separate token.
  const src = `${TE_NILUVADU}, ${TE_MANASU}!\n{Charanam 1}\n${TE_NILUVADU} . ${TE_NA}`
  const out = buildKeyterms(src)
  // normaliseWord strips punctuation; heading skipped; duplicate collapsed.
  eq(out, [TE_NILUVADU, TE_MANASU, TE_NA])
})

test('buildKeyterms never emits a comma/semicolon or empty value', () => {
  // Deepgram silently ignores a comma/semicolon-joined "keyterm", so the
  // extractor must never produce one. Punctuation-only pieces become empty and
  // are dropped entirely.
  const out = buildKeyterms('!!  ??  ;;;  ,,,  word , word ; word')
  eq(out, ['word'])
})

test('buildKeyterms honours the 100-term cap and sorts longest first', () => {
  const words = []
  // 150 genuinely distinct tokens: vary the length with a unique prefix per
  // index so no two collapse after normalisation.
  for (let i = 0; i < 150; i++) words.push(`w${i}${'x'.repeat(i % 30)}`)
  const out = buildKeyterms(words.join(' '))
  eq(out.length, MAX_KEYTERMS)
  // Longest first: the first term must be at least as long as the last.
  assert.ok(out[0].length >= out[out.length - 1].length, 'longest words survive the cap first')
})

test('buildKeyterms on empty/markup-only lyrics returns nothing', () => {
  eq(buildKeyterms(''), [])
  eq(buildKeyterms('{Pallavi}\n{Charanam 1}\n{{Music}}'), [])
})

// ---------------------------------------------------------------------------
// Acoustic repeat ingestion (hybrid acoustic + Deepgram)
// ---------------------------------------------------------------------------

// A placed-line result shaped exactly like alignLyrics() returns.
const acPlaced = (lineIndex, text, start, end, confidence = 0.9) => ({
  lineIndex, text, startSeconds: start, endSeconds: end, confidence,
})

test('ingestAcousticRepeats maps a repeat via the Deepgram word inside its span', () => {
  const alignment = {
    lines: [
      acPlaced(0, TE_NILUVADU, 3.0, 4.0),
      acPlaced(1, TE_MANASU, 5.0, 6.0),
    ],
    repeats: [],
  }
  // The second span b (6.5..7.5) contains a Deepgram word "manasu"-like at 7.0.
  const words = [{ word: TE_MANASU, start: 7.0, end: 7.4, confidence: 0.9 }]
  const lines = [TE_NILUVADU, TE_MANASU]
  const acoustic = [{
    a: { start: 3.0, end: 4.0, error: 0.01 },
    b: { start: 6.5, end: 7.5, error: 0.01 },
    similarity: 0.9,
  }]
  const out = ingestAcousticRepeats(alignment, acoustic, words, lines)
  eq(out.length, 1)
  eq(out[0].text, TE_MANASU)
  eq(out[0].start, 6.5)
  eq(out[0].repeated, true)
  eq(out[0].acoustic, true)
})

test('ingestAcousticRepeats falls back to the line at `a` when no word is in the span', () => {
  const alignment = {
    lines: [acPlaced(0, TE_NILUVADU, 3.0, 4.0)],
    repeats: [],
  }
  const words = [] // Deepgram heard nothing in the repeat span
  const lines = [TE_NILUVADU]
  const acoustic = [{
    a: { start: 3.0, end: 4.0, error: 0.01 },
    b: { start: 6.5, end: 7.5, error: 0.01 },
    similarity: 0.8,
  }]
  const out = ingestAcousticRepeats(alignment, acoustic, words, lines)
  eq(out.length, 1)
  eq(out[0].text, TE_NILUVADU) // reused from `a`'s placed line
  eq(out[0].lineIndex, 0)
})

test('ingestAcousticRepeats drops malformed or non-lyric spans', () => {
  const alignment = { lines: [acPlaced(0, TE_NILUVADU, 3.0, 4.0)], repeats: [] }
  const lines = [TE_NILUVADU]
  // b with start >= end is malformed; a span that maps to no placed line and no
  // word is dropped; empty acoustic list is a no-op.
  eq(ingestAcousticRepeats(alignment, null, [], lines), [])
  eq(ingestAcousticRepeats(alignment, [], [], lines), [])
  eq(ingestAcousticRepeats(alignment, [{ a: {}, b: { start: 5, end: 2 } }], [], lines), [])
  eq(ingestAcousticRepeats(alignment, [{ a: { start: 50 }, b: { start: 60, end: 61 } }], [], lines), [])
})

test('buildSyncCues merges acoustic repeats into the sung timeline', () => {
  const plainLyrics = `${TE_NILUVADU}\n${TE_MANASU}`
  const alignment = {
    lines: [acPlaced(0, TE_NILUVADU, 3.0, 4.0), acPlaced(1, TE_MANASU, 5.0, 6.0)],
    repeats: [],
  }
  const words = [
    { word: TE_NILUVADU, start: 3.1, end: 3.9, confidence: 0.9 },
    { word: TE_MANASU, start: 5.1, end: 5.9, confidence: 0.9 },
  ]
  const acousticRepeats = [{
    a: { start: 3.0, end: 4.0, error: 0.01 },
    b: { start: 8.0, end: 9.0, error: 0.01 },
    similarity: 0.9,
  }]
  const build = buildSyncCues({ plainLyrics, alignment, words, audioDuration: 12, acousticRepeats })
  // 2 placed + 1 acoustic repeat (mapped to line 0 via fallback) = 3 lyric cues.
  eq(build.lyricCueCount, 3)
  eq(build.repeatCueCount, 1)
  const repeat = build.cues.find((c) => c.acoustic)
  assert.ok(repeat, 'an acoustic repeat cue exists')
  eq(repeat.start, 8.0)
  eq(repeat.repeated, true)
})

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

for (const [name, fn] of tests) {
  try {
    await fn()
    passed++
    console.log(`  ok   ${name}`)
  } catch (err) {
    failed++
    console.error(`  FAIL ${name}`)
    console.error(`       ${err.message}`)
  }
}

console.log(`\n${passed} passed, ${failed} failed, ${passed + failed} total`)
process.exit(failed ? 1 : 0)
