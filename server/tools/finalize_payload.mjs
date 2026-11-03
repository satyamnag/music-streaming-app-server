#!/usr/bin/env node
// Validate the finished timeline for all three languages, then optionally write them.
//
// Inputs
//   --final out/final.srt       the reconciled Telugu timeline (with {{Music}})
//   --variant out/payload.json  render-variant-sync output for en / en_tr
//   --track <id>  --duration 291  [--shift -0.5]  [--write]
//
// Validation before anything is written:
//   * three columns, identical cue count
//   * identical start/end at every index, identical music mask
//   * every sung cue carries text in all three columns
//   * contiguous, 0 -> duration, no zero-length, no negative
//   * EVERY plain-lyric line is cued at least once, and every cue is an exact
//     plain-lyric line - so a line can never be silently dropped by the timeline
//   * with --expect-lyric-cues N, the timeline must carry exactly N sung cues (the
//     alignment script's own cue count), so an occurrence can never be dropped either
//   * with --shift, every sung cue moves by exactly that offset (head/tail music absorb
//     the clamp, so a lyric cue is never clamped)
// Then, with --write: back up the three columns, PATCH them in ONE request, and
// re-read to confirm the stored value equals what was produced.
//
// --allow-uncued-lines exists for the one legitimate case: a plain-lyric row that is
// not a sung line at all (the section/raga heading rows such as `రాగం: సింధుభైరవి`
// that the classifier still counts as a lyric). It is explicit and it is logged.
import crypto from 'node:crypto'
import fs from 'node:fs'
import {
  parseSrtTimeline, MUSIC_LABEL, splitLyricLines, classifyLine,
} from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const TRACK = arg('track')
const FINAL = arg('final', 'out/final.srt')
const VARIANT = arg('variant', 'out/payload.json')
const OFFSET_MS = Math.round(Number(arg('shift', 0)) * 1000)
const DURATION = Number(arg('duration'))
const WRITE = process.argv.includes('--write')
const EXPECT_LYRIC_CUES = arg('expect-lyric-cues') === null ? null : Number(arg('expect-lyric-cues'))
const ALLOW_UNCUED = process.argv.includes('--allow-uncued-lines')
const SUPA = (process.env.SUPABASE_URL || 'https://ngemrcsdfxufxnazeqke.supabase.co').replace(/\/$/, '')
const READ_KEY = process.env.SUPABASE_ANON_KEY
const WRITE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
const COLS = ['synced_lyrics', 'synced_lyrics_en', 'synced_lyrics_en_tr']

if (!TRACK) { console.error('--track <id> required'); process.exit(2) }
if (!(DURATION > 0)) { console.error('--duration required'); process.exit(2) }
if (!READ_KEY) { console.error('SUPABASE_ANON_KEY required'); process.exit(2) }

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex')
const fmt = (msv) => {
  const h = Math.floor(msv / 3600000)
  const m = Math.floor((msv % 3600000) / 60000)
  const s = Math.floor((msv % 60000) / 1000)
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(msv % 1000).padStart(3, '0')}`
}
const render = (cues) => cues.map((c, i) => `${i + 1}\n${fmt(c.s)} --> ${fmt(c.e)}\n${c.text}\n`).join('\n')
const toCues = (srt) => parseSrtTimeline(srt).map((c) => ({ s: Math.round(c.start * 1000), e: Math.round(c.end * 1000), text: c.text.trim() }))

const te = toCues(fs.readFileSync(FINAL, 'utf8'))
const [variantRow] = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=title,plain_lyrics,${COLS.join(',')}`, {
  headers: { apikey: READ_KEY, Authorization: `Bearer ${READ_KEY}` },
})).json()
if (!variantRow) { console.error('track not found'); process.exit(1) }
const variant = JSON.parse(fs.readFileSync(VARIANT, 'utf8'))
const en = toCues(variant.synced_lyrics_en || '')
const tr = toCues(variant.synced_lyrics_en_tr || '')

