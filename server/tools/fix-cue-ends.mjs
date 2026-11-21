#!/usr/bin/env node
// ============================================================================
// Repair cue END times in a synced column - nothing else.
//
//   node server/tools/fix-cue-ends.mjs \
//        --ids "<uuid>[,<uuid>]" \
//        --col synced_lyrics \
//        --fixes "48=00:06:05,380;59=00:07:02,000" \
//        [--write]
//
// Use when a row carries a cue whose end is before its start (an editor slip:
// `06:05,380` typed as `05:06,380`). Such a column cannot become a valid SRT and
// every downstream tool refuses it, but the repair itself is a few characters on
// one time line - which is exactly what this tool does, and all it does.
//
// It refuses, before sending anything, unless:
//   * every named cue exists, and its new end is a valid SRT time after its start;
//   * the cue count is unchanged;
//   * the ONLY differences between the stored column and the new one are the END
//     halves of the named cues (the index line, the start time and the text are
//     copied through byte for byte, and no other cue is touched).
// After the write it re-reads the column and compares it byte for byte.
// ============================================================================

import crypto from 'node:crypto'
import { fixCueEnds, assertOnlyEndsChanged } from '../libs/cueEnds.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const IDS = String(arg('ids', '')).split(',').map((s) => s.trim()).filter(Boolean)
const COL = String(arg('col', 'synced_lyrics')).trim()
const FIX_ARG = String(arg('fixes', '')).trim()
const WRITE = process.argv.includes('--write')
const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const ANON = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || ''
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY || ''

const COLUMNS = new Set(['synced_lyrics', 'synced_lyrics_en', 'synced_lyrics_en_tr'])
if (!COLUMNS.has(COL)) { console.error(`--col must be one of ${[...COLUMNS].join(', ')}`); process.exit(2) }
if (!IDS.length) { console.error('--ids "<uuid>[,<uuid>...]" required'); process.exit(2) }
if (!FIX_ARG) { console.error('--fixes "48=00:06:05,380;59=00:07:02,000" required'); process.exit(2) }
if (!SUPA || !ANON) { console.error('SUPABASE_URL + key required'); process.exit(2) }
if (WRITE && !SERVICE) { console.error('SUPABASE_SERVICE_ROLE_KEY required for --write'); process.exit(2) }

/** "48=00:06:05,380;59=00:07:02,000" -> { 48: '00:06:05,380', 59: '00:07:02,000' } */
const fixes = {}
for (const part of FIX_ARG.split(';').map((s) => s.trim()).filter(Boolean)) {
  const m = /^(\d+)\s*=\s*(\d\d:\d\d:\d\d,\d\d\d)$/.exec(part)
  if (!m) { console.error(`fix ${part} is not "<cue>=<HH:MM:SS,mmm>"`); process.exit(2) }
  fixes[Number(m[1])] = m[2]
}
if (!Object.keys(fixes).length) { console.error('no fixes parsed'); process.exit(2) }

const sha = (s) => crypto.createHash('sha256').update(String(s ?? '')).digest('hex')
const read = { apikey: ANON, Authorization: `Bearer ${ANON}` }
let failed = 0

for (const id of IDS) {
  const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}&select=id,title,${COL}`, { headers: read })
  if (!res.ok) { console.error(`${id}: supabase ${res.status}`); failed += 1; continue }
  const [row] = await res.json()
  if (!row) { console.error(`${id}: not found`); failed += 1; continue }

  const stored = row[COL] ?? ''
  const { next, changed, errors } = fixCueEnds(stored, fixes)
  const problems = [...errors, ...assertOnlyEndsChanged(stored, next, fixes)]

  console.log(`\n${row.title}   [${COL}]   ${sha(stored).slice(0, 16)} -> ${sha(next).slice(0, 16)}`)
  for (const c of changed) console.log(`   cue ${String(c.cue).padStart(3)}   end ${c.before} -> ${c.after}`)
  if (problems.length) {
    for (const p of problems.slice(0, 6)) console.log(`   REFUSE  ${p}`)
    failed += 1
    continue
  }

  if (!WRITE) { console.log('   dry run - nothing sent'); continue }

  const patch = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify({ [COL]: next }),
  })
  if (!patch.ok) { console.log(`   FAIL  PATCH http=${patch.status}`); failed += 1; continue }

  const back = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}&select=${COL}`, { headers: read })).json()
  const same = String(back?.[0]?.[COL] ?? '') === next
  console.log(`   ${same ? 'WROTE' : 'READ-BACK MISMATCH'}  PATCH http=${patch.status}`)
  if (!same) failed += 1
}

console.log(`\n${IDS.length} track(s), ${failed} failure(s)${WRITE ? '' : ' (dry run - nothing sent)'}`)
// process.exit() while fetch keep-alive sockets are open trips a libuv teardown
// assertion on Windows; setting exitCode lets Node close them and still report the status.
process.exitCode = failed ? 1 : 0
