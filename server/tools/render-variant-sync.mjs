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
  classifyLine,
} from '../libs/autoSyncLyrics.mjs'
import { variantBannerText, VARIANT_MUSIC_LABEL } from '../libs/musicBanner.mjs'

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

// --- Map each Telugu cue onto a plain-lyric row -----------------------------
// Four tiers, in order of how much they assume. The Telugu sync column and the
// Telugu plain column are authored separately and neither may be edited, so a cue is
// often not a byte-identical plain line even when it plainly IS that line:
//
//   1. the cue IS a plain line, ignoring whitespace                       -> whole line
//   2. the cue is the HEAD or the TAIL of a plain line, ignoring spaces   -> split
//   3. the cue is the head/tail of a plain line spelled slightly
//      differently (a dropped long vowel, a closed word gap, ...)        -> split
//   4. the cue CONTAINS a whole plain line (the sync carries extra words) -> whole line
//
// Measured in this catalogue: "రావమ్మ మహాలక్ష్మి" against the plain line
// "రావమ్మా మహలక్ష్మీ! రావమ్మా శ్రీ లక్ష్మీ!" (tier 3, two vowel lengths differ),
// "కలిలోన" against "కలి లోన" (tier 1), "మునిగి తేలే మాకు," against
// "మాయ కడలి లోన మునిగి  తేలే మాకు," (tier 2, the plain line has a double space).
const sq = (s) => String(s ?? '').replace(/\s+/g, '')

/** 1 - (Levenshtein distance / longer length). Small alphabet, short strings. */
function editRatio(a, b) {
  if (a === b) return 1
  const n = a.length
  const m = b.length
  if (!n || !m) return 0
  let prev = Array.from({ length: m + 1 }, (_, j) => j)
  const cur = new Array(m + 1)
  for (let i = 1; i <= n; i += 1) {
    cur[0] = i
    for (let j = 1; j <= m; j += 1) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
    }
    for (let j = 0; j <= m; j += 1) prev[j] = cur[j]
  }
  return 1 - prev[m] / Math.max(n, m)
}

/** Word boundaries of a plain line in whitespace-stripped offsets. */
function sqWords(text) {
  const words = String(text).match(/\S+/g) || []
  const out = []
  let at = 0
  for (const w of words) {
    const s = sq(w)
    out.push({ from: at, to: at + s.length })
    at += s.length
  }
  return out
}

// Only rows the classifier calls a lyric can be sung; headings and blank rows cannot.
const lyricRows = plainLines
  .map((line, i) => ({ i, text: String(line), sq: sq(line) }))
  .filter((r) => r.text.trim() && classifyLine(r.text.trim()) === 'lyric')
  .map((r) => ({ ...r, words: sqWords(r.text) }))

const MIN_FUZZY = 0.72

/**
 * The cue text with the author's own ANNOTATIONS removed - a trailing parenthetical note
 * and a trailing ellipsis. Neither is sung and neither appears in the plain column, so
 * they make an otherwise exact cue look unmappable:
 *
 *   * `రావమ్మ శ్రీలక్ష్మి (రా...)` - the parenthetical records what the singer repeats;
 *   * `రమణా!...`                   - the ellipsis records a held vowel.
 *
 * Only the MATCHING text is stripped; the emitted text always comes from the plain
 * columns, so no annotation can leak into a variant column.
 */
function forMatch(text) {
  return String(text ?? '')
    .replace(/\s*[(\uFF08][^()\uFF08\uFF09]*[)\uFF09]\s*$/, '')
    .replace(/\s*[.\u2026]{2,}\s*$/, '')
    .trim()
}

/**
 * Shortest cue, in whitespace-stripped characters, that may be mapped to a SLICE of a
 * plain line. Below it a "match" is meaningless: the cue "రా..." reduces to "రా", which
 * occurs inside dozens of Telugu words, and matching it produced the nonsense cue
 * "In" / "Ramuni" on Ramuni Keerthi. A too-short cue is reported instead of guessed.
 */
const MIN_SLICE_CUE = 4

/**
 * Resolve one cue's text to `{ lineIndex, piece }`, where `piece` is null for a whole
 * line and `{ from, to, total, beforeFrom, beforeTo }` for a SLICE of a line (offsets
 * are whitespace-stripped character offsets into the plain line).
 *
 * A slice can be the head, the tail or the MIDDLE: the owner's timeline splits some
 * plain lines into three or more cues (measured on Madhava Mukundha, "శ్రీధర,  శ్రీకర,
 * శ్రీవేంకట రమణా!" becomes three cues), and a head/tail-only model drops the middle.
 *
 * [near] is the line index the previous cue resolved to. It only breaks ties: several
 * plain lines can contain the same short phrase, and the cue sequence walks the lyric
 * in order, so the nearest candidate is the right one.
 *
 * Returns null when nothing safe can be said - never a guess.
 */
