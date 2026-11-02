// ============================================================================
// Fill UNPLACED lyric lines using OpenAI, against MEASURED Whisper words.
//
// This is NOT interpolation. Every timestamp it assigns is the measured
// start/end of a real Whisper transcript segment. The model only decides WHICH
// measured segment sings WHICH line (a correspondence judgement), which is
// exactly the failure the deterministic akshara matcher cannot resolve when
// Whisper merges words across beats (e.g. `వేద విద్యలు` heard as one token
// `వేదవిత్యలు`).
//
// Reuses libs/openaiLyricSecondOpinion.mjs verbatim: secondOpinionPicks +
// applySecondOpinion. That library is fail-closed and caps assisted lines at
// 0.5 confidence, so an assisted line can never trigger an automatic write.
//
// Run:
//   node server/tools/whisper-fill-unplaced.mjs --track <id> --words <file> [--out srt.txt]
// ============================================================================

import fs from 'node:fs'
import {
  alignLyrics,
  buildSyncCues,
  renderCuesToSrt,
  splitLyricLines,
  classifyLine,
} from '../libs/autoSyncLyrics.mjs'
import {
  secondOpinionPicks,
  segmentTranscript,
} from '../libs/openaiLyricSecondOpinion.mjs'
import { normaliseWord, wordSimilarity } from '../libs/autoSyncLyrics.mjs'

/** Character-level Levenshtein similarity in [0,1]. */
function levRatio(a, b) {
  if (!a || !b) return 0
  if (a === b) return 1
  const m = a.length
  const n = b.length
  if (!m || !n) return 0
  let prev = new Array(n + 1)
  let cur = new Array(n + 1)
  for (let j = 0; j <= n; j++) prev[j] = j
  for (let i = 1; i <= m; i++) {
    cur[0] = i
    for (let j = 1; j <= n; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    }
    const t = prev
    prev = cur
    cur = t
  }
  return 1 - prev[n] / Math.max(m, n)
}

/**
 * Similarity used ONLY for assisted-line span recovery.
 *
 * Whisper on sung Telugu merges words (`వేద విద్యలు` -> `వేదవిత్యలు`) and swaps
 * similar consonants (`విద్యలు` -> `విత్యలు`). Akshara-bigram Dice scores both
 * of those 0, so we take the BEST of bigram Dice and character Levenshtein.
 */
function spanSimilarity(a, b) {
  const na = normaliseWord(a)
  const nb = normaliseWord(b)
  if (!na || !nb) return 0
  return Math.max(wordSimilarity(na, nb), levRatio(na, nb))
}

/**
 * GLOBAL alignment of every lyric line against the full Whisper word sequence.
 *
 * Why this is needed: the per-line deterministic matcher is order-blind. It
 * matched `ఎదురుగా నీ ముందు ఒకసారి నిలిచిన` to the `ఒకసారి` at 99.1 s (a word
 * that belongs to the PREVIOUS line) and left `వేద విద్యలు...` unplaced, even
 * though Whisper measured both correctly (101.8 s and 140.0 s).
 *
 * A single global Needleman-Wunsch pass over the flat lyric-word sequence
 * enforces order, so each line can only claim words that come after the previous
 * line's words. Every timestamp it emits is a measured Whisper word time.
 *
 * Similarity = max(akshara-bigram Dice, character Levenshtein) because Whisper
 * on sung Telugu merges words (`వేద విద్యలు` -> `వేదవిత్యలు`) and swaps similar
 * consonants (`విద్యలు` -> `విత్యలు`), which bigram Dice scores 0.
 */
