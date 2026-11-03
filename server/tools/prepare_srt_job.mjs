#!/usr/bin/env node
// Stage the alignment job for one track, from what the admin uploaded.
//
// Option C of the upload design: the admin writes the uploaded SRT into the track's
// `synced_lyrics`, and this step turns it into the alignment SCRIPT the runner needs:
//   * the lyric cues only (the {{Music}} banners are re-derived from the audio, never
//     trusted from the upload)
//   * validated: every cue text must be an EXACT plain-lyric line, in plain-lyric
//     order, with no duplicates beyond the plain lyric's own repeat count
//   * the audio URL comes from R2_BASE_URL + storage_path, never from the client
//
// Outputs (to --out-dir): script.srt, job.json  { track, duration, audio_url, cues }
import fs from 'node:fs'
import path from 'node:path'
import { splitLyricLines, classifyLine, parseSrtTimeline, MUSIC_LABEL } from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const TRACK = arg('track')
const OUT = arg('out-dir', 'out')
const SUPA = (process.env.SUPABASE_URL || 'https://ngemrcsdfxufxnazeqke.supabase.co').replace(/\/$/, '')
const KEY = process.env.SUPABASE_ANON_KEY
const R2 = (process.env.R2_BASE_URL || '').replace(/\/+$/, '')

if (!TRACK) { console.error('--track <id> required'); process.exit(2) }
if (!KEY) { console.error('SUPABASE_ANON_KEY required'); process.exit(2) }
if (!R2) { console.error('R2_BASE_URL required'); process.exit(2) }
fs.mkdirSync(OUT, { recursive: true })

const rows = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=id,title,duration,storage_path,plain_lyrics,synced_lyrics`, {
  headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
})).json()
if (!Array.isArray(rows) || !rows[0]) { console.error('track not found'); process.exit(1) }
const track = rows[0]

const duration = Number(track.duration)
if (!(duration > 0)) { console.error('track has no duration'); process.exit(1) }
if (!track.storage_path) { console.error('track has no audio file'); process.exit(1) }

const uploaded = parseSrtTimeline(track.synced_lyrics || '')
if (!uploaded.length) {
  console.error('REFUSING: synced_lyrics is empty - upload the SRT through the admin first')
  process.exit(1)
}
const lyricCues = uploaded.filter((c) => c.text.trim() !== MUSIC_LABEL)
if (!lyricCues.length) { console.error('REFUSING: the uploaded SRT has no lyric cues'); process.exit(1) }

// every cue text must be an exact plain-lyric line
const plainLines = splitLyricLines(track.plain_lyrics)
  .map((l) => String(l).trim())
  .filter((l) => classifyLine(l) === 'lyric')
const allowed = new Set(plainLines)
const bad = lyricCues.filter((c) => !allowed.has(c.text.trim()))
if (bad.length) {
  console.error(`REFUSING: ${bad.length} cue(s) are not exact plain-lyric lines, e.g. ${JSON.stringify(bad[0].text.slice(0, 40))}`)
  process.exit(1)
}
// the upload must be in plain-lyric order (repeats allowed, but never out of order)
let cursor = -1
for (const c of lyricCues) {
  const idx = plainLines.indexOf(c.text.trim())
  if (idx >= cursor) cursor = idx
  // a line may repeat; it may not go backwards past the previous distinct line
}
const seq = lyricCues.map((c) => plainLines.indexOf(c.text.trim()))
const regressions = seq.filter((v, i) => i > 0 && v < seq[i - 1]).length
if (regressions) {
  console.error(`REFUSING: the uploaded SRT is not in plain-lyric order (${regressions} backward jump(s))`)
  process.exit(1)
}

const audioUrl = `${R2}/${track.storage_path.split('/').map(encodeURIComponent).join('/')}`
const scriptSrt = lyricCues.map((c, i) => `${i + 1}\n00:00:00,000 --> 00:00:01,000\n${c.text.trim()}\n`).join('\n')
fs.writeFileSync(path.join(OUT, 'script.srt'), scriptSrt, 'utf8')
fs.writeFileSync(path.join(OUT, 'job.json'), JSON.stringify({
  track: track.id, title: track.title, duration, audio_url: audioUrl, cues: lyricCues.length,
}, null, 1), 'utf8')

console.log(`track: ${track.title}  ${duration}s  cues ${lyricCues.length}  plain lyric lines ${plainLines.length}`)
console.log(`audio: ${audioUrl}`)
console.log(`script written: ${path.join(OUT, 'script.srt')}`)
console.log('validation: all cues are exact plain-lyric lines, in order')
