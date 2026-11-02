// ============================================================================
// Build a sync-lyrics timeline from Whisper words by GREEDY LINE SEGMENTATION.
//
// WHY THIS EXISTS
// ---------------
// The deterministic aligner and the global word-sequence pass both assign each
// lyric line exactly ONE position. That is wrong for a song whose refrain is
// sung many times: every additional occurrence is then either swallowed into a
// neighbouring cue or shown as a `{{Music}}` banner while the singer is singing.
// Measured on Kavalini Eleti: the refrain is sung 8 times, and 7 music banners
// had real singing inside them.
//
// WHAT IT DOES
// ------------
// Walks the measured word stream left to right. At each position it scores every
// lyric line against the words starting there and takes the best-scoring line
// whose words are contiguous. It then emits ONE cue for that occurrence and
// advances past its words. A line therefore appears as many times as it is sung,
// each at its own measured time, always carrying the author's exact text.
//
// Similarity is max(akshara-bigram Dice, character Levenshtein) because Whisper
// on sung Telugu both merges words (`వేద విద్యలు` -> `వేదవిత్యలు`) and swaps
// similar consonants (`విద్యలు` -> `విత్యలు`), which bigram Dice scores 0.
//
// Nothing is interpolated: every start/end is a measured Whisper word boundary.
//
// Run:
//   node server/tools/whisper-segment-sync.mjs --words <file> --plain <file>
//        [--duration 311] [--out srt.txt] [--report json]
// ============================================================================

import fs from 'node:fs'
import {
  parseSrtTimeline,
  renderCuesToSrt,
  buildSyncCues,
  splitLyricLines,
  classifyLine,
  normaliseWord,
  wordSimilarity,
  MUSIC_LABEL,
} from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : (process.argv[i + 1] ?? true)
}

const WORDS_FILE = arg('words')
const PLAIN_FILE = arg('plain')
const DURATION = Number(arg('duration', 0)) || null
const OUT = arg('out', null)
const REPORT = arg('report', null)

if (!WORDS_FILE || !PLAIN_FILE) {
  console.error('--words <whisper-output.txt> --plain <plain-lyrics.txt> required')
  process.exit(2)
}

/** Character Levenshtein similarity in [0,1]. */
function levRatio(a, b) {
  if (!a || !b) return 0
  if (a === b) return 1
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j)
  for (let i = 1; i <= a.length; i++) {
    const cur = [i]
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
    }
    prev = cur
  }
  return 1 - prev[b.length] / Math.max(a.length, b.length)
}

const sim = (a, b) => (a === b ? 1 : Math.max(wordSimilarity(a, b), levRatio(a, b)))

/**
 * Score how well a window of measured words sings a lyric line.
 *
 * Two measures, best-of:
 *   * per-key mean - works when Whisper emits one token per lyric word;
 *   * CONCATENATED character Levenshtein - works when Whisper merges several
 *     lyric words into one token (`అతిశయముగ నీవు` -> `అదిషయముగనివు`). Comparing
 *     the joined character sequence makes word boundaries irrelevant, which is
 *     exactly the failure mode that left these lines unplaced.
 */
function scoreWindow(keys, run) {
  let total = 0
  for (const key of keys) {
    let s = 0
    for (const wd of run) { const v = sim(key, wd.n); if (v > s) s = v }
    total += s
  }
  const perKey = total / keys.length
  const concat = levRatio(keys.join(''), run.map((x) => x.n).join(''))
  const extra = Math.max(0, run.length - keys.length)
  return Math.max(perKey, concat) - 0.05 * extra
}

// --- Load words ----------------------------------------------------------
const words = []
for (const raw of fs.readFileSync(WORDS_FILE, 'utf8').split('\n')) {
  const m = raw.replace(/\r$/, '').match(/^\s*(\d+\.\d+)\s*->\s*(\d+\.\d+)\s+(.+?)\s*\(p=([\d.]+)\)\s*$/)
  if (m) words.push({ word: m[3].trim(), n: normaliseWord(m[3]), start: +m[1], end: +m[2], conf: +m[4] })
}
if (!words.length) { console.error('no words parsed'); process.exit(2) }

