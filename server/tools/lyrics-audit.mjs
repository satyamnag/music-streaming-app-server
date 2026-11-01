// ============================================================================
// READ-ONLY audit of every track's sync lyrics.
//
// Answers, without touching the audio or writing anything:
//   * which tracks have lyric lines with NO cue (a line silently skipped),
//   * which tracks repeat a line in PLAIN but have fewer cues for that exact
//     text in SYNC (a repeated occurrence never timed).
//
// Both are provable from the database alone. Whether an occurrence exists in the
// AUDIO can only be known by transcribing again, which costs money and would
// overwrite existing timings - that is deliberately NOT done here.
//
// Run: node server/tools/lyrics-audit.mjs [--json out.json]
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// ============================================================================

import fs from 'node:fs'
import { classifyLine, parseSrtTimeline, splitLyricLines } from '../libs/autoSyncLyrics.mjs'

const OUT = process.argv.indexOf('--json') !== -1 ? process.argv[process.argv.indexOf('--json') + 1] : null
const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '')
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || ''

if (!url || !key) {
  console.error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required')
  process.exit(2)
}

const COLUMNS = [
  { lang: 'te', plain: 'plain_lyrics', synced: 'synced_lyrics' },
  { lang: 'en', plain: 'plain_lyrics_en', synced: 'synced_lyrics_en' },
  { lang: 'en_tr', plain: 'plain_lyrics_en_tr', synced: 'synced_lyrics_en_tr' },
  { lang: 'hi', plain: 'plain_lyrics_hi', synced: 'synced_lyrics_hi' },
  { lang: 'hi_tr', plain: 'plain_lyrics_hi_tr', synced: 'synced_lyrics_hi_tr' },
]

const select = [...new Set(COLUMNS.flatMap((c) => [c.plain, c.synced]))].join(',')

/** Count how many times each exact line appears. */
function counts(lines) {
  const m = new Map()
  for (const l of lines) if (l) m.set(l, (m.get(l) || 0) + 1)
  return m
}

async function fetchPage(from, size) {
  const res = await fetch(
    `${url}/rest/v1/tracks?select=id,title,status,${select}&order=title.asc`,
    {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        Range: `${from}-${from + size - 1}`,
        'Range-Unit': 'items',
      },
    },
  )
  if (!res.ok) throw new Error(`supabase ${res.status}: ${(await res.text()).slice(0, 300)}`)
  return res.json()
}

const rows = []
for (let from = 0; ; from += 500) {
  const page = await fetchPage(from, 500)
  rows.push(...page)
  if (page.length < 500) break
}

const findings = []
for (const t of rows) {
  for (const col of COLUMNS) {
    const plain = String(t[col.plain] || '')
    const synced = String(t[col.synced] || '')
    if (!plain.trim()) continue

    const lyricLines = splitLyricLines(plain).filter((l) => classifyLine(l) === 'lyric')
    if (!lyricLines.length) continue

    const cues = parseSrtTimeline(synced)
    const cueTexts = counts(cues.map((c) => c.text.trim()))

    const problems = []

    // 1. A line present in plain but with no cue at all.
    const plainCounts = counts(lyricLines)
    let missing = 0
    for (const [text, n] of plainCounts) {
      const have = cueTexts.get(text) || 0
      if (have < n) missing += (n - have)
    }
    if (missing > 0) problems.push({ kind: 'missing_cues', count: missing })

    // 2. A line the author wrote ONCE but the author repeated in plain is
    //    covered by (1). A repeat that exists only in the AUDIO cannot be seen
    //    from the database and is reported as unknown rather than guessed.
    if (!cues.length) problems.push({ kind: 'no_cues_at_all', count: lyricLines.length })

    if (problems.length) {
      findings.push({
        id: t.id,
        title: t.title,
        status: t.status,
        column: col.lang,
        plain_lines: lyricLines.length,
        cues: cues.length,
        problems,
      })
    }
  }
}

const summary = {
  generated_at: new Date().toISOString(),
  tracks: rows.length,
  tracks_with_findings: new Set(findings.map((f) => f.id)).size,
  findings: findings.length,
  by_kind: findings.reduce((acc, f) => {
    for (const p of f.problems) acc[p.kind] = (acc[p.kind] || 0) + p.count
    return acc
  }, {}),
  detail: findings,
}

console.log(JSON.stringify(summary, null, 2))
if (OUT) fs.writeFileSync(OUT, JSON.stringify(summary, null, 2))
console.log(`\n${summary.tracks} tracks · ${summary.tracks_with_findings} with findings · ${summary.findings} column findings`)
console.log('READ ONLY - nothing was written.')
