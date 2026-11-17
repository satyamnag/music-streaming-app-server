#!/usr/bin/env node
// ============================================================================
// Replace the music-banner marker `{{Music}}` with `{{ ♪ సంగీతం ♪ }}` in the
// TELUGU sync column. Nothing else in the column may change, and no other
// column is touched.
//
// WHY A WRITER OF ITS OWN
// -----------------------
// `write-timeline-text.mjs` re-spells LYRIC cues and deliberately refuses to
// touch a banner ("banners are not re-spelled by this tool"), so it cannot do
// this job. `finalize_payload.mjs` rewrites lyrics too. This tool does exactly
// one thing, and refuses anything else.
//
// WHAT IT GUARANTEES, each asserted before a single byte is sent
// -------------------------------------------------------------
//   * only a cue whose ENTIRE text is `{{Music}}` is rewritten - never a
//     substring, never a lyric line that merely mentions the marker;
//   * every block that is not such a banner is copied through BYTE FOR BYTE,
//     including its index line, its time line and any surrounding whitespace;
//   * the cue count is unchanged and EVERY time line is byte-identical, so no
//     timestamp can move;
//   * the number of replacements equals the number of `{{Music}}` banners that
//     were counted in the stored column, and the result contains none left;
//   * the PATCH body carries ONE key, `synced_lyrics`;
//   * after the write the column is read back and compared exactly.
//
// Run:
//   node server/tools/repair-music-banner.mjs --ids "<uuid>[,<uuid>...]" [--write]
// ============================================================================

import crypto from 'node:crypto'

const MARKER = '{{Music}}'
const REPLACEMENT = '{{ \u266A \u0C38\u0C02\u0C17\u0C40\u0C24\u0C02 \u266A }}'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const IDS = String(arg('ids', '')).split(',').map((s) => s.trim()).filter(Boolean)
const WRITE = process.argv.includes('--write')
const SUPA = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const ANON = process.env.SUPABASE_ANON_KEY || ''
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY || ''

if (!IDS.length) { console.error('--ids "<uuid>[,<uuid>...]" required'); process.exit(2) }
if (!SUPA || !ANON) { console.error('SUPABASE_URL + SUPABASE_ANON_KEY required'); process.exit(2) }
if (WRITE && !SERVICE) { console.error('SUPABASE_SERVICE_ROLE_KEY required for --write'); process.exit(2) }

const sha = (s) => crypto.createHash('sha256').update(String(s ?? '')).digest('hex')
const read = { apikey: ANON, Authorization: `Bearer ${ANON}` }
const TIME = /^\d\d:\d\d:\d\d,\d\d\d --> \d\d:\d\d:\d\d,\d\d\d$/

/**
 * Rewrite the whole-text `{{Music}}` banners of one column.
 *
 * Works on the raw text, block by block, so every untouched block survives
 * byte for byte. A block that does not have exactly the canonical three lines
 * (index, time, text) is never edited; it is reported instead.
 */
