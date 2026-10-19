// ============================================================================
// Deterministic lyric <-> transcript aligner for the admin "Auto-Sync Lyrics"
// feature.
//
// WHY THIS FILE EXISTS
// --------------------
// Deepgram's /v1/listen returns word-level timestamps, but it RE-TRANSCRIBES:
// it tells us what it believes it heard and when. It does NOT align a known
// script to audio (there is no forced-alignment parameter on the Listen API).
// So the transcript must be matched back onto the author's exact `plain_lyrics`
// lines ourselves. That matching is done here, deterministically, with no LLM
// and no randomness: the same transcript + the same lyrics always produce the
// same timings and the same confidence scores.
//
// WHY IT REFUSES RATHER THAN GUESSES
// ----------------------------------
// Singing is not speech: sustained vowels, elided consonants and percussive
// masking make ASR word timings materially less reliable than on speech. The
// honest contract is therefore:
//   * produce a timing for every lyric line,
//   * attach an independent per-line confidence,
//   * and let the caller (server.js) refuse to write anything unless EVERY
//     line clears the bar.
// A wrong-but-plausible timestamp silently written to the DB is far worse than
// no timestamp, so every uncertain path here degrades to "low confidence"
// rather than to "best guess".
// ============================================================================

// ---------------------------------------------------------------------------
// Script detection & normalisation
// ---------------------------------------------------------------------------

// Telugu block. Divided by 16 to keep the resulting weights small and exactly
// representable as float64 (so DP scores are bit-for-bit reproducible).
const TELUGU = /[\u0C00-\u0C7F]/

/** True when `s` contains at least one Telugu codepoint. */
export function isTelugu(s) {
  return TELUGU.test(String(s || ''))
}

/**
 * Normalise a word for comparison.
 *
 * Deliberately conservative: we strip punctuation and whitespace but KEEP the
 * script's own combining marks, because in Telugu (and Devanagari) a vowel sign
 * is a separate codepoint that carries meaning — removing it would turn two
 * different words into a false match.
 */
export function normaliseWord(raw) {
  return String(raw || '')
    .normalize('NFC')
    .toLowerCase()
    // Punctuation / symbols / whitespace. \p{L} and \p{M} are kept, so every
    // letter and every combining mark (vowel signs, virama, anusvara) survives.
    .replace(/[^\p{L}\p{M}\p{N}]/gu, '')
}

/**
 * Split a normalised word into aksharas (orthographic syllables).
 *
 * A consonant cluster is written C + virama + C..., so we group each base
 * letter with the viramas and vowel signs that follow it. This matters because
 * every Telugu word in a line tends to begin with the same handful of letters,
 * so comparing raw letters is almost information-free.
 */
function aksharas(normalised) {
  return Array.from(normalised).reduce((out, ch) => {
    const isMark = /\p{M}/u.test(ch)
    if (isMark && out.length) out[out.length - 1] += ch
    else out.push(ch)
    return out
  }, [])
}

/**
 * Similarity in [0, 1] between two words, by akshara bigram overlap (Dice).
 *
 * Why not exact equality: on singing, a long Telugu word is routinely split
 * across beats and transcribed as fragments, so exact matching scores real
 * hits as total misses. Why not first-letter matching: measured against the
 * real lyrics in migrations/002_lyrics.sql, `నిలువదు`, `నిముషము` and `నీ` all
 * begin with `న`, and `కల్ల`, `కాంక్షలతో` and `కేశవా` all begin with `క` — a
 * first-letter key makes every word in a line identical, which collapses the
 * alignment entirely.
 *
 * Bigrams of aksharas keep genuine fragments scoring high (`నిముషము` vs
 * `నిముష`) while separating different words (`నిముషము` vs `నిలువదు` -> 0).
 */
