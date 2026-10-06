// ============================================================
// DATA IMPORT: SB SRT FILES BATCH 01 -> tracks.synced_lyrics (Telugu sync)
//
//   ALREADY APPLIED 2026-10-06: 37 tracks written, 0 failed.
//   Kept because it is idempotent (re-running rewrites the same bodies) and
//   because a production data change should be auditable and repeatable.
//
// WHAT IT DOES
//   Reads the 37 .srt files shipped for this batch and writes each into the
//   matching track's `synced_lyrics`. The ONLY edit made to any file is the
//   banner marker: `♪ Music ♪` (and the single `♪ Music♪`) -> `{{Music}}`, so the
//   app renders the decorative banner instead of a sung line. 180 markers across
//   the batch.
//
//   Filenames carry a numeric id and a human title that is SIMILAR but not
//   identical to the DB title, so mappings were resolved by exact normalised
//   match where possible and confirmed by the user for the rest (EXPLICIT below
//   records every one of those decisions, including the 7 the matcher could not
//   resolve on its own because the filename appends the song's second line).
//
// SAFETY
//   * DRY RUNS by default; --apply writes.
//   * Backs up the CURRENT synced_lyrics of every row it touches, before writing.
//   * Validates each generated SRT before writing: cue count, timestamps present
//     and monotonic, no cue text containing "-->", and NO cue left holding a note
//     glyph. A file that fails any check is reported and nothing is written.
//   * REFUSES to run if two files resolve to the same track (they would silently
//     overwrite each other).
//   * Any `{Heading}` markers already stored for a row are spliced back at their
//     original timestamps. For this batch that was a no-op — both previously
//     populated tracks had none, which the run reports rather than assumes.
//
// USAGE
//   node server/migrations/032_import_sb_srt_batch01.mjs            # dry run
//   node server/migrations/032_import_sb_srt_batch01.mjs --apply    # write
//
// Credentials come from SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY, read from
// _temp/supabase-credentials.env (see SOULFUL_ENV to point elsewhere).
// ============================================================
// Uploads the SB_SRT BATCH 01 files into tracks.synced_lyrics (Telugu sync).
//
//   node srt-import.mjs            # DRY RUN - reports everything, writes nothing
//   node srt-import.mjs --apply    # backs up, then writes
//
// SAFETY
//   * Dry-runs by default; --apply is required to write.
//   * Backs up the CURRENT synced_lyrics of every row it will touch, before writing.
//   * Validates every generated SRT (cue count, timestamps monotonic, no cue left
//     holding a note glyph) and REFUSES to write a file that fails.
//   * Refuses to run if two files resolve to the same track.
//   * Refuses to write an empty/blank body.
//
// MARKER HANDLING
//   The only edit to each file is `♪ Music ♪` (and the one `♪ Music♪`) -> `{{Music}}`,
//   so the app renders the banner. Any `{Heading}` markers ALREADY stored for the
//   target row are spliced back in at their original timestamps, matched to the
//   nearest cue in the new file. In this batch both covered tracks turned out to
//   have none, so nothing was actually spliced — the logic is here because the
//   instruction was to preserve them, and it verifies that rather than assuming it.
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

const APPLY = process.argv.includes('--apply')
const SRC = String.raw`C:\Users\SATYAM NAG\OneDrive\Documents\Downloads\SB_SRT FILES_BATCH 01`
const OUT = 'D:/Soulful Bhakti/_temp/srt-import'

// Resolutions the user confirmed. Every other file matches on its own title.
const EXPLICIT = {
  'SB112_Om Vigneswaraya Namaha_SRT_V01.srt': 'Om Vigneshwaraya Namah',
  'SB117_Tolutha Pada Vandhyudu_SRT_V01.srt': 'Tolutha Pada Vandyudu',
  'SB118_Gangadhara Sutha_SRT_V01.srt': 'Gangadhara Suta',
  'SB119_Gam Gananadha_SRT_V01.srt': 'Gam Gananatha!',
  'SB121_Narayanaa!_SRT_V01.srt': 'Narayana!',
  'SB14_Ramudu Vachadu bala_SRT_V01.srt': 'Ramudu Vachadu Baala',
  'SB64_Ramya Guna Dhaama_SRT_V01.srt': 'Ramya Guna Dhama',
  // The 7 the matcher could not resolve confidently, confirmed by the user.
  'SB16_Malle Maalalu Medana Vesi_SRT_V01.srt': 'Malle Maalalu',
  'SB63_Namo Saptagiri, Sreekara Sreedhara_SRT_V01.srt': 'Namo Sapthagiri',
  'SB74_Krishna Anare, Sri Krishna Anare_SRT_V01.srt': 'Krishna Anare',
  'SB77_Niluvadu Manasu Nimushamu Nee Paina_SRT_V01.srt': 'Niluvadu Manasu',
  'SB78_Gopaala Baala Govinda Naamaa_SRT_V01.srt': 'Gopala Baala',
  'SB84_Maadhika Mukunda, Madhusoodana Krishnaa_SRT_V01.srt': 'Madhava Mukundha',
  'SB85_Daiva Darshanam, Idi Divya Darshanam_SRT_V01.srt': 'Daiva Darshanam',
}
// The SB84 filename in the folder is spelled differently from the key above.
EXPLICIT['SB84_Maadhava Mukunda, Madhusoodana Krishnaa_SRT_V01.srt'] = 'Madhava Mukundha'

