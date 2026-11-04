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
  formatSrtTime,
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
// Read the Telugu timeline from a local SRT instead of the database. Used by the
// catalogue orchestrator, which renders the variants BEFORE anything is written.
const TIMELINE_FILE = arg('timeline-file', null)

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
const teluguSrt = TIMELINE_FILE
  ? String(fs.readFileSync(TIMELINE_FILE, 'utf8')).trim()
  : String(track.synced_lyrics || '').trim()
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
const ANY_MARKER = /^\{\{.*\}\}$/
for (const c of parsed) {
  const text = String(c.text || '').trim()
  // Any {{...}} marker is a music banner. The owner may write `{{♪ Music ♪}}`; it is
  // mirrored into the variants verbatim so all three columns carry the SAME text for
  // the same row (the apps stack languages per row).
  if (ANY_MARKER.test(text)) {
    cues.push({ kind: 'music', start: c.start, end: c.end, lineIndex: null, text })
    continue
  }
  if (textToIndex.has(text)) {
    cues.push({ kind: 'lyric', start: c.start, end: c.end, lineIndex: textToIndex.get(text), text })
    continue
  }
  // A cue that is only PART of a plain line (the Telugu timeline may split one plain
  // line into two cues, e.g. "రమ్య గుణ ధామా," + "శ్రీరామ చంద్రా,"). Find the row that
  // contains it so the variant line can be split at the matching point.
  const holders = []
  plainLines.forEach((line, i) => {
    const at = String(line).indexOf(text)
    if (at >= 0 && String(line).trim() !== text) holders.push({ i, at })
  })
  if (holders.length) {
    cues.push({ kind: 'lyric', start: c.start, end: c.end, lineIndex: holders[0].i, piece: text, text })
    continue
  }
  // A cue whose text is not a plain line: keep the timeline row but let the
  // variant renderer fall back to the cue's own text, so no time is lost.
  unmapped.push(text)
  cues.push({ kind: 'lyric', start: c.start, end: c.end, lineIndex: null, text })
}
console.log(`rebuilt cues: ${cues.length} (lyric ${cues.filter((c) => c.kind === 'lyric').length}, music ${cues.filter((c) => c.kind === 'music').length}, ` +
  `sub-line pieces ${cues.filter((c) => c.piece).length})`)
if (unmapped.length) {
  console.error(`WARNING: ${unmapped.length} cue(s) not found in plain_lyrics: ${unmapped.slice(0, 3).join(' | ')}`)
}

// --- Split a variant line where the Telugu timeline splits the plain line ------
const FUNCTION_WORDS = /^(of|the|a|an|in|to|towards|with|and|or|for|on|at|by|from|o)$/i

/**
 * The Telugu cue covers [at, at+len) of its plain line. Return the piece of the variant
 * line that corresponds to it, split at a punctuation mark when the Telugu split is at
 * punctuation, otherwise at the word boundary nearest the same relative position.
 * Returns null when the cue is a middle fragment (not supported, never guessed).
 */
