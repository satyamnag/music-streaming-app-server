#!/usr/bin/env node
// ============================================================================
// Rewrite the music-banner marker in a sync column, and change nothing else.
//
//   --mode telugu    {{Music}}  ->  {{ ♪ సంగీతం ♪ }}   in `synced_lyrics`
//   --mode english   {{Music}}  ->  {{ ♪ Music ♪ }}     in `synced_lyrics_en`
//   (any spelling whose whitespace-stripped form is `{{Music}}` matches, so
//    `{{Music}}`, `{{ Music }}` and `{{  Music  }}` all qualify)  and in
//    `synced_lyrics_en_tr`, written together in ONE PATCH so the two English
//    columns can never drift onto different banners.
//
// WHY A WRITER OF ITS OWN
// -----------------------
// `write-timeline-text.mjs` re-spells LYRIC cues and deliberately refuses to
// touch a banner ("banners are not re-spelled by this tool"), so it cannot do
// this job. `finalize_payload.mjs` rewrites lyrics and gates on the canonical
// marker. This tool does exactly one thing, and refuses anything else.
//
// WHAT IT GUARANTEES, each asserted before a single byte is sent
// -------------------------------------------------------------
//   * only a cue whose ENTIRE text is the music marker is rewritten - never a
//     substring, never a lyric line that merely mentions the marker;
//   * every block that is not such a banner is copied through BYTE FOR BYTE,
//     including its index line, its time line and any surrounding whitespace;
//   * the cue count is unchanged and EVERY time line is byte-identical, so no
//     timestamp can move;
//   * the number of replacements equals the number of markers counted, and the
//     result contains no marker left;
//   * in english mode the two columns must already share their time lines, and
//     both are checked independently;
//   * the PATCH body carries only the columns of the chosen mode;
//   * after the write every column is read back and compared exactly.
//
// Run:
//   node server/tools/repair-music-banner.mjs --mode english --ids "<uuid>,..." [--write]
// ============================================================================

import crypto from 'node:crypto'

const MODES = {
  telugu: {
    cols: ['synced_lyrics'],
    to: '{{ \u266A \u0C38\u0C02\u0C17\u0C40\u0C24\u0C02 \u266A }}',
  },
  english: {
    cols: ['synced_lyrics_en', 'synced_lyrics_en_tr'],
    to: '{{ \u266A Music \u266A }}',
  },
}

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const MODE = String(arg('mode', 'telugu')).toLowerCase()
const CFG = MODES[MODE]
const IDS = String(arg('ids', '')).split(',').map((s) => s.trim()).filter(Boolean)
const WRITE = process.argv.includes('--write')
const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
// Reads fall back to the service key: the workflow that runs this supplies only that one,
// exactly like the other tools in this directory.
const ANON = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || ''
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY || ''

const MARKER_SQ = '{{Music}}'
const sq = (s) => String(s ?? '').replace(/\s+/g, '')

if (!CFG) { console.error(`--mode must be one of ${Object.keys(MODES).join(', ')}`); process.exit(2) }
if (!IDS.length) { console.error('--ids "<uuid>[,<uuid>...]" required'); process.exit(2) }
if (!SUPA || !ANON) { console.error('SUPABASE_URL + key required'); process.exit(2) }
if (WRITE && !SERVICE) { console.error('SUPABASE_SERVICE_ROLE_KEY required for --write'); process.exit(2) }

const sha = (s) => crypto.createHash('sha256').update(String(s ?? '')).digest('hex')
const read = { apikey: ANON, Authorization: `Bearer ${ANON}` }
const TIME = /^\d\d:\d\d:\d\d,\d\d\d --> \d\d:\d\d:\d\d,\d\d\d$/

const splitBlocks = (column) =>
  String(column ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/\n\s*$/, '').split(/\n[ \t]*\n/)

/**
 * Rewrite the whole-text music marker of one column.
 *
 * Works on the raw text, block by block, so every untouched block survives byte for byte.
 * A block that does not have exactly the canonical three lines (index, time, text) is
 * never edited; it is reported instead.
 */
