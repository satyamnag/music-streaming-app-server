// ============================================================
// DATA MIGRATION: normalise the stored lyric markup TO THE CANONICAL FORMS
//
//   ALREADY APPLIED to production on 2026-10-05: 147 cells across 49 tracks.
//   Kept because it is IDEMPOTENT — re-running it finds nothing left to change —
//   and because a production data change should be auditable and repeatable.
//
// WHAT IT DOES
//   * PLAIN lyric columns:  [ ]  ->  { }
//     The catalogue's lyrics were authored with SQUARE-bracket headings
//     (`[Pallavi]`, `[Charanam 1]`, `[Repeat Pallavi]`, ... 1290 whole lines
//     across 49 tracks). The renderers only treat CURLY braces as markup, so
//     every one of those was being printed as literal text instead of drawing a
//     section divider. After the migration: 441 divider groups across 48 songs,
//     up from 11 across 1.
//
//   * SYNC lyric columns: the banner written in note glyphs (`♪ Music ♪`) ->
//     `{{Music}}`. Only one track used the glyph form (10 lines); the other
//     synced track already stored the canonical `{{Music}}`.
//
// SAFETY
//   * DRY RUNS by default. Pass --apply to write.
//   * Backs up the original value of every cell it rewrites, to a JSON file,
//     BEFORE writing anything. That file is the rollback.
//   * REFUSES to apply if any bracketed line looks like a timestamp
//     (`[00:12.34]`), which the bracket rewrite would otherwise destroy.
//   * Only changed columns are sent, one PATCH per cell, using the service role.
//
// USAGE
//   node server/migrations/031_normalise_lyrics_markup.mjs            # dry run
//   node server/migrations/031_normalise_lyrics_markup.mjs --apply    # write
//
// Credentials come from SOULFUL_ENV (default: _temp/supabase-credentials.env)
// and must define SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.
// ============================================================
// Normalises the stored lyric markup so the canonical forms are in the DATA:
//
//   * PLAIN lyric columns: [ ]  ->  { }      (the app's divider syntax)
//   * SYNC  lyric columns: the note-glyph banner `♪ Music ♪` -> `{{Music}}`
//
// Safe by construction: it DRY-RUNS by default and prints every line it would
// change, and it writes a full backup of each affected cell before touching
// anything. Pass --apply to actually write.
//
//   node migrate-lyrics-markup.mjs            # dry run, prints a full report
//   node migrate-lyrics-markup.mjs --apply    # writes, after backing up
//
// The bracket rewrite is the risky half: if a plain column contained LRC-style
// timestamps (`[00:12.34]`) this would destroy them, so the dry run classifies
// every bracketed line and REFUSES to apply if any looks like a timestamp.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'

const APPLY = process.argv.includes('--apply')
const OUT_DIR = process.env.SOULFUL_BACKUP_DIR || 'D:/Soulful Bhakti/_temp/lyrics-migration'

const PLAIN_COLS = [
  'plain_lyrics',
  'plain_lyrics_en',
  'plain_lyrics_hi',
  'plain_lyrics_en_tr',
  'plain_lyrics_hi_tr',
  'lyrics', // legacy plain column; included only if populated
]
const SYNC_COLS = [
  'synced_lyrics',
  'synced_lyrics_en',
  'synced_lyrics_hi',
  'synced_lyrics_en_tr',
  'synced_lyrics_hi_tr',
]

// A whole line whose label is wrapped in note glyphs, mirroring the app's rule.
const NOTE_LINE = /^\s*\u266A\s*([^\u266A]+?)\s*\u266A\s*$/
// A line that is an LRC/SRT timestamp rather than content.
const TIMESTAMP_LINE = /^\s*\[?\d{1,2}:\d{2}([:.,]\d{1,3})?\]?/

// ---- credentials ------------------------------------------------------------
const env = Object.fromEntries(
  readFileSync(process.env.SOULFUL_ENV || 'D:/Soulful Bhakti/_temp/supabase-credentials.env', 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => {
      const i = l.indexOf('=')
      return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')]
    }),
)
const URL_BASE = env.SUPABASE_URL
const KEY = env.SUPABASE_SERVICE_ROLE_KEY
if (!URL_BASE || !KEY) {
  console.error('need SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY')
  process.exit(1)
}

const rest = (path, init = {}) =>
  fetch(`${URL_BASE}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: KEY,
      Authorization: `Bearer ${KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
  })

const HEAD = ['id', 'title', ...PLAIN_COLS, ...SYNC_COLS].join(',')
const res = await rest(`tracks?select=${HEAD}`)
const rows = await res.json()
if (!Array.isArray(rows)) {
  console.error('query failed:', JSON.stringify(rows).slice(0, 300))
  process.exit(1)
}
console.log(`fetched ${rows.length} tracks (service role)\n`)

