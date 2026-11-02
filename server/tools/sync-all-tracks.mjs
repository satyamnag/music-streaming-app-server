// ============================================================================
// Apply the verified Kavalini pipeline to the WHOLE catalogue.
//
// For every track that has plain lyrics and audio:
//   1. segment Whisper's measured words into one cue per sung occurrence
//      (reuses whisper-segment-sync.mjs - the exact code verified on Kavalini)
//   2. AUDIT the result against the measured words
//   3. render EN / EN-TR from the SAME timeline
//      (reuses render-variant-sync.mjs - the renderer the admin endpoint uses)
//   4. only if EVERY check passes, the track becomes eligible for writing
//
// Default is a DRY RUN: it writes nothing and produces a report. `--write`
// captures the previous values of all three synced columns FIRST, then applies.
//
// PLAIN LYRICS ARE NEVER TOUCHED. Only synced_lyrics* columns are written.
//
// Run:
//   node server/tools/sync-all-tracks.mjs [--write] [--limit N] [--ids a,b]
//                                         [--out-dir DIR]
// ============================================================================

import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import {
  parseSrtTimeline,
  splitLyricLines,
  splitVariantLines,
  classifyLine,
  normaliseWord,
  renderCuesToSrt,
  MUSIC_LABEL,
} from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : (process.argv[i + 1] ?? true)
}
const WRITE = process.argv.includes('--write')
const LIMIT = Number(arg('limit', 0)) || 0
const ONLY = String(arg('ids', '') || '').split(',').map((s) => s.trim()).filter(Boolean)
const OUT_DIR = arg('out-dir', 'sync-out')
const WORDS_FILE = arg('words', 'whisper-words.json')
const TRACKS_FILE = arg('tracks', 'track-list.json')

const TOOLS = path.dirname(fileURLToPath(import.meta.url))
const SUPA = (process.env.SUPABASE_URL || 'https://ngemrcsdfxufxnazeqke.supabase.co').replace(/\/$/, '')
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''
if (!KEY) { console.error('supabase key required'); process.exit(2) }
if (WRITE && !process.env.SUPABASE_SERVICE_ROLE_KEY) {
  console.error('--write requires SUPABASE_SERVICE_ROLE_KEY'); process.exit(2)
}

// --- helpers --------------------------------------------------------------
function lev(a, b) {
  if (!a || !b) return 0
  if (a === b) return 1
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j)
  for (let i = 1; i <= a.length; i++) {
    const cur = [i]
    for (let j = 1; j <= b.length; j++) cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
    prev = cur
  }
  return 1 - prev[b.length] / Math.max(a.length, b.length)
}

/** Write Whisper words in the exact text format whisper-segment-sync.mjs parses. */
function wordsToText(words) {
  return words
    .map((w) => `${w.start.toFixed(2)} -> ${w.end.toFixed(2)}   ${w.word}  (p=${(w.confidence ?? 0).toFixed(3)})`)
    .join('\n') + '\n'
}

/** Character Levenshtein similarity between two strings. */
function simStr(a, b) { return lev(a, b) }

/**
 * Best agreement between a line's text and ANY contiguous run of words inside a
 * span.
 *
 * The audit must not score the whole cue span: a cue holds until the next one
 * starts, so it can contain Whisper's hallucinated bursts or an adjacent
 * phrase. Measuring the BEST run inside the span answers the question that
 * actually matters - "is this line sung somewhere in this cue?".
 */
