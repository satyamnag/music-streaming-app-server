// ============================================================================
// Rebuild sync lyrics for the whole catalogue, ON GitHub Actions.
//
// Why a runner: this downloads every track's audio, transcribes it and rewrites
// columns - hours of network and CPU that must not run on the web dyno.
//
// The safety rule that makes a catalogue-wide rewrite acceptable:
//
//   A track is only replaced when the new timeline has STRICTLY MORE CUES than
//   the one already stored. That is precisely the reported defect - repeats that
//   existed in the audio but were never timed - and it means a track that is
//   already good is left untouched, even with --write.
//
// Default is a DRY RUN: it prints what it would do and writes nothing.
//
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, DEEPGRAM_API_KEY, R2_BASE_URL
//      (R2_BASE_URL is the PUBLIC CDN base, e.g. https://music.example.com - the
//      bucket is served publicly for playback, so no R2 key is needed here. An
//      S3 client with an empty credential is exactly what failed the first run.)
//
// Usage:
//   node server/tools/lyrics-rebuild.mjs [--write] [--limit N]
//                                        [--ids id1,id2] [--out report.json]
// ============================================================================

import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { fileURLToPath } from 'node:url'
import { alignLyrics, buildSyncCues, parseSrtTimeline, renderCuesForVariant, splitLyricLines, buildKeyterms } from '../libs/autoSyncLyrics.mjs'

const execFileP = promisify(execFile)
const TOOLS_DIR = path.dirname(fileURLToPath(import.meta.url))
const ACOUSTIC = process.env.ACOUSTIC !== '0'

const arg = (name, dflt = null) => {
  const i = process.argv.indexOf(`--${name}`)
  return i === -1 ? dflt : (process.argv[i + 1] ?? true)
}
const WRITE = process.argv.includes('--write')
const LIMIT = Number(arg('limit', 0)) || 0
const IDS = String(arg('ids', '') || '').split(',').map((s) => s.trim()).filter(Boolean)
const OUT = arg('out', 'lyrics-rebuild.json')
const BACKUP = arg('backup', 'lyrics-backup.json')
const RESTORE = arg('restore', null)

const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''
const DG = process.env.DEEPGRAM_API_KEY || ''
// The R2 bucket is served publicly for playback, so the audio is fetched over
// HTTPS from the CDN base. That removes the need for any R2 credential here -
// an S3 client with missing keys is exactly what failed the first run.
const CDN = (process.env.R2_BASE_URL || '').replace(/\/+$/, '')

if (!SUPA || !KEY) { console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY required'); process.exit(2) }
if (!DG) { console.error('DEEPGRAM_API_KEY required'); process.exit(2) }
if (!CDN) { console.error('R2_BASE_URL required (public CDN base, e.g. https://music.example.com)'); process.exit(2) }

const FIELDS = [
  'id', 'title', 'storage_path', 'duration',
  'plain_lyrics', 'plain_lyrics_en', 'plain_lyrics_en_tr', 'plain_lyrics_hi', 'plain_lyrics_hi_tr',
  'synced_lyrics', 'synced_lyrics_en', 'synced_lyrics_en_tr', 'synced_lyrics_hi', 'synced_lyrics_hi_tr',
].join(',')

async function supaGet(path, extraHeaders = {}) {
  const res = await fetch(`${SUPA}/rest/v1/${path}`, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, ...extraHeaders },
  })
  if (!res.ok) throw new Error(`supabase GET ${res.status}: ${(await res.text()).slice(0, 300)}`)
  return res.json()
}

async function supaPatch(id, body) {
  const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: {
      apikey: KEY, Authorization: `Bearer ${KEY}`,
      'Content-Type': 'application/json', Prefer: 'return=minimal',
    },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`supabase PATCH ${res.status}: ${(await res.text()).slice(0, 300)}`)
}

const MAX_AUDIO = 40 * 1024 * 1024

/** Public CDN URL for an object key, matching the server's r2PublicUrl(). */
function cdnUrl(storagePath) {
  const key = String(storagePath || '').replace(/^\/+/, '')
  return `${CDN}/${key.split('/').map(encodeURIComponent).join('/')}`
}

async function audioFor(storagePath) {
  const url = cdnUrl(storagePath)
  const head = await fetch(url, { method: 'HEAD' })
  if (!head.ok) throw new Error(`audio HEAD ${head.status} for ${url}`)
  const size = Number(head.headers.get('content-length')) || 0
  if (!size) throw new Error('audio has no content-length')
  if (size > MAX_AUDIO) throw new Error(`audio ${(size / 1048576).toFixed(1)} MB exceeds the 40 MB cap`)
  const res = await fetch(url)
  if (!res.ok) throw new Error(`audio GET ${res.status} for ${url}`)
  return Buffer.from(await res.arrayBuffer())
}