export function wordSimilarity(a, b) {
  const na = normaliseWord(a)
  const nb = normaliseWord(b)
  if (!na || !nb) return 0
  if (na === nb) return 1

  const grams = (n) => {
    const ak = aksharas(n)
    if (ak.length === 1) return [ak[0]]
    const out = []
    for (let i = 0; i < ak.length - 1; i++) out.push(ak[i] + ak[i + 1])
    return out
  }

  const ga = grams(na)
  const gb = grams(nb)
  if (!ga.length || !gb.length) return 0

  const pool = new Map()
  for (const g of gb) pool.set(g, (pool.get(g) || 0) + 1)
  let overlap = 0
  for (const g of ga) {
    const n = pool.get(g) || 0
    if (n > 0) { overlap++; pool.set(g, n - 1) }
  }
  return (2 * overlap) / (ga.length + gb.length)
}

/** At or above this, two words are treated as the same sung word. */
export const WORD_MATCH_THRESHOLD = 0.5

// ---------------------------------------------------------------------------
// Lyric markup
// ---------------------------------------------------------------------------

// Mirrors libs/lyricsMarkup.ts (web) and
// lib/modules/lyrics/lyrics_markup.dart (Android):
//   `{Section}`   -> a decorative heading / ornament divider
//   `{{Music}}`   -> a "music" banner
// These lines carry NO sung audio, so they must never consume an alignable
// transcript word. They are timed from their neighbours instead.
const MUSIC_LINE = /^\{\{.*\}\}$/
const SECTION_LINE = /^\{[^{}]*\}$/

/**
 * Split a `plain_lyrics*` column into significant lines.
 *
 * `plain_lyrics` is stored as line-separated text and is line-by-line parallel
 * across all five languages (libs/lyrics.ts and lib/provider/lyrics/synced.dart
 * both depend on that invariant), so the line index is shared by every
 * language column.
 */
export function splitLyricLines(text) {
  return String(text || '')
    .replace(/\r/g, '')
    .split('\n')
    .map((l) => l.trim())
}

/** True when a plain-lyrics line is a `{Section}` / `{{Music}}` marker. */
export function isMarkupLine(line) {
  const t = String(line || '').trim()
  return MUSIC_LINE.test(t) || SECTION_LINE.test(t)
}

/**
 * What kind of line is this?
 *
 *  - 'empty'    : blank separator, contributes a same-text row to every column
 *  - 'music'    : `{{Music}}` banner, unsung
 *  - 'section'  : `{Pallavi}` heading, unsung
 *  - 'lyric'    : real sung text, must be aligned
 */
export function classifyLine(line) {
  const t = String(line || '').trim()
  if (!t) return 'empty'
  if (MUSIC_LINE.test(t)) return 'music'
  if (SECTION_LINE.test(t)) return 'section'
  return 'lyric'
}

// ---------------------------------------------------------------------------
// Timestamp parsing / rendering
// ---------------------------------------------------------------------------

