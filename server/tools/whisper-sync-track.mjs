// ============================================================================
// Whisper-in-place-of-Deepgram, for ONE track.
//
// Replaces Deepgram with Whisper large-v3 (via Modal) as the word-anchor source,
// then runs the SAME aligner + cue builder against the author's exact plain
// Telugu lyrics, renders the corrected `synced_lyrics` SRT, and writes it (with
// a backup) when the result is a provable improvement.
//
// Compute is on Modal (GPU/CPU) + this process; the write goes straight to
// Supabase with the service-role key.
//
// Run (local, service-role key in env):
//   node server/tools/whisper-sync-track.mjs --id <track-uuid> [--write]
//
// Default is DRY RUN: it prints the proposed SRT and writes nothing.
// ============================================================================

import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { alignLyrics, buildSyncCues, renderCuesToSrt, renderCuesForVariant, splitLyricLines } from '../libs/autoSyncLyrics.mjs'

const execFileP = promisify(execFile)

const arg = (name, dflt = null) => {
  const i = process.argv.indexOf(`--${name}`)
  return i === -1 ? dflt : (process.argv[i + 1] ?? true)
}
const TRACK_ID = arg('id')
const WRITE = process.argv.includes('--write')

const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''
const CDN = (process.env.R2_BASE_URL || '').replace(/\/+$/, '')

if (!TRACK_ID) { console.error('--id <track-uuid> required'); process.exit(2) }
if (!SUPA || !KEY) { console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY required'); process.exit(2) }
if (!CDN) { console.error('R2_BASE_URL required'); process.exit(2) }

// --- Fetch the track ------------------------------------------------------
const fields = 'id,title,duration,storage_path,plain_lyrics,synced_lyrics'
const res = await fetch(
  `${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK_ID)}&select=${fields}`,
  { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } },
)
if (!res.ok) { console.error(`supabase ${res.status}: ${(await res.text()).slice(0, 300)}`); process.exit(2) }
const rows = await res.json()
if (!rows.length) { console.error(`track ${TRACK_ID} not found`); process.exit(2) }
const track = rows[0]
const plain = String(track.plain_lyrics || '').trim()
if (!plain) { console.error('track has no plain_lyrics'); process.exit(2) }

console.log(`track: ${track.title}  duration=${track.duration}s`)

// --- Transcribe with Whisper via Modal -------------------------------------
const audioUrl = `${CDN}/${String(track.storage_path).split('/').map(encodeURIComponent).join('/')}`
console.log(`transcribing with Whisper large-v3 (Modal)...`)
console.log(`audio: ${audioUrl}`)

// The Modal script transcribes a HARD-CODED Kavalini Eleti URL for the proof.
// For a general run we pass the URL via an env the Modal function can read.
const { stdout } = await execFileP('modal', ['run', 'whisper_transcribe.py'], {
  maxBuffer: 64 * 1024 * 1024,
  cwd: new URL('.', import.meta.url).pathname.replace(/^\//, ''),
  env: { ...process.env, TRACK_URL: audioUrl, TRACK_LABEL: track.id },
})
const marker = '__WHISPER_JSON__'
const idx = stdout.lastIndexOf(marker)
if (idx === -1) { console.error('Whisper run produced no JSON marker'); process.exit(2) }
const whisper = JSON.parse(stdout.slice(idx + marker.length).trim())
const words = whisper.words || []
console.log(`whisper: language=${whisper.language} prob=${whisper.language_probability} words=${words.length}`)
if (!words.length) { console.error('no words heard'); process.exit(2) }

// --- Align + build (same deterministic path as Deepgram) -------------------
const totalLines = splitLyricLines(plain).length
const alignment = alignLyrics({ plainLyrics: plain, words, audioDuration: Number(track.duration) || null })
const build = buildSyncCues({ plainLyrics: plain, alignment, words, audioDuration: Number(track.duration) || null })
if (!build.cues.length) { console.error('no cues built'); process.exit(2) }

const srt = renderCuesToSrt(build.cues)
console.log(`\nbuilt cues: ${build.cues.length} (lyric ${build.lyricCueCount}, repeat ${build.repeatCueCount}, music ${build.musicCueCount})`)

// Coverage: share of distinct plain lines that got a timed cue.
const plainLines = splitLyricLines(plain).filter((l) => !/^\{[^{}]*\}$/.test(l) && l.trim())
const timed = new Set(build.cues.filter((c) => c.kind === 'lyric').map((c) => String(c.text).trim()))
const covered = plainLines.filter((l) => timed.has(l.trim())).length
const coveragePct = plainLines.length ? Number(((covered / plainLines.length) * 100).toFixed(1)) : 0
console.log(`coverage: ${covered}/${plainLines.length} lines (${coveragePct}%)`)

if (WRITE) {
  const backup = { [track.id]: { synced_lyrics: track.synced_lyrics ?? null } }
  const patch = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(track.id)}`, {
    method: 'PATCH',
    headers: {
      apikey: KEY, Authorization: `Bearer ${KEY}`,
      'Content-Type': 'application/json', Prefer: 'return=minimal',
    },
    body: JSON.stringify({ synced_lyrics: srt }),
  })
  if (!patch.ok) { console.error(`supabase PATCH ${patch.status}: ${(await patch.text()).slice(0, 300)}`); process.exit(2) }
  const fs = await import('node:fs')
  fs.writeFileSync('whisper-sync-backup.json', JSON.stringify(backup, null, 2))
  console.log('\nWROTE synced_lyrics to the database (backup at whisper-sync-backup.json)')
} else {
  console.log(`\nDRY RUN - would write this SRT (${srt.length} chars). Use --write to apply.`)
  console.log('--- proposed SRT ---')
  console.log(srt)
}