async function transcribe(audio, plainLyrics) {
  const q = new URLSearchParams({
    model: 'nova-3', language: 'te',
    smart_format: 'false', punctuate: 'false', utterances: 'false', diarize: 'false',
  })
  // Bias nova-3 towards this track's own lyric words (one repeat per term, as
  // Deepgram's keyterm docs require - never a comma/semicolon-joined value).
  for (const term of buildKeyterms(plainLyrics)) q.append('keyterm', term)
  const res = await fetch(`https://api.deepgram.com/v1/listen?${q}`, {
    method: 'POST',
    headers: { Authorization: `Token ${DG}`, 'Content-Type': 'application/octet-stream' },
    body: audio,
  })
  if (!res.ok) throw new Error(`deepgram ${res.status}: ${(await res.text()).slice(0, 200)}`)
  const j = await res.json()
  const alt = j?.results?.channels?.[0]?.alternatives?.[0]
  const words = Array.isArray(alt?.words)
    ? alt.words.map((w) => ({
        word: w.punctuated_word || w.word || '',
        start: Number(w.start) || 0,
        end: Number(w.end) || 0,
        confidence: typeof w.confidence === 'number' ? w.confidence : 0,
      }))
    : []
  return { words, duration: Number(j?.metadata?.duration) || null }
}

/**
 * Run the acoustic repeat detector (Python, docs/ACOUSTIC-REPEAT-DETECTION.md)
 * against a track's audio bytes. The detector reads the vocal-energy envelope
 * and returns spans where a stanza is sung again but Deepgram heard no words.
 *
 * Returns `{ repeats, error }` — `repeats` is the `repeats` array from the
 * detector's JSON, or `[]` when the detector cannot run (no ffmpeg/python),
 * in which case `error` is set and the pipeline continues with transcript-only
 * repeats (never a hard failure: acoustic recovery is additive).
 */
async function runAcoustic(audioBytes) {
  const tmp = path.join(os.tmpdir(), `soulful-bhakti-${Date.now()}-${Math.random().toString(36).slice(2)}.audio`)
  try {
    fs.writeFileSync(tmp, audioBytes)
    const script = path.join(TOOLS_DIR, 'acoustic-repeat-detect.py')
    const { stdout } = await execFileP('python3', [script, '--audio', tmp], { maxBuffer: 64 * 1024 * 1024 })
    const parsed = JSON.parse(stdout)
    process.stdout.write(`[acoustic] onsets=${parsed.onsets?.length ?? 0} repeats=${parsed.repeats?.length ?? 0}\n`)
    return Array.isArray(parsed.repeats) ? parsed.repeats : []
  } catch (err) {
    console.warn(`[acoustic] skipped for this track (${err && err.message ? err.message : err})`)
    return []
  } finally {
    fs.rmSync(tmp, { force: true })
  }
}

/** Count cues that carry SUNG text ({{Music}} banners are language scaffolding). */
function lyricCueCount(srt) {
  return parseSrtTimeline(srt).filter((c) => String(c.text || '').trim() !== '{{Music}}').length
}

/**
 * True when the stored SRT has a TIMING defect: overlapping or zero-duration cues,
 * a duplicate start, or a cue outside [0, duration]. These are the "TIMING
 * problems" the read-only verification reports, and a re-run that regenerates the
 * column cleanly may repair them even when the sung-cue count is unchanged.
 */
function hasTimingDefects(srt, duration) {
  const cues = parseSrtTimeline(srt)
  if (!cues.length) return false
  const starts = new Set()
  for (let i = 0; i < cues.length; i++) {
    const c = cues[i]
    if (c.end <= c.start) return true
    if (i > 0 && c.start < cues[i - 1].end) return true
  }
  const dur = Number(duration)
  for (const c of cues) {
    if (starts.has(c.start)) return true
    starts.add(c.start)
    if (Number.isFinite(dur) && dur > 0 && (c.start < 0 || c.end > dur + 0.5)) return true
  }
  return false
}

const SYNCED_COLUMNS = ['synced_lyrics', 'synced_lyrics_en', 'synced_lyrics_en_tr', 'synced_lyrics_hi', 'synced_lyrics_hi_tr']

