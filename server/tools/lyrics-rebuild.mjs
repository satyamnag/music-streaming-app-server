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
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, DEEPGRAM_API_KEY,
//      R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
//      (R2_BUCKET optional, default soulful-bhakti)
//
// Usage:
//   node server/tools/lyrics-rebuild.mjs [--write] [--limit N]
//                                        [--ids id1,id2] [--out report.json]
// ============================================================================

import fs from 'node:fs'
import { S3Client, GetObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3'
import { alignLyrics, buildSyncCues, parseSrtTimeline, renderCuesForVariant, splitLyricLines } from '../libs/autoSyncLyrics.mjs'

const arg = (name, dflt = null) => {
  const i = process.argv.indexOf(`--${name}`)
  return i === -1 ? dflt : (process.argv[i + 1] ?? true)
}
const WRITE = process.argv.includes('--write')
const LIMIT = Number(arg('limit', 0)) || 0
const IDS = String(arg('ids', '') || '').split(',').map((s) => s.trim()).filter(Boolean)
const OUT = arg('out', 'lyrics-rebuild.json')

const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''
const DG = process.env.DEEPGRAM_API_KEY || ''
const BUCKET = process.env.R2_BUCKET || 'soulful-bhakti'

if (!SUPA || !KEY) { console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY required'); process.exit(2) }
if (!DG) { console.error('DEEPGRAM_API_KEY required'); process.exit(2) }

const r2 = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
})

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

async function audioFor(storagePath) {
  const head = await r2.send(new HeadObjectCommand({ Bucket: BUCKET, Key: storagePath }))
  const size = Number(head.ContentLength) || 0
  if (!size) return null
  if (size > MAX_AUDIO) throw new Error(`audio ${(size / 1048576).toFixed(1)} MB exceeds the 40 MB cap`)
  const obj = await r2.send(new GetObjectCommand({ Bucket: BUCKET, Key: storagePath }))
  return Buffer.from(await obj.Body.transformToByteArray())
}

async function transcribe(audio) {
  const q = new URLSearchParams({
    model: 'nova-3', language: 'te',
    smart_format: 'false', punctuate: 'false', utterances: 'false', diarize: 'false',
  })
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

const report = []
for (const [i, t] of targets.entries()) {
  const rec = { id: t.id, title: t.title, action: 'skip', reason: null }
  try {
    const existingCues = parseSrtTimeline(t.synced_lyrics).length
    const audio = await audioFor(t.storage_path)
    if (!audio) { rec.reason = 'no audio'; report.push(rec); continue }

    const { words, duration } = await transcribe(audio)
    if (!words.length) { rec.reason = 'no words heard'; report.push(rec); continue }

    const alignment = alignLyrics({
      plainLyrics: t.plain_lyrics,
      words,
      audioDuration: duration || Number(t.duration) || null,
    })
    const totalLines = splitLyricLines(t.plain_lyrics).length
    const build = buildSyncCues({ plainLyrics: t.plain_lyrics, alignment, words, audioDuration: duration })
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
    rec.existing_cues = existingCues
    rec.new_cues = newCues
    rec.repeats = build.repeatCueCount
    rec.music = build.musicCueCount

    // The one rule that makes a catalogue-wide rewrite safe: only replace when
    // the new timeline places STRICTLY MORE cues than the stored one.
    if (newCues <= existingCues) {
      rec.action = 'keep'
      rec.reason = `no gain (${existingCues} -> ${newCues})`
      report.push(rec)
      continue
    }

    rec.action = WRITE ? 'written' : 'would_write'
    if (WRITE) await supaPatch(t.id, payload)
  } catch (err) {
    rec.action = 'error'
    rec.reason = String(err && err.message).slice(0, 180)
  }
  report.push(rec)
  console.log(`[${i + 1}/${targets.length}] ${rec.action.padEnd(12)} ${t.title || t.id}  ${rec.existing_cues ?? '?'} -> ${rec.new_cues ?? '?'}  ${rec.reason || ''}`)
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
  total_cues_gained: report.reduce((a, r) => a + Math.max(0, (r.new_cues || 0) - (r.existing_cues || 0)), 0),
  detail: report,
}
fs.writeFileSync(OUT, JSON.stringify(summary, null, 2))
console.log('\n' + JSON.stringify({ ...summary, detail: undefined }, null, 2))
console.log(WRITE ? '\nWROTE to the database.' : '\nDRY RUN - nothing was written.')