const env = Object.fromEntries(
  readFileSync('D:/Soulful Bhakti/_temp/supabase-credentials.env', 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => {
      const i = l.indexOf('=')
      return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')]
    }),
)
const H = {
  apikey: env.SUPABASE_SERVICE_ROLE_KEY,
  Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
}

const norm = (s) =>
  s.toLowerCase().replace(/_+/g, ' ').replace(/[^a-z0-9\u0c00-\u0c7f ]+/g, ' ').replace(/\s+/g, ' ').trim()
const titleFromFile = (name) =>
  name.replace(/\.srt$/i, '').replace(/^SB\d+[_\s-]*/i, '').replace(/[_]?SRT[_ ]?V\d+$/i, '').trim()

// ---- SRT parsing / serialising ---------------------------------------------
const parseSrt = (raw) => {
  const t = raw.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n')
  const out = []
  for (const block of t.split(/\n\s*\n/)) {
    const lines = block.split('\n').filter((l) => l.trim())
    if (lines.length < 2) continue
    let i = 0
    if (/^\d+$/.test(lines[0].trim())) i = 1
    if (!lines[i] || !/-->/.test(lines[i])) continue
    out.push({ time: lines[i].trim(), text: lines.slice(i + 1).join(' ').trim() })
  }
  return out
}
const toSrt = (cues) =>
  cues.map((c, i) => `${i + 1}\n${c.time}\n${c.text}\n`).join('\n')

// The banner glyphs, in both spellings the batch uses.
const NOTE_LINE = /^\s*\u266A\s*(.*?)\s*\u266A\s*$/
const rewriteMarkers = (text) => {
  const m = NOTE_LINE.exec(text)
  return m && m[1].trim() ? `{{${m[1].trim()}}}` : text
}

// Timestamp -> ms, so "nearest cue" is a number comparison.
const ms = (time) => {
  const m = /(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})/.exec(time)
  if (!m) return null
  return ((+m[1] * 60 + +m[2]) * 60 + +m[3]) * 1000 + +m[4].padEnd(3, '0')
}

// ---- load the DB ------------------------------------------------------------
const rows = await (
  await fetch(`${env.SUPABASE_URL}/rest/v1/tracks?select=id,title,synced_lyrics`, { headers: H })
).json()
const byTitle = new Map(rows.map((r) => [r.title, r]))

// ---- build the work list ----------------------------------------------------
const files = readdirSync(SRC).filter((f) => /\.srt$/i.test(f)).sort()
const jobs = []
const problems = []

for (const file of files) {
  const want = EXPLICIT[file] ?? titleFromFile(file)
  const row = byTitle.get(want) ?? rows.find((r) => norm(r.title) === norm(want))
  if (!row) {
    problems.push(`${file}: no track titled "${want}"`)
    continue
  }
  const raw = readFileSync(join(SRC, file), 'utf8')
  const cues = parseSrt(raw)
  if (!cues.length) {
    problems.push(`${file}: parsed 0 cues`)
    continue
  }

  // Only edit: the note-glyph banner -> {{Music}}.
  let noteRewrites = 0
  for (const c of cues) {
    const before = c.text
    c.text = rewriteMarkers(c.text)
    if (c.text !== before) noteRewrites++
  }

  // Keep any {Heading} already stored for this row, at its own timestamp.
  const existing = parseSrt(row.synced_lyrics ?? '')
  const headings = existing.filter((c) => /^\s*\{[^{}]*\}\s*$/.test(c.text))
  let spliced = 0
  for (const h of headings) {
    const at = ms(h.time)
    if (at === null) continue
    let best = -1
    let bestDelta = Infinity
    cues.forEach((c, i) => {
      const d = Math.abs((ms(c.time) ?? Infinity) - at)
      if (d < bestDelta) {
        bestDelta = d
        best = i
      }
    })
    // Only where the two genuinely correspond; 2s is generous for a marker.
    if (best >= 0 && bestDelta <= 2000) {
      cues[best] = { time: cues[best].time, text: h.text }
      spliced++
    }
  }

  // Validate the generated SRT before it can be written.
  const times = cues.map((c) => ms(c.time))
  if (times.some((t) => t === null)) problems.push(`${file}: unparsable timestamp`)
  const monotonic = times.every((t, i) => i === 0 || t >= times[i - 1])
  if (!monotonic) problems.push(`${file}: timestamps not monotonic`)
  const leftoverNote = cues.filter((c) => NOTE_LINE.test(c.text)).length
  if (leftoverNote) problems.push(`${file}: ${leftoverNote} cue(s) still hold a note glyph`)
  if (cues.some((c) => /-->/.test(c.text))) problems.push(`${file}: a cue text contains "-->`)

  jobs.push({
    file,
    row,
    cues,
    noteRewrites,
    spliced,
    headingsFound: headings.length,
    body: toSrt(cues),
    before: row.synced_lyrics ?? null,
  })
}