// --- Lyric lines ---------------------------------------------------------
const plainLyrics = fs.readFileSync(PLAIN_FILE, 'utf8')
const rawLines = splitLyricLines(plainLyrics)
const lyric = []
rawLines.forEach((text, i) => {
  if (classifyLine(text) !== 'lyric') return
  const keys = String(text).split(/\s+/).map(normaliseWord).filter(Boolean)
  if (keys.length) lyric.push({ lineIndex: i, text: String(text).trim(), keys })
})
if (!lyric.length) { console.error('no lyric lines'); process.exit(2) }

const dur = DURATION || words[words.length - 1].end + 1
console.log(`words: ${words.length}  lyric lines: ${lyric.length}  duration: ${dur}s`)

// --- Greedy segmentation -------------------------------------------------
// 0.45 (not 0.5): Whisper MERGES several sung words into one token (e.g.
// `అతిశయముగ నీవు` -> `అదిషయముగనివు`), so a 5-word line can legitimately be
// covered by 2 words and its mean per-key similarity lands just under 0.5.
const MIN_SCORE = 0.45

/** Best lyric line matching the words starting at `w`. */
function bestAt(w) {
  let best = null
  for (const L of lyric) {
    const k = L.keys.length
    // A line's words are contiguous, so only consider windows near its own
    // length. Without the upper cap a longer window always scores >= a shorter
    // one (each key takes its best over the run), so the line would swallow the
    // words of the NEXT line and that line would never be placed. The lower cap
    // still allows MERGED singing, where one Whisper token carries two or more
    // lyric words (`అతిశయముగ నీవు` -> `అదిషయముగనివు`).
    const minLen = Math.max(1, Math.ceil(k * 0.4))
    const maxEnd = Math.min(words.length, w + k + 2)
    const minEnd = w + minLen
    for (let end = minEnd; end <= maxEnd; end++) {
      const run = words.slice(w, end)
      const score = scoreWindow(L.keys, run)
      if (score < MIN_SCORE) continue
      const span = run[run.length - 1].end - run[0].start
      const better = !best
        || score > best.score + 1e-9
        || (Math.abs(score - best.score) < 1e-9 && run.length < best.runLen)
        || (Math.abs(score - best.score) < 1e-9 && run.length === best.runLen && span < best.span)
      if (better) best = { L, score, end, runLen: run.length, span, start: run[0].start, stop: run[run.length - 1].end }
    }
  }
  return best
}

const occurrences = []
let w = 0
let skipped = 0
while (w < words.length) {
  const b = bestAt(w)
  if (!b) { w += 1; skipped += 1; continue }
  occurrences.push({
    lineIndex: b.L.lineIndex,
    text: b.L.text,
    start: Number(b.start.toFixed(3)),
    end: Number(b.stop.toFixed(3)),
    score: Number(b.score.toFixed(3)),
  })
  w = b.end
}
console.log(`occurrences: ${occurrences.length}  (unmatched words skipped: ${skipped})`)

// --- Second pass: lines the greedy walk never placed ---------------------
// Two real cases on sung Telugu: Whisper merges so many words that the mean
// per-key similarity falls under the greedy bar, and the walk has already
// moved past them. Such a line is searched across the WHOLE word stream for its
// best-fitting run, accepting only spans that do not overlap an existing
// occurrence. Still entirely measured - nothing is interpolated.
function fillMissing(occs) {
  const placedIdx = new Set(occs.map((o) => o.lineIndex))
  const added = []
  for (const L of lyric) {
    if (placedIdx.has(L.lineIndex)) continue
    const k = L.keys.length
    const minLen = Math.max(1, Math.ceil(k * 0.4))
    const maxLen = k + 2
    let best = null
    for (let a = 0; a < words.length; a++) {
      for (let len = minLen; len <= maxLen && a + len <= words.length; len++) {
        const run = words.slice(a, a + len)
        const score = scoreWindow(L.keys, run)
        if (score < 0.45) continue
        const start = run[0].start
        const end = run[run.length - 1].end
        // must not overlap an occurrence already timed
        if (occs.some((o) => start < o.end - 0.05 && end > o.start + 0.05)) continue
        if (!best || score > best.score) best = { score, start, end }
      }
    }
    if (best) {
      added.push({
        lineIndex: L.lineIndex,
        text: L.text,
        start: Number(best.start.toFixed(3)),
        end: Number(best.end.toFixed(3)),
        score: Number(best.score.toFixed(3)),
      })
    } else if (process.env.SEGMENT_DEBUG) {
      // Show the best candidate that was rejected, and why.
      let top = null
      for (let a = 0; a < words.length; a++) {
        for (let len = minLen; len <= maxLen && a + len <= words.length; len++) {
          const run = words.slice(a, a + len)
          const score = scoreWindow(L.keys, run)
          if (!top || score > top.score) {
            const st = run[0].start
            const en = run[run.length - 1].end
            top = { score, st, en, len, overlaps: occs.some((o) => st < o.end - 0.05 && en > o.start + 0.05) }
          }
        }
      }
      console.log(`   [debug] "${L.text.slice(0, 30)}" best=${top.score.toFixed(3)} at ${top.st.toFixed(1)}-${top.en.toFixed(1)} len=${top.len} overlaps=${top.overlaps}`)
    }
  }
  return added
}

