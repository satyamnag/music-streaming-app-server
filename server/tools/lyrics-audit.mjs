// ============================================================================
// READ-ONLY verification of every track's sync lyrics.
//
// Measures, per track and column, the four structural properties that define a
// CORRECT SRT:
//   * coverage   - every plain lyric line has >= 1 timed cue,
//   * monotonic  - cues strictly increasing, never overlapping,
//   * in-range   - every cue sits inside [0, track duration],
//   * valid      - no zero/negative cue, no duplicate timestamps.
//
// This proves STRUCTURAL correctness. It cannot prove that a timestamp lands on
// the exact millisecond of the sung syllable - that requires ground truth (a
// human-timed reference, or forced-alignment output), which no ASR-derived
// timeline has. The report tells you the difference rather than blurring it.
//
// Run: node server/tools/lyrics-audit.mjs [--json out.json]
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// ============================================================================

import fs from 'node:fs'
import { classifyLine, parseSrtTimeline, splitLyricLines } from '../libs/autoSyncLyrics.mjs'

const OUT = process.argv.indexOf('--json') !== -1 ? process.argv[process.argv.indexOf('--json') + 1] : null
const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || ''

if (!url || !key) {
  console.error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required')
  process.exit(2)
}

const COLUMNS = [
  { lang: 'te', plain: 'plain_lyrics', synced: 'synced_lyrics' },
  { lang: 'en', plain: 'plain_lyrics_en', synced: 'synced_lyrics_en' },
  { lang: 'en_tr', plain: 'plain_lyrics_en_tr', synced: 'synced_lyrics_en_tr' },
  { lang: 'hi', plain: 'plain_lyrics_hi', synced: 'synced_lyrics_hi' },
  { lang: 'hi_tr', plain: 'plain_lyrics_hi_tr', synced: 'synced_lyrics_hi_tr' },
]

const select = [...new Set(COLUMNS.flatMap((c) => [c.plain, c.synced])), 'duration'].join(',')

/** Count how many times each exact line appears. */
function counts(lines) {
  const m = new Map()
  for (const l of lines) if (l) m.set(l, (m.get(l) || 0) + 1)
  return m
}

/**
 * Structural checks for one column's SRT. Returns problems as a list of
 * {kind, count}, where a count of 0 means the property holds.
 */
function structuralProblems(synced, lyricLineCount, duration) {
  const problems = []
  const cues = parseSrtTimeline(synced)

  if (!cues.length) {
    problems.push({ kind: 'no_cues', count: lyricLineCount })
    return { problems, cues, cueLyricCount: 0 }
  }

  // coverage: how many distinct plain lines have at least one cue
  const sungTexts = new Set(cues.map((c) => c.text.trim()))
  const cueLyricCount = cues.filter((c) => !/^\{\{.*\}\}$/.test(c.text.trim())).length

  // monotonic + no overlap + valid duration
  let overlap = 0
  let zeroDur = 0
  let duplicated = 0
  for (let i = 0; i < cues.length; i++) {
    const c = cues[i]
    if (c.end <= c.start) zeroDur += 1
    if (i > 0 && c.start < cues[i - 1].end) overlap += 1
  }
  const times = new Set(cues.map((c) => c.start))
  if (times.size !== cues.length) duplicated = cues.length - times.size

  // in range
  const dur = Number(duration)
  let outOfRange = 0
  if (Number.isFinite(dur) && dur > 0) {
    for (const c of cues) {
      if (c.start < 0 || c.end > dur + 0.5 || c.start > dur) outOfRange += 1
    }
  }

  if (overlap) problems.push({ kind: 'overlapping_cues', count: overlap })
  if (zeroDur) problems.push({ kind: 'zero_duration_cues', count: zeroDur })
  if (duplicated) problems.push({ kind: 'duplicate_timestamps', count: duplicated })
  if (outOfRange) problems.push({ kind: 'out_of_range', count: outOfRange })

  return { problems, cues, cueLyricCount }
}