/** Parse `HH:MM:SS,mmm` / `HH:MM:SS.mmm` / `MM:SS.cc` into seconds, else null. */
export function parseTimecode(raw) {
  const s = String(raw || '').trim()
  let m = /^(\d{1,3}):(\d{2}):(\d{2})[.,](\d{1,3})$/.exec(s)
  if (m) {
    const frac = parseInt(m[4], 10) / Math.pow(10, m[4].length)
    return (+m[1]) * 3600 + (+m[2]) * 60 + (+m[3]) + frac
  }
  m = /^(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?$/.exec(s)
  if (m) {
    const frac = m[3] ? parseInt(m[3], 10) / Math.pow(10, m[3].length) : 0
    return (+m[1]) * 60 + (+m[2]) + frac
  }
  return null
}

/**
 * Render seconds as an LRC `[MM:SS.cc]` tag, matching formatLrcTime() in
 * admin.html so that a value round-trips through the existing editor unchanged.
 */
export function formatLrcTime(sec) {
  const s = Math.max(0, Number(sec) || 0)
  const totalCs = Math.round(s * 100)
  const pad = (n) => String(n).padStart(2, '0')
  return `${pad(Math.floor(totalCs / 6000))}:${pad(Math.floor((totalCs % 6000) / 100))}.${pad(totalCs % 100)}`
}

/**
 * Parse an LRC or SRT blob into `[{ time, text }]`, sorted by time.
 *
 * Needed for the "existing verified timing" check: a track whose current
 * `synced_lyrics` is already hand-timed must not be silently overwritten.
 */
export function parseTimedLyrics(raw) {
  const text = String(raw || '')
  if (!text.trim()) return []
  const out = []
  const seen = new Set()

  // SRT cue lines: `HH:MM:SS,mmm --> HH:MM:SS,mmm`
  const srtCue = /(\d{1,3}):(\d{2}):(\d{2})[.,](\d{1,3})\s*-->\s*\d{1,3}:\d{2}:\d{2}[.,]\d{1,3}/
  for (const block of text.replace(/\r/g, '').split(/\n\s*\n/)) {
    const lines = block.split('\n').map((l) => l.trim()).filter(Boolean)
    if (!lines.length) continue
    let i = 0
    if (/^\d+$/.test(lines[0])) i = 1
    const m = srtCue.exec(lines[i] || '')
    if (!m) continue
    const frac = parseInt(m[4], 10) / Math.pow(10, m[4].length)
    const time = (+m[1]) * 3600 + (+m[2]) * 60 + (+m[3]) + frac
    const body = lines.slice(i + 1).join(' ').trim()
    if (body && !seen.has(time)) { seen.add(time); out.push({ time, text: body }) }
  }
  if (out.length) return out.sort((a, b) => a.time - b.time)

  // LRC lines: one or more `[MM:SS.cc]` tags per line.
  for (const line of text.replace(/\r/g, '').split('\n')) {
    const tags = line.match(/\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]/g)
    if (!tags) continue
    const body = line.replace(/^(\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]\s*)+/, '').trim()
    if (!body) continue
    for (const tag of tags) {
      const time = parseTimecode(tag.slice(1, -1))
      if (time === null || seen.has(time)) continue
      seen.add(time)
      out.push({ time, text: body })
    }
  }
  return out.sort((a, b) => a.time - b.time)
}

// ---------------------------------------------------------------------------
// Dynamic-programming alignment
// ---------------------------------------------------------------------------

// Scores are integers (kept small so float64 addition stays exact and results
// are bit-for-bit reproducible).
const MATCH = 26       // a word matched to the line that actually sings it
const MISMATCH = -18   // a word force-matched to the wrong line: strictly
                       // worse than leaving it unmatched, so the aligner
                       // prefers to leave a word unplaced when unsure
const GAP_IN_TRANSCRIPT = 0 // transcript word matched to no lyric line
const GAP_IN_LYRIC = 0      // lyric line with no transcript word (unsung)

/**
 * Needleman-Wunsch global alignment between the sung lyric lines and the
 * transcript word stream.
 *
 * Global (not local) alignment is deliberate: a lyric line the model failed to
 * hear must still land somewhere in the timeline, so skipping words has to be
 * a scored, penalised decision rather than a free pass. Anything the aligner is
 * unsure about then surfaces as a low per-line confidence instead of as a
 * silently missing line.
 *
 * @param {string[][]} lyricKeys per-line word arrays (raw words)
 * @param {string[]}   wordKeys  transcript words, in time order
 * @returns {{pairs: Array<{line:number, word:number}>, score:number}}
 */
