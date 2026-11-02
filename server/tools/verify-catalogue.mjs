// ============================================================================
// CATALOGUE-WIDE verification of the sync-lyrics columns. Read-only.
//
// For every track with plain lyrics it checks:
//   * plain lyrics are non-empty and the three plain columns are line-parallel
//     (the source of truth must never drift)
//   * structure: monotonic, no overlap, positive duration, in range, no duplicate
//     start, no blank cue, covers 0..duration
//   * shared timeline: whenever en / en_tr are present they must carry the SAME
//     cue count and the SAME start/end at every index as Telugu
//   * coverage: every plain lyric line appears at least once
//
// Run:  KEY=<supabase key> node server/tools/verify-catalogue.mjs [--verbose]
// ============================================================================

import {
  parseSrtTimeline,
  splitLyricLines,
  classifyLine,
  MUSIC_LABEL,
} from '../libs/autoSyncLyrics.mjs'

const SUPA = 'https://ngemrcsdfxufxnazeqke.supabase.co'
const KEY = process.env.KEY
const VERBOSE = process.argv.includes('--verbose')
if (!KEY) { console.error('KEY env required'); process.exit(2) }

const rows = []
for (let from = 0; ; from += 500) {
  const r = await fetch(
    `${SUPA}/rest/v1/tracks?select=id,title,duration,` +
    'plain_lyrics,plain_lyrics_en,plain_lyrics_en_tr,' +
    'synced_lyrics,synced_lyrics_en,synced_lyrics_en_tr&order=title.asc',
    { headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, Range: `${from}-${from + 499}`, 'Range-Unit': 'items' } },
  )
  if (!r.ok) { console.error(r.status); process.exit(2) }
  const page = await r.json()
  rows.push(...page)
  if (page.length < 500) break
}

const has = (s) => String(s || '').trim().length > 0
let ok = 0
const failures = []

for (const t of rows) {
  if (!has(t.plain_lyrics) || !has(t.synced_lyrics)) continue
  const dur = Number(t.duration)
  const problems = []
  const te = parseSrtTimeline(t.synced_lyrics)

  if (!te.length) problems.push('no cues')

  // structure
  let overlap = 0, zero = 0, oor = 0, blank = 0
  const starts = new Set()
  for (let i = 0; i < te.length; i++) {
    if (te[i].end <= te[i].start) zero += 1
    if (i > 0 && te[i].start < te[i - 1].end - 1e-6) overlap += 1
    if (te[i].start < 0 || te[i].end > dur + 0.5) oor += 1
    if (!String(te[i].text || '').trim()) blank += 1
    starts.add(te[i].start)
  }
  if (overlap) problems.push(`${overlap} overlap`)
  if (zero) problems.push(`${zero} zero-duration`)
  if (oor) problems.push(`${oor} out-of-range`)
  if (blank) problems.push(`${blank} blank`)
  if (te.length - starts.size) problems.push(`${te.length - starts.size} dup start`)
  if (te.length && Math.abs(te[0].start) > 0.05) problems.push(`starts at ${te[0].start}`)
  if (te.length && Math.abs(te[te.length - 1].end - dur) > 0.5) problems.push(`ends at ${te[te.length - 1].end} (dur ${dur})`)

  // coverage
  const lyricLines = splitLyricLines(t.plain_lyrics).filter((l) => classifyLine(l) === 'lyric').map((l) => String(l).trim())
  const present = new Set(te.filter((c) => c.text.trim() !== MUSIC_LABEL).map((c) => c.text.trim()))
  const missing = lyricLines.filter((l) => !present.has(l))
  if (missing.length) problems.push(`${missing.length}/${lyricLines.length} lines untimed`)

  // shared timeline
  for (const [col, plainCol] of [['synced_lyrics_en', 'plain_lyrics_en'], ['synced_lyrics_en_tr', 'plain_lyrics_en_tr']]) {
    if (!has(t[col])) continue
    const c = parseSrtTimeline(t[col])
    const same = c.length === te.length && c.every((x, i) => Math.abs(x.start - te[i].start) < 1e-6 && Math.abs(x.end - te[i].end) < 1e-6)
    if (!same) problems.push(`${col} timeline drift (${c.length} vs ${te.length})`)
    // plain parallelism
    if (has(t[plainCol]) && splitLyricLines(t[plainCol]).length !== splitLyricLines(t.plain_lyrics).length) {
      problems.push(`${plainCol} not line-parallel`)
    }
  }

  if (problems.length) failures.push({ title: t.title, problems })
  else ok += 1
}

const considered = rows.filter((t) => has(t.plain_lyrics) && has(t.synced_lyrics)).length
console.log(`tracks considered : ${considered}`)
console.log(`fully valid       : ${ok}`)
console.log(`with problems     : ${failures.length}`)
if (failures.length) {
  console.log('\nPROBLEMS:')
  for (const f of failures) console.log(`  ${String(f.title).slice(0, 38).padEnd(40)} ${f.problems.join('; ')}`)
}
if (VERBOSE) {
  console.log('\nvalid tracks:')
  const bad = new Set(failures.map((f) => f.title))
  for (const t of rows) if (has(t.plain_lyrics) && has(t.synced_lyrics) && !bad.has(t.title)) console.log('  ' + t.title)
}
process.exitCode = failures.length ? 1 : 0