async function fetchPage(from, size) {
  const res = await fetch(
    `${url}/rest/v1/tracks?select=id,title,status,${select}&order=title.asc`,
    {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        Range: `${from}-${from + size - 1}`,
        'Range-Unit': 'items',
      },
    },
  )
  if (!res.ok) throw new Error(`supabase ${res.status}: ${(await res.text()).slice(0, 300)}`)
  return res.json()
}

const rows = []
for (let from = 0; ; from += 500) {
  const page = await fetchPage(from, 500)
  rows.push(...page)
  if (page.length < 500) break
}

const findings = []
for (const t of rows) {
  for (const col of COLUMNS) {
    const plain = String(t[col.plain] || '')
    const synced = String(t[col.synced] || '')
    if (!plain.trim()) continue

    const lyricLines = splitLyricLines(plain).filter((l) => classifyLine(l) === 'lyric')
    if (!lyricLines.length) continue

    const { problems, cues, cueLyricCount } = structuralProblems(synced, lyricLines.length, t.duration)
    const cueTexts = counts(cues.map((c) => c.text.trim()))

    // coverage: distinguish "the line has NO cue" from "the line is written N
    // times but timed fewer than N". The second is exactly the complaint
    // "repeated lines' timelines are not there".
    const plainCounts = counts(lyricLines)
    let missingLines = 0     // distinct plain lines with zero cues
    let undertimed = 0       // written N times, timed 1..N-1
    for (const [text, n] of plainCounts) {
      const have = cueTexts.get(text) || 0
      if (have === 0) missingLines += 1
      else if (have < n) undertimed += (n - have)
    }
    if (missingLines > 0) problems.push({ kind: 'missing_lines', count: missingLines })
    if (undertimed > 0) problems.push({ kind: 'repeated_line_undertimed', count: undertimed })

    // Structural verdict: only missing/repeated content is a "content" issue;
    // timing problems are their own, more serious, class.
    const coverage = lyricLines.length ? (1 - missing / lyricLines.length) : 1

    if (problems.length) {
      findings.push({
        id: t.id,
        title: t.title,
        status: t.status,
        column: col.lang,
        duration: Number(t.duration) || null,
        plain_lines: lyricLines.length,
        sung_cues: cueLyricCount,
        total_cues: cues.length,
        coverage_pct: Number((coverage * 100).toFixed(1)),
        problems,
      })
    }
  }
}

const tracks = rows.length
const summaries = findings.map((f) => f.problems.map((p) => p.kind)).flat()
const byKind = {}
for (const k of summaries) byKind[k] = (byKind[k] || 0) + 1
// count distinct tracks with a TIMING problem (vs mere missing content)
const timingKinds = new Set(['overlapping_cues', 'zero_duration_cues', 'duplicate_timestamps', 'out_of_range'])
const tracksWithTimingProblems = new Set(
  findings.filter((f) => f.problems.some((p) => timingKinds.has(p.kind))).map((f) => f.id),
).size

const summary = {
  generated_at: new Date().toISOString(),
  tracks,
  tracks_with_findings: new Set(findings.map((f) => f.id)).size,
  findings: findings.length,
  tracks_with_timing_problems: tracksWithTimingProblems,
  // The honest headline: how many tracks have NO measurable defect at all.
  tracks_fully_valid: Math.max(0, tracks - new Set(findings.map((f) => f.id)).size),
  by_kind: byKind,
  detail: findings,
}

console.log(JSON.stringify(summary, null, 2))
if (OUT) fs.writeFileSync(OUT, JSON.stringify(summary, null, 2))
console.log(`\n${summary.tracks} tracks · ${summary.tracks_with_findings} with findings · ${tracksWithTimingProblems} with TIMING problems`)
console.log(`coverage across flagged columns: see coverage_pct in detail`)
console.log('READ ONLY - nothing was written.')
