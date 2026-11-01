// Tests for the Telugu plain-lyrics -> sync-lyrics cue builder.
//
// Run: node test/auto-sync-cues.test.mjs
//
// The lyrics below are the real "Kavalini Eleti" (Kanaka Durga Maa) script, so
// the tests exercise the shapes that actually occur: `{Section}` headings,
// blank separators, and lines the author wrote once but the singer repeats.

import assert from 'node:assert/strict'
import {
  MUSIC_GAP_MIN_SECONDS,
  MUSIC_LABEL,
  alignLyrics,
  buildSyncCues,
  classifyLine,
  renderCuesForVariant,
  rescueUnplacedLines,
  RESCUE_CONFIDENCE_CAP,
  interpolateUnplacedLines,
  INTERPOLATED_CONFIDENCE,
  parseSrtTimeline,
  deriveVariantSrt,
  renderCuesToSrt,
  unclaimedRuns,
} from '../libs/autoSyncLyrics.mjs'
import { validateLineMap } from '../libs/openaiLyricSecondOpinion.mjs'

let passed = 0
let failed = 0
const tests = []
const test = (name, fn) => tests.push([name, fn])
const eq = (a, b, m) => assert.deepEqual(a, b, m)

// ---------------------------------------------------------------------------
// The real plain-lyrics column
// ---------------------------------------------------------------------------

const PLAIN = `{Pallavi}
à°•à°¾à°µà°²à°¿à°¨à°¿ à°à°²à±‡à°¡à°¿ à°•à°¨à°• à°¦à±à°°à±à°—à°¾,
à°µà°¾à°¸à°µà°¿ à°•à°¨à±à°¨à±†à°• à°µà°¿à°¶à±à°µà°®à°¾à°¤!

{Anupallavi}
à°ªà°°à°®à±‡à°¶à±à°µà°°à°¿ à°—à±Œà°°à°¿. à°ªà°°à°®à°¾à°°à±à°¥ à°¦à°¾à°¯à°¨à°¿!
à°—à±Œà°°à°¿, à°¶à°¾à°‚à°­à°µà°¿, à°œà°¨à°¨à°¿, à°—à°‚à°— à°­à°µà°¾à°¨à°¿

{Charanam 1}
à°à°¦à± à°µà°°à°¹à°®à± à°²à±€à°¯ à°à°¶à±à°µà°°à±à°¯ à°®à°¿à°šà±à°šà±†à°¦à°µà±
à°®à±‡à°¦à°¿à°¨à°¿ à°¯à±à°¨à±à°¨ à°µà°¿à°¦à±à°¯ à°²à°¿à°šà±à°šà±†à°¦à°µà±
à°µà°¦à°¨ à°¬à°¿à°‚à°¬à°®à± à°¨à±€à°¦à± à°’à°• à°¸à°¾à°°à°¿ à°•à°¨à°¿à°¨à°‚à°¤,
à°µà±‡à°¦ à°µà°¿à°¦à±à°¯à°²à± à°¯à°¿à°šà±à°šà°¿ à°µà°¨à±à°¨à±‡ à°—à±‚à°°à±à°šà±†à°¦à°µà±.`

const P1 = 'à°•à°¾à°µà°²à°¿à°¨à°¿ à°à°²à±‡à°¡à°¿ à°•à°¨à°• à°¦à±à°°à±à°—à°¾,'
const P2 = 'à°µà°¾à°¸à°µà°¿ à°•à°¨à±à°¨à±†à°• à°µà°¿à°¶à±à°µà°®à°¾à°¤!'
const A1 = 'à°ªà°°à°®à±‡à°¶à±à°µà°°à°¿ à°—à±Œà°°à°¿. à°ªà°°à°®à°¾à°°à±à°¥ à°¦à°¾à°¯à°¨à°¿!'

// A placed-line result shaped exactly like alignLyrics() returns.
const placed = (lineIndex, text, start, end, confidence = 0.9) => ({
  lineIndex, text, startSeconds: start, endSeconds: end, confidence,
})

// ---------------------------------------------------------------------------
// 1. Section headings are never cues
// ---------------------------------------------------------------------------

