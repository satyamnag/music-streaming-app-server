// ============================================================================
// OpenAI "second opinion" for lyric <-> transcript correspondence.
//
// WHY THIS EXISTS
// ---------------
// The deterministic aligner matches akshara bigrams. On singing that leaves two
// failures the admin sees as "unplaced lines":
//   * a word is split or merged across beats, so no single transcript word
//     clears the 0.5 similarity bar against any lyric word;
//   * a transliterated or re-spelled form (`వెలగేటి` sung as `వెలిగేటి`) scores
//     below the bar even though a human reads them as the same line.
//
// A language model reads both sides and says WHICH measured segment sings WHICH
// line. That is a correspondence judgement, not a timing measurement.
//
// WHAT THIS FILE WILL NEVER DO
// ----------------------------
// It cannot create time. Every timestamp it returns is the measured start/end of
// an existing transcript segment, produced by Deepgram from the actual audio.
// The model only chooses among those measured spans; it is never asked to
// invent seconds, and its answer is only used for lines that are currently
// UNPLACED. A wrong-but-plausible timestamp is worse than a missing one, which
// is why anything this adds is emitted at low confidence and stays flagged for
// human review.
//
// FAIL-CLOSED CONTRACT
// --------------------
// `secondOpinionPicks` never throws. Network failure, timeout, refusal,
// malformed JSON, a schema-violating answer or an out-of-range index all degrade
// to `{ ok: false }`, and the caller then behaves exactly as it did before this
// feature existed. Nothing here can block or corrupt the deterministic path.
// ============================================================================

/** Cheapest current model that supports Strict Structured Outputs. */
export const OPENAI_DEFAULT_MODEL = 'gpt-4o-mini'

/**
 * A transcript segment is a run of consecutive words with no silent gap inside.
 *
 * 2.5 s is above the longest breath inside a sung line and below a real
 * interlude, so a segment normally corresponds to one sung phrase.
 */
export const DEFAULT_SEGMENT_GAP_SECONDS = 2.5

/** Minimum model agreement before an unplaced line is given a position. */
export const DEFAULT_MIN_AGREEMENT = 0.7

/** Structured-output schema. `strict: true` makes the model unable to drift. */
const PICKS_SCHEMA = {
  type: 'object',
  properties: {
    picks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          line_index: { type: 'integer' },
          segment_index: { type: 'integer' },
          agreement: { type: 'number' },
          reason: { type: 'string' },
        },
        required: ['line_index', 'segment_index', 'agreement', 'reason'],
        additionalProperties: false,
      },
    },
  },
  required: ['picks'],
  additionalProperties: false,
}

const SYSTEM_PROMPT =
  'You match Telugu lyric lines to transcript segments produced by speech recognition ' +
  'of singing. Singing merges, splits and mishears words, so compare by sound and by ' +
  'meaning, not by exact spelling. Answer with segment indices from the transcript only. ' +
  'Never invent a segment index that was not supplied. Use -1 when no segment sings that line.'

/** Build the user message. Deterministic formatting keeps answers reproducible. */
function buildUserMessage(lines, segments) {
  const lyricBlock = lines.map((l) => `${l.index}: ${l.text}`).join('\n')
  const segBlock = segments
    .map((s) => `${s.index}: [${s.start.toFixed(2)}] ${s.text}`)
    .join('\n')
  return (
    'Match every lyric line to the transcript segment that sings it.\n' +
    'Return one pick per lyric line. agreement is 0..1: how sure you are that this ' +
    'segment sings this line. segment_index = -1 when nothing plausibly does.\n\n' +
    `LYRIC LINES:\n${lyricBlock}\n\nTRANSCRIPT SEGMENTS:\n${segBlock}`
  )
}

/**
 * Group transcript words into sung segments.
 *
 * @param {Array<{word:string,start:number,end:number}>} words
 * @param {number} gapSeconds
 * @returns {Array<{index:number,start:number,end:number,text:string}>}
 */
export function segmentTranscript(words, gapSeconds = DEFAULT_SEGMENT_GAP_SECONDS) {
  const ordered = (Array.isArray(words) ? words : [])
    .filter((w) => w && typeof w.start === 'number' && typeof w.end === 'number')
    .slice()
    .sort((a, b) => a.start - b.start)

  const segments = []
  let current = null
  for (const w of ordered) {
    if (!current || w.start - current.end > gapSeconds) {
      current = { start: w.start, end: w.end, words: [] }
      segments.push(current)
    }
    current.words.push(String(w.word || '').trim())
    current.end = Math.max(current.end, w.end)
  }

  return segments
    .map((s, i) => ({
      index: i,
      start: s.start,
      end: s.end,
      text: s.words.filter(Boolean).join(' ').trim(),
    }))
    .filter((s) => s.text)
}

