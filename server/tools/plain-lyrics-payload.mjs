#!/usr/bin/env node
// ============================================================================
// Build the PATCH body for the three PLAIN lyric columns of one track, after
// proving that the row has not moved since the text was reviewed.
//
// WHY THIS EXISTS
// ---------------
// Every other writer in this repo touches only the `synced_*` columns. The plain
// columns are the owner's text of record, and they are normally edited in the admin
// app - but a corrected set of plain lyrics for Maa Inti Daivama repeatedly failed to
// reach the database (the row was byte-identical before and after the owner's save, and
// the corrected text's signature line existed on none of the 85 tracks), so the owner
// authorised this one writer for it.
//
// WHAT IT REFUSES
// ---------------
//   * a track id whose current column does not match the sha256 prefix the caller
//     reviewed - so if anyone (or the admin app) saves in between, nothing is written;
//   * a missing or empty column, or fewer than two files: all three go together;
//   * columns that are not the same number of RAW lines, because the apps' plain-lyrics
//     view stacks the languages by line index;
//   * content identical to what is already stored (nothing to do).
//
// Run:
//   node server/tools/plain-lyrics-payload.mjs --track <uuid> --dir <dir> \
//        --expect-te <sha16> --expect-en <sha16> --expect-tr <sha16> --out payload.json
// Writes nothing to the database; it only emits the PATCH body.
// ============================================================================

import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}

const TRACK = arg('track')
const DIR = arg('dir')
const OUT = arg('out', 'plain-payload.json')
const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''

const FILES = [
  ['plain_lyrics', 'plain_lyrics.txt', arg('expect-te')],
  ['plain_lyrics_en', 'plain_lyrics_en.txt', arg('expect-en')],
  ['plain_lyrics_en_tr', 'plain_lyrics_en_tr.txt', arg('expect-tr')],
]

if (!TRACK) { console.error('--track <uuid> required'); process.exit(2) }
if (!DIR) { console.error('--dir <dir with the three plain_lyrics*.txt files> required'); process.exit(2) }
if (!SUPA || !KEY) { console.error('SUPABASE_URL + key required'); process.exit(2) }

const sha = (s) => crypto.createHash('sha256').update(String(s ?? '')).digest('hex')
const fail = (msg) => { console.error(`REFUSING: ${msg}`); process.exit(1) }

// --- what is stored now -----------------------------------------------------
const cols = FILES.map(([c]) => c).join(',')
const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=id,title,${cols}`, {
  headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
})
if (!res.ok) { console.error(`supabase ${res.status}: ${(await res.text()).slice(0, 300)}`); process.exit(2) }
const [row] = await res.json()
if (!row) fail('track not found')

console.log(`track: ${row.title}  (${TRACK})`)

// --- the reviewed text ------------------------------------------------------
const payload = {}
const summary = []
for (const [col, file, expect] of FILES) {
  const p = path.join(DIR, file)
  if (!fs.existsSync(p)) fail(`${file} is missing from ${DIR} - all three columns must be supplied`)
  const text = fs.readFileSync(p, 'utf8')
  if (!text.trim()) fail(`${file} is empty`)
  const stored = row[col] || ''
  const now = sha(stored)
  if (!expect) fail(`--expect for ${col} was not supplied (reviewed sha256 prefix)`)
  if (!now.startsWith(String(expect).toLowerCase())) {
    fail(`${col} has changed since review: stored sha256 is ${now.slice(0, 16)}, `
      + `the reviewed one was ${expect}. Re-read the row and review the text again.`)
  }
  // A column may legitimately be supplied unchanged - a repair often touches only one or
  // two of the three (measured on Ravamma Mahalakshmi, where the English and the
  // transliteration plain columns had been pasted the wrong way round and the Telugu was
  // correct). It is still supplied, still checked for line-parallelism, and simply left out
  // of the PATCH. All three files stay mandatory, and at least one must differ.
  const unchanged = text === stored
  const lines = (t) => t.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').length
  summary.push({ col, file, storedLen: stored.length, newLen: text.length,
    storedSha: now.slice(0, 16), newSha: sha(text).slice(0, 16), lines: lines(text), unchanged })
  if (!unchanged) payload[col] = text
}

const counts = new Set(summary.map((s) => s.lines))
if (counts.size !== 1) {
  fail(`the three columns are not line-parallel: ${summary.map((s) => `${s.col}=${s.lines}`).join(' ')}`)
}
if (!Object.keys(payload).length) fail('all three columns are byte-identical to what is stored - nothing to write')

console.log('\ncolumn                 lines   chars (stored -> new)   sha256 (stored -> new)   action')
for (const s of summary) {
  console.log(`${s.col.padEnd(20)} ${String(s.lines).padStart(5)}   ${String(s.storedLen).padStart(6)} -> ${String(s.newLen).padStart(6)}   ${s.storedSha} -> ${s.newSha}   ${s.unchanged ? 'unchanged' : 'WRITE'}`)
}
fs.writeFileSync(OUT, JSON.stringify(payload, null, 2), 'utf8')
console.log(`\nwrote ${OUT} with ${Object.keys(payload).length} column(s); nothing sent to the database.`)
