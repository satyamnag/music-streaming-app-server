// Repair the TEXT of a sync column without touching a single timestamp.
//
// Purpose: the owner's rule is "plain lyrics spellings are the text of record,
// sync lyrics timestamps are the timing of record". When a sync column drifts in
// spelling, the variants cannot be rendered from it (their cue text no longer maps
// to a plain line). This tool re-spells such cues back to the plain wording and
// writes ONLY the requested column.
//
// Gates, all asserted before anything is written:
//   * the supplied SRT has exactly the same cue count as the stored column;
//   * EVERY start and end matches the stored column to within 0.5 ms - timings are
//     immutable, which is why this cannot be done through finalize_payload.mjs
//     (that tool also demands contiguity and the canonical {{Music}} label);
//   * every changed cue is a re-spelling: its OLD text is not an exact plain line
//     and its NEW text is, so this can never rewrite a lyric into something new;
//   * music-banner rows keep their stored text exactly;
//   * every plain lyric line the stored column covered is still covered.
//
//   node write-timeline-text.mjs --track <uuid> --srt <file> [--write]
import fs from 'node:fs'
import {
  parseSrtTimeline,
  splitLyricLines,
  classifyLine,
  MUSIC_LABEL,
} from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const TRACK = arg('track')
const SRT = arg('srt')
const WRITE = process.argv.includes('--write')
const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const ANON = process.env.SUPABASE_ANON_KEY || ''
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY || ''

const fail = (m) => { console.error('FAIL: ' + m); process.exit(1) }
if (!TRACK) fail('--track <uuid> required')
if (!SRT) fail('--srt <file> required')
if (!SUPA || !ANON) fail('SUPABASE_URL + SUPABASE_ANON_KEY required')
if (WRITE && !SERVICE) fail('SUPABASE_SERVICE_ROLE_KEY required for --write')
if (!fs.existsSync(SRT)) fail(`--srt ${SRT} not found`)

const read = { apikey: ANON, Authorization: `Bearer ${ANON}` }
const sel = 'title,duration,plain_lyrics,synced_lyrics,synced_lyrics_en,synced_lyrics_en_tr'
const [row] = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=${sel}`, { headers: read })).json()
if (!row) fail('track not found')

const stored = parseSrtTimeline(row.synced_lyrics || '')
const supplied = parseSrtTimeline(fs.readFileSync(SRT, 'utf8'))
if (!stored.length) fail('stored synced_lyrics is empty')
if (supplied.length !== stored.length) fail(`supplied SRT has ${supplied.length} cues, stored column has ${stored.length}`)

const plainLines = splitLyricLines(row.plain_lyrics).filter((l) => classifyLine(l) === 'lyric')
if (!plainLines.length) fail('plain_lyrics has no lyric lines')
const plainSet = new Set(plainLines)
const isBanner = (t) => classifyLine(t) === 'music'

// ---- gates ------------------------------------------------------------------
let timeMoved = 0
for (let i = 0; i < stored.length; i++) {
  if (Math.abs(supplied[i].start - stored[i].start) > 0.0005 || Math.abs(supplied[i].end - stored[i].end) > 0.0005) timeMoved++
}
if (timeMoved) fail(`${timeMoved} cue(s) changed timing - this tool never moves a timestamp`)

const changes = []
let bannerDrift = 0
for (let i = 0; i < stored.length; i++) {
  const a = String(stored[i].text || '').trim()
  const b = String(supplied[i].text || '').trim()
  if (a === b) continue
  if (isBanner(a) || isBanner(b)) { bannerDrift++; continue }
  if (plainSet.has(a)) fail(`cue ${i + 1} would rewrite a plain line: ${JSON.stringify(a)} -> ${JSON.stringify(b)}`)
  if (!plainSet.has(b)) fail(`cue ${i + 1} new text is not an exact plain line: ${JSON.stringify(b)}`)
  changes.push({ i: i + 1, from: a, to: b })
}
if (bannerDrift) fail(`${bannerDrift} music banner(s) changed text - banners are not re-spelled by this tool`)

// coverage: a re-spelling can only turn a non-plain text INTO a plain line, so the
// set of exactly-cued plain lines must only grow. A line that stops being cued
// exactly would mean a correct cue was replaced - refuse that.
const exact = (cues) => new Set(cues
  .filter((c) => !isBanner(String(c.text || '')) && plainSet.has(String(c.text || '').trim()))
  .map((c) => String(c.text || '').trim()))
const before = exact(stored)
const after = exact(supplied)
const lost = [...before].filter((t) => !after.has(t))
if (lost.length) fail(`${lost.length} plain line(s) are no longer cued exactly: ${lost.slice(0, 3).join(' | ')}`)
const gained = [...after].filter((t) => !before.has(t))
if (gained.length !== new Set(changes.map((c) => c.to)).size) {
  fail(`${gained.length} newly-cued plain line(s) but only ${new Set(changes.map((c) => c.to)).size} distinct re-spelling target(s)`)
}

const music = supplied.filter((c) => isBanner(String(c.text || ''))).length
const sung = supplied.length - music
console.log(`${row.title}   ${supplied.length} cues (${sung} sung, ${music} banners)   duration ${row.duration}`)
console.log(`timings: ${supplied.length}/${supplied.length} identical to the stored column`)
console.log(`coverage: ${after.size}/${plainLines.length} plain lyric lines cued\n`)

console.log(`re-spellings (${changes.length} cue(s)):`)
const byPair = new Map()
for (const c of changes) {
  const k = `${c.from}\u0000${c.to}`
  byPair.set(k, (byPair.get(k) || 0) + 1)
}
for (const [k, n] of byPair) {
  const [from, to] = k.split('\u0000')
  console.log(`  ${String(n).padStart(2)}x  ${from}\n       -> ${to}`)
}

if (!changes.length) {
  console.log('\nnothing to change: the supplied SRT already equals the stored column.')
  process.exit(0)
}
if (!WRITE) {
  console.log('\nDRY RUN - nothing written. Re-run with --write to apply.')
  process.exit(0)
}

// ---- write ------------------------------------------------------------------
const backup = {
  track: row.title,
  id: TRACK,
  column: 'synced_lyrics',
  before: { synced_lyrics: row.synced_lyrics },
}
fs.writeFileSync('sync-text-backup.json', JSON.stringify(backup, null, 2))
console.log('\nbackup written to sync-text-backup.json')

const patch = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}`, {
  method: 'PATCH',
  headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({ synced_lyrics: fs.readFileSync(SRT, 'utf8') }),
})
console.log(`PATCH http=${patch.status}`)
if (!patch.ok) { console.error((await patch.text()).slice(0, 300)); process.exit(1) }

const [back] = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=synced_lyrics`, { headers: read })).json()
const same = String(back.synced_lyrics) === fs.readFileSync(SRT, 'utf8')
console.log(`read-back synced_lyrics identical: ${same}`)
if (!same) { console.error('READ-BACK MISMATCH'); process.exit(1) }
console.log('WROTE synced_lyrics; read-back matches exactly.')