test('ANY single-brace label is excluded, not just Pallavi/Anupallavi/Charanam', () => {
  // The rule is generic on purpose: authors invent their own labels. A future
  // "optimisation" that switches this to a fixed list of known section names
  // would silently start timing headings as sung lines, so every one of these
  // shapes is pinned here.
  const labels = ['{Pallavi}', '{Anupallavi}', '{Charanam 1}', '{Charanam 5}', '{Intro}', '{Sthayi}', '{any_text}', '{à°¤à±†à°²à±à°—à±}', '{  spaced  }']

  const lyrics = [
    '{Intro}',
    'à°®à±Šà°¦à°Ÿà°¿ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚',
    '{Sthayi}',
    'à°°à±†à°‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚',
    '{Charanam 5}',
    '{any_text}',
    'à°®à±‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚',
  ].join('\n')

  const lines = lyrics.split('\n')
  const idx = (t) => lines.findIndex((l) => l.trim() === t)
  const alignment = {
    ok: true,
    lines: [
      placed(idx('à°®à±Šà°¦à°Ÿà°¿ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚'), 'à°®à±Šà°¦à°Ÿà°¿ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚', 5, 9),
      placed(idx('à°°à±†à°‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚'), 'à°°à±†à°‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚', 9, 13),
      placed(idx('à°®à±‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚'), 'à°®à±‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚', 13, 17),
    ],
  }

  const { cues } = buildSyncCues({ plainLyrics: lyrics, alignment, words: [], audioDuration: 20 })

  // No cue may carry a brace label, of any spelling.
  for (const c of cues) {
    assert.ok(!/^\{[^{}]*\}$/.test(c.text), `a heading leaked into the timeline: ${c.text}`)
  }
  // ...and every one of the labels above is genuinely classified as a heading.
  for (const l of labels) eq(classifyLine(l), 'section', `${l} was not treated as a heading`)

  // The sung lines survive, in order.
  eq(cues.filter((c) => c.kind === 'lyric').map((c) => c.text), [
    'à°®à±Šà°¦à°Ÿà°¿ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚',
    'à°°à±†à°‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚',
    'à°®à±‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿ à°¸à°¾à°¹à°¿à°¤à±à°¯à°‚',
  ])
})

test('{Pallavi}/{Anupallavi}/{Charanam} headings never become cues', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = {
    ok: true,
    lines: [
      placed(idx, P1, 10, 14),
      placed(idx + 1, P2, 14, 18),
    ],
  }
  const { cues } = buildSyncCues({ plainLyrics: PLAIN, alignment, words: [], audioDuration: 30 })
  const texts = cues.map((c) => c.text)
  assert.ok(!texts.some((t) => t.startsWith('{Pallavi}')), 'Pallavi heading leaked into cues')
  assert.ok(!texts.some((t) => t.startsWith('{Anupallavi}')), 'Anupallavi heading leaked into cues')
  assert.ok(!texts.some((t) => t.trim() === '{Charanam 1}'), 'Charanam heading leaked into cues')
  // ...and the sung lines are present, in order.
  eq(texts[1], P1)
  eq(texts[2], P2)
})

// ---------------------------------------------------------------------------
// 2. {{Music}} covers every stretch with no voice
// ---------------------------------------------------------------------------

test('a leading intro gap becomes a {{Music}} cue starting at 00:00:00,000', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 8, 12), placed(idx + 1, P2, 12, 16)] }
  const { cues, musicCueCount } = buildSyncCues({
    plainLyrics: PLAIN, alignment, words: [], audioDuration: 20,
  })
  eq(cues[0].kind, 'music')
  eq(cues[0].text, MUSIC_LABEL)
  eq(cues[0].start, 0)
  eq(cues[0].end, 8)
  assert.ok(musicCueCount >= 1)
})

test('an interlude and the outro both become {{Music}} cues', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 2, 6), placed(idx + 1, P2, 12, 16)] }
  const { cues } = buildSyncCues({
    plainLyrics: PLAIN, alignment, words: [], audioDuration: 24,
  })
  const music = cues.filter((c) => c.kind === 'music')
  eq(music.length, 2, 'expected one interlude banner and one outro banner')
  eq(music[0].start, 6)
  eq(music[0].end, 12)
  eq(music[1].start, 16)
  eq(music[1].end, 24)
})

test('a gap shorter than the threshold stays music-free (a held note is not an interlude)', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const short = MUSIC_GAP_MIN_SECONDS - 0.5
  const alignment = { ok: true, lines: [placed(idx, P1, 0, 6), placed(idx + 1, P2, 6 + short, 20)] }
  const { cues } = buildSyncCues({
    plainLyrics: PLAIN, alignment, words: [], audioDuration: 20,
  })
  eq(cues.filter((c) => c.kind === 'music').length, 0)
})