/** Pull the JSON string out of a Responses payload, or null if there is none. */
export function extractOutputText(payload) {
  for (const item of payload?.output || []) {
    if (item?.type !== 'message') continue
    for (const part of item.content || []) {
      if (part?.type === 'refusal') return { refusal: String(part.refusal || '') }
      if (part?.type === 'output_text' && typeof part.text === 'string') return { text: part.text }
    }
  }
  return {}
}

/**
 * Validate the model's answer against what WE asked about.
 *
 * A schema-conforming answer can still be nonsense: a line index that was never
 * sent, a segment index from another song, agreement of 42. Every one of those is
 * dropped rather than trusted.
 */
export function validatePicks(raw, { lineCount, segmentCount }) {
  let parsed
  try { parsed = typeof raw === 'string' ? JSON.parse(raw) : raw } catch { return [] }
  const list = Array.isArray(parsed?.picks) ? parsed.picks : []
  const seen = new Set()
  const out = []
  for (const p of list) {
    const line = Number(p?.line_index)
    const seg = Number(p?.segment_index)
    let agreement = Number(p?.agreement)
    if (!Number.isInteger(line) || line < 0 || line >= lineCount) continue
    if (!Number.isInteger(seg) || seg < -1 || seg >= segmentCount) continue
    if (!Number.isFinite(agreement)) continue
    agreement = Math.max(0, Math.min(1, agreement))
    if (seen.has(line)) continue
    seen.add(line)
    out.push({ lineIndex: line, segmentIndex: seg, agreement, reason: String(p?.reason || '').slice(0, 200) })
  }
  return out.sort((a, b) => a.lineIndex - b.lineIndex)
}

/**
 * Ask the model which measured segment sings which line.
 *
 * @returns {Promise<{ok:boolean, reason:string|null, picks:Array, model:string, elapsed_ms:number}>}
 *          Never rejects.
 */
export async function secondOpinionPicks({
  apiKey,
  lines,
  segments,
  model = OPENAI_DEFAULT_MODEL,
  baseUrl = 'https://api.openai.com',
  timeoutMs = 45000,
}) {
  const startedAt = Date.now()
  const done = (ok, reason, picks = []) => ({
    ok, reason, picks, model, elapsed_ms: Date.now() - startedAt,
  })

  if (!apiKey) return done(false, 'no_api_key')
  if (!Array.isArray(lines) || !lines.length) return done(false, 'no_lyric_lines')
  if (!Array.isArray(segments) || !segments.length) return done(false, 'no_segments')

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const res = await fetch(`${baseUrl}/v1/responses`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        temperature: 0,
        max_output_tokens: 2000,
        input: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: buildUserMessage(lines, segments) },
        ],
        text: { format: { type: 'json_schema', name: 'lyric_picks', strict: true, schema: PICKS_SCHEMA } },
      }),
      signal: controller.signal,
    })

    if (!res.ok) {
      // The body may contain a reason; keep it short and never echo the key.
      const detail = await res.text().catch(() => '')
      return done(false, `http_${res.status}${detail ? `: ${detail.slice(0, 160)}` : ''}`)
    }

    const payload = await res.json()
    const { text, refusal } = extractOutputText(payload)
    if (refusal) return done(false, 'model_refusal')
    if (!text) return done(false, 'no_output_text')

    const picks = validatePicks(text, { lineCount: lines.length, segmentCount: segments.length })
    if (!picks.length) return done(false, 'no_valid_picks')
    return done(true, null, picks)
  } catch (err) {
    const aborted = err && (err.name === 'AbortError' || err.code === 'ABORT_ERR')
    return done(false, aborted ? 'timeout' : `request_failed: ${String(err && err.message).slice(0, 120)}`)
  } finally {
    clearTimeout(timer)
  }
}

/**
 * Apply the picks to an alignment result, IN PLACE, for UNPLACED lines only.
 *
 * Guarantees:
 *   * a line that the deterministic aligner already placed is never moved;
 *   * the assigned time is the measured segment's own start/end;
 *   * the resulting confidence is capped low (the model's agreement is evidence
 *     about correspondence, not about millisecond accuracy), so the line stays
 *     in the review list.
 *
 * @returns {{ placed:number, considered:number }}
 */
export function applySecondOpinion(alignment, picks, segments, {
  minAgreement = DEFAULT_MIN_AGREEMENT,
  maxConfidence = 0.5,
} = {}) {
  const byIndex = new Map(segments.map((s) => [s.index, s]))
  let placed = 0
  let considered = 0

  for (const pick of picks || []) {
    if (pick.segmentIndex < 0) continue
    if (pick.agreement < minAgreement) continue
    const target = (alignment?.lines || []).find((l) => l.lineIndex === pick.lineIndex)
    if (!target) continue
    // Never move a line the deterministic aligner measured.
    if (target.startSeconds !== null && target.startSeconds !== undefined) continue
    const seg = byIndex.get(pick.segmentIndex)
    if (!seg) continue

    considered += 1
    target.startSeconds = seg.start
    target.endSeconds = seg.end
    target.confidence = Math.min(maxConfidence, Math.round(pick.agreement * maxConfidence * 10000) / 10000)
    target.llmAssisted = true
    target.llmAgreement = pick.agreement
    placed += 1
  }

  return { placed, considered }
}