export function alignLines(lyricKeys, wordKeys) {
  const n = lyricKeys.length
  const m = wordKeys.length
  const width = m + 1
  const idx = (i, j) => i * width + j

  const score = new Float64Array((n + 1) * width)

  for (let j = 1; j <= m; j++) score[idx(0, j)] = score[idx(0, j - 1)] + GAP_IN_TRANSCRIPT
  for (let i = 1; i <= n; i++) score[idx(i, 0)] = score[idx(i - 1, 0)] + GAP_IN_LYRIC

  // `simCache[i][j]` is the best similarity of transcript word j to any word in
  // line i. A line is compared against a word, not a single word against it, so
  // a line can absorb whichever of its words matches.
  const simCache = []
  for (let i = 0; i < n; i++) {
    const keys = lyricKeys[i]
    const row = new Float64Array(m)
    for (let j = 0; j < m; j++) {
      const wk = wordKeys[j]
      let best = 0
      for (const key of keys) {
        const sim = key === wk ? 1 : wordSimilarity(key, wk)
        if (sim > best) best = sim
      }
      row[j] = best
    }
    simCache.push(row)
  }

  const gainFor = (sim) => sim >= WORD_MATCH_THRESHOLD
    ? Math.round((MISMATCH + sim * (MATCH - MISMATCH)) / 2) * 2
    : MISMATCH

  // Recurrence over (line i, word j).
  //
  // The critical property is that ONE LINE MAY CONSUME SEVERAL CONSECUTIVE
  // WORDS: a Telugu lyric line is typically 4-8 words, so a recurrence that
  // advances the line index on every word can never let a line claim more than
  // one of them. Two transitions are therefore allowed:
  //
  //   next  -> start line i+1 and consume word j   (a new line begins)
  //   more  -> stay on line i and consume word j    (another word of this line)
  for (let i = 1; i <= n; i++) {
    const row = simCache[i - 1]
    for (let j = 1; j <= m; j++) {
      const sim = row[j - 1]
      // Staying on this line: consume word j-1 while still on line i.
      const stay = score[idx(i, j - 1)] + gainFor(sim)
      // Starting this line with word j-1 (the previous line ended before it).
      const start = score[idx(i - 1, j - 1)] + gainFor(sim)
      // Or this line matched nothing and we move past a transcript word.
      const skipWord = score[idx(i, j - 1)] + GAP_IN_TRANSCRIPT
      // Or this line is unsung; finish it and keep the word for a later line.
      const skipLine = score[idx(i - 1, j)] + GAP_IN_LYRIC

      let best = skipLine
      if (stay > best) best = stay
      if (start > best) best = start
      if (skipWord > best) best = skipWord
      score[idx(i, j)] = best
    }
  }

  // Traceback over the recurrence above. `wordOwner[j]` records the line that
  // claimed transcript word j, which is exactly what the caller needs: it makes
  // both the per-line word grouping and the confidence scoring exact, instead
  // of inferring ownership from a reconstructed pair list.
  const wordOwner = new Int32Array(m).fill(-1)
  let i = n
  let j = m
  while (i > 0 || j > 0) {
    const here = score[idx(i, j)]

    if (j > 0 && i > 0) {
      const sim = simCache[i - 1][j - 1]
      const g = gainFor(sim)
      // Prefer actually claiming the word over either kind of skip, so the
      // walk lands on a maximal path that used its matches.
      if (score[idx(i, j - 1)] + g === here) {
        if (sim >= WORD_MATCH_THRESHOLD) wordOwner[j - 1] = i - 1
        j--
        continue
      }
      if (score[idx(i - 1, j - 1)] + g === here) {
        if (sim >= WORD_MATCH_THRESHOLD) wordOwner[j - 1] = i - 1
        i--; j--
        continue
      }
    }
    if (i > 0 && score[idx(i - 1, j)] + GAP_IN_LYRIC === here) { i--; continue }
    if (j > 0 && score[idx(i, j - 1)] + GAP_IN_TRANSCRIPT === here) { j--; continue }
    // Unreachable while the matrix is consistent; fail loudly rather than spin.
    throw new Error('alignLines: traceback lost its path')
  }

  const pairs = []
  for (let w = 0; w < m; w++) {
    if (wordOwner[w] >= 0) pairs.push({ line: wordOwner[w], word: w })
  }
  return { pairs, score: score[idx(n, m)], wordOwner }
}

/**
 * A wrong transcript (wrong audio file, wrong language, wrong track) cannot
 * reach this rate by chance: matching requires a syllable-bigram overlap of at
 * least WORD_MATCH_THRESHOLD against a specific word in a specific line, and
 * the DP actively prefers to leave a word unmatched (score 0) over pairing it
 * with an unrelated line (score MISMATCH, negative). Measured on the real
 * lyrics in migrations/002_lyrics.sql, unrelated text scores far below this
 * floor, so falling under it means "this transcript is not these lyrics" and
 * the result must be rejected outright rather than reported as low confidence.
 */
export const MIN_MATCH_RATE = 0.7

// ---------------------------------------------------------------------------
// Confidence scoring
// ---------------------------------------------------------------------------