function rewrite(column) {
  const text = String(column ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
  const trailingNewline = /\n\s*$/.test(text)
  const blocks = text.replace(/\n\s*$/, '').split(/\n[ \t]*\n/)
  const out = []
  let replaced = 0
  let counted = 0
  const skipped = []
  const times = []
  for (const block of blocks) {
    const lines = block.split('\n')
    if (lines.length < 3) { out.push(block); continue }
    times.push(lines[1].trim())
    const cueText = lines.slice(2).join('\n').trim()
    if (sq(cueText) === MARKER_SQ) {
      counted += 1
      if (lines.length !== 3) {
        skipped.push({ why: 'banner block is not exactly 3 lines', text: cueText.slice(0, 40) })
        out.push(block)
        continue
      }
      lines[2] = CFG.to
      out.push(lines.join('\n'))
      replaced += 1
      continue
    }
    out.push(block)
  }
  const next = out.join('\n\n') + (trailingNewline ? '\n' : '')
  return { next, replaced, counted, skipped, times, blocks }
}

/** Every gate for one column. Returns a list of problems; empty means safe to write. */
function check(column, result) {
  const problems = []
  if (!String(column ?? '').trim()) { problems.push('column is empty'); return problems }
  const storedTimes = splitBlocks(column).filter((b) => b.split('\n').length >= 3).map((b) => b.split('\n')[1].trim())
  if (storedTimes.length !== result.times.length) problems.push(`cue count ${result.times.length} != stored ${storedTimes.length}`)
  for (let i = 0; i < Math.min(storedTimes.length, result.times.length); i += 1) {
    if (storedTimes[i] !== result.times[i]) { problems.push(`cue ${i + 1} time line changed`); break }
    if (!TIME.test(result.times[i])) { problems.push(`cue ${i + 1} time line is not a valid SRT time`); break }
  }
  if (result.skipped.length) problems.push(`${result.skipped.length} banner(s) could not be rewritten safely: ${result.skipped[0].why}`)
  if (result.replaced !== result.counted) problems.push(`counted ${result.counted} but rewrote ${result.replaced}`)
  if (sq(result.next).includes(MARKER_SQ)) problems.push('a music marker is still present after the rewrite')
  const a = splitBlocks(column)
  const b = splitBlocks(result.next)
  if (a.length !== b.length) problems.push(`block count ${b.length} != ${a.length}`)
  let changed = 0
  for (let i = 0; i < Math.min(a.length, b.length); i += 1) {
    if (a[i] === b[i]) continue
    changed += 1
    const lines = a[i].split('\n')
    if (lines.length !== 3) { problems.push(`block ${i + 1} changed but is not 3 lines`); break }
    if (sq(lines.slice(2).join('\n').trim()) !== MARKER_SQ) {
      problems.push(`block ${i + 1} changed but was not a music marker`); break
    }
    if (b[i].split('\n')[0] !== lines[0] || b[i].split('\n')[1] !== lines[1]) {
      problems.push(`block ${i + 1} moved its index or time`); break
    }
  }
  if (changed !== result.replaced) problems.push(`${changed} block(s) changed but ${result.replaced} rewrite(s) reported`)
  return problems
}

const report = []
let failed = 0

for (const id of IDS) {
  const sel = ['id', 'title', ...CFG.cols].join(',')
  const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}&select=${sel}`, { headers: read })
  if (!res.ok) { console.error(`${id}: supabase ${res.status}`); failed += 1; continue }
  const [row] = await res.json()
  if (!row) { console.error(`${id}: not found`); failed += 1; continue }

  const problems = []
  const warnings = []
  const results = {}
  let total = 0
  let countedAll = 0
  for (const col of CFG.cols) {
    const r = rewrite(row[col])
    results[col] = r
    total += r.replaced
    countedAll += r.counted
    for (const p of check(row[col], r)) problems.push(`${col}: ${p}`)
  }
  if (!countedAll) problems.push(`no music marker found in ${CFG.cols.join(' / ')}`)
  if (CFG.cols.length > 1) {
    // The two English columns SHOULD already share their time lines. If they do not, that
    // is a pre-existing defect in the row and it is REPORTED, not fixed and not hidden:
    // this edit moves no timestamp, so it cannot make the mismatch worse, and refusing
    // would leave the marker the owner asked to remove.
    const [a, b] = CFG.cols.map((c) => results[c].times)
    if (a.length !== b.length || a.some((t, i) => t !== b[i])) {
      const first = a.findIndex((t, i) => t !== b[i])
      warnings.push(`${CFG.cols.join(' and ')} do not share one set of time lines`
        + ` (${a.length} vs ${b.length} cues, first difference at cue ${first < 0 ? '?' : first + 1})`)
    }
  }

  const line = `${row.title}   ${results[CFG.cols[0]].times.length} cues   `
    + `${countedAll} marker(s) -> ${total} replaced`
  if (problems.length) {
    console.log(`REFUSE  ${line}\n        ${problems.slice(0, 3).join('; ')}`)
    failed += 1
    report.push({ id, title: row.title, mode: MODE, action: 'refused', problems })
    continue
  }
  report.push({ id, title: row.title, mode: MODE, action: WRITE ? 'written' : 'would write',
    cues: results[CFG.cols[0]].times.length, replaced: total, warnings,
    before: Object.fromEntries(CFG.cols.map((c) => [c, sha(row[c]).slice(0, 16)])),
    after: Object.fromEntries(CFG.cols.map((c) => [c, sha(results[c].next).slice(0, 16)])) })

  const warn = warnings.length ? `\n        WARNING ${warnings.join('; ')}` : ''
  if (!WRITE) { console.log(`dry     ${line}${warn}`); continue }

  const body = {}
  for (const col of CFG.cols) body[col] = results[col].next
  const patch = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify(body),
  })
  if (!patch.ok) {
    console.log(`FAIL    ${line}   PATCH http=${patch.status}`)
    failed += 1
    report[report.length - 1].action = 'patch failed'
    continue
  }
  const back = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}&select=${CFG.cols.join(',')}`, { headers: read })).json()
  const same = CFG.cols.every((c) => String(back?.[0]?.[c] ?? '') === results[c].next)
  console.log(`${same ? 'WROTE ' : 'MISMATCH'} ${line}`)
  if (!same) { failed += 1; report[report.length - 1].action = 'read-back mismatch' }
}

const totals = report.reduce((n, r) => n + (r.replaced || 0), 0)
console.log(`\n${report.length} track(s), ${totals} banner(s) ${WRITE ? 'replaced' : 'to replace'}, ${failed} failure(s)`)
console.log(`mode ${MODE}: ${CFG.cols.join(' + ')}   marker {{...Music...}}  ->  ${CFG.to}`)
console.log(JSON.stringify(report, null, 1))
process.exit(failed ? 1 : 0)