function resolveCue(text, near = -1) {
  const s = sq(forMatch(text))
  if (!s) return null

  const pick = (cands) => {
    const base = Math.max(near, 0)
    let best = null
    for (const c of cands) {
      // Distance to the line the previous cue resolved to, with a small penalty for
      // stepping BACKWARDS: the lyric mostly walks forward, but a refrain legitimately
      // returns to line 1 right after line 2 (measured on Rama Naamamu Madhuramu, where
      // punishing a backward step at all cost sent "రామ నామము" to line 28).
      const d = Math.abs(c.row.i - base) + (c.row.i < base ? 0.5 : 0)
      if (best === null || d < best.d - 1e-9
        || (Math.abs(d - best.d) < 1e-9 && c.row.i < best.c.row.i)) {
        best = { d, c }
      }
    }
    return best === null ? null : best.c
  }

  // 1 & 2. a whole plain line, or a slice of one, ignoring whitespace
  const exact = lyricRows
    .filter((r) => r.sq.includes(s))
    .map((r) => ({ row: r, tier: r.sq === s ? 1 : 2, at: r.sq.indexOf(s) }))
  if (exact.length) {
    const whole = exact.filter((c) => c.tier === 1)
    if (!whole.length && s.length < MIN_SLICE_CUE) return null
    const c = pick(whole.length ? whole : exact)
    const from = c.at
    const to = c.at + s.length
    if (from === 0 && to >= c.row.sq.length) return { lineIndex: c.row.i, piece: null }
    return {
      lineIndex: c.row.i,
      piece: { from, to, total: c.row.sq.length,
        beforeFrom: c.row.sq.slice(0, from), beforeTo: c.row.sq.slice(0, to) },
    }
  }

  // 3. a slice of one line, spelled slightly differently
  let best = null
  for (const r of lyricRows) {
    for (let a = 0; a < r.words.length; a += 1) {
      let acc = ''
      for (let b = a; b < r.words.length; b += 1) {
        acc += r.sq.slice(r.words[b].from, r.words[b].to)
        const ratio = editRatio(s, acc)
        if (ratio < MIN_FUZZY) continue
        // Prefer a slice that touches an end of the line, then the best ratio.
        const touches = a === 0 || b === r.words.length - 1
        const score = ratio + (touches ? 0.05 : 0)
        if (best === null || score > best.score + 1e-9) {
          best = { score, r, from: r.words[a].from, to: r.words[b].to }
        }
      }
    }
  }
  if (best) {
    if (best.from === 0 && best.to >= best.r.sq.length) return { lineIndex: best.r.i, piece: null }
    return {
      lineIndex: best.r.i,
      piece: { from: best.from, to: best.to, total: best.r.sq.length,
        beforeFrom: best.r.sq.slice(0, best.from), beforeTo: best.r.sq.slice(0, best.to) },
    }
  }

  // 4. the cue CONTAINS a whole plain line - the sync carries extra words, so the
  //    whole line's translation is the closest thing that exists for it.
  let container = null
  for (const r of lyricRows) {
    if (!r.sq || r.sq.length < 0.5 * s.length) continue
    if (!s.includes(r.sq)) continue
    if (container === null || r.sq.length > container.sq.length) container = r
  }
  if (container) return { lineIndex: container.i, piece: null }

  return null
}

