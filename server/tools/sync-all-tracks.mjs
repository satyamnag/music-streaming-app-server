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

// --- audit one column against the measured words -------------------------
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

for (const [i, t] of tracks.entries()) {
  const rec = { id: t.id, title: t.title, status: 'skip', reason: null }
  try {
    const w = byId.get(t.id)
    if (!w) { rec.reason = 'no whisper transcription'; report.push(rec); continue }
    if (w.error) { rec.reason = `whisper error: ${w.error}`; report.push(rec); continue }
    const words = Array.isArray(w.words) ? w.words : []
    if (words.length < 10) { rec.reason = `insufficient audio (${words.length} words)`; report.push(rec); continue }

    // plain lyrics are READ ONLY - never modified
    const q = await fetch(
      `${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(t.id)}` +
      '&select=plain_lyrics,plain_lyrics_en,plain_lyrics_en_tr,synced_lyrics,synced_lyrics_en,synced_lyrics_en_tr,duration',
      { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } },
    )
    const [row] = await q.json()
    if (!row || !String(row.plain_lyrics || '').trim()) { rec.reason = 'no plain lyrics'; report.push(rec); continue }
    const duration = Number(row.duration) || t.duration || (words[words.length - 1].end + 1)

    const srt = segmentTrack(t, row.plain_lyrics, words, duration)
    // Always persist the proposed SRT so a rejected track can be diagnosed.
    const tlFile = path.join(OUT_DIR, `${t.id}.te.srt`)
    fs.writeFileSync(tlFile, srt, 'utf8')
    const cues = parseSrtTimeline(srt)
    rec.cues = cues.length
    rec.lyric_cues = cues.filter((c) => c.text.trim() !== MUSIC_LABEL).length

    const audit = auditColumn(cues, duration, row.plain_lyrics)
    if (audit.problems.length) { rec.reason = audit.problems.join('; '); report.push(rec); continue }
    rec.missing_lines = audit.missing.length
    rec.coverage_pct = audit.lyricLines.length
      ? Number((((audit.lyricLines.length - audit.missing.length) / audit.lyricLines.length) * 100).toFixed(1))
      : 0

    // audio truth: every word inside a cue, no lyric hidden under music
    const cueAt = (time) => cues.findIndex((c) => time >= c.start - 0.001 && time < c.end)
    const orphans = words.filter((x) => cueAt(x.start) === -1).length
    if (orphans) { rec.reason = `${orphans} word(s) outside every cue`; report.push(rec); continue }

    const lyricWordSims = []
    let hiddenUnderMusic = 0
    const plainWords = splitLyricLines(row.plain_lyrics)
      .filter((l) => classifyLine(l) === 'lyric')
      .flatMap((l) => String(l).split(/\s+/).map(normaliseWord).filter(Boolean))
    for (const c of cues) {
      const inside = words.filter((x) => x.start >= c.start - 0.001 && x.start < c.end)
      if (!inside.length) continue
      if (c.text.trim() === MUSIC_LABEL) {
        for (const x of inside) {
          const n = normaliseWord(x.word)
          let best = 0
          for (const k of plainWords) { const v = Math.max(0, lev(k, n)); if (v > best) best = v }
          if (best >= 0.75) hiddenUnderMusic += 1
        }
        continue
      }
      const keys = c.text.split(/\s+/).map(normaliseWord).filter(Boolean).join('')
      const heard = inside.map((x) => normaliseWord(x.word)).join('')
      lyricWordSims.push(lev(keys, heard))
    }
    if (hiddenUnderMusic) { rec.reason = `${hiddenUnderMusic} lyric word(s) hidden under a music banner`; report.push(rec); continue }
    const worst = lyricWordSims.length ? Math.min(...lyricWordSims) : 0
    rec.worst_cue_match = Number(worst.toFixed(3))
    if (worst < 0.55) { rec.reason = `a cue text does not match the words sung (${worst.toFixed(2)})`; report.push(rec); continue }

    // render EN / EN-TR from the SAME timeline
    const cols = []
    if (String(row.plain_lyrics_en || '').trim()) cols.push('en')
    if (String(row.plain_lyrics_en_tr || '').trim()) cols.push('en_tr')

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
    if (!payload) { report.push(rec); continue }

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
      report.push(rec)
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
    rec.reason = String(e && e.message).slice(0, 160)
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