let fail = 0
const failIf = (cond, msg) => { if (cond) { console.error(`FAIL  ${msg}`); fail++ } }
failIf(!te.length, 'Telugu timeline is empty')
failIf(en.length !== te.length || tr.length !== te.length, `cue counts differ: te ${te.length} en ${en.length} en_tr ${tr.length}`)
if (!fail) {
  for (let i = 0; i < te.length; i++) {
    for (const [tag, col] of [['en', en], ['en_tr', tr]]) {
      if (col[i].s !== te[i].s || col[i].e !== te[i].e) failIf(true, `${tag} cue ${i + 1} timing differs from te`)
      if ((col[i].text === MUSIC_LABEL) !== (te[i].text === MUSIC_LABEL)) failIf(true, `${tag} cue ${i + 1} music mask differs`)
      if (te[i].text !== MUSIC_LABEL && !col[i].text.trim()) failIf(true, `${tag} cue ${i + 1} is empty`)
    }
  }
  const sung = te.map((c, i) => (c.text === MUSIC_LABEL ? -1 : i)).filter((i) => i >= 0)
  failIf(sung.length === 0, 'no sung cues')
  for (const col of [te, en, tr]) {
    for (let i = 0; i < col.length; i++) {
      if (col[i].e <= col[i].s) failIf(true, 'zero-length cue')
      if (i && col[i].s !== col[i - 1].e) failIf(true, 'gap/overlap in a column')
    }
  }
  failIf(te[0].s !== 0, 'Telugu does not start at 0')
  failIf(Math.abs(te[te.length - 1].e - Math.round(DURATION * 1000)) > 50, 'Telugu does not end at the duration')
}

// --- "no line is ever missed" ------------------------------------------------------
// The timeline exists to time the plain lyrics. A structurally perfect SRT that omits a
// whole line is still wrong, and nothing above this point can see that: it only checks
// the timeline against itself. Measured on Pattabhi Raamuni, one 25.3 s cue carried the
// refrain once while the singer repeats it three times inside that span (the ASR never
// transcribed those repeats), so every check here passed and the repeats were simply
// gone. Both directions are therefore checked against the source of truth:
//   * every plain-lyric line appears in at least one cue, and
//   * every cue's text is an exact plain-lyric line.
const plainLines = splitLyricLines(variantRow.plain_lyrics || '')
  .map((l) => String(l).trim())
  .filter((l) => l && classifyLine(l) === 'lyric')
const sungTexts = te.filter((c) => c.text !== MUSIC_LABEL).map((c) => c.text)
const cuedSet = new Set(sungTexts)
const plainSet = new Set(plainLines)
const uncued = plainLines.filter((l) => !cuedSet.has(l))
const foreign = [...new Set(sungTexts.filter((t) => !plainSet.has(t)))]
const counts = new Map()
for (const t of sungTexts) counts.set(t, (counts.get(t) || 0) + 1)

console.log(`\nplain lyric lines: ${plainLines.length}   sung cues: ${sungTexts.length}`)
const repeated = [...counts].filter(([, n]) => n > 1).sort((a, b) => b[1] - a[1])
if (repeated.length) {
  console.log('repeated lines (occurrences in the timeline):')
  for (const [t, n] of repeated) console.log(`  ${String(n).padStart(2)}x  ${t.slice(0, 44)}`)
}
if (uncued.length) {
  if (ALLOW_UNCUED) {
    console.log(`ALLOWED (--allow-uncued-lines): ${uncued.length} plain line(s) have no cue:`)
    for (const l of uncued) console.log(`  ${l}`)
  } else {
    fail++
    console.error(`FAIL  ${uncued.length} plain-lyric line(s) have NO cue in the timeline:`)
    for (const l of uncued) console.error(`        ${l}`)
    console.error('      Refusing to write a timeline that omits a lyric line. If one of these is')
    console.error('      not a sung line at all (a section/raga heading row), pass')
    console.error('      --allow-uncued-lines and say so in the commit message.')
  }
}
if (foreign.length) {
  fail++
  console.error(`FAIL  ${foreign.length} cue(s) are not exact plain-lyric lines:`)
  for (const t of foreign.slice(0, 10)) console.error(`        ${t}`)
}
if (EXPECT_LYRIC_CUES !== null && Number.isFinite(EXPECT_LYRIC_CUES)) {
  failIf(sungTexts.length !== EXPECT_LYRIC_CUES,
    `the alignment script has ${EXPECT_LYRIC_CUES} cue(s) but the timeline has ${sungTexts.length} - an occurrence was dropped`)
} else {
  console.log('(no --expect-lyric-cues: occurrences are reported, not gated)')
}

