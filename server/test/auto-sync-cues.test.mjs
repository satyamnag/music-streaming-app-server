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
  buildSyncCues,
  classifyLine,
  renderCuesForVariant,
  renderCuesToSrt,
  unclaimedRuns,
} from '../libs/autoSyncLyrics.mjs'

let passed = 0
let failed = 0
const tests = []
const test = (name, fn) => tests.push([name, fn])
const eq = (a, b, m) => assert.deepEqual(a, b, m)

// ---------------------------------------------------------------------------
// The real plain-lyrics column
// ---------------------------------------------------------------------------

const PLAIN = `{Pallavi}
కావలిని ఏలేడి కనక దుర్గా,
వాసవి కన్నెక విశ్వమాత!

{Anupallavi}
పరమేశ్వరి గౌరి. పరమార్థ దాయని!
గౌరి, శాంభవి, జనని, గంగ భవాని

{Charanam 1}
ఐదు వరహము లీయ ఐశ్వర్య మిచ్చెదవు
మేదిని యున్న విద్య లిచ్చెదవు
వదన బింబము నీదు ఒక సారి కనినంత,
వేద విద్యలు యిచ్చి వన్నే గూర్చెదవు.`

const P1 = 'కావలిని ఏలేడి కనక దుర్గా,'
const P2 = 'వాసవి కన్నెక విశ్వమాత!'
const A1 = 'పరమేశ్వరి గౌరి. పరమార్థ దాయని!'

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
  const labels = ['{Pallavi}', '{Anupallavi}', '{Charanam 1}', '{Charanam 5}', '{Intro}', '{Sthayi}', '{any_text}', '{తెలుగు}', '{  spaced  }']

  const lyrics = [
    '{Intro}',
    'మొదటి పంక్తి సాహిత్యం',
    '{Sthayi}',
    'రెండవ పంక్తి సాహిత్యం',
    '{Charanam 5}',
    '{any_text}',
    'మూడవ పంక్తి సాహిత్యం',
  ].join('\n')

  const lines = lyrics.split('\n')
  const idx = (t) => lines.findIndex((l) => l.trim() === t)
  const alignment = {
    ok: true,
    lines: [
      placed(idx('మొదటి పంక్తి సాహిత్యం'), 'మొదటి పంక్తి సాహిత్యం', 5, 9),
      placed(idx('రెండవ పంక్తి సాహిత్యం'), 'రెండవ పంక్తి సాహిత్యం', 9, 13),
      placed(idx('మూడవ పంక్తి సాహిత్యం'), 'మూడవ పంక్తి సాహిత్యం', 13, 17),
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
    'మొదటి పంక్తి సాహిత్యం',
    'రెండవ పంక్తి సాహిత్యం',
    'మూడవ పంక్తి సాహిత్యం',
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
    { word: 'కావలిని', start: 2, end: 2.6 },
    { word: 'ఏలేడి', start: 2.6, end: 3.4 },
    { word: 'కనక', start: 3.4, end: 4.2 },
    { word: 'దుర్గా', start: 4.2, end: 5.4 },
    { word: 'వాసవి', start: 6, end: 6.8 },
    // repeat
    { word: 'కావలిని', start: 20, end: 20.6 },
    { word: 'ఏలేడి', start: 20.6, end: 21.4 },
    { word: 'కనక', start: 21.4, end: 22.2 },
    { word: 'దుర్గా', start: 22.2, end: 23.4 },
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
  assert.match(srt, /00:02:17,440 --> 00:02:20,375\nకావలిని ఏలేడి కనక దుర్గా,/m)
  assert.match(srt, /00:02:20,375 --> 00:02:24,000\nవాసవి కన్నెక విశ్వమాత!/m)

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