// ---- analyse ----------------------------------------------------------------
const plainChanges = [] // { id, title, col, before, after }
const syncChanges = []
const bracketLines = new Map() // line -> occurrences
const timestampSuspicions = []

for (const row of rows) {
  for (const col of PLAIN_COLS) {
    const before = row[col]
    if (typeof before !== 'string' || !/[\[\]]/.test(before)) continue
    for (const line of before.split('\n')) {
      if (!/[\[\]]/.test(line)) continue
      bracketLines.set(line, (bracketLines.get(line) ?? 0) + 1)
      if (TIMESTAMP_LINE.test(line) && !/^[\[{][A-Za-z]/.test(line)) {
        timestampSuspicions.push({ title: row.title, col, line })
      }
    }
    const after = before.replace(/\[/g, '{').replace(/\]/g, '}')
    if (after !== before) plainChanges.push({ id: row.id, title: row.title, col, before, after })
  }

  for (const col of SYNC_COLS) {
    const before = row[col]
    if (typeof before !== 'string' || !before.includes('\u266A')) continue
    let touched = false
    const after = before
      .split('\n')
      .map((line) => {
        const m = NOTE_LINE.exec(line)
        if (!m) return line
        touched = true
        return `{{${m[1].trim()}}}`
      })
      .join('\n')
    if (touched && after !== before) syncChanges.push({ id: row.id, title: row.title, col, before, after })
  }
}

// ---- report -----------------------------------------------------------------
console.log('=== PLAIN: every distinct bracketed line in the database ===')
if (bracketLines.size === 0) console.log('  (none)')
for (const [line, n] of [...bracketLines.entries()].sort()) {
  console.log(`  x${String(n).padStart(2)}  ${JSON.stringify(line)}  ->  ${JSON.stringify(line.replace(/\[/g, '{').replace(/\]/g, '}'))}`)
}

console.log(`\n=== PLAIN cells to rewrite: ${plainChanges.length} ===`)
for (const c of plainChanges) {
  console.log(`  ${c.title}  [${c.col}]  ${c.before.length} chars`)
}

console.log('\n=== SYNC: note-glyph banner lines found ===')
const syncLines = new Map()
for (const c of syncChanges) {
  for (const line of c.before.split('\n')) {
    if (NOTE_LINE.test(line)) syncLines.set(line, (syncLines.get(line) ?? 0) + 1)
  }
}
if (syncLines.size === 0) console.log('  (none)')
for (const [line, n] of [...syncLines.entries()].sort()) {
  console.log(`  x${String(n).padStart(2)}  ${JSON.stringify(line)}  ->  ${JSON.stringify(`{{${NOTE_LINE.exec(line)[1].trim()}}}`)}`)
}
console.log(`\n=== SYNC cells to rewrite: ${syncChanges.length} ===`)
for (const c of syncChanges) console.log(`  ${c.title}  [${c.col}]`)

// ---- guard ------------------------------------------------------------------
if (timestampSuspicions.length) {
  console.error('\nREFUSING TO APPLY: these bracketed lines look like TIMESTAMPS,')
  console.error('and rewriting their brackets would destroy them:')
  for (const t of timestampSuspicions) console.error(`  ${t.title} [${t.col}] ${JSON.stringify(t.line)}`)
  process.exit(2)
}
console.log('\nGuard: no bracketed line looks like a timestamp, so the rewrite is safe.')

if (!APPLY) {
  console.log('\nDRY RUN. Re-run with --apply to write these changes.')
  process.exit(0)
}

// ---- backup -----------------------------------------------------------------
mkdirSync(OUT_DIR, { recursive: true })
const stamp = new Date().toISOString().replace(/[:.]/g, '-')
const backupPath = `${OUT_DIR}/backup-${stamp}.json`
writeFileSync(
  backupPath,
  JSON.stringify(
    {
      takenAt: new Date().toISOString(),
      note: 'ORIGINAL values of every cell this migration rewrites. To roll back, PATCH each id with the cell values below.',
      plain: plainChanges.map(({ id, title, col, before }) => ({ id, title, col, value: before })),
      sync: syncChanges.map(({ id, title, col, before }) => ({ id, title, col, value: before })),
    },
    null,
    2,
  ),
  'utf8',
)
console.log(`\nbackup written: ${backupPath}`)

// ---- apply ------------------------------------------------------------------
let ok = 0
let failed = 0
for (const change of [...plainChanges, ...syncChanges]) {
  const r = await rest(`tracks?id=eq.${change.id}`, {
    method: 'PATCH',
    headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({ [change.col]: change.after }),
  })
  if (r.ok) {
    ok++
    console.log(`  WROTE ${change.title} [${change.col}]`)
  } else {
    failed++
    console.error(`  FAILED ${change.title} [${change.col}]: ${r.status} ${(await r.text()).slice(0, 200)}`)
  }
}

console.log(`\napplied: ${ok} cell(s) written, ${failed} failed`)
process.exit(failed === 0 ? 0 : 1)