function bestRunAgreement(text, wordsInSpan) {
  const keys = String(text).split(/\s+/).map(normaliseWord).filter(Boolean)
  if (!keys.length || !wordsInSpan.length) return 0
  const keyStr = keys.join('')
  // 1 (not ceil(k*0.4)): a whole sung line can arrive as ONE merged Whisper
  // token, and a floor above 1 would score such a cue 0 and wrongly reject it.
  const minLen = 1
  const maxLen = keys.length + 2
  let best = 0
  for (let a = 0; a < wordsInSpan.length; a++) {
    for (let len = minLen; len <= maxLen && a + len <= wordsInSpan.length; len++) {
      const run = wordsInSpan.slice(a, a + len).map((w) => normaliseWord(w.word)).join('')
      const score = simStr(keyStr, run)
      if (score > best) best = score
    }
  }
  // A single short token can score deceptively high against a whole line, so
  // also consider a per-key mean for windows that cover most of the line.
  let perKeyBest = 0
  for (let a = 0; a < wordsInSpan.length; a++) {
    for (let len = minLen; len <= maxLen && a + len <= wordsInSpan.length; len++) {
      const run = wordsInSpan.slice(a, a + len)
      let total = 0
      for (const k of keys) {
        let s = 0
        for (const w of run) { const v = simStr(k, normaliseWord(w.word)); if (v > s) s = v }
        total += s
      }
      const score = total / keys.length
      if (score > perKeyBest) perKeyBest = score
    }
  }
  return Math.max(best, perKeyBest)
}
function auditColumn(cues, duration, plainLyrics) {
  const problems = []
  let overlap = 0, zero = 0, oor = 0, blank = 0
  const starts = new Set()
  for (let i = 0; i < cues.length; i++) {
    if (cues[i].end <= cues[i].start) zero += 1
    if (i > 0 && cues[i].start < cues[i - 1].end - 1e-6) overlap += 1
    if (cues[i].start < 0 || cues[i].end > Number(duration) + 0.5) oor += 1
    if (!String(cues[i].text || '').trim()) blank += 1
    starts.add(cues[i].start)
  }
  if (overlap) problems.push(`${overlap} overlap`)
  if (zero) problems.push(`${zero} zero-duration`)
  if (oor) problems.push(`${oor} out-of-range`)
  if (blank) problems.push(`${blank} blank`)
  if (cues.length - starts.size) problems.push(`${cues.length - starts.size} duplicate start`)
  if (cues.length && Math.abs(cues[0].start) > 1e-6) problems.push(`does not start at 0`)
  if (cues.length && Math.abs(cues[cues.length - 1].end - Number(duration)) > 0.5) problems.push(`does not end at duration`)

  // every plain lyric line must appear
  const lyricLines = splitLyricLines(plainLyrics).filter((l) => classifyLine(l) === 'lyric').map((l) => String(l).trim())
  const present = new Set(cues.filter((c) => c.text.trim() !== MUSIC_LABEL).map((c) => c.text.trim()))
  const missing = lyricLines.filter((l) => !present.has(l))

  return { problems, lyricLines, missing }
}

/** Count SUNG cues ({{Music}} banners are language scaffolding). */
function lyricCueCount(srt) {
  return parseSrtTimeline(srt).filter((c) => c.text.trim() !== MUSIC_LABEL).length
}

/**
 * Guarantee the cue list covers the whole track.
 *
 * When the first sung line starts a second or two in, the builder emits no
 * banner for that lead-in (it is under MUSIC_GAP_MIN_SECONDS), so the timeline
 * begins late: the player would show nothing and any measured word there looks
 * "outside every cue". Prepending/appending a {{Music}} banner makes coverage
 * complete without inventing any lyric time.
 */
function coverTimeline(srt, duration) {
  const cues = parseSrtTimeline(srt)
  if (!cues.length) return srt
  const dur = Number(duration) || cues[cues.length - 1].end
  const out = cues.map((c) => ({ kind: c.text.trim() === MUSIC_LABEL ? 'music' : 'lyric', text: c.text, start: c.start, end: c.end }))
  if (out[0].start > 0.05) {
    out.unshift({ kind: 'music', text: MUSIC_LABEL, start: 0, end: out[0].start })
  }
  const last = out[out.length - 1]
  if (last.end < dur - 0.05) {
    out.push({ kind: 'music', text: MUSIC_LABEL, start: last.end, end: dur })
  }
  return renderCuesToSrt(out)
}

// --- process one track ----------------------------------------------------
function segmentTrack(track, plainLyrics, words, duration) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'syncseg-'))
  const wFile = path.join(tmp, 'words.txt')
  const pFile = path.join(tmp, 'plain.txt')
  const oFile = path.join(tmp, 'out.srt')
  fs.writeFileSync(wFile, wordsToText(words), 'utf8')
  fs.writeFileSync(pFile, plainLyrics, 'utf8')
  execFileSync(process.execPath, [
    path.join(TOOLS, 'whisper-segment-sync.mjs'),
    '--words', wFile, '--plain', pFile, '--duration', String(duration), '--out', oFile,
  ], { stdio: 'pipe' })
  const srt = fs.readFileSync(oFile, 'utf8')
  fs.rmSync(tmp, { recursive: true, force: true })
  return srt
}

