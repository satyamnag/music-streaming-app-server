// ============================================================================
// Render additional language columns from the AUTHORITATIVE Telugu timeline.
//
// All five lyric columns MUST share one cue timeline, or the apps' per-line
// language stacking drifts (a `{{Music}}` banner present only in Telugu would
// shift every later row in the other columns). So the timeline - cue count,
// kinds, start/end - comes from the Telugu `synced_lyrics` that is already
// verified in the database, and only the TEXT of each lyric cue is taken from
// the target column.
//
// This is exactly what libs/autoSyncLyrics.renderCuesForVariant does, and what
// the admin `POST /api/admin/tracks/:id/sync-variant` endpoint uses. Reusing it
// guarantees the renderer's invariants instead of re-implementing them.
//
// Run:
//   node server/tools/render-variant-sync.mjs --track <uuid> [--cols en,en_tr]
//                                             [--out-dir <dir>] [--emit-payload]
//
// Writes nothing to the database. It emits one SRT file per column plus (with
// --emit-payload) a JSON PATCH body for the write workflow to apply.
// ============================================================================

import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import {
  parseSrtTimeline,
  renderCuesForVariant,
  splitLyricLines,
  splitVariantLines,
  classifyLine,
  MUSIC_LABEL,
} from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : (process.argv[i + 1] ?? true)
}

const TRACK_ID = arg('track')
const COLS = String(arg('cols', 'en,en_tr')).split(',').map((s) => s.trim()).filter(Boolean)
const OUT_DIR = arg('out-dir', '.')
const EMIT_PAYLOAD = process.argv.includes('--emit-payload')

const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''
if (!TRACK_ID) { console.error('--track <uuid> required'); process.exit(2) }
if (!SUPA || !KEY) { console.error('SUPABASE_URL + key required'); process.exit(2) }

const COLUMN_TO_PLAIN = {
  en: 'plain_lyrics_en',
  en_tr: 'plain_lyrics_en_tr',
  hi: 'plain_lyrics_hi',
  hi_tr: 'plain_lyrics_hi_tr',
}
const COLUMN_TO_SYNCED = {
  en: 'synced_lyrics_en',
  en_tr: 'synced_lyrics_en_tr',
  hi: 'synced_lyrics_hi',
  hi_tr: 'synced_lyrics_hi_tr',
}

// --- Fetch ----------------------------------------------------------------
const select = ['id', 'title', 'duration', 'plain_lyrics', 'synced_lyrics',
  ...COLS.flatMap((c) => [COLUMN_TO_PLAIN[c], COLUMN_TO_SYNCED[c]])].join(',')