// ---------------------------------------------------------------------------
// 3. Repeated singing of a line listed once
// ---------------------------------------------------------------------------

test('a line the transcript hears twice produces two cues for that line', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 2, 6), placed(idx + 1, P2, 6, 10)] }

  // Second occurrence of the pallavi at 20-24, its words claimed by no line.
  const words = [
    { word: 'à°•à°¾à°µà°²à°¿à°¨à°¿', start: 2, end: 2.6 },
    { word: 'à°à°²à±‡à°¡à°¿', start: 2.6, end: 3.4 },
    { word: 'à°•à°¨à°•', start: 3.4, end: 4.2 },
    { word: 'à°¦à±à°°à±à°—à°¾', start: 4.2, end: 5.4 },
    { word: 'à°µà°¾à°¸à°µà°¿', start: 6, end: 6.8 },
    // repeat
    { word: 'à°•à°¾à°µà°²à°¿à°¨à°¿', start: 20, end: 20.6 },
    { word: 'à°à°²à±‡à°¡à°¿', start: 20.6, end: 21.4 },
    { word: 'à°•à°¨à°•', start: 21.4, end: 22.2 },
    { word: 'à°¦à±à°°à±à°—à°¾', start: 22.2, end: 23.4 },
  ]

  const { cues, repeatCueCount } = buildSyncCues({
    plainLyrics: PLAIN, alignment, words, audioDuration: 24,
  })
  const p1 = cues.filter((c) => c.text === P1)
  eq(p1.length, 2, 'the repeated pallavi must be timed twice')
  eq(p1[0].start, 2)
  eq(p1[1].start, 20)
  eq(repeatCueCount, 1)
})

test('unrelated words are never promoted to a repeat cue', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 2, 6)] }
  const words = [
    { word: 'completely', start: 20, end: 20.5 },
    { word: 'different', start: 20.5, end: 21 },
    { word: 'words', start: 21, end: 21.5 },
  ]
  const { repeatCueCount } = buildSyncCues({
    plainLyrics: PLAIN, alignment, words, audioDuration: 22,
  })
  eq(repeatCueCount, 0)
})

test('unclaimedRuns groups consecutive unclaimed words and splits on claimed ones', () => {
  const placedCues = [{ start: 5, end: 8 }]
  const words = [
    { word: 'a', start: 1, end: 1.5 },
    { word: 'b', start: 1.5, end: 2 },
    { word: 'c', start: 6, end: 6.5 },
    { word: 'd', start: 12, end: 12.5 },
    { word: 'e', start: 12.5, end: 13 },
  ]
  const runs = unclaimedRuns(words, placedCues)
  eq(runs.length, 2)
  eq(runs[0].words, ['a', 'b'])
  eq(runs[1].words, ['d', 'e'])
})

// ---------------------------------------------------------------------------
// 4. The rendered SRT
// ---------------------------------------------------------------------------

test('SRT uses HH:MM:SS,mmm and numbers cues from 1 with no gaps or overlaps', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = {
    ok: true,
    lines: [placed(idx, P1, 137.44, 140.375), placed(idx + 1, P2, 140.375, 144)],
  }
  const { cues } = buildSyncCues({ plainLyrics: PLAIN, alignment, words: [], audioDuration: 150 })
  const srt = renderCuesToSrt(cues)

  assert.match(srt, /^1\n00:00:00,000 --> 00:02:17,440\n\{\{Music\}\}/m)
  assert.match(srt, /00:02:17,440 --> 00:02:20,375\nà°•à°¾à°µà°²à°¿à°¨à°¿ à°à°²à±‡à°¡à°¿ à°•à°¨à°• à°¦à±à°°à±à°—à°¾,/m)
  assert.match(srt, /00:02:20,375 --> 00:02:24,000\nà°µà°¾à°¸à°µà°¿ à°•à°¨à±à°¨à±†à°• à°µà°¿à°¶à±à°µà°®à°¾à°¤!/m)

  // Every cue but the last ends exactly where the next begins.
  for (let i = 0; i < cues.length - 1; i++) {
    assert.equal(cues[i].end, cues[i + 1].start, `cue ${i + 1} does not hand over cleanly`)
  }
  // Strictly increasing, never zero-length.
  for (const c of cues) assert.ok(c.end > c.start, 'cue must have positive length')
})