function renderVariants(trackId, cols, timelineFile, outDir) {
  execFileSync(process.execPath, [
    path.join(TOOLS, 'render-variant-sync.mjs'),
    '--track', trackId, '--cols', cols.join(','), '--timeline-file', timelineFile,
    '--out-dir', outDir, '--emit-payload',
  ], {
    stdio: 'pipe',
    env: { ...process.env, SUPABASE_URL: SUPA, SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || KEY },
  })
  return JSON.parse(fs.readFileSync(path.join(outDir, 'payload.json'), 'utf8'))
}

// --- main -----------------------------------------------------------------
const whisper = JSON.parse(fs.readFileSync(WORDS_FILE, 'utf8'))
const byId = new Map(whisper.map((w) => [w.id, w]))
let tracks = JSON.parse(fs.readFileSync(TRACKS_FILE, 'utf8'))
if (ONLY.length) tracks = tracks.filter((t) => ONLY.includes(t.id))
if (LIMIT) tracks = tracks.slice(0, LIMIT)

fs.mkdirSync(OUT_DIR, { recursive: true })
console.log(`mode: ${WRITE ? 'WRITE' : 'DRY RUN'}   tracks: ${tracks.length}\n`)

const report = []
const patch = {}
const backup = {}
let written = 0

/** Record a result and always print it, so no skip is silent. */
const emit = (rec, t, i) => {
  report.push(rec)
  const detail = rec.reason || `cues ${rec.cues} (lyric ${rec.lyric_cues})`
  console.log(`[${i + 1}/${tracks.length}] ${String(rec.status).padEnd(12)} ${String(t.title).slice(0, 40).padEnd(40)} ${detail}`)
}