/**
 * How much of a line's text the alignment accounted for, in [0, 1].
 *
 * The subtlety that matters: a line is scored against words the ASR DID
 * produce. If the model dropped half a line's words, the aligner cannot be
 * blamed by dividing by the original word count — it never had those words to
 * match. Coverage therefore measures the QUALITY of what was claimed, plus a
 * modest volume bonus, so that claiming two solid words for a four-word line
 * scores as a usable placement rather than as a failure.
 *
 *   * `simTotal / wordsMatched` — mean similarity of the words actually
 *     claimed. This is the honest "did it key onto the right words" signal.
 *   * a volume factor, so that a single lucky word cannot by itself carry a
 *     long line to full confidence.
 *
 * A line with no claimed words scores 0 regardless.
 */
function coverage(matched, keyCount, simTotal, wordsMatched) {
  if (keyCount <= 0) return 0
  if (wordsMatched <= 0) return 0

  // Quality of the words actually claimed.
  const meanClaimed = Math.max(0, Math.min(1, simTotal / wordsMatched))

  // How much of the line those claims represent. Full credit at 50% of the
  // line's words (singing ASR reliably loses more than that), tapering below.
  const volume = Math.min(1, (wordsMatched / keyCount) / 0.5)

  return Math.max(0, Math.min(1, meanClaimed * (0.7 + 0.3 * volume)))
}

/**
 * Score one aligned line.
 *
 * Three independent signals, combined by their WEAKEST link — a line is only
 * as trustworthy as its worst dimension:
 *   * `coverage`     — did the alignment actually key the line onto words?
 *   * `asr`          — how sure was Deepgram about those words?
 *   * `plausibility` — is the resulting duration humanly possible?
 *
 * Taking the minimum (rather than an average) is deliberate: averaging lets a
 * confident ASR reading paper over an alignment that silently keyed the line
 * onto the wrong words.
 */
export function scoreLine({ matched, keyCount, asrConfidences, start, end, prevEnd, startMin, startMax, wordsMatched, simTotal = 0 }) {
  const cov = coverage(matched, keyCount, simTotal, wordsMatched)

  const asr = asrConfidences.length
    ? asrConfidences.reduce((a, b) => a + b, 0) / asrConfidences.length
    : 0

  // Duration plausibility. Bounds are deliberately loose — they exist to catch
  // gross misplacement (a whole line collapsed onto one blink of audio, or
  // stretched across the song), not to police tempo. Measured against the
  // author's own timings in migrations/002_lyrics.sql, real lines run about
  // 2.5s for 5 words, so the lower bound is set well beneath that.
  const dur = end - start
  // A line must occupy at least a plausible fraction of the audio its matched
  // words span. 0.6s is roughly the shortest a sung Telugu line can be.
  const minDur = Math.min(1.5, Math.max(0.6, wordsMatched * 0.18))
  const maxDur = 25
  let plaus = 1
  if (dur < minDur) plaus = 0.5
  else if (dur > maxDur) plaus = 0.4

  // Monotonicity: a line should not start before the previous line ended.
  //
  // Scaled rather than binary. Word timings on singing routinely run a few
  // hundred milliseconds into the next line (the previous word's `end` is
  // extended over a sustained final vowel), and that is normal, not an error.
  // Only a *substantial* inversion means the line was placed wrongly.
  if (prevEnd !== null && prevEnd !== undefined && start < prevEnd) {
    const overlap = prevEnd - start
    if (overlap > 1.0) plaus = Math.min(plaus, 0.2)
    else if (overlap > 0.35) plaus = Math.min(plaus, 0.6)
  }

  // Bounds: never before 0, never past the end of the audio.
  if (start < -0.001 || (startMax !== null && start > startMax)) plaus = Math.min(plaus, 0.2)
  if (startMin !== null && startMin > 0 && wordsMatched === 0) plaus = Math.min(plaus, 0.5)

  return Math.min(cov, asr === 0 ? 0.2 : asr, plaus)
}

export const DEFAULT_CONFIDENCE_FLOOR = 0.55

// ---------------------------------------------------------------------------
// Top-level alignment
// ---------------------------------------------------------------------------

/**
 * Align lyric lines to Deepgram word timings.
 *
 * @param {object} args
 * @param {string} args.plainLyrics   the Telugu `plain_lyrics` column
 * @param {Array<{word:string,start:number,end:number,confidence:number}>} args.words
 * @param {number|null} args.audioDuration
 * @param {number} [args.confidenceFloor]
 * @returns {{
 *   ok: boolean, reason: string|null, matchRate: number,
 *   lines: Array<object>, buildableLineCount: number, overallConfidence: number
 * }}
 */