function globalAlignLyrics({ plainLyrics, words, audioDuration }) {
  const rawLines = splitLyricLines(plainLyrics)
  const lyricIdx = []
  rawLines.forEach((t, i) => { if (classifyLine(t) === 'lyric') lyricIdx.push(i) })

  // Flat lyric word sequence with the owning line.
  const flat = []
  for (const li of lyricIdx) {
    for (const w of String(rawLines[li]).split(/\s+/)) {
      const n = normaliseWord(w)
      if (n) flat.push({ n, line: li })
    }
  }
  const wn = words.map((w) => ({ n: normaliseWord(w.word), start: w.start, end: w.end, conf: w.confidence }))

  const MATCH_MIN = 0.45
  const M = flat.length
  const N = wn.length
  if (!M || !N) {
    return {
      ok: false, reason: 'no_input', matchRate: 0, lines: [], repeats: [],
      buildableLineCount: 0, overallConfidence: 0,
    }
  }

  // Precompute similarity only where it can matter.
  const sim = (i, j) => {
    const a = flat[i].n
    const b = wn[j].n
    if (a === b) return 1
    return Math.max(wordSimilarity(a, b), levRatio(a, b))
  }

  // Skipping a transcript word is nearly free, but not exactly free: a tiny
  // negative cost makes the DP consume the EARLIEST occurrence of a repeated
  // line rather than a later one that scores identically. Without it the first
  // refrain was left unclaimed and shown as a music banner.
  const SKIP = -0.001
  const MATCH_BONUS = 2

  const dp = Array.from({ length: M + 1 }, () => new Float64Array(N + 1))
  for (let i = 1; i <= M; i++) {
    for (let j = 1; j <= N; j++) {
      const s = sim(i - 1, j - 1)
      const diag = dp[i - 1][j - 1] + (s >= MATCH_MIN ? MATCH_BONUS + s : -1)
      const up = dp[i - 1][j] + SKIP
      const left = dp[i][j - 1] + SKIP
      dp[i][j] = Math.max(diag, up, left)
    }
  }

  // Traceback.
  const pairs = []
  let i = M
  let j = N
  const TOL = 1e-9
  while (i > 0 && j > 0) {
    const s = sim(i - 1, j - 1)
    const diagScore = s >= MATCH_MIN ? MATCH_BONUS + s : -1
    if (s >= MATCH_MIN && Math.abs(dp[i][j] - (dp[i - 1][j - 1] + diagScore)) < TOL) {
      pairs.push({ li: i - 1, wj: j - 1, s })
      i -= 1
      j -= 1
    } else if (Math.abs(dp[i][j] - (dp[i - 1][j] + SKIP)) < TOL) {
      i -= 1
    } else {
      j -= 1
    }
  }
  pairs.reverse()

  // Group by line.
  const byLine = new Map()
  for (const p of pairs) {
    const li = flat[p.li].line
    if (!byLine.has(li)) byLine.set(li, [])
    byLine.get(li).push(p)
  }

  const REPEAT_GAP = 4
  const lines = []
  const repeats = []
  let prevEnd = null
  let matchedLines = 0

  for (const li of lyricIdx) {
    const ps = (byLine.get(li) || []).slice().sort((a, b) => wn[a.wj].start - wn[b.wj].start)
    if (!ps.length) {
      lines.push({
        lineIndex: li, text: rawLines[li], startSeconds: null, endSeconds: null,
        confidence: 0, matchedKeys: 0, totalKeys: 0, wordCount: 0,
      })
      continue
    }

    // Split into occurrences where the singer leaves a long silence.
    const clusters = []
    let cur = [ps[0]]
    for (let k = 1; k < ps.length; k++) {
      const gap = wn[ps[k].wj].start - wn[cur[cur.length - 1].wj].end
      if (gap > REPEAT_GAP) { clusters.push(cur); cur = [ps[k]] } else cur.push(ps[k])
    }
    clusters.push(cur)

    const first = clusters[0]
    const start = Math.min(...first.map((p) => wn[p.wj].start))
    const end = Math.max(...first.map((p) => wn[p.wj].end))
    const meanSim = first.reduce((a, p) => a + p.s, 0) / first.length
    const meanConf = first.reduce((a, p) => a + (wn[p.wj].conf || 0), 0) / first.length

    for (const cl of clusters.slice(1)) {
      repeats.push({
        lineIndex: li,
        text: rawLines[li],
        startSeconds: Math.min(...cl.map((p) => wn[p.wj].start)),
        endSeconds: Math.max(...cl.map((p) => wn[p.wj].end)),
        wordCount: cl.length,
      })
    }

    // Confidence: similarity + ASR certainty + temporal sanity.
    let plaus = 1
    if (prevEnd != null && start < prevEnd - 0.35) plaus = 0.6
    const confidence = Math.min(meanSim, meanConf === 0 ? 0.2 : meanConf, plaus)
    prevEnd = end
    matchedLines += 1

    lines.push({
      lineIndex: li,
      text: rawLines[li],
      startSeconds: Number(start.toFixed(3)),
      endSeconds: Number(end.toFixed(3)),
      confidence: Number(confidence.toFixed(4)),
      matchedKeys: first.length,
      totalKeys: String(rawLines[li]).split(/\s+/).length,
      wordCount: first.length,
      meanSimilarity: Number(meanSim.toFixed(3)),
    })
  }

  const matchRate = lyricIdx.length ? matchedLines / lyricIdx.length : 0
  const buildableLineCount = lines.filter((l) => l.startSeconds != null).length
  const overallConfidence = lines.reduce((a, l) => Math.min(a, l.startSeconds == null ? 0 : l.confidence), 1)

  return {
    ok: true,
    reason: null,
    matchRate: Number(matchRate.toFixed(4)),
    lines,
    repeats,
    buildableLineCount,
    overallConfidence: Number(overallConfidence.toFixed(4)),
  }
}

