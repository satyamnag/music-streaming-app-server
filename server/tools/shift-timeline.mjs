#!/usr/bin/env node
// Shift a track's whole sync timeline by a constant offset, for every language
// column at once, and prove nothing else changed.
//
// WHY A SINGLE TRANSFORM FOR ALL THREE COLUMNS
// The app stacks languages per row, so the three columns must share one timeline
// exactly. Shifting one column alone would desynchronise them. This reads all three,
// applies the same integer-millisecond offset, and writes them in ONE PATCH.
//
// WHAT MOVES
//   * every sung cue start/end moves by exactly `--shift` seconds (negative = earlier)
//   * the timeline must still start at 0 and end at the track duration, so the head
//     music cue's start is clamped to 0 and the tail music cue's end to the duration
//   * text is never touched, cue count never changes, contiguity is preserved
//
// GUARDS (the script refuses otherwise)
//   * the three columns must already share the same cue count, the same start/end at
//     every index, and the same music mask
//   * after shifting: no negative time, still contiguous, still 0 -> duration, and
//     every sung cue moved by exactly the requested offset
//
//   node shift-timeline.mjs --track <id> --shift -0.5            dry run
//   node shift-timeline.mjs --track <id> --shift -0.5 --write    apply (service role)
import crypto from 'node:crypto'
import fs from 'node:fs'
import { parseSrtTimeline, MUSIC_LABEL } from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const TRACK = arg('track')
const OFFSET_S = Number(arg('shift', 0))
const WRITE = process.argv.includes('--write')
const SUPA = (process.env.SUPABASE_URL || 'https://ngemrcsdfxufxnazeqke.supabase.co').replace(/\/$/, '')
const READ_KEY = process.env.SUPABASE_ANON_KEY
const WRITE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!TRACK) { console.error('--track <id> required'); process.exit(2) }
if (!OFFSET_S) { console.error('--shift <seconds> required (e.g. -0.5)'); process.exit(2) }
if (!READ_KEY) { console.error('SUPABASE_ANON_KEY required'); process.exit(2) }

const OFFSET_MS = Math.round(OFFSET_S * 1000)
const COLS = [
  ['synced_lyrics', 'te'],
  ['synced_lyrics_en', 'en'],
  ['synced_lyrics_en_tr', 'en_tr'],
]
const sha = (s) => crypto.createHash('sha256').update(s).digest('hex')
const ms = (sec) => Math.round(sec * 1000)
const fmt = (msv) => {
  const h = Math.floor(msv / 3600000)
  const m = Math.floor((msv % 3600000) / 60000)
  const s = Math.floor((msv % 60000) / 1000)
  const r = msv % 1000
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(r).padStart(3, '0')}`
}
const render = (cues) => cues.map((c, i) => `${i + 1}\n${fmt(c.s)} --> ${fmt(c.e)}\n${c.text}\n`).join('\n')

// --- read ------------------------------------------------------------------
const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=title,duration,${COLS.map((c) => c[0]).join(',')}`, {
  headers: { apikey: READ_KEY, Authorization: `Bearer ${READ_KEY}` },
})
const rows = await res.json()
if (!Array.isArray(rows) || !rows[0]) { console.error('track not found'); process.exit(2) }
const row = rows[0]
const durationMs = Math.round(Number(row.duration) * 1000)
console.log(`${row.title}  duration ${row.duration}s  shift ${OFFSET_S}s (${OFFSET_MS}ms)`)

// parse every column into {s,e,text} in integer ms
const cols = {}
for (const [field, tag] of COLS) {
  const parsed = parseSrtTimeline(row[field] || '')
  if (!parsed.length) { console.error(`REFUSING: ${field} is empty`); process.exit(1) }
  cols[tag] = { field, cues: parsed.map((c) => ({ s: ms(c.start), e: ms(c.end), text: c.text.trim() })) }
}

// --- preconditions: the columns already share one timeline -----------------
const te = cols.te.cues
let fail = 0
const failIf = (cond, msg) => { if (cond) { console.error(`REFUSING: ${msg}`); fail++ } }
for (const tag of ['en', 'en_tr']) {
  const c = cols[tag].cues
  failIf(c.length !== te.length, `${tag} has ${c.length} cues vs te ${te.length}`)
  if (c.length !== te.length) continue
  for (let i = 0; i < te.length; i++) {
    failIf(c[i].s !== te[i].s || c[i].e !== te[i].e, `${tag} cue ${i + 1} timing differs from te`)
    failIf((c[i].text === MUSIC_LABEL) !== (te[i].text === MUSIC_LABEL), `${tag} cue ${i + 1} music mask differs`)
  }
}
failIf(te[0].s !== 0, `timeline does not start at 0 (${te[0].s}ms)`)
failIf(Math.abs(te[te.length - 1].e - durationMs) > 50, `timeline does not end at the duration (${te[te.length - 1].e} vs ${durationMs}ms)`)
if (fail) process.exit(1)

