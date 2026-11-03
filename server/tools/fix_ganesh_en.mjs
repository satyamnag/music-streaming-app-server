#!/usr/bin/env node
// ONE-OFF, GUARDED content fix for Ganesh Gayatri Mantra.
//
// Problem: plain_lyrics_en has 14 lines while plain_lyrics (the source of truth) and
// plain_lyrics_en_tr both have 19. The English column also merged two lines per
// stanza, so every entry after the first is misaligned and the track cannot be
// synced (its three synced columns currently hold 48 / 29 / 48 cues).
//
// This rebuilds plain_lyrics_en as exactly 19 line-parallel lines:
//   * 16 lines are the EXISTING author text, moved to the correct index, verbatim
//   * 3 lines are new, approved by the owner:
//       మహోదరాయ ధీమహి   -> "We meditate on the One with the great belly."
//       వక్రతుండాయ ధీమహి -> "We meditate on the One with the curved trunk."
//       ఓం తత్పురుషాయ విద్మహే -> "Om, let us meditate on the Supreme Person;"
//
// GUARDS: the Telugu column and the transliteration column must be byte-identical
// to the hashes captured when the change was approved, otherwise it refuses to run.
// plain_lyrics is never written.
//
//   node fix_ganesh_en.mjs            dry run - prints the resulting column
//   node fix_ganesh_en.mjs --write    performs the PATCH (needs service role key)
import crypto from 'node:crypto'
import fs from 'node:fs'

const ID = 'f64c8a76-2b7e-4e85-8bc6-863b6daf9120'
const TITLE = 'Ganesh Gayatri Mantra'
const GUARD_TE = '868c88e7d7596282324f044c70b45eafa18365872296b4d6f38fc6d146fd0054'
const GUARD_TR = 'd224ad9baab6dc323e83b57992c7f4ef820f4bb3f657a1ffc17a74af8266c119'
const GUARD_EN = 'f6432c5021cdafe3095e2446e82b68b08aac6bb898b447d2ab9cd629e4bd551d'
const SUPA = 'https://ngemrcsdfxufxnazeqke.supabase.co'
const READ_KEY = process.env.SUPABASE_ANON_KEY
const WRITE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
const WRITE = process.argv.includes('--write')

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex')
const raw = (s) => String(s || '').replace(/\r\n/g, '\n').split('\n')

// The 19-line English column: index -> text. '' stays blank, matching the Telugu.
const EXISTING = {
  meditateLargeBelly: 'Om, let us meditate on the One with the large belly;',
  meditateGreatPower: 'Om, let us meditate on the One of immense power;',
  meditateSingleTusk: 'Om, let us meditate on the One with a single tusk;',
  meditateSupremeBeing: 'Om, let us meditate on the Supreme Being;',
  meditateElephantFace: 'Om, let us meditate on the One with the elephant face;',
  inspireIntellect: 'May that tusked One inspire and guide our intellect.',
}
const APPROVED = {
  mahodarayaDheemahi: 'We meditate on the One with the great belly.',
  vakratundayaDheemahi: 'We meditate on the One with the curved trunk.',
  tatpurushayaVidmahe: 'Om, let us meditate on the Supreme Person;',
}

const EN19 = [
  EXISTING.meditateLargeBelly,          // 0  ఓం లంబోదరాయ విద్మహే
  APPROVED.mahodarayaDheemahi,          // 1  మహోదరాయ ధీమహి  (new)
  EXISTING.inspireIntellect,            // 2  తన్నో దంతిః ప్రచోదయాత్
  '',                                   // 3  blank
  EXISTING.meditateGreatPower,          // 4  ఓం మహోత్కటాయ విద్మహే
  APPROVED.vakratundayaDheemahi,        // 5  వక్రతుండాయ ధీమహి  (new)
  EXISTING.inspireIntellect,            // 6  తన్నో దంతిః ప్రచోదయాత్
  '',                                   // 7  blank
  EXISTING.meditateSingleTusk,          // 8  ఓం ఏకదంతాయ విద్మహే
  APPROVED.vakratundayaDheemahi,        // 9  వక్రతుండాయ ధీమహి  (new)
  EXISTING.inspireIntellect,            // 10 తన్నో దంతిః ప్రచోదయాత్
  '',                                   // 11 blank
  EXISTING.meditateSupremeBeing,        // 12 ఓం తత్కరాటాయ విద్మహే
  EXISTING.meditateElephantFace,        // 13 హస్తిముఖాయ ధీమహి
  EXISTING.inspireIntellect,            // 14 తన్నో దంతిః ప్రచోదయాత్
  '',                                   // 15 blank
  APPROVED.tatpurushayaVidmahe,         // 16 ఓం తత్పురుషాయ విద్మహే  (new)
  APPROVED.vakratundayaDheemahi,        // 17 వక్రతుండాయ ధీమహి  (new)
  EXISTING.inspireIntellect,            // 18 తన్నో దంతిః ప్రచోదయాత్
]