/**
 * Find EVERY occurrence of each line in the Whisper word sequence.
 *
 * The global alignment deliberately assigns each line its single best (earliest)
 * occurrence so the timeline is ordered. A refrain that is sung several times
 * therefore appears only once. This pass scans the whole word sequence for
 * additional runs that match a line, so each real repetition gets its own cue -
 * at its own measured time, with the author's exact text.
 *
 * Occurrences that overlap an already-timed span for the same line are skipped,
 * so this can never duplicate the primary placement.
 */
function findAllOccurrences(alignment, words) {
  const MIN_SCORE = 0.62
  const found = []
  for (const line of alignment.lines) {
    if (line.startSeconds == null) continue
    const keys = String(line.text).split(/\s+/).map(normaliseWord).filter(Boolean)
    if (keys.length < 2) continue

    const taken = [[line.startSeconds, line.endSeconds]]
    const maxWin = keys.length + 3
    for (let a = 0; a < words.length; a++) {
      for (let b = a; b < Math.min(a + maxWin, words.length); b++) {
        const run = words.slice(a, b + 1)
        if (run.length < 2) continue
        let total = 0
        for (const k of keys) {
          let s = 0
          for (const w of run) {
            const v = spanSimilarity(k, w.word)
            if (v > s) s = v
          }
          total += s
        }
        const score = total / keys.length
        if (score < MIN_SCORE) continue
        const start = run[0].start
        const end = run[run.length - 1].end
        if (taken.some(([s, e]) => start < e - 0.05 && end > s + 0.05)) continue
        taken.push([start, end])
        found.push({
          lineIndex: line.lineIndex,
          text: line.text,
          startSeconds: Number(start.toFixed(3)),
          endSeconds: Number(end.toFixed(3)),
          wordCount: run.length,
          occurrenceScore: Number(score.toFixed(3)),
        })
      }
    }
  }
  return found
}

/**
 * Place an unplaced line at the best-matching contiguous WORD RUN between its
 * already-placed neighbours.
 *
 * Retained as a second pass for any line the global alignment still cannot
 * place. Every timestamp comes from a measured Whisper word - never invented.
 */