test('a track with no placed line yields no cues at all', () => {
  const { cues, musicCueCount } = buildSyncCues({
    plainLyrics: PLAIN, alignment: { ok: false, lines: [] }, words: [], audioDuration: 200,
  })
  eq(cues, [])
  eq(musicCueCount, 0, 'no singing means no timeline to fill; nothing is invented')
})

test('millisecond precision is preserved, not rounded to seconds', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 1.234, 2.345)] }
  const srt = renderCuesToSrt(buildSyncCues({
    plainLyrics: PLAIN, alignment, words: [], audioDuration: 2.345,
  }).cues)
  assert.match(srt, /00:00:01,234 --> 00:00:02,345/)
})

// ---------------------------------------------------------------------------
// 5. One timeline, five columns
// ---------------------------------------------------------------------------

test('every language column gets the same {{Music}} cues at the same times', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 10, 14), placed(idx + 1, P2, 14, 18)] }
  const { cues } = buildSyncCues({ plainLyrics: PLAIN, alignment, words: [], audioDuration: 30 })

  // The plain columns are line-parallel, so an English translation has the same
  // shape; only its text differs.
  const plainEn = lines.map((l) => (l.trim() === P1 ? 'Kavalini Eledi Kanaka Durga,' : l.trim() === P2 ? 'Vasavi Kanneka Viswamata!' : l)).join('\n')

  const te = renderCuesForVariant(cues, PLAIN, lines.length)
  const en = renderCuesForVariant(cues, plainEn, lines.length)

  const parse = (srt) => srt.trim().split(/\n\s*\n/).map((b) => {
    const parts = b.split('\n')
    return { time: parts[1], text: parts[2] }
  })
  const teCues = parse(te)
  const enCues = parse(en)

  // Same number of cues, and every cue carries the same time range.
  eq(teCues.length, enCues.length)
  for (let i = 0; i < teCues.length; i++) eq(enCues[i].time, teCues[i].time, `cue ${i + 1} drifted`)

  // Banners are identical in every column; lyric text comes from that column.
  const musicTe = teCues.filter((c) => c.text === MUSIC_LABEL)
  const musicEn = enCues.filter((c) => c.text === MUSIC_LABEL)
  eq(musicEn.length, musicTe.length)
  assert.ok(teCues.some((c) => c.text === P1), 'Telugu column keeps its own line')
  assert.ok(enCues.some((c) => c.text === 'Kavalini Eledi Kanaka Durga,'), 'English column keeps its own line')
})

test('renderCuesForVariant skips a line the column has no text for, without shifting times', () => {
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 10, 14), placed(idx + 1, P2, 14, 18)] }
  const { cues } = buildSyncCues({ plainLyrics: PLAIN, alignment, words: [], audioDuration: 30 })

  // A column that only translated the first line.
  const onlyFirst = lines.map((l, i) => (i === idx ? 'First line only' : '')).join('\n')
  const srt = renderCuesForVariant(cues, onlyFirst, lines.length)
  const blocks = srt.trim().split(/\n\s*\n/).map((b) => b.split('\n'))
  // The banner is still there at its exact time; the untranslated line is absent.
  assert.ok(blocks.some((b) => b[1] === '00:00:10,000 --> 00:00:14,000' && b[2] === 'First line only'))
  assert.ok(blocks.some((b) => b[2] === MUSIC_LABEL))
  assert.ok(!blocks.some((b) => b[2] === P2), 'untranslated line must not leak Telugu into this column')
})

test('headings stay in the plain column untouched, and never enter the SRT', () => {
  const before = PLAIN
  const lines = PLAIN.split('\n')
  const idx = lines.findIndex((l) => l.trim() === P1)
  const alignment = { ok: true, lines: [placed(idx, P1, 10, 14), placed(idx + 1, P2, 14, 18)] }

  const { cues } = buildSyncCues({ plainLyrics: PLAIN, alignment, words: [], audioDuration: 20 })
  const srt = renderCuesForVariant(cues, PLAIN, lines.length)

  // 1. The builder is a pure reader: the plain column is byte-identical after.
  eq(PLAIN, before, 'the plain lyrics value must not be mutated')

  // 2. The headings are still THERE in the plain column â€” that is the whole
  //    point: the app renders them as ornament dividers, so the database keeps
  //    them exactly as the author typed them.
  for (const label of ['{Pallavi}', '{Anupallavi}', '{Charanam 1}']) {
    assert.ok(PLAIN.includes(label), `${label} must remain in the plain lyrics`)
  }

  // 3. ...and not one of them reached the generated SRT.
  for (const label of ['{Pallavi}', '{Anupallavi}', '{Charanam 1}']) {
    assert.ok(!srt.includes(label), `${label} leaked into the SRT`)
  }
})