const got = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${ID}&select=title,plain_lyrics,plain_lyrics_en,plain_lyrics_en_tr`, {
  headers: { apikey: READ_KEY, Authorization: `Bearer ${READ_KEY}` },
})).json()
const row = got[0]
if (!row) throw new Error('track not found')
if (row.title !== TITLE) throw new Error(`title mismatch: ${row.title}`)

const teHash = sha(row.plain_lyrics)
const trHash = sha(row.plain_lyrics_en_tr)
const enHash = sha(row.plain_lyrics_en)
if (teHash !== GUARD_TE) throw new Error(`plain_lyrics changed since approval (${teHash}) - refusing`)
if (trHash !== GUARD_TR) throw new Error(`plain_lyrics_en_tr changed since approval (${trHash}) - refusing`)
if (enHash !== GUARD_EN) throw new Error(`plain_lyrics_en changed since approval (${enHash}) - refusing`)

const teLines = raw(row.plain_lyrics)
const trLines = raw(row.plain_lyrics_en_tr)
if (teLines.length !== 19) throw new Error(`expected 19 telugu lines, got ${teLines.length}`)
if (trLines.length !== 19) throw new Error(`expected 19 transliteration lines, got ${trLines.length}`)
for (let i = 0; i < 19; i++) {
  const teBlank = !String(teLines[i]).trim()
  const trBlank = !String(trLines[i]).trim()
  if (teBlank !== trBlank) throw new Error(`telugu/transliteration blank mismatch at ${i}`)
  if (teBlank !== (EN19[i] === '')) throw new Error(`english blank mismatch at ${i}`)
}

const next = EN19.join('\n')
console.log(`${TITLE}: plain_lyrics_en ${raw(row.plain_lyrics_en).length} -> 19 lines`)
console.log('guards ok: telugu hash, transliteration hash, current english hash\n')
for (let i = 0; i < 19; i++) {
  const mark = String(row.plain_lyrics_en).includes(EN19[i]) && EN19[i] !== '' ? '   ' : 'NEW'
  console.log(`${mark} ${String(i).padStart(2)} | ${(teLines[i] ?? '').padEnd(30)} | ${EN19[i]}`)
}

if (!WRITE) {
  console.log('\nDRY RUN - nothing written. Re-run with --write to apply.')
  process.exitCode = 0
}
if (WRITE) {
if (!WRITE_KEY) throw new Error('SUPABASE_SERVICE_ROLE_KEY required for --write')

fs.writeFileSync('ganesh-en-backup.json', JSON.stringify({ id: ID, before: row.plain_lyrics_en, after: next }, null, 1), 'utf8')

const res = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${ID}`, {
  method: 'PATCH',
  headers: {
    apikey: WRITE_KEY, Authorization: `Bearer ${WRITE_KEY}`,
    'Content-Type': 'application/json', Prefer: 'return=representation',
  },
  body: JSON.stringify({ plain_lyrics_en: next }),
})
if (!res.ok) throw new Error(`PATCH ${res.status}: ${(await res.text()).slice(0, 300)}`)

const after = (await res.json())[0]
const enAfter = raw(after.plain_lyrics_en)
console.log(`\nPATCH ok. plain_lyrics_en now ${enAfter.length} lines`)
if (enAfter.length !== 19) throw new Error('post-write line count wrong')
console.log('telugu unchanged  :', sha(after.plain_lyrics) === GUARD_TE)
console.log('transliteration unchanged:', sha(after.plain_lyrics_en_tr) === GUARD_TR)
console.log('english hash      :', sha(after.plain_lyrics_en))
}