// --- Restore mode -----------------------------------------------------------
// Writing 64 tracks with no way back is not a safe operation. Every write this
// tool makes is preceded by dumping the PREVIOUS value of each synced column it
// is about to touch, and this mode puts them back.
if (RESTORE) {
  const backup = JSON.parse(fs.readFileSync(String(RESTORE), 'utf8'))
  const ids = Object.keys(backup)
  console.log(`restoring ${ids.length} track(s) from ${RESTORE}`)
  let ok = 0
  for (const id of ids) {
    const patch = {}
    for (const c of SYNCED_COLUMNS) {
      if (Object.prototype.hasOwnProperty.call(backup[id], c)) patch[c] = backup[id][c]
    }
    if (!Object.keys(patch).length) continue
    await supaPatch(id, patch)
    ok += 1
    console.log(`  restored ${id}`)
  }
  console.log(`restored ${ok}/${ids.length}`)
  process.exit(0)
}

const rows = []
for (let from = 0; ; from += 500) {
  const page = await supaGet(`tracks?select=${FIELDS}&order=title.asc`, {
    Range: `${from}-${from + 499}`, 'Range-Unit': 'items',
  })
  rows.push(...page)
  if (page.length < 500) break
}

let targets = rows.filter((t) => String(t.plain_lyrics || '').trim() && String(t.storage_path || '').trim())
if (IDS.length) targets = targets.filter((t) => IDS.includes(String(t.id)))
if (LIMIT > 0) targets = targets.slice(0, LIMIT)

console.log(`tracks scanned: ${rows.length} · candidates: ${targets.length} · mode: ${WRITE ? 'WRITE' : 'DRY RUN'}`)
// Diagnostic: when `candidates` is 0 while rows exist, the runner is talking to
// a DIFFERENT Supabase project than the one holding the lyrics (typically a
// retired project ref in the `supabase/url` AWS secret). Print the resolved
// project host and how many rows actually carry lyric/audio data, so a stale
// secret is diagnosed from the log instead of guessed at.
console.log(`supabase project: ${SUPA.replace(/^https?:\/\//, '').split('.')[0]}`)
console.log(`rows with plain_lyrics: ${rows.filter((t) => String(t.plain_lyrics || '').trim()).length} · rows with storage_path: ${rows.filter((t) => String(t.storage_path || '').trim()).length}`)