const cues = []
const unmapped = []
let lastLine = -1
for (const c of parsed) {
  const text = String(c.text || '').trim()
  // A music banner is written either in the canonical `{{Music}}` form or in the
  // banner's own note glyphs (`♪ Music ♪`, and `♪ సంగీతం ♪` in a localized column).
  // Both app parsers accept either spelling, so the banner must be recognised here
  // too: left unrecognised it matches no plain line, falls through to the unmapped
  // fallback and puts Telugu text into the English columns. The text emitted for a
  // banner is language-safe by construction - see libs/musicBanner.mjs.
  const banner = variantBannerText(text)
  if (banner !== null) {
    cues.push({ kind: 'music', start: c.start, end: c.end, lineIndex: null, text: banner })
    continue
  }
  const hit = resolveCue(text, lastLine)
  if (hit) {
    lastLine = hit.lineIndex
    cues.push({ kind: 'lyric', start: c.start, end: c.end, lineIndex: hit.lineIndex,
      piece: hit.piece, text })
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
 * The slice of the variant line that corresponds to a sliced cue, cut at a punctuation
 * mark when the Telugu boundary is at punctuation, otherwise at the word boundary
 * nearest the same relative position. Never guesses: null when no usable cut exists, and
 * the caller then reports the cue instead of emitting something wrong.
 */
function splitVariantForCue(piece, rowVariant) {
  const v = String(rowVariant)
  if (!piece || !v.trim()) return null
  const vEnd = v.replace(/\s+$/, '').length
  const total = piece.total || 1
  // Both cuts come from the same pure function, so a boundary shared by two cues yields
  // one position: measured on "శ్రీవేంకటేశ్వరుని సర్వదర్శనం" against "A complete vision of
  // Lord Sri Venkateswara.", cutting each side independently gave "...of Lord" and
  // "Venkateswara." and the word "Sri" was emitted by neither cue.
  const left = piece.from <= 0 ? 0 : variantCut(piece.beforeFrom, v, piece.from / total)
  const right = piece.to >= total ? vEnd : variantCut(piece.beforeTo, v, piece.to / total)
  if (left === null || right === null) return null
  if (!(left < right)) return null
  return v.slice(left, right).trim() || null
}

/**
 * Where to cut the variant line for a split at relative position [f].
 *
 * Pure: the same boundary always yields the same cut, which is what keeps a head and its
 * tail consistent. Measured on "శ్రీవేంకటేశ్వరుని సర్వదర్శనం" against "A complete vision
 * of Lord Sri Venkateswara.": deciding each side separately gave the head "...of Lord"
 * and the tail "Venkateswara.", so the word "Sri" was emitted by neither cue.
 * Returns null when no usable cut exists.
 */
function variantCut(teBefore, v, f) {
  const vEnd = v.replace(/\s+$/, '').length
  let cut
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
      // The LAST word end is a legitimate cut: a slice that runs to the end of the Telugu
      // line ends with the last word of the variant too, and refusing it dropped the
      // final word of every such slice (measured on Vedu Vaarike).
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
  if (!(cut >= 0 && cut <= vEnd)) return null
  return cut
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

  // Align this column to the Telugu plain column by LYRIC ORDINAL, not by raw line index.
  //
  // The columns are line-parallel by contract, so the two agree whenever the column is
  // well formed. They stop agreeing as soon as one column carries an extra or missing
  // BLANK line: measured on Sukha Madhuvu Kadalilo, where `plain_lyrics_en_tr` had one
  // blank too many after `{Charanam 4}` and every row of the last stanza was therefore
  // read one line off - structurally valid, silently wrong text. Blank rows and `{...}`
  // headings carry no sung text at all, so counting only the lyric rows restores the
  // intended mapping.
  //
  // The gate is the count: if the two columns do not hold the same number of LYRIC lines
  // then a sung line really is missing or duplicated, the ordinal is meaningless, and the
  // column is refused instead of being guessed at. That is what makes the ordinal safe.
  const variantLines = splitLyricLines(variantText)
  const variantLyricRows = []
  variantLines.forEach((l, i) => { if (classifyLine(l) === 'lyric') variantLyricRows.push(i) })
  const teluguLyricRows = []
  plainLines.forEach((l, i) => { if (classifyLine(String(l).trim()) === 'lyric') teluguLyricRows.push(i) })
  const variantForPlain = new Map()
  teluguLyricRows.forEach((pi, ord) => variantForPlain.set(pi, variantLyricRows[ord]))
  const rowOf = (plainIndex) => {
    const r = variantForPlain.get(plainIndex)
    return r === undefined ? '' : String(variantLines[r] || '')
  }
  const countProblem = variantLyricRows.length === teluguLyricRows.length
    ? null
    : `${plainCol} holds ${variantLyricRows.length} lyric line(s) but plain_lyrics holds `
      + `${teluguLyricRows.length} - a sung line is missing or duplicated, so no cue can be `
      + `matched to it safely`

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
      // The banner a variant column carries: `{{ Music }}`, never the Telugu
      // author marker - see VARIANT_MUSIC_LABEL in libs/musicBanner.mjs.
      text = String(c.text || VARIANT_MUSIC_LABEL).trim()
    } else if (c.piece) {
      text = splitVariantForCue(c.piece, rowOf(c.lineIndex))
      if (!text) missingPieces.push(c.text)
    } else if (c.lineIndex !== null && c.lineIndex !== undefined) {
      text = rowOf(c.lineIndex).trim()
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
  if (countProblem) problems.push(countProblem)
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
  // A variant cue is only "out of range" if it runs past BOTH the stored duration and
  // the Telugu timeline it mirrors. The audio routinely ends a fraction past the
  // integer `duration` column (e.g. 284.52s of audio against duration=284), and the
  // Telugu column is the authority on where the song actually ends - so judging the
  // variants by the integer alone would reject a correct timeline.
  const teluguEnd = cues.length ? cues[cues.length - 1].end : 0
  const rangeLimit = Math.max(Number(track.duration) || 0, teluguEnd)
  for (let i = 0; i < renderedCues.length; i++) {
    const c = renderedCues[i]
    if (c.end <= c.start) zero += 1
    if (i > 0 && c.start < renderedCues[i - 1].end - 1e-6) overlap += 1
    if (c.start < 0 || (rangeLimit && c.end > rangeLimit + 0.5)) outOfRange += 1
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

  // Coverage: how many of this column's lyric rows are actually carried by a cue.
  const cuedPlain = new Set(cues.filter((c) => c.kind === 'lyric' && c.lineIndex !== null
    && c.lineIndex !== undefined).map((c) => c.lineIndex))
  const covered = teluguLyricRows.filter((pi) => cuedPlain.has(pi) && rowOf(pi).trim()).length
  const variantLyric = teluguLyricRows

  const srtPath = path.join(OUT_DIR, `${TRACK_ID}-synced_${col}.srt`)
  fs.writeFileSync(srtPath, rendered, 'utf8')
  payload[COLUMN_TO_SYNCED[col]] = rendered

  console.log(`\n[${col}] ${plainCol}`)
  console.log(`  column lines: ${variantLines.length} (lyric ${variantLyricRows.length})`)
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