const filled = fillMissing(occurrences)
if (filled.length) {
  occurrences.push(...filled)
  occurrences.sort((a, b) => a.start - b.start)
  console.log(`second pass placed ${filled.length} line(s): ${filled.map((f) => f.text.slice(0, 24)).join(' | ')}`)
}

// --- Build the cue timeline (reuses the shared music-gap + sanitise pass) --
const byLine = new Map()
for (const o of occurrences) {
  if (!byLine.has(o.lineIndex)) byLine.set(o.lineIndex, [])
  byLine.get(o.lineIndex).push(o)
}

const alignmentLines = lyric.map((L) => {
  const os = (byLine.get(L.lineIndex) || []).slice().sort((a, b) => a.start - b.start)
  const first = os[0]
  return {
    lineIndex: L.lineIndex,
    text: L.text,
    startSeconds: first ? first.start : null,
    endSeconds: first ? first.end : null,
    confidence: first ? first.score : 0,
    wordCount: 0,
  }
})
const repeats = []
for (const L of lyric) {
  const os = (byLine.get(L.lineIndex) || []).slice().sort((a, b) => a.start - b.start)
  for (const o of os.slice(1)) {
    repeats.push({ lineIndex: L.lineIndex, text: L.text, startSeconds: o.start, endSeconds: o.end, wordCount: 0 })
  }
}

const build = buildSyncCues({
  plainLyrics,
  alignment: { lines: alignmentLines, repeats },
  words: words.map((x) => ({ word: x.word, start: x.start, end: x.end, confidence: x.conf })),
  audioDuration: dur,
})
const srt = renderCuesToSrt(build.cues)

// --- Report --------------------------------------------------------------
const cues = parseSrtTimeline(srt)
const lyricCueCount = cues.filter((c) => c.text.trim() !== MUSIC_LABEL).length
console.log(`\ncues: ${cues.length} (lyric ${lyricCueCount}, music ${build.musicCueCount})`)

// Which lines were never placed?
const placed = new Set(occurrences.map((o) => o.lineIndex))
const missing = lyric.filter((L) => !placed.has(L.lineIndex))
if (missing.length) console.log(`\nWARNING: ${missing.length} line(s) never matched:\n  ` + missing.map((m) => m.text).join('\n  '))

// Occurrence count per line
console.log('\noccurrences per line:')
for (const L of lyric) {
  const n = (byLine.get(L.lineIndex) || []).length
  console.log(`  ${String(n).padStart(2)}x  ${L.text.slice(0, 46)}`)
}

if (OUT) { fs.writeFileSync(OUT, srt, 'utf8'); console.log(`\nwrote ${OUT} (${srt.length} chars)`) }
else { console.log('\n--- SRT ---'); console.log(srt) }

if (REPORT) {
  fs.writeFileSync(REPORT, JSON.stringify({ occurrences, cues: cues.length, lyricCueCount, missing: missing.map((m) => m.text) }, null, 2), 'utf8')
  console.log(`wrote ${REPORT}`)
}