const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK_ID)}&select=${select}`, {
  headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
})
if (!res.ok) { console.error(`supabase ${res.status}: ${(await res.text()).slice(0, 300)}`); process.exit(2) }
const [track] = await res.json()
if (!track) { console.error('track not found'); process.exit(2) }

const teluguPlain = String(track.plain_lyrics || '')
const teluguSrt = String(track.synced_lyrics || '').trim()
if (!teluguPlain.trim()) { console.error('no plain_lyrics'); process.exit(2) }
if (!teluguSrt) { console.error('no synced_lyrics (Telugu timeline is required first)'); process.exit(2) }

const plainLines = splitLyricLines(teluguPlain)
const totalLines = plainLines.length
console.log(`track: ${track.title}  duration=${track.duration}s`)
console.log(`telugu timeline: ${totalLines} plain lines`)

// --- Rebuild cues from the verified Telugu SRT ----------------------------
const parsed = parseSrtTimeline(teluguSrt)
if (!parsed.length) { console.error('Telugu synced_lyrics produced no cues'); process.exit(2) }

// Telugu text -> line index in plain_lyrics (repeats reuse the same index).
const textToIndex = new Map()
plainLines.forEach((t, i) => {
  const k = String(t).trim()
  if (k && !textToIndex.has(k)) textToIndex.set(k, i)
})

const cues = []
const unmapped = []
for (const c of parsed) {
  const text = String(c.text || '').trim()
  if (text === MUSIC_LABEL) {
    cues.push({ kind: 'music', start: c.start, end: c.end, lineIndex: null, text })
    continue
  }
  if (textToIndex.has(text)) {
    cues.push({ kind: 'lyric', start: c.start, end: c.end, lineIndex: textToIndex.get(text), text })
    continue
  }
  // A cue whose text is not a plain line: keep the timeline row but let the
  // variant renderer fall back to the cue's own text, so no time is lost.
  unmapped.push(text)
  cues.push({ kind: 'lyric', start: c.start, end: c.end, lineIndex: null, text })
}
console.log(`rebuilt cues: ${cues.length} (lyric ${cues.filter((c) => c.kind === 'lyric').length}, music ${cues.filter((c) => c.kind === 'music').length})`)
if (unmapped.length) {
  console.error(`WARNING: ${unmapped.length} cue(s) not found in plain_lyrics: ${unmapped.slice(0, 3).join(' | ')}`)
}

// --- Render each requested column ----------------------------------------
const payload = {}
let failed = false

for (const col of COLS) {
  const plainCol = COLUMN_TO_PLAIN[col]
  const variantText = String(track[plainCol] || '')
  if (!variantText.trim()) {
    console.error(`SKIP ${col}: ${plainCol} is empty`)
    continue
  }

  const variantLines = splitVariantLines(variantText, totalLines)
  const rendered = renderCuesForVariant(cues, variantText, totalLines)
  const renderedCues = parseSrtTimeline(rendered)

  // ---- Validation: shared-timeline + structural invariants --------------
  const problems = []
  if (renderedCues.length !== cues.length) {
    problems.push(`cue count ${renderedCues.length} != timeline ${cues.length}`)
  }
  let overlap = 0
  let zero = 0
  let outOfRange = 0
  let dup = 0
  const starts = new Set()
  for (let i = 0; i < renderedCues.length; i++) {
    const c = renderedCues[i]
    if (c.end <= c.start) zero += 1
    if (i > 0 && c.start < renderedCues[i - 1].end - 1e-6) overlap += 1
    if (c.start < 0 || (track.duration && c.end > Number(track.duration) + 0.5)) outOfRange += 1
    if (starts.has(c.start)) dup += 1
    starts.add(c.start)
    // Times must be IDENTICAL to the Telugu timeline, index by index.
    const ref = cues[i]
    if (ref && (Math.abs(c.start - ref.start) > 1e-6 || Math.abs(c.end - ref.end) > 1e-6)) {
      problems.push(`cue ${i + 1} time drift vs Telugu`)
    }
  }
  if (overlap) problems.push(`${overlap} overlapping`)
  if (zero) problems.push(`${zero} zero-duration`)
  if (outOfRange) problems.push(`${outOfRange} out-of-range`)
  if (dup) problems.push(`${dup} duplicate starts`)

  // Every lyric cue must carry real text (no blank rows)
  const blank = renderedCues.filter((c) => !String(c.text || '').trim()).length
  if (blank) problems.push(`${blank} blank cue(s)`)

  // Coverage of distinct variant lines used
  const usedTexts = new Set(renderedCues.map((c) => String(c.text).trim()))
  const variantLyric = variantLines.filter((l) => classifyLine(String(l).trim()) === 'lyric')
  const covered = variantLyric.filter((l) => usedTexts.has(String(l).trim())).length

  const srtPath = path.join(OUT_DIR, `${TRACK_ID}-synced_${col}.srt`)
  fs.writeFileSync(srtPath, rendered, 'utf8')
  payload[COLUMN_TO_SYNCED[col]] = rendered

  console.log(`\n[${col}] ${plainCol}`)
  console.log(`  variant lines: ${variantLines.length} (lyric ${variantLyric.length})`)
  console.log(`  cues rendered: ${renderedCues.length}`)
  console.log(`  lyric lines covered: ${covered}/${variantLyric.length}`)
  console.log(`  problems: ${problems.length ? problems.join('; ') : 'NONE'}`)
  console.log(`  wrote ${srtPath} (${rendered.length} chars)`)
  if (problems.length) failed = true
}

if (EMIT_PAYLOAD) {
  const p = path.join(OUT_DIR, 'payload.json')
  fs.writeFileSync(p, JSON.stringify(payload, null, 2), 'utf8')
  console.log(`\nwrote ${p} (${Object.keys(payload).length} column(s))`)
}

if (failed) { console.error('\nVALIDATION FAILED - do not write.'); process.exit(1) }
console.log('\nVALIDATION PASSED - all columns share the Telugu timeline exactly.')