export function alignLyrics({ plainLyrics, words, audioDuration = null, confidenceFloor = DEFAULT_CONFIDENCE_FLOOR }) {
  const rawLines = splitLyricLines(plainLyrics)
  const kinds = rawLines.map(classifyLine)

  const usableWords = (Array.isArray(words) ? words : [])
    .filter((w) => w && typeof w.start === 'number' && typeof w.end === 'number')
    .slice()
    .sort((a, b) => a.start - b.start)

  const lyricIdx = []
  kinds.forEach((k, i) => { if (k === 'lyric') lyricIdx.push(i) })

  if (!lyricIdx.length) {
    return {
      ok: false, reason: 'no_lyric_lines', matchRate: 0, lines: [],
      buildableLineCount: 0, overallConfidence: 0,
    }
  }
  if (!usableWords.length) {
    return {
      ok: false, reason: 'no_transcript_words', matchRate: 0, lines: [],
      buildableLineCount: 0, overallConfidence: 0,
    }
  }

  const lyricKeys = lyricIdx.map((i) => String(rawLines[i]).split(/\s+/).filter(Boolean))
  const wordKeys = usableWords.map((w) => String(w.word || ''))

  const { pairs } = alignLines(lyricKeys, wordKeys)

  // Group matched words per lyric line. A transcript word belongs to at most
  // one line, so a line's span is exactly min/max of its own words.
  const byLine = new Map()
  for (const p of pairs) {
    if (!byLine.has(p.line)) byLine.set(p.line, [])
    byLine.get(p.line).push(p.word)
  }

  let matchedLines = 0
  const lyricResults = []
  let prevEnd = null

  for (let li = 0; li < lyricIdx.length; li++) {
    const absoluteIndex = lyricIdx[li]
    const keys = lyricKeys[li]
    const wordIdxs = byLine.get(li) || []

    // `pairs` already contains only words the aligner actually claimed for a
    // line (a word similar to some word in it). `simTotal` measures HOW similar,
    // so a line that was claimed by barely-similar words still scores low.
    let matched = 0
    let simTotal = 0
    for (const wi of wordIdxs) {
      let best = 0
      for (const key of keys) {
        const s = key === wordKeys[wi] ? 1 : wordSimilarity(key, wordKeys[wi])
        if (s > best) best = s
      }
      simTotal += best
      if (best >= WORD_MATCH_THRESHOLD) matched++
    }
    if (matched > 0) matchedLines++

    let start = null
    let end = null
    const asrConfidences = []
    if (wordIdxs.length) {
      start = Math.min(...wordIdxs.map((w) => usableWords[w].start))
      end = Math.max(...wordIdxs.map((w) => usableWords[w].end))
      for (const w of wordIdxs) {
        const c = usableWords[w].confidence
        if (typeof c === 'number' && c > 0) asrConfidences.push(c)
      }
    }

    const confidence = start === null
      ? 0
      : scoreLine({
          matched, keyCount: keys.length, asrConfidences,
          start, end, prevEnd,
          startMin: 0, startMax: audioDuration,
          wordsMatched: wordIdxs.length,
          simTotal,
        })

    if (start !== null) prevEnd = end

    lyricResults.push({
      lineIndex: absoluteIndex,
      text: rawLines[absoluteIndex],
      startSeconds: start,
      endSeconds: end,
      confidence: Number(confidence.toFixed(4)),
      matchedKeys: matched,
      totalKeys: keys.length,
      wordCount: wordIdxs.length,
      asrConfidence: asrConfidences.length
        ? Number((asrConfidences.reduce((a, b) => a + b, 0) / asrConfidences.length).toFixed(4))
        : null,
    })
  }

  const matchRate = matchedLines / lyricIdx.length
  const overallConfidence = lyricResults.reduce((a, r) => Math.min(a, r.confidence), 1)
  const buildableLineCount = lyricResults.filter((r) => r.startSeconds !== null).length

  let reason = null
  let ok = true
  if (matchRate < MIN_MATCH_RATE) {
    ok = false
    reason = 'transcript_mismatch'
  } else if (buildableLineCount < lyricResults.length) {
    ok = false
    reason = 'unplaced_lines'
  } else if (overallConfidence < confidenceFloor) {
    ok = false
    reason = 'below_confidence_floor'
  }

  return {
    ok,
    reason,
    matchRate: Number(matchRate.toFixed(4)),
    lines: lyricResults,
    buildableLineCount,
    overallConfidence: Number(overallConfidence.toFixed(4)),
  }
}