function placeUnplacedByWordRun(alignment, words, duration) {
  const MIN_SCORE = 0.45
  let placed = 0
  let changed = true
  let guard = 0
  while (changed && guard < 10) {
    changed = false
    guard += 1
    for (let i = 0; i < (alignment.lines || []).length; i++) {
      const line = alignment.lines[i]
      if (line.startSeconds != null) continue
      const keys = String(line.text).split(/\s+/).map(normaliseWord).filter(Boolean)
      if (!keys.length) continue

      const prev = [...alignment.lines.slice(0, i)].reverse().find((l) => l.startSeconds != null)
      const next = alignment.lines.slice(i + 1).find((l) => l.startSeconds != null)
      const lo = prev ? prev.endSeconds : 0
      const hi = next ? next.startSeconds : (Number(duration) || Number.MAX_SAFE_INTEGER)
      if (!(hi > lo)) continue

      const cand = []
      for (const w of words) {
        const n = normaliseWord(w.word)
        if (!n) continue
        if (w.start >= lo - 0.05 && w.start <= hi + 0.05) cand.push({ n, start: w.start, end: w.end })
      }
      if (!cand.length) continue

      let best = null
      for (let a = 0; a < cand.length; a++) {
        for (let b = a; b < cand.length; b++) {
          const run = cand.slice(a, b + 1)
          let total = 0
          let hits = 0
          for (const k of keys) {
            let s = 0
            for (const w of run) {
              const v = spanSimilarity(k, w.n)
              if (v > s) s = v
            }
            total += s
            if (s >= 0.5) hits += 1
          }
          const score = total / keys.length
          const span = run[run.length - 1].end - run[0].start
          const better = !best
            || score > best.score + 1e-9
            || (Math.abs(score - best.score) < 1e-9 && hits > best.hits)
            || (Math.abs(score - best.score) < 1e-9 && hits === best.hits && span < best.span)
          if (better) best = { score, hits, span, start: run[0].start, end: run[run.length - 1].end }
        }
      }

      if (best && best.score >= MIN_SCORE) {
        line.startSeconds = Number(best.start.toFixed(3))
        line.endSeconds = Number(best.end.toFixed(3))
        line.deterministicFill = true
        line.fillScore = Number(best.score.toFixed(3))
        line.confidence = Math.min(Number(line.confidence) || 0.45, 0.45)
        placed += 1
        changed = true
      }
    }
  }
  return placed
}

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : (process.argv[i + 1] ?? true)
}
const TRACK_ID = arg('track')
const WORDS_FILE = arg('words')
const OUT = arg('out', null)

const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''
const OPENAI_KEY = process.env.OPENAI_API_KEY || ''

if (!TRACK_ID || !WORDS_FILE) { console.error('--track and --words required'); process.exit(2) }
if (!SUPA || !KEY) { console.error('SUPABASE_URL + key required'); process.exit(2) }
if (!OPENAI_KEY) { console.error('OPENAI_API_KEY required'); process.exit(2) }

// --- Track ----------------------------------------------------------------
const res = await fetch(
  `${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK_ID)}&select=title,plain_lyrics,duration`,
  { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } },
)
const [track] = await res.json()
if (!track) { console.error('track not found'); process.exit(2) }
const PLAIN = track.plain_lyrics
const DUR = Number(track.duration) || null
console.log(`track: ${track.title}  duration=${DUR}s`)

// --- Parsed Whisper words -------------------------------------------------
const words = []
for (const raw of fs.readFileSync(WORDS_FILE, 'utf8').split('\n')) {
  const line = raw.replace(/\r$/, '')
  const m = line.match(/^\s*(\d+\.\d+)\s*->\s*(\d+\.\d+)\s+(.+?)\s*\(p=([\d.]+)\)\s*$/)
  if (m) words.push({ word: m[3].trim(), start: +m[1], end: +m[2], confidence: +m[4] })
}
console.log(`whisper words: ${words.length}`)
if (!words.length) { console.error('no whisper words parsed'); process.exit(2) }

// --- GLOBAL alignment (order-enforcing, Levenshtein tolerant) -------------
const alignment = globalAlignLyrics({ plainLyrics: PLAIN, words, audioDuration: DUR })
const before = alignment.lines.filter((l) => l.startSeconds == null).length
console.log(`global align: matchRate=${alignment.matchRate} unplaced=${before} overall=${alignment.overallConfidence}`)