// ---------------------------------------------------------------------------
// 6. Bounded rescue of lines with zero matched words
// ---------------------------------------------------------------------------

const RESCUE_LINES = () => [
  { lineIndex: 0, text: 'à°®à±Šà°¦à°Ÿà°¿ à°ªà°‚à°•à±à°¤à°¿', startSeconds: 10, endSeconds: 14, confidence: 0.9 },
  { lineIndex: 1, text: 'à°¦à±à°°à±à°µà°¾à°° à°•à±ƒà°ªà°¾à°£à°¿, à°¦à°¿à°µà±à°¯à°¾à°¸à±à°¤à±à°° à°ªà°¾à°£à°¿,', startSeconds: null, endSeconds: null, confidence: 0 },
  { lineIndex: 2, text: 'à°°à±†à°‚à°¡à°µ à°ªà°‚à°•à±à°¤à°¿', startSeconds: 20, endSeconds: 24, confidence: 0.9 },
]

test('a zero-word line is rescued from words between its neighbours', () => {
  const alignment = { lines: RESCUE_LINES() }
  const words = [
    { word: 'à°¦à±à°°à±à°µà°¾à°°', start: 15.0, end: 15.6 },
    { word: 'à°•à±ƒà°ªà°¾à°£à°¿', start: 15.6, end: 16.4 },
    { word: 'à°¦à°¿à°µà±à°¯à°¾à°¸à±à°¤à±à°°', start: 16.4, end: 17.0 },
    { word: 'à°ªà°¾à°£à°¿', start: 17.0, end: 17.6 },
  ]
  const out = rescueUnplacedLines(alignment, words)
  eq(out.rescued, 1)
  const line = alignment.lines[1]
  eq(line.startSeconds, 15.0)
  assert.ok(line.endSeconds >= 17.6)
  assert.ok(line.confidence > 0 && line.confidence <= RESCUE_CONFIDENCE_CAP)
  eq(line.rescued, true)
})

test('rescue never moves a line that already had a measured time', () => {
  const alignment = { lines: RESCUE_LINES() }
  const words = [{ word: 'à°®à±Šà°¦à°Ÿà°¿', start: 11, end: 11.5 }, { word: 'à°ªà°‚à°•à±à°¤à°¿', start: 11.5, end: 12 }]
  rescueUnplacedLines(alignment, words)
  eq(alignment.lines[0].startSeconds, 10)
  eq(alignment.lines[0].endSeconds, 14)
  eq(alignment.lines[0].confidence, 0.9)
  assert.equal(alignment.lines[0].rescued, undefined)
})

test('rescue cannot pull words from outside the neighbour window', () => {
  const alignment = { lines: RESCUE_LINES() }
  // Correct words, but at 40 s - far past the next placed line at 20 s.
  const words = [
    { word: 'à°¦à±à°°à±à°µà°¾à°°', start: 40.0, end: 40.6 },
    { word: 'à°•à±ƒà°ªà°¾à°£à°¿', start: 40.6, end: 41.4 },
  ]
  const out = rescueUnplacedLines(alignment, words)
  eq(out.rescued, 0)
  eq(alignment.lines[1].startSeconds, null)
})

test('rescue leaves the line empty when nothing in the window matches it', () => {
  const alignment = { lines: RESCUE_LINES() }
  const words = [{ word: 'completely', start: 15, end: 15.5 }, { word: 'different', start: 15.5, end: 16 }]
  const out = rescueUnplacedLines(alignment, words)
  eq(out.rescued, 0)
  eq(alignment.lines[1].startSeconds, null)
})

test('a rescued line can never reach the write floor on its own', () => {
  const alignment = { lines: RESCUE_LINES() }
  const words = [
    { word: 'à°¦à±à°°à±à°µà°¾à°°', start: 15, end: 15.6 },
    { word: 'à°•à±ƒà°ªà°¾à°£à°¿', start: 15.6, end: 16.4 },
  ]
  rescueUnplacedLines(alignment, words)
  assert.ok(alignment.lines[1].confidence < 0.55, 'a rescued guess must stay below the 0.55 gate')
})

// ---------------------------------------------------------------------------
// 7. Final stage: the timeline is never incomplete
// ---------------------------------------------------------------------------