// ---------------------------------------------------------------------------
// Build the per-column SRT text
// ---------------------------------------------------------------------------

const pad3 = (n) => String(n).padStart(3, '0')
const pad2 = (n) => String(n).padStart(2, '0')

/** Seconds -> `HH:MM:SS,mmm` (the format the admin SRT validator requires). */
export function formatSrtTime(sec) {
  const s = Math.max(0, Number(sec) || 0)
  const ms = Math.round(s * 1000)
  return `${pad2(Math.floor(ms / 3600000))}:${pad2(Math.floor((ms % 3600000) / 60000))}:${pad2(Math.floor((ms % 60000) / 1000))},${pad3(ms % 1000)}`
}

/** Split every `plain_lyrics*` variant with the same rules as the main column. */
export function splitVariantLines(variant, expectedCount) {
  const lines = splitLyricLines(variant)
  if (lines.length === expectedCount) return lines
  // Non-parallel variants are padded rather than truncated: a shorter variant
  // must not silently drop the tail of the song, and a longer one must not
  // shift the shared timeline.
  const out = lines.slice(0, expectedCount)
  while (out.length < expectedCount) out.push('')
  return out
}

/**
 * Render one timed SRT for a language variant.
 *
 * `lineTimings[globalIndex]` is the whole-line start time (or null when the
 * line could not be placed — those lines are omitted from the cue list rather
 * than emitted with a bogus time).
 *
 * Cue end times are the NEXT timed line's start. That is what makes the
 * on-screen highlight hold until the following line begins, instead of
 * blinking off during the instrumental gap after a line is sung.
 *
 * `{{Music}}` banners are emitted as real cues (a banner with no audio needs a
 * time to be shown at); `{Section}` headings are not, because they are
 * decorative structure rather than content.
 */
export function buildSrtForVariant(variantText, lineTimings, totalLines) {
  const lines = splitVariantLines(variantText, totalLines)
  const entries = []
  for (let i = 0; i < totalLines; i++) {
    const t = lineTimings[i]
    if (t === null || t === undefined) continue
    const text = String(lines[i] || '').trim()
    if (!text) continue
    if (classifyLine(text) === 'section') continue
    entries.push({ start: t, text })
  }
  entries.sort((a, b) => a.start - b.start)

  const blocks = []
  for (let i = 0; i < entries.length; i++) {
    const start = entries[i].start
    let end = i + 1 < entries.length ? entries[i + 1].start : null
    // Guarantee a strictly positive, visually stable cue.
    if (end === null || end - start < 0.05) end = start + 1.5
    blocks.push(`${i + 1}\n${formatSrtTime(start)} --> ${formatSrtTime(end)}\n${entries[i].text}`)
  }
  return blocks.join('\n\n') + (blocks.length ? '\n' : '')
}

/**
 * Give unsung lines (`{Section}` headings, blank separators) a time derived
 * from their sung neighbours so that every row keeps a usable position.
 */
export function fillUnsungTimings(lineTimings) {
  const out = lineTimings.slice()
  let last = null
  for (let i = 0; i < out.length; i++) {
    if (out[i] !== null && out[i] !== undefined) { last = out[i]; continue }
    // Look ahead for the next placed line to interpolate towards.
    let next = null
    for (let j = i + 1; j < out.length; j++) {
      if (out[j] !== null && out[j] !== undefined) { next = out[j]; break }
    }
    if (last !== null && next !== null) out[i] = last + (next - last) / 2
    else if (last !== null) out[i] = last + 0.1
    else if (next !== null) out[i] = Math.max(0, next - 0.1)
    else out[i] = null
  }
  return out
}