for (const [i, t] of tracks.entries()) {
  const rec = { id: t.id, title: t.title, status: 'skip', reason: null }
  try {
    const w = byId.get(t.id)
    if (!w) { rec.reason = 'no whisper transcription'; emit(rec, t, i); continue }
    if (w.error) { rec.reason = `whisper error: ${w.error}`; emit(rec, t, i); continue }
    const words = Array.isArray(w.words) ? w.words : []
    if (words.length < 10) { rec.reason = `insufficient audio (${words.length} words)`; emit(rec, t, i); continue }

    // plain lyrics are READ ONLY - never modified
    const q = await fetch(
      `${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(t.id)}` +
      '&select=plain_lyrics,plain_lyrics_en,plain_lyrics_en_tr,synced_lyrics,synced_lyrics_en,synced_lyrics_en_tr,duration',
      { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } },
    )
    const [row] = await q.json()
    if (!row || !String(row.plain_lyrics || '').trim()) { rec.reason = 'no plain lyrics'; emit(rec, t, i); continue }
    const duration = Number(row.duration) || t.duration || (words[words.length - 1].end + 1)

    const srtRaw = segmentTrack(t, row.plain_lyrics, words, duration)
    const srt = coverTimeline(srtRaw, duration)
    // Always persist the proposed SRT so a rejected track can be diagnosed.
    const tlFile = path.join(OUT_DIR, `${t.id}.te.srt`)
    fs.writeFileSync(tlFile, srt, 'utf8')
    const cues = parseSrtTimeline(srt)
    rec.cues = cues.length
    rec.lyric_cues = cues.filter((c) => c.text.trim() !== MUSIC_LABEL).length

    const audit = auditColumn(cues, duration, row.plain_lyrics)
    if (audit.problems.length) { rec.reason = audit.problems.join('; '); emit(rec, t, i); continue }
    rec.missing_lines = audit.missing.length
    rec.coverage_pct = audit.lyricLines.length
      ? Number((((audit.lyricLines.length - audit.missing.length) / audit.lyricLines.length) * 100).toFixed(1))
      : 0

    // audio truth: every word inside a cue, no lyric hidden under music
    const cueAt = (time) => cues.findIndex((c) => time >= c.start - 0.001 && time < c.end)
    // Words at or beyond the stored duration are Whisper hallucination appended
    // past the end of the audio (measured: 4 tokens at 411.2-411.7 s on a 411 s
    // track). They sit outside the player's timeline and must not fail a track.
    const inTimeline = words.filter((x) => x.start >= 0 && x.start < duration)
    const orphans = inTimeline.filter((x) => cueAt(x.start) === -1).length
    if (orphans) { rec.reason = `${orphans} word(s) outside every cue`; emit(rec, t, i); continue }

    const lyricWordSims = []
    let hiddenUnderMusic = 0
    const plainWords = splitLyricLines(row.plain_lyrics)
      .filter((l) => classifyLine(l) === 'lyric')
      .flatMap((l) => String(l).split(/\s+/).map(normaliseWord).filter(Boolean))
    for (const c of cues) {
      const inside = words.filter((x) => x.start >= c.start - 0.001 && x.start < c.end)
      if (!inside.length) continue
      if (c.text.trim() === MUSIC_LABEL) {
        // A music banner is only "hiding a lyric" if a RUN of several words
        // matches plain lyric words. A single short token matching by chance is
        // not evidence (measured false positive: 1 word tripped this).
        const hit = inside.map((x) => {
          const n = normaliseWord(x.word)
          let b = 0
          for (const k of plainWords) { const v = lev(k, n); if (v > b) b = v }
          return b >= 0.8
        })
        let run = 0
        let maxRun = 0
        for (const h of hit) { run = h ? run + 1 : 0; if (run > maxRun) maxRun = run }
        if (maxRun >= 3) hiddenUnderMusic += maxRun
        continue
      }
      lyricWordSims.push(bestRunAgreement(c.text, inside))
    }
    if (hiddenUnderMusic) { rec.reason = `${hiddenUnderMusic} lyric word(s) hidden under a music banner`; emit(rec, t, i); continue }
    const worst = lyricWordSims.length ? Math.min(...lyricWordSims) : 0
    const weak = lyricWordSims.filter((s) => s < 0.5).length
    rec.worst_cue_match = Number(worst.toFixed(3))
    rec.weak_cues = weak
    // Judge the track on the SHAPE of its agreement, not one outlier: a single
    // garbled sung line is common and must not reject a track whose other cues
    // are excellent. Two or more weak cues, or one gross mismatch, is a real
    // misalignment and blocks the write.
    if (worst < 0.35 || weak >= 2) {
      rec.reason = `cue/audio agreement too low (worst ${worst.toFixed(2)}, ${weak} weak cue(s))`
      emit(rec, t, i)
      continue
    }

    // render EN / EN-TR from the SAME timeline
    //
    // A translation column can only be rendered when it is LINE-PARALLEL with the
    // Telugu plain lyrics AND has text on every sung line. Otherwise the renderer
    // would emit fewer cues than the timeline (blank lines are skipped), which
    // would desynchronise the apps' per-row language stacking. In that case the
    // whole track is skipped rather than writing Telugu alone - leaving the old
    // translation on a different timeline would be worse than not touching it.
    const totalLines = splitLyricLines(row.plain_lyrics).length
    const teLines = splitLyricLines(row.plain_lyrics)
    const cols = []
    for (const [col, field] of [['en', 'plain_lyrics_en'], ['en_tr', 'plain_lyrics_en_tr']]) {
      const text = String(row[field] || '')
      if (!text.trim()) continue
      const vlines = splitLyricLines(text)
      if (vlines.length !== totalLines) {
        rec.reason = `translation ${field} is not line-parallel (te ${totalLines} vs ${vlines.length}) - fix the translation, then re-run`
        break
      }
      // A sung Telugu line must have text in the translation at the same index,
      // or the renderer would drop that cue and desynchronise the columns.
      const emptySung = teLines.filter((l, i) =>
        classifyLine(String(l)) === 'lyric' && !String(vlines[i] || '').trim()).length
      if (emptySung) {
        rec.reason = `translation ${field} has ${emptySung} empty sung line(s)`
        break
      }
      cols.push(col)
    }
    if (rec.reason) { emit(rec, t, i); continue }

    let payload = { synced_lyrics: srt }
    if (cols.length) {
      const rendered = renderVariants(t.id, cols, tlFile, OUT_DIR)
      payload = { ...payload, ...rendered }
    }

    // cross-column timeline identity
    for (const k of Object.keys(payload)) {
      if (k === 'synced_lyrics') continue
      const cc = parseSrtTimeline(payload[k])
      const same = cc.length === cues.length && cc.every((x, j) => Math.abs(x.start - cues[j].start) < 1e-6 && Math.abs(x.end - cues[j].end) < 1e-6)
      if (!same) { rec.reason = `${k} timeline drift`; payload = null; break }
    }
    if (!payload) { emit(rec, t, i); continue }

    rec.columns = Object.keys(payload)

    // Comparative safety gate (same philosophy as lyrics-rebuild): only replace a
    // track's timeline when the new one has STRICTLY MORE sung cues. Every hard
    // check above already passed, so this can only improve a track - never
    // regress one whose stored timeline is already richer.
    const existingLyric = lyricCueCount(row.synced_lyrics || '')
    const newLyric = cues.filter((c) => c.text.trim() !== MUSIC_LABEL).length
    rec.existing_lyric_cues = existingLyric
    rec.new_lyric_cues = newLyric
    if (newLyric <= existingLyric) {
      rec.status = 'keep'
      rec.reason = `no sung-cue gain (${existingLyric} -> ${newLyric})`
      emit(rec, t, i)
      continue
    }

    rec.status = WRITE ? 'written' : 'would_write'

    if (WRITE) {
      backup[t.id] = {
        synced_lyrics: row.synced_lyrics ?? null,
        synced_lyrics_en: row.synced_lyrics_en ?? null,
        synced_lyrics_en_tr: row.synced_lyrics_en_tr ?? null,
      }
      fs.writeFileSync(path.join(OUT_DIR, 'sync-all-backup.json'), JSON.stringify(backup, null, 1), 'utf8')
      const r = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(t.id)}`, {
        method: 'PATCH',
        headers: {
          apikey: KEY, Authorization: `Bearer ${KEY}`,
          'Content-Type': 'application/json', Prefer: 'return=minimal',
        },
        body: JSON.stringify(payload),
      })
      if (!r.ok) {
        rec.status = 'error'
        rec.reason = `PATCH ${r.status}`
        delete backup[t.id]
      } else {
        written += 1
      }
    } else {
      patch[t.id] = payload
    }
  } catch (e) {
    rec.status = 'error'
    // Surface the child process's own stderr: a bare "Command failed" hides the
    // actual reason (bad path, validation failure, missing column, ...).
    const stderr = e && e.stderr ? String(e.stderr).trim().split('\n').slice(-2).join(' ') : ''
    rec.reason = `${String(e && e.message).slice(0, 120)}${stderr ? ' :: ' + stderr.slice(0, 200) : ''}`
  }
  report.push(rec)
  console.log(`[${i + 1}/${tracks.length}] ${rec.status.padEnd(12)} ${String(t.title).slice(0, 40).padEnd(40)} ${rec.reason || `cues ${rec.cues} (lyric ${rec.lyric_cues})`}`)
}
const summary = {
  generated_at: new Date().toISOString(),
  mode: WRITE ? 'write' : 'dry_run',
  tracks: tracks.length,
  would_write: report.filter((r) => r.status === 'would_write').length,
  written: report.filter((r) => r.status === 'written').length,
  skipped: report.filter((r) => r.status === 'skip').length,
  errors: report.filter((r) => r.status === 'error').length,
  detail: report,
}
fs.writeFileSync(path.join(OUT_DIR, 'sync-all-report.json'), JSON.stringify(summary, null, 2), 'utf8')
if (!WRITE) fs.writeFileSync(path.join(OUT_DIR, 'sync-all-payload.json'), JSON.stringify(patch, null, 1), 'utf8')

console.log(`\n${JSON.stringify({ ...summary, detail: undefined }, null, 2)}`)
console.log(WRITE ? `\nWROTE ${written} track(s). Backup: ${OUT_DIR}/sync-all-backup.json` : '\nDRY RUN - nothing was written.')