test('a run of empty lines is filled evenly between its placed neighbours', () => {
  const alignment = { lines: [
    { lineIndex: 0, text: 'ఒకటి', startSeconds: 10, endSeconds: 14, confidence: 0.9 },
    { lineIndex: 1, text: 'రెండు', startSeconds: null, endSeconds: null, confidence: 0 },
    { lineIndex: 2, text: 'మూడు', startSeconds: null, endSeconds: null, confidence: 0 },
    { lineIndex: 3, text: 'నాలుగు', startSeconds: 20, endSeconds: 24, confidence: 0.9 },
  ] }
  const out = interpolateUnplacedLines(alignment)
  eq(out.interpolated, 2)

  // Confined to the 14..20 gap, sequential, non-overlapping, monotonic.
  eq(alignment.lines[0].startSeconds, 10)
  eq(alignment.lines[1].startSeconds, 14)
  eq(alignment.lines[2].startSeconds, 17)
  eq(alignment.lines[1].endSeconds, alignment.lines[2].startSeconds)
  eq(alignment.lines[2].endSeconds, 20)

  // No evidence, so no confidence, and marked as an estimate.
  for (const i of [1, 2]) {
    eq(alignment.lines[i].confidence, INTERPOLATED_CONFIDENCE)
    eq(alignment.lines[i].interpolated, true)
  }
})

test('interpolation never moves a placed line and never crosses it', () => {
  const alignment = { lines: [
    { lineIndex: 0, text: 'ఒకటి', startSeconds: 5, endSeconds: 9, confidence: 0.8 },
    { lineIndex: 1, text: 'రెండు', startSeconds: null, endSeconds: null, confidence: 0 },
    { lineIndex: 2, text: 'మూడు', startSeconds: 12, endSeconds: 16, confidence: 0.8 },
  ] }
  interpolateUnplacedLines(alignment)
  eq(alignment.lines[0].startSeconds, 5)
  eq(alignment.lines[2].startSeconds, 12)
  assert.ok(alignment.lines[1].startSeconds >= 9, 'must not start before the previous line ends')
  assert.ok(alignment.lines[1].endSeconds <= 12, 'must not end after the next line starts')
})

test('a trailing run after the last placed line still gets cues', () => {
  const alignment = { lines: [
    { lineIndex: 0, text: 'ఒకటి', startSeconds: 2, endSeconds: 6, confidence: 0.9 },
    { lineIndex: 1, text: 'రెండు', startSeconds: null, endSeconds: null, confidence: 0 },
  ] }
  const out = interpolateUnplacedLines(alignment)
  eq(out.interpolated, 1)
  assert.ok(alignment.lines[1].startSeconds >= 6)
  assert.ok(alignment.lines[1].endSeconds > alignment.lines[1].startSeconds)
})

test('with no anchor at all nothing is invented', () => {
  const alignment = { lines: [
    { lineIndex: 0, text: 'ఒకటి', startSeconds: null, endSeconds: null, confidence: 0 },
    { lineIndex: 1, text: 'రెండు', startSeconds: null, endSeconds: null, confidence: 0 },
  ] }
  const out = interpolateUnplacedLines(alignment)
  eq(out.interpolated, 0)
  eq(alignment.lines[0].startSeconds, null)
  eq(alignment.lines[1].startSeconds, null)
})

test('headings are never interpolated', () => {
  const alignment = { lines: [
    { lineIndex: 0, text: 'ఒకటి', startSeconds: 2, endSeconds: 6, confidence: 0.9 },
    { lineIndex: 1, text: '{Charanam 2}', startSeconds: null, endSeconds: null, confidence: 0 },
  ] }
  const out = interpolateUnplacedLines(alignment)
  eq(out.interpolated, 0)
  eq(alignment.lines[1].startSeconds, null)
})

// ---------------------------------------------------------------------------
// 8. Deriving a translated column from an EXISTING Telugu SRT
// ---------------------------------------------------------------------------

const TE_SRT = `1
00:00:00,000 --> 00:02:17,440
{{Music}}

2
00:02:17,440 --> 00:02:20,375
కావలిని ఏలేడి కనక దుర్గా,

3
00:02:20,375 --> 00:02:24,000
వాసవి కన్నెక విశ్వమాత!`

const TE_PLAIN = `{Pallavi}
కావలిని ఏలేడి కనక దుర్గా,
వాసవి కన్నెక విశ్వమాత!`

const EN_PLAIN = `{Pallavi}
O Kanaka Durga who rules as we wish,
Vasavi, the mother of the universe!`