// --- shift -----------------------------------------------------------------
function shift(cues) {
  const out = cues.map((c) => ({ s: c.s + OFFSET_MS, e: c.e + OFFSET_MS, text: c.text }))
  out[0].s = 0                       // head stays anchored at 0
  out[out.length - 1].e = durationMs // tail stays anchored at the duration
  return out
}

const shifted = {}
for (const [field, tag] of COLS) shifted[tag] = shift(cols[tag].cues)

// --- post-conditions -------------------------------------------------------
for (const [field, tag] of COLS) {
  const before = cols[tag].cues
  const after = shifted[tag]
  failIf(after.length !== before.length, `${tag} cue count changed`)
  failIf(after[0].s !== 0, `${tag} no longer starts at 0`)
  failIf(after[after.length - 1].e !== durationMs, `${tag} no longer ends at the duration`)
  for (let i = 0; i < after.length; i++) {
    failIf(after[i].e <= after[i].s, `${tag} cue ${i + 1} not positive duration`)
    if (i) failIf(after[i].s !== after[i - 1].e, `${tag} cue ${i + 1} not contiguous`)
    failIf(after[i].text !== before[i].text, `${tag} cue ${i + 1} text changed`)
    // every SUNG cue must move by exactly the offset
    if (before[i].text !== MUSIC_LABEL) {
      failIf(after[i].s - before[i].s !== OFFSET_MS, `${tag} cue ${i + 1} did not move by ${OFFSET_MS}ms`)
    }
  }
}
// cross-column identity after the shift
for (const tag of ['en', 'en_tr']) {
  for (let i = 0; i < te.length; i++) {
    failIf(shifted[tag][i].s !== shifted.te[i].s || shifted[tag][i].e !== shifted.te[i].e,
      `${tag} cue ${i + 1} diverged from te after the shift`)
  }
}
if (fail) process.exit(1)

// --- show ------------------------------------------------------------------
const musicIdx = te.map((c, i) => (c.text === MUSIC_LABEL ? i : -1)).filter((i) => i >= 0)
console.log(`\nsung cues: ${te.length - musicIdx.length}   music cues: ${musicIdx.length}   (only the head/tail music cues change length)`)
console.log('\n  #   before                  after                   delta    text')
const shown = new Set([0, 1, 2, ...musicIdx, te.length - 2, te.length - 1])
for (const i of [...shown].sort((a, b) => a - b)) {
  const b = te[i], a = shifted.te[i]
  const d = a.s - b.s
  console.log(`${String(i + 1).padStart(3)}  ${(b.s / 1000).toFixed(3)}-${(b.e / 1000).toFixed(3)}`.padEnd(27)
    + `${(a.s / 1000).toFixed(3)}-${(a.e / 1000).toFixed(3)}`.padEnd(24)
    + `${d >= 0 ? '+' : ''}${d}ms`.padEnd(9) + (b.text === MUSIC_LABEL ? '[music]' : b.text.slice(0, 30)))
}

const payload = {}
const hashes = {}
for (const [field, tag] of COLS) {
  payload[field] = render(shifted[tag])
  hashes[tag] = { before: sha(row[field]), after: sha(payload[field]) }
}
console.log('\ncolumn hashes (before -> after):')
for (const tag of ['te', 'en', 'en_tr']) console.log(`  ${tag.padEnd(6)} ${hashes[tag].before.slice(0, 16)}… -> ${hashes[tag].after.slice(0, 16)}…`)

if (!WRITE) {
  console.log('\nDRY RUN - nothing written. Re-run with --write to apply.')
  process.exitCode = 0
} else {
  if (!WRITE_KEY) { console.error('SUPABASE_SERVICE_ROLE_KEY required for --write'); process.exit(2) }
  fs.writeFileSync('shift-backup.json', JSON.stringify({
    track: TRACK, title: row.title, offset_ms: OFFSET_MS,
    before: Object.fromEntries(COLS.map(([f, t]) => [t, row[f]])),
  }, null, 1), 'utf8')
  console.log('\nbackup written to shift-backup.json')

  const patch = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}`, {
    method: 'PATCH',
    headers: {
      apikey: WRITE_KEY, Authorization: `Bearer ${WRITE_KEY}`,
      'Content-Type': 'application/json', Prefer: 'return=minimal',
    },
    body: JSON.stringify(payload),
  })
  console.log(`PATCH http=${patch.status}`)
  if (!patch.ok) { console.error((await patch.text()).slice(0, 300)); process.exit(1) }

  // read back and re-verify from the database
  const back = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=${COLS.map((c) => c[0]).join(',')}`, {
    headers: { apikey: READ_KEY, Authorization: `Bearer ${READ_KEY}` },
  })).json()
  const got = back[0]
  let ok = true
  for (const [field, tag] of COLS) {
    const same = sha(String(got[field] || '').trim()) === sha(payload[field].trim())
    console.log(`read-back ${tag.padEnd(6)} identical: ${same}`)
    if (!same) ok = false
  }
  console.log(ok ? '\nWROTE all three columns; read-back matches exactly.' : '\nREAD-BACK MISMATCH')
  process.exitCode = ok ? 0 : 1
}