// optional shift, applied identically to all three columns
let out = { te, en, tr }
if (!fail && OFFSET_MS) {
  const shiftCol = (cues) => {
    const o = cues.map((c) => ({ s: c.s + OFFSET_MS, e: c.e + OFFSET_MS, text: c.text }))
    o[0].s = 0
    o[o.length - 1].e = Math.round(DURATION * 1000)
    return o
  }
  out = { te: shiftCol(te), en: shiftCol(en), tr: shiftCol(tr) }
  for (const [tag, before, after] of [['te', te, out.te], ['en', en, out.en], ['en_tr', tr, out.tr]]) {
    for (let i = 0; i < before.length; i++) {
      if (before[i].text !== MUSIC_LABEL && after[i].s - before[i].s !== OFFSET_MS) failIf(true, `${tag} cue ${i + 1} did not move by ${OFFSET_MS}ms`)
      if (after[i].text !== before[i].text) failIf(true, `${tag} cue ${i + 1} text changed`)
    }
    if (after[0].s !== 0 || after[after.length - 1].e !== Math.round(DURATION * 1000)) failIf(true, `${tag} lost its 0 -> duration anchor`)
  }
}
// --- "the upload does not describe the whole song" guard --------------------
// A {{Music}} cue covering a huge share of the track means the aligner ran out of
// script and had nothing left to place: measured on Pattabhi Raamuni, 41 cues were
// packed into the first 131s and one banner then covered 131.5 -> 292.0 (55% of the
// track) while the independent ASR still heard words at 288.9s. Structurally valid,
// semantically wrong. Refuse rather than ship a half-timed track; a genuinely long
// instrumental can be allowed with --max-music-fraction.
const MAX_MUSIC_FRACTION = Number(arg('max-music-fraction', 0.25))
const durationMs = Math.round(DURATION * 1000)
const musicCues = out.te.filter((c) => c.text === MUSIC_LABEL)
let longestMusic = { len: 0, s: 0, e: 0 }
for (const c of musicCues) {
  const len = c.e - c.s
  if (len > longestMusic.len) longestMusic = { len, s: c.s, e: c.e }
}
const musicShare = longestMusic.len / durationMs
if (musicShare > MAX_MUSIC_FRACTION) {
  fail++
  console.error(
    `\nFAIL  one {{Music}} cue covers ${(musicShare * 100).toFixed(1)}% of the track ` +
    `(${(longestMusic.s / 1000).toFixed(2)}s -> ${(longestMusic.e / 1000).toFixed(2)}s of ${DURATION}s), ` +
    `above the ${(MAX_MUSIC_FRACTION * 100).toFixed(0)}% limit.\n` +
    '      That almost always means the uploaded SRT does not list every sung line, so the\n' +
    '      aligner ran out of script part-way through. Check the upload first. If this track\n' +
    '      genuinely has a long instrumental passage, re-run with --max-music-fraction 0.5.',
  )
} else {
  console.log(`longest {{Music}} cue: ${(longestMusic.len / 1000).toFixed(2)}s ` +
              `(${(musicShare * 100).toFixed(1)}% of the track, limit ${(MAX_MUSIC_FRACTION * 100).toFixed(0)}%)`)
}

if (fail) { console.error(`\n${fail} finding(s) - REFUSING to write`); process.exit(1) }

const musicCount = out.te.filter((c) => c.text === MUSIC_LABEL).length
console.log(`timeline OK: ${out.te.length} cues (${out.te.length - musicCount} sung, ${musicCount} music), 0 -> ${DURATION}s`)
if (OFFSET_MS) console.log(`shift applied to all three columns: ${OFFSET_MS}ms`)

const payload = { synced_lyrics: render(out.te), synced_lyrics_en: render(out.en), synced_lyrics_en_tr: render(out.tr) }
console.log('hashes:')
for (const [field, tag] of [['synced_lyrics', 'te'], ['synced_lyrics_en', 'en'], ['synced_lyrics_en_tr', 'en_tr']]) {
  console.log(`  ${tag.padEnd(6)} ${sha(payload[field]).slice(0, 16)}…`)
}

if (!WRITE) {
  console.log('\nDRY RUN - nothing written. Re-run with --write to apply.')
  process.exitCode = 0
} else {
  if (!WRITE_KEY) { console.error('SUPABASE_SERVICE_ROLE_KEY required for --write'); process.exit(2) }
  fs.writeFileSync('sync-from-srt-backup.json', JSON.stringify({
    track: TRACK, title: variantRow.title, shift_ms: OFFSET_MS,
    before: Object.fromEntries(COLS.map((c) => [c, variantRow[c]])),
  }, null, 1), 'utf8')
  console.log('\nbackup written to sync-from-srt-backup.json')

  const patch = await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}`, {
    method: 'PATCH',
    headers: { apikey: WRITE_KEY, Authorization: `Bearer ${WRITE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify(payload),
  })
  console.log(`PATCH http=${patch.status}`)
  if (!patch.ok) { console.error((await patch.text()).slice(0, 300)); process.exit(1) }

  const back = await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${encodeURIComponent(TRACK)}&select=${COLS.join(',')}`, {
    headers: { apikey: READ_KEY, Authorization: `Bearer ${READ_KEY}` },
  })).json()
  let ok = true
  for (const field of COLS) {
    const same = sha(String(back[0][field] || '').trim()) === sha(payload[field].trim())
    console.log(`read-back ${field.padEnd(20)} identical: ${same}`)
    if (!same) ok = false
  }
  console.log(ok ? 'WROTE all three columns; read-back matches exactly.' : 'READ-BACK MISMATCH')
  process.exitCode = ok ? 0 : 1
}