test('parseSrtTimeline keeps BOTH ends (unlike parseTimedLyrics)', () => {
  const tl = parseSrtTimeline(TE_SRT)
  eq(tl.length, 3)
  eq(tl[0], { start: 0, end: 137.44, text: '' + MUSIC_LABEL })
  eq(tl[1].start, 137.44)
  eq(tl[1].end, 140.375)
  eq(parseSrtTimeline(''), [])
  eq(parseSrtTimeline('not an srt'), [])
})

test('a translated column inherits the exact Telugu timings, line by line', () => {
  const tl = parseSrtTimeline(TE_SRT)
  const out = deriveVariantSrt({ teluguPlain: TE_PLAIN, timeline: tl, targetPlain: EN_PLAIN })
  eq(out.cues, 3)
  eq(out.matched, 2)
  eq(out.skipped, 0)
  // Same milliseconds as the Telugu cues - not re-derived, not rounded.
  assert.match(out.srt, /^1\n00:00:00,000 --> 00:02:17,440\n\{\{Music\}\}/)
  assert.match(out.srt, /00:02:17,440 --> 00:02:20,375\nO Kanaka Durga who rules as we wish,/)
  assert.match(out.srt, /00:02:20,375 --> 00:02:24,000\nVasavi, the mother of the universe!/)
})

test('a line the translation does not have is skipped, never filled with Telugu', () => {
  const tl = parseSrtTimeline(TE_SRT)
  const partial = `{Pallavi}\nO Kanaka Durga who rules as we wish,`
  const out = deriveVariantSrt({ teluguPlain: TE_PLAIN, timeline: tl, targetPlain: partial })
  eq(out.cues, 2)
  eq(out.matched, 1)
  eq(out.skipped, 1)
  assert.ok(!out.srt.includes('వాసవి'), 'Telugu text must never leak into the translated column')
})

test('a line sung twice maps to both of its occurrences, in order', () => {
  const plain = `{Pallavi}\nఒకటి\nరెండు`
  const plainEn = `{Pallavi}\nOne\nTwo`
  const timeline = [
    { start: 1, end: 2, text: 'ఒకటి' },
    { start: 5, end: 6, text: 'రెండు' },
    { start: 9, end: 10, text: 'ఒకటి' },   // repeated line
  ]
  const out = deriveVariantSrt({ teluguPlain: plain, timeline, targetPlain: plainEn })
  eq(out.cues, 3)
  eq(out.matched, 3)
  assert.match(out.srt, /00:00:01,000 --> 00:00:02,000\nOne/)
  assert.match(out.srt, /00:00:09,000 --> 00:00:10,000\nOne/)
})

test('an empty translation keeps the music banner but emits no lyric text', () => {
  const tl = parseSrtTimeline(TE_SRT)
  const out = deriveVariantSrt({ teluguPlain: TE_PLAIN, timeline: tl, targetPlain: '   ' })
  // `{{Music}}` is language-independent, so the banner survives; no Telugu may
  // leak into the column, and nothing counts as matched.
  eq(out.matched, 0)
  eq(out.cues, 1)
  assert.match(out.srt, /\{\{Music\}\}/)
  assert.ok(!out.srt.includes('వాసవి'))
  assert.ok(!out.srt.includes('కావలిని'))
})

// ---------------------------------------------------------------------------
// 9. Line correspondence for non-parallel translations
// ---------------------------------------------------------------------------

test('a lineMap overrides positional mapping when a translation splits a line', () => {
  const tePlain = `{Pallavi}\nఒకటి\nరెండు`
  const enPlain = `{Pallavi}\nOne (part a)\nOne (part b)\nTwo`
  const timeline = [
    { start: 1, end: 2, text: 'ఒకటి' },
    { start: 3, end: 4, text: 'రెండు' },
  ]
  // Telugu line 1 ("ఒకటి") was split into English lines 1 and 2; we place part a,
  // then skip part b, then line 2 -> English line 3.
  const lineMap = [-1, 1, 3]
  const out = deriveVariantSrt({ teluguPlain: tePlain, timeline, targetPlain: enPlain, lineMap })
  eq(out.matched, 2)
  assert.match(out.srt, /00:00:01,000 --> 00:00:02,000\nOne \(part a\)/)
  assert.match(out.srt, /00:00:03,000 --> 00:00:04,000\nTwo/)
})