const report = []
// Previous values of every column this run overwrites, so any write can be undone.
// Written to disk after EACH track, so a timeout mid-run still leaves a usable
// backup rather than only an in-memory one.
const backup = {}
for (const [i, t] of targets.entries()) {
  const rec = { id: t.id, title: t.title, action: 'skip', reason: null }
  try {
    const existingCues = parseSrtTimeline(t.synced_lyrics).length
    const audio = await audioFor(t.storage_path)
    if (!audio) { rec.reason = 'no audio'; report.push(rec); continue }

    const { words, duration } = await transcribe(audio, t.plain_lyrics)
    if (!words.length) { rec.reason = 'no words heard'; report.push(rec); continue }

    // The DATABASE duration is what the app draws and where the audit measures
    // "in range". Deepgram's measured length can exceed it (it sees the audio,
    // not the stored number), which produced `out_of_range` cues that run past
    // the track's displayed end. Clamp the timeline to the stored duration so a
    // cue can never outlive what the player shows.
    const storedDur = Number(t.duration) > 0 ? Number(t.duration) : null
    const measuredDur = Number(duration) > 0 ? Number(duration) : null
    const ceiling = (storedDur && measuredDur) ? Math.min(storedDur, measuredDur) : (storedDur || measuredDur || null)

    const alignment = alignLyrics({
      plainLyrics: t.plain_lyrics,
      words,
      audioDuration: ceiling,
    })
    const totalLines = splitLyricLines(t.plain_lyrics).length
    // Acoustic repeat recovery: spans where a stanza is sung again but Deepgram
    // heard no words. Additive only — a detector failure leaves transcript-only
    // repeats and never aborts the build.
    const acousticRepeats = ACOUSTIC ? await runAcoustic(audio) : []
    const build = buildSyncCues({
      plainLyrics: t.plain_lyrics,
      alignment,
      words,
      audioDuration: ceiling,
      acousticRepeats,
    })
    if (!build.cues.length) { rec.reason = 'no cues built'; report.push(rec); continue }

    const payload = {
      synced_lyrics: renderCuesForVariant(build.cues, t.plain_lyrics, totalLines),
    }
    if (String(t.plain_lyrics_en || '').trim()) {
      payload.synced_lyrics_en = renderCuesForVariant(build.cues, t.plain_lyrics_en, totalLines)
    }
    if (String(t.plain_lyrics_en_tr || '').trim()) {
      payload.synced_lyrics_en_tr = renderCuesForVariant(build.cues, t.plain_lyrics_en_tr, totalLines)
    }

    const newCues = parseSrtTimeline(payload.synced_lyrics).length
    // The decision is made on SUNG cues only. The new timeline also inserts
    // {{Music}} banners, which inflate the total: comparing totals would let a
    // track be "upgraded" merely because banners were added, replacing timings
    // that may already be better than anything ASR can produce. Only a strict
    // gain in SUNG cues - i.e. genuinely recovered repeated lines - may replace.
    const existingLyric = lyricCueCount(t.synced_lyrics)
    const newLyric = lyricCueCount(payload.synced_lyrics)
    rec.existing_cues = existingCues
    rec.new_cues = newCues
    rec.existing_lyric_cues = existingLyric
    rec.new_lyric_cues = newLyric
    rec.banners_added = Math.max(0, newCues - newLyric) - Math.max(0, existingCues - existingLyric)
    rec.repeats = build.repeatCueCount
    rec.music = build.musicCueCount
    rec.acoustic_repeats = acousticRepeats.length
    rec.acoustic_error_bound_s = acousticRepeats.length
      ? Math.max(...acousticRepeats.map((r) => Math.max(r.a?.error ?? 0, r.b?.error ?? 0)))
      : 0
    // Measured coverage: what share of distinct plain-lyric lines got >=1 cue.
    const plainTexts = splitLyricLines(t.plain_lyrics)
    const timedTexts = new Set(parseSrtTimeline(payload.synced_lyrics).map((c) => String(c.text || '').trim()))
    const timedCount = plainTexts.filter((l) => timedTexts.has(l.trim())).length
    rec.coverage_pct = plainTexts.length
      ? Number(((timedCount / plainTexts.length) * 100).toFixed(1))
      : 0

    // The one rule that makes a catalogue-wide rewrite safe, now two-part:
    //   * strictly more SUNG cues (recovered repeats), OR
    //   * the STORED timeline has a timing defect and the new one is structurally
    //     clean (this repairs the 31 tracks the verification flagged with
    //     overlapping / zero-duration / duplicate / out-of-range cues).
    const existingDefective = hasTimingDefects(t.synced_lyrics, t.duration)
    const newDefective = hasTimingDefects(payload.synced_lyrics, t.duration)
    rec.existing_timing_defect = existingDefective
    rec.new_timing_defect = newDefective

    const gain = newLyric > existingLyric
    const repair = existingDefective && !newDefective
    if (!gain && !repair) {
      rec.action = 'keep'
      rec.reason = `no sung-cue gain (${existingLyric} -> ${newLyric})`
      report.push(rec)
      continue
    }

    rec.action = WRITE ? 'written' : 'would_write'
    if (WRITE) {
      // Capture what is about to be replaced BEFORE replacing it.
      backup[t.id] = {}
      for (const c of Object.keys(payload)) backup[t.id][c] = t[c] ?? null
      await supaPatch(t.id, payload)
      fs.writeFileSync(BACKUP, JSON.stringify(backup, null, 2))
    }
  } catch (err) {
    rec.action = 'error'
    rec.reason = String(err && err.message).slice(0, 180)
  }
  report.push(rec)
  console.log(`[${i + 1}/${targets.length}] ${rec.action.padEnd(12)} ${t.title || t.id}  sung ${rec.existing_lyric_cues ?? '?'} -> ${rec.new_lyric_cues ?? '?'} (total ${rec.existing_cues ?? '?'} -> ${rec.new_cues ?? '?'}, banners +${rec.banners_added ?? 0})  ${rec.reason || ''}`)
  await new Promise((r) => setTimeout(r, 50))
}

const summary = {
  generated_at: new Date().toISOString(),
  mode: WRITE ? 'write' : 'dry_run',
  scanned: rows.length,
  candidates: targets.length,
  written: report.filter((r) => r.action === 'written').length,
  would_write: report.filter((r) => r.action === 'would_write').length,
  kept: report.filter((r) => r.action === 'keep').length,
  errors: report.filter((r) => r.action === 'error').length,
  skipped: report.filter((r) => r.action === 'skip').length,
  // Gain in SUNG cues only - the number that represents recovered repeats.
  total_lyric_cues_gained: report.reduce((a, r) => a + Math.max(0, (r.new_lyric_cues || 0) - (r.existing_lyric_cues || 0)), 0),
  // Measured coverage across written tracks (honest, not a "100%" stamp).
  avg_coverage_pct_written: (() => {
    const w = report.filter((r) => r.coverage_pct != null)
    return w.length ? Number((w.reduce((a, r) => a + r.coverage_pct, 0) / w.length).toFixed(1)) : null
  })(),
  detail: report,
}
fs.writeFileSync(OUT, JSON.stringify(summary, null, 2))
console.log('\n' + JSON.stringify({ ...summary, detail: undefined }, null, 2))
console.log(WRITE ? '\nWROTE to the database.' : '\nDRY RUN - nothing was written.')