// --- OpenAI second opinion (correspondence confirmation only) -------------
const lyricLines = splitLyricLines(PLAIN)
  .map((text, index) => ({ index, text: String(text).trim() }))
  .filter((l) => classifyLine(l.text) === 'lyric')
const segments = segmentTranscript(words)
console.log(`measured segments: ${segments.length}`)

let openaiVerdict = null
if (before > 0) {
  const picked = await secondOpinionPicks({
    apiKey: OPENAI_KEY,
    lines: lyricLines,
    segments,
  })
  console.log(`second opinion: ok=${picked.ok} reason=${picked.reason} picks=${picked.picks.length} model=${picked.model} (${picked.elapsed_ms}ms)`)
  if (picked.ok) openaiVerdict = picked
}

// --- Deterministic precise placement (authoritative for TIME) -------------
// OpenAI correctly says WHICH segment, but can only return that whole segment's
// start/end; Whisper merges multiple lines per segment, so the span is far too
// wide. The line's own words give the accurate, still-fully-measured time.
const filled = placeUnplacedByWordRun(alignment, words, DUR)
console.log(`deterministic fill placed: ${filled}`)

// --- Recover every repetition of each line (measured, exact text) ---------
const extra = findAllOccurrences(alignment, words)
alignment.repeats = [...(alignment.repeats || []), ...extra]
console.log(`additional occurrences recovered: ${extra.length}`)

// --- Cross-check: does OpenAI's chosen segment contain our placed span? ----
if (openaiVerdict) {
  for (const l of alignment.lines) {
    if (!l.deterministicFill) continue
    const pick = openaiVerdict.picks.find((p) => p.lineIndex === l.lineIndex
      || lyricLines[p.lineIndex]?.text === String(l.text).trim())
    if (!pick || pick.segmentIndex < 0) { console.log(`   line ${l.lineIndex}: OpenAI had no pick`); continue }
    const seg = segments.find((s) => s.index === pick.segmentIndex)
    const inside = seg && l.startSeconds >= seg.start - 0.05 && l.startSeconds <= seg.end + 0.05
    console.log(`   line ${l.lineIndex}: OpenAI segment ${seg ? `${seg.start.toFixed(1)}-${seg.end.toFixed(1)}` : 'n/a'}`
      + ` vs placed ${l.startSeconds.toFixed(1)} -> ${inside ? 'CONSISTENT' : 'MISMATCH'}`)
  }
}

// --- Report per-line outcome ---------------------------------------------
const after = alignment.lines.filter((l) => l.startSeconds == null).length
console.log(`\nunplaced after OpenAI pass: ${after} (was ${before})`)
for (const l of alignment.lines) {
  const flag = l.startSeconds == null ? '✗' : l.llmAssisted ? '◆' : '✓'
  const t = l.startSeconds == null ? '   --   ' : `${l.startSeconds.toFixed(2).padStart(7)}`
  console.log(`${flag} ${t} conf=${String(l.confidence).padStart(5)} ${String(l.text).slice(0, 46)}`)
}

// --- Build + render -------------------------------------------------------
const build = buildSyncCues({ plainLyrics: PLAIN, alignment, words, audioDuration: DUR })
const srt = renderCuesToSrt(build.cues)

const plainLyricLines = lyricLines
const timed = new Set(build.cues.filter((c) => c.kind === 'lyric').map((c) => String(c.text).trim()))
const covered = plainLyricLines.filter((l) => timed.has(l.text)).length
console.log(`\ncoverage: ${covered}/${plainLyricLines.length} lines`)
console.log(`cues: ${build.cues.length} (lyric ${build.lyricCueCount}, repeat ${build.repeatCueCount}, music ${build.musicCueCount})`)
console.log(`assisted lines: ${alignment.lines.filter((l) => l.llmAssisted).length}`)

if (OUT) {
  fs.writeFileSync(OUT, srt, 'utf8')
  console.log(`wrote ${OUT} (${srt.length} chars)`)
} else {
  console.log('\n--- SRT ---')
  console.log(srt)
}