test('a -1 in the lineMap skips that line rather than guessing', () => {
  const tePlain = `{Pallavi}\nఒకటి\nరెండు`
  const enPlain = `{Pallavi}\nOne`
  const timeline = [
    { start: 1, end: 2, text: 'ఒకటి' },
    { start: 3, end: 4, text: 'రెండు' },
  ]
  const out = deriveVariantSrt({ teluguPlain: tePlain, timeline, targetPlain: enPlain, lineMap: [-1, 1, -1] })
  eq(out.matched, 1)
  eq(out.skipped, 1)
  assert.ok(!out.srt.includes('రెండు'))
})

test('validateLineMap rejects garbage, out-of-range indices and empty maps', () => {
  eq(validateLineMap('not json', { teluguCount: 2, targetCount: 2 }), null)
  eq(validateLineMap({ map: [{ telugu_index: 9, target_index: 0 }] }, { teluguCount: 2, targetCount: 2 }), null)
  eq(validateLineMap({ map: [{ telugu_index: 0, target_index: 99 }] }, { teluguCount: 2, targetCount: 2 }), null)
  // A map that translates nothing is not better than positional mapping.
  eq(validateLineMap({ map: [{ telugu_index: 0, target_index: -1 }] }, { teluguCount: 2, targetCount: 2 }), null)
  eq(validateLineMap({ map: [{ telugu_index: 0, target_index: 1 }] }, { teluguCount: 2, targetCount: 2 }), [1, -1])
})

// ---------------------------------------------------------------------------
// 10. A line sung more than once must produce a cue per occurrence
// ---------------------------------------------------------------------------

test('a chorus claimed once is split at silence into one cue per occurrence', () => {
  // The reported bug: the chorus is sung three times, the plain column lists it
  // once, and the SRT showed it once. The aligner used to take the min..max of
  // every claimed word, so one line swallowed all three occurrences and rendered
  // as a single 47-second cue.
  const plain = 'మా ఇంటి దైవమా'
  const words = [
    { word: 'మా', start: 32.70, end: 33.18, confidence: 0.9 },
    { word: 'ఇంటి', start: 33.18, end: 34.22, confidence: 0.9 },
    { word: 'దైవమా', start: 34.22, end: 35.90, confidence: 0.9 },
    { word: 'మా', start: 44.80, end: 45.44, confidence: 0.9 },
    { word: 'ఇంటి', start: 45.44, end: 46.24, confidence: 0.9 },
    { word: 'దైవమా', start: 46.24, end: 47.50, confidence: 0.9 },
    { word: 'మా', start: 77.40, end: 77.48, confidence: 0.9 },
    { word: 'ఇంటి', start: 77.48, end: 78.20, confidence: 0.9 },
    { word: 'దైవమా', start: 78.20, end: 80.00, confidence: 0.9 },
  ]

  const a = alignLyrics({ plainLyrics: plain, words, audioDuration: 95 })
  // The line keeps only its FIRST occurrence's span...
  eq(a.lines[0].startSeconds, 32.70)
  eq(a.lines[0].endSeconds, 35.90)
  // ...and the other two are reported as measured repeats.
  eq(a.repeats.length, 2)
  eq(a.repeats.map((r) => r.startSeconds), [44.80, 77.40])

  const { cues, repeatCueCount } = buildSyncCues({ plainLyrics: plain, alignment: a, words, audioDuration: 95 })
  const lyricCues = cues.filter((c) => c.kind === 'lyric')
  eq(lyricCues.length, 3, 'every sung occurrence needs its own cue')
  eq(lyricCues.map((c) => c.start), [32.70, 44.80, 77.40])
  eq(repeatCueCount, 2)
  // The stretches between occurrences are music, not dead air.
  assert.ok(cues.some((c) => c.kind === 'music' && c.start === 0 && c.end === 32.70))
  assert.ok(cues.some((c) => c.kind === 'music' && c.start === 35.90 && c.end === 44.80))
})

test('a line sung once is never split', () => {
  const plain = 'ఒకే సారి పాడిన పంక్తి'
  const words = [
    { word: 'ఒకే', start: 10, end: 10.5 },
    { word: 'సారి', start: 10.5, end: 11 },
    { word: 'పాడిన', start: 11, end: 11.6 },
    { word: 'పంక్తి', start: 11.6, end: 12.2 },
  ]
  const a = alignLyrics({ plainLyrics: plain, words, audioDuration: 20 })
  eq(a.repeats.length, 0)
  eq(a.lines[0].startSeconds, 10)
  eq(a.lines[0].endSeconds, 12.2)
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