// ============================================================================
// Line mapping between a Telugu column and its translation
// ============================================================================
//
// The translation of a song is not always line-parallel: a translator may merge
// two Telugu lines into one English sentence, or split one line into two. The
// positional renderer (`splitVariantLines`) then puts the wrong text on a cue, or
// silently truncates the tail.
//
// This asks the model for the CORRESPONDENCE only - "which English line
// translates Telugu line N" - which is a text task with no audio involved. Times
// are never requested: the timeline still comes from the Telugu sync lyrics.
//
// Fail-closed: any error returns `{ ok: false, map: null }` and the caller falls
// back to positional mapping, i.e. exactly today's behaviour.

const MAP_SCHEMA = {
  type: 'object',
  properties: {
    map: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          telugu_index: { type: 'integer' },
          target_index: { type: 'integer' },
        },
        required: ['telugu_index', 'target_index'],
        additionalProperties: false,
      },
    },
  },
  required: ['map'],
  additionalProperties: false,
}

const MAP_SYSTEM_PROMPT =
  'You map song lyric lines between a source language and its translation. ' +
  'A translation may MERGE several source lines into one target line, or SPLIT one ' +
  'source line across several. Return, for every source line index, the target line ' +
  'index that translates it, or -1 when the target has no translation for it. ' +
  'Use only indices that were supplied. Never invent text.'

/** Normalise a model answer into a dense array of length `teluguCount`. */
export function validateLineMap(raw, { teluguCount, targetCount }) {
  let parsed
  try { parsed = typeof raw === 'string' ? JSON.parse(raw) : raw } catch { return null }
  const list = Array.isArray(parsed?.map) ? parsed.map : null
  if (!list) return null

  const map = new Array(teluguCount).fill(-1)
  let used = 0
  for (const entry of list) {
    const t = Number(entry?.telugu_index)
    const g = Number(entry?.target_index)
    if (!Number.isInteger(t) || t < 0 || t >= teluguCount) continue
    if (!Number.isInteger(g) || g < -1 || g >= targetCount) continue
    if (map[t] !== -1) continue          // first answer wins
    map[t] = g
    if (g >= 0) used += 1
  }
  // A map that translates nothing is not better than the positional default.
  if (!used) return null
  return map
}

/**
 * Ask the model which target line translates each source line.
 *
 * @returns {Promise<{ok:boolean, reason:string|null, map:number[]|null, model:string, elapsed_ms:number}>}
 *          Never rejects.
 */
export async function mapTranslationLines({
  apiKey,
  teluguLines,
  targetLines,
  model = OPENAI_DEFAULT_MODEL,
  baseUrl = 'https://api.openai.com',
  timeoutMs = 45000,
}) {
  const startedAt = Date.now()
  const done = (ok, reason, map = null) => ({ ok, reason, map, model, elapsed_ms: Date.now() - startedAt })

  if (!apiKey) return done(false, 'no_api_key')
  if (!Array.isArray(teluguLines) || !teluguLines.length) return done(false, 'no_source_lines')
  if (!Array.isArray(targetLines) || !targetLines.length) return done(false, 'no_target_lines')

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const src = teluguLines.map((l, i) => `${i}: ${l}`).join('\n')
    const tgt = targetLines.map((l, i) => `${i}: ${l}`).join('\n')
    const res = await fetch(`${baseUrl}/v1/responses`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        temperature: 0,
        max_output_tokens: 2000,
        input: [
          { role: 'system', content: MAP_SYSTEM_PROMPT },
          { role: 'user', content: `SOURCE LINES:\n${src}\n\nTARGET LINES:\n${tgt}` },
        ],
        text: { format: { type: 'json_schema', name: 'line_map', strict: true, schema: MAP_SCHEMA } },
      }),
      signal: controller.signal,
    })
    if (!res.ok) {
      const detail = await res.text().catch(() => '')
      return done(false, `http_${res.status}${detail ? `: ${detail.slice(0, 160)}` : ''}`)
    }
    const payload = await res.json()
    const { text, refusal } = extractOutputText(payload)
    if (refusal) return done(false, 'model_refusal')
    if (!text) return done(false, 'no_output_text')

    const map = validateLineMap(text, { teluguCount: teluguLines.length, targetCount: targetLines.length })
    if (!map) return done(false, 'no_valid_map')
    return done(true, null, map)
  } catch (err) {
    const aborted = err && (err.name === 'AbortError' || err.code === 'ABORT_ERR')
    return done(false, aborted ? 'timeout' : `request_failed: ${String(err && err.message).slice(0, 120)}`)
  } finally {
    clearTimeout(timer)
  }
}