function rewrite(column) {
  const text = String(column ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
  const trailingNewline = /\n\s*$/.test(text)
  const body = text.replace(/\n\s*$/, '')
  const blocks = body.split(/\n[ \t]*\n/)
  const out = []
  let replaced = 0
  let counted = 0
  const skipped = []
  const times = []
  for (const block of blocks) {
    const lines = block.split('\n')
    if (lines.length < 3) { out.push(block); continue }
    const timeLine = lines[1].trim()
    times.push(timeLine)
    const cueText = lines.slice(2).join('\n').trim()
    if (cueText === MARKER) {
      counted += 1
      if (lines.length !== 3) {
        // e.g. a banner written across two lines - never guessed at.
        skipped.push({ why: 'banner block is not exactly 3 lines', block: cueText.slice(0, 40) })
        out.push(block)
        continue
      }
      lines[2] = REPLACEMENT
      out.push(lines.join('\n'))
      replaced += 1
      continue
    }
    out.push(block)
  }
  const next = out.join('\n\n') + (trailingNewline ? '\n' : '')
  return { next, replaced, counted, skipped, times }
}

const report = []
let failed = 0

for (const id of IDS) {
  const sel = 'id,title,synced_lyrics'
  const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}&select=${sel}`, { headers: read })
  if (!res.ok) { console.error(`${id}: supabase ${res.status}`); failed += 1; continue }
  const [row] = await res.json()
  if (!row) { console.error(`${id}: not found`); failed += 1; continue }

  const stored = String(row.synced_lyrics ?? '')
  const { next, replaced, counted, skipped, times } = rewrite(stored)

  // ---- gates ---------------------------------------------------------------
  const storedTimes = String(stored).replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    .split(/\n[ \t]*\n/).filter((b) => b.split('\n').length >= 3).map((b) => b.split('\n')[1].trim())
  const problems = []
  if (!stored.trim()) problems.push('column is empty')
  if (storedTimes.length !== times.length) problems.push(`cue count ${times.length} != stored ${storedTimes.length}`)
  for (let i = 0; i < Math.min(storedTimes.length, times.length); i += 1) {
    if (storedTimes[i] !== times[i]) { problems.push(`cue ${i + 1} time line changed`); break }
    if (!TIME.test(times[i])) { problems.push(`cue ${i + 1} time line is not a valid SRT time`); break }
  }
  if (skipped.length) problems.push(`${skipped.length} banner(s) could not be rewritten safely: ${skipped[0].why}`)
  if (!counted) problems.push(`no exact ${MARKER} banner cue found`)
  if (replaced !== counted) problems.push(`counted ${counted} but rewrote ${replaced}`)
  if (next.includes(MARKER)) problems.push(`${MARKER} still present after the rewrite`)
  // every non-banner block must be byte-identical
  const a = String(stored).replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/\n\s*$/, '').split(/\n[ \t]*\n/)
  const b = next.replace(/\n\s*$/, '').split(/\n[ \t]*\n/)
  if (a.length !== b.length) problems.push(`block count ${b.length} != ${a.length}`)
  let changedBlocks = 0
  for (let i = 0; i < Math.min(a.length, b.length); i += 1) {
    if (a[i] === b[i]) continue
    changedBlocks += 1
    const cue = a[i].split('\n').slice(2).join('\n').trim()
    if (cue !== MARKER) problems.push(`block ${i + 1} changed but was not a ${MARKER} banner`)
  }
  if (changedBlocks !== replaced) problems.push(`${changedBlocks} block(s) changed but ${replaced} rewrite(s) reported`)

  const line = `${row.title}   ${times.length} cues   ${counted} x ${MARKER} -> ${replaced} replaced`
  if (problems.length) {
    console.log(`REFUSE  ${line}\n        ${problems.join('; ')}`)
    failed += 1
    report.push({ id, title: row.title, action: 'refused', problems })
    continue
  }
  report.push({ id, title: row.title, action: WRITE ? 'written' : 'would write',
    cues: times.length, replaced, beforeSha: sha(stored).slice(0, 16), afterSha: sha(next).slice(0, 16),
    beforeLen: stored.length, afterLen: next.length })

  if (!WRITE) {
    console.log(`dry     ${line}`)
    continue
  }

  const patch = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify({ synced_lyrics: next }),
  })
  if (!patch.ok) {
    console.log(`FAIL    ${line}   PATCH http=${patch.status}`)
    failed += 1
    report[report.length - 1].action = 'patch failed'
    continue
  }
  const back = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(id)}&select=synced_lyrics`, { headers: read })).json()
  const same = String(back?.[0]?.synced_lyrics ?? '') === next
  console.log(`${same ? 'WROTE ' : 'MISMATCH'} ${line}`)
  if (!same) { failed += 1; report[report.length - 1].action = 'read-back mismatch' }
}

const totals = report.reduce((n, r) => n + (r.replaced || 0), 0)
console.log(`\n${report.length} track(s), ${totals} banner(s) ${WRITE ? 'replaced' : 'to replace'}, ${failed} failure(s)`)
console.log(`marker ${MARKER}  ->  ${REPLACEMENT}`)
console.log(JSON.stringify(report, null, 1))
process.exit(failed ? 1 : 0)