function splitVariantForCue(rowTe, rowVariant, piece) {
  const te = String(rowTe)
  const v = String(rowVariant)
  const at = te.indexOf(piece)
  if (at < 0 || !v.trim()) return null
  const end = at + piece.length
  const isPrefix = at === 0
  const isSuffix = end >= te.replace(/\s+$/, '').length
  if (!isPrefix && !isSuffix) return null
  const splitTe = isPrefix ? end : at
  const f = te.length ? splitTe / te.length : 0

  let cut
  const vEnd = v.replace(/\s+$/, '').length
  const teBefore = te.slice(0, splitTe).replace(/\s+$/, '')
  if (/[,!?;:]$/.test(teBefore)) {
    // A punctuation mark that is the LAST character cannot be the split point: the piece
    // after it would be empty (measured: "సౌశీల్య రామా," against "All-powerful Rama of
    // noble character," whose only comma is final).
    const marks = []
    for (let i = 0; i < vEnd - 1; i += 1) if (/[,!?;:]/.test(v[i])) marks.push(i + 1)
    if (marks.length) {
      const target = f * v.length
      cut = marks.reduce((a, b) => (Math.abs(b - target) < Math.abs(a - target) ? b : a))
    }
  }
  if (cut === undefined) {
    const words = [...v.matchAll(/\S+/g)]
    const target = f * v.length
    let best = null
    let bestD = Infinity
    for (const m of words) {
      const b = m.index + m[0].length
      if (b >= v.replace(/\s+$/, '').length) continue
      const d = Math.abs(b - target)
      if (d < bestD) { bestD = d; best = b }
    }
    if (best === null) return null
    cut = best
    // Do not leave a dangling function word at the end of the left piece.
    const left = v.slice(0, cut).trim().split(/\s+/)
    if (left.length > 1 && FUNCTION_WORDS.test(left[left.length - 1].replace(/[,!?;:]+$/, ''))) {
      const prev = [...v.slice(0, cut).replace(/\s+$/, '').matchAll(/\S+/g)]
      if (prev.length > 1) cut = prev[prev.length - 2].index + prev[prev.length - 2][0].length
    }
  }
  if (!(cut > 0 && cut < vEnd)) return null
  const out = isPrefix ? v.slice(0, cut) : v.slice(cut)
  return out.trim() || null
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
  // Render the SAME cue list, taking each cue's text from this column. A cue that is
  // only part of a plain line gets the corresponding part of this column's line; a music
  // banner is mirrored verbatim. Rendering here (instead of calling
  // renderCuesForVariant) is what makes sub-line cues possible; the shared-timeline
  // invariant is still enforced by the validation below, which compares every cue's
  // start/end against the Telugu timeline index by index.
  const blocks = []
  const missingPieces = []
  for (const c of cues) {
    let text
    if (c.kind === 'music') {
      text = String(c.text || MUSIC_LABEL).trim()
    } else if (c.piece) {
      text = splitVariantForCue(plainLines[c.lineIndex], variantLines[c.lineIndex], c.piece)
      if (!text) missingPieces.push(c.piece)
    } else if (c.lineIndex !== null && c.lineIndex !== undefined) {
      text = String(variantLines[c.lineIndex] || '').trim()
    } else {
      text = String(c.text || '').trim()
    }
    if (!text) continue
    blocks.push(`${blocks.length + 1}\n${formatSrtTime(c.start)} --> ${formatSrtTime(c.end)}\n${text}`)
  }
  const rendered = blocks.join('\n\n') + (blocks.length ? '\n' : '')
  const renderedCues = parseSrtTimeline(rendered)

  // ---- Validation: shared-timeline + structural invariants --------------
  const problems = []
  if (renderedCues.length !== cues.length) {
    problems.push(`cue count ${renderedCues.length} != timeline ${cues.length}`)
  }
  if (missingPieces.length) {
    problems.push(`${missingPieces.length} sub-line cue(s) could not be split out of this column: ${missingPieces.slice(0, 2).join(' | ')}`)
  }
  // HARD GUARD: no Telugu script may survive into a translation/transliteration column.
  // The old fallback (use the cue's own text when it maps to no plain line) is how Telugu
  // text used to leak into the English columns; refuse instead of shipping it.
  const teluguLeaks = renderedCues.filter((c) => /[\u0C00-\u0C7F]/.test(String(c.text || '')))
  if (teluguLeaks.length) {
    problems.push(`${teluguLeaks.length} cue(s) still contain Telugu script, e.g. ${JSON.stringify(String(teluguLeaks[0].text).slice(0, 40))}`)
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
  const variantLyric = variantLines.filter((l) => classifyLine(String(l).trim()) === 'lyric')
  // A plain line counts as covered when at least one cue carries it, whole or as a piece.
  const coveredIdx = new Set(cues.filter((c) => c.kind === 'lyric' && c.lineIndex !== null
    && c.lineIndex !== undefined).map((c) => c.lineIndex))
  const covered = variantLyric.filter((_, i) => {
    const rowIndex = variantLines.indexOf(variantLyric[i])
    return coveredIdx.has(rowIndex)
  }).length

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