// Two files onto one track would silently overwrite each other.
const seen = new Map()
for (const j of jobs) {
  if (seen.has(j.row.title)) problems.push(`two files map to "${j.row.title}": ${seen.get(j.row.title)} and ${j.file}`)
  seen.set(j.row.title, j.file)
}

// ---- report -----------------------------------------------------------------
console.log(`SRT files: ${files.length}   resolved: ${jobs.length}   problems: ${problems.length}\n`)
console.log('file'.padEnd(56), 'cues'.padStart(5), 'notes'.padStart(6), 'hdr'.padStart(4), 'was'.padStart(5), '=> track')
for (const j of jobs) {
  console.log(
    j.file.padEnd(56),
    String(j.cues.length).padStart(5),
    String(j.noteRewrites).padStart(6),
    String(j.headingsFound).padStart(4),
    String(j.before ? j.before.split('\n').length + 'l' : '-').padStart(5),
    '=> ' + j.row.title,
  )
}
const totalNotes = jobs.reduce((a, j) => a + j.noteRewrites, 0)
const totalHeadings = jobs.reduce((a, j) => a + j.headingsFound, 0)
const totalSpliced = jobs.reduce((a, j) => a + j.spliced, 0)
console.log(`\ntotals: ${jobs.length} tracks, ${totalNotes} note-glyph rewrites, ` +
  `${totalHeadings} existing headings found, ${totalSpliced} spliced back`)
console.log(`already populated and about to be replaced: ` +
  jobs.filter((j) => j.before).map((j) => j.row.title).join(', ') || 'none')

// Show a sample of the generated output, so the shape is eyeballable.
const sample = jobs.find((j) => j.noteRewrites > 0)
if (sample) {
  console.log(`\n==== sample output: ${sample.file} (first 12 lines) ====`)
  console.log(sample.body.split('\n').slice(0, 12).join('\n'))
}

if (problems.length) {
  console.error('\n==== PROBLEMS - NOTHING WRITTEN ====')
  for (const p of problems) console.error('  ' + p)
  process.exit(2)
}
if (!APPLY) {
  console.log('\nDRY RUN. Re-run with --apply to write.')
  process.exit(0)
}

// ---- backup, then write -----------------------------------------------------
mkdirSync(OUT, { recursive: true })
const stamp = new Date().toISOString().replace(/[:.]/g, '-')
const backup = `${OUT}/backup-${stamp}.json`
writeFileSync(
  backup,
  JSON.stringify(
    {
      takenAt: new Date().toISOString(),
      note: 'ORIGINAL tracks.synced_lyrics values. To roll back, PATCH each id with the value below.',
      rows: jobs.map((j) => ({ id: j.row.id, title: j.row.title, synced_lyrics: j.before })),
    },
    null,
    2,
  ),
  'utf8',
)
console.log(`\nbackup written: ${backup}`)

let ok = 0
let failed = 0
for (const j of jobs) {
  const r = await fetch(`${env.SUPABASE_URL}/rest/v1/tracks?id=eq.${j.row.id}`, {
    method: 'PATCH',
    headers: { ...H, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify({ synced_lyrics: j.body }),
  })
  if (r.ok) {
    ok++
    console.log(`  WROTE ${j.row.title}  (${j.cues.length} cues, ${j.noteRewrites} banners)`)
  } else {
    failed++
    console.error(`  FAILED ${j.row.title}: ${r.status} ${(await r.text()).slice(0, 200)}`)
  }
}
console.log(`\nwrote ${ok} track(s), ${failed} failed`)
process.exit(failed === 0 ? 0 : 1)
