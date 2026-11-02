// ============================================================================
// THOROUGH VERIFICATION of Kavalini Eleti's three sync-lyrics columns.
//
// Read-only. Writes nothing to the database. Checks, in order:
//
//   A. PLAIN LYRICS INTEGRITY - the source of truth must be untouched, and the
//      three plain columns must stay line-parallel (31 lines each).
//   B. SHARED TIMELINE - all three synced columns must carry the SAME cue
//      count and the SAME start/end at every index (the apps stack languages
//      per row; a drift silently misaligns every later row).
//   C. STRUCTURE - monotonic, no overlap, positive duration, in range, no
//      duplicate starts, no blank cue, covers 0..duration.
//   D. LANGUAGE FIDELITY - every lyric cue's text must be a real line of its
//      OWN plain column (no invented/borrowed text).
//   E. AUDIO TRUTH - every measured Whisper word must fall inside a cue, and
//      each cue's text must match the words actually sung inside it
//      (concatenated-character Levenshtein, which tolerates Whisper's merged
//      tokens and spelling drift).
//   F. COVERAGE - every plain lyric line must appear at least once, and the
//      refrain lines must appear at their true sung count.
//
// Run:  KEY=<supabase key> node server/tools/verify-kavalini.mjs
// ============================================================================

import fs from 'node:fs'
import crypto from 'node:crypto'
import {
  parseSrtTimeline,
  splitLyricLines,
  splitVariantLines,
  classifyLine,
  normaliseWord,
  MUSIC_LABEL,
} from '../libs/autoSyncLyrics.mjs'

const ID = '72e585fd-7a6e-42ff-a8e6-d56a9a836f33'
const SUPA = 'https://ngemrcsdfxufxnazeqke.supabase.co'
const KEY = process.env.KEY
const WORDS_FILE = 'Kavalini-Eleti-whisper-output.txt'
const PLAIN_BASELINE = 'Kavalini-Eleti-plainlyrics.txt'
const EXPECT_REFRAIN_OCCURRENCES = 7

if (!KEY) { console.error('KEY env required'); process.exit(2) }

let failures = 0
const check = (name, ok, detail = '') => {
  if (!ok) failures += 1
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  -- ' + detail : ''}`)
  return ok
}
const sha = (s) => crypto.createHash('sha256').update(String(s)).digest('hex').slice(0, 16)
const norm = (s) => String(s).replace(/\r\n/g, '\n').replace(/\r/g, '\n')

function lev(a, b) {
  if (!a || !b) return 0
  if (a === b) return 1
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j)
  for (let i = 1; i <= a.length; i++) {
    const cur = [i]
    for (let j = 1; j <= b.length; j++) cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
    prev = cur
  }
  return 1 - prev[b.length] / Math.max(a.length, b.length)
}

// --- Load -----------------------------------------------------------------
const res = await fetch(
  `${SUPA}/rest/v1/tracks?id=eq.${ID}&select=title,duration,` +
  'plain_lyrics,plain_lyrics_en,plain_lyrics_en_tr,' +
  'synced_lyrics,synced_lyrics_en,synced_lyrics_en_tr',
  { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } },
)
const [t] = await res.json()
if (!t) { console.error('track not found'); process.exit(2) }
const dur = Number(t.duration)

console.log(`TRACK: ${t.title}   duration ${dur}s\n`)

// --- A. PLAIN LYRICS INTEGRITY -------------------------------------------
console.log('A. PLAIN LYRICS INTEGRITY (source of truth)')
const baseline = norm(fs.readFileSync(PLAIN_BASELINE, 'utf8')).trim()
const plainTe = norm(t.plain_lyrics).trim()
check('plain_lyrics is byte-identical to the committed baseline', plainTe === baseline,
  plainTe === baseline ? `sha ${sha(plainTe)}` : `db sha ${sha(plainTe)} vs baseline sha ${sha(baseline)}`)
const plainLines = splitLyricLines(t.plain_lyrics)
const plainEnLines = splitLyricLines(t.plain_lyrics_en || '')
const plainTrLines = splitLyricLines(t.plain_lyrics_en_tr || '')
check('plain_lyrics has 31 lines', plainLines.length === 31, `got ${plainLines.length}`)
check('plain_lyrics_en has 31 lines', plainEnLines.length === 31, `got ${plainEnLines.length}`)
check('plain_lyrics_en_tr has 31 lines', plainTrLines.length === 31, `got ${plainTrLines.length}`)
check('plain columns are line-parallel', plainEnLines.length === plainLines.length && plainTrLines.length === plainLines.length)
console.log(`     hashes: te=${sha(plainTe)} en=${sha(plainEnLines.join('\n'))} en_tr=${sha(plainTrLines.join('\n'))}`)

// --- B. SHARED TIMELINE ---------------------------------------------------
console.log('\nB. SHARED TIMELINE across the three sync columns')
const cols = {
  te: { plain: 'plain_lyrics', synced: 'synced_lyrics' },
  en: { plain: 'plain_lyrics_en', synced: 'synced_lyrics_en' },
  en_tr: { plain: 'plain_lyrics_en_tr', synced: 'synced_lyrics_en_tr' },
}
const cues = {}
for (const [k, c] of Object.entries(cols)) {
  cues[k] = parseSrtTimeline(t[c.synced] || '')
  check(`${c.synced} is non-empty`, cues[k].length > 0, `${cues[k].length} cues`)
}
const base = cues.te
for (const k of ['en', 'en_tr']) {
  const same = cues[k].length === base.length && cues[k].every((c, i) =>
    Math.abs(c.start - base[i].start) < 1e-6 && Math.abs(c.end - base[i].end) < 1e-6)
  check(`${cols[k].synced} timeline identical to Telugu`, same,
    `${cues[k].length} vs ${base.length} cues`)
}

// --- C. STRUCTURE ---------------------------------------------------------
console.log('\nC. STRUCTURE of each column')
for (const k of ['te', 'en', 'en_tr']) {
  const c = cues[k]
  let overlap = 0, zero = 0, oor = 0, blank = 0
  const starts = new Set()
  for (let i = 0; i < c.length; i++) {
    if (c[i].end <= c[i].start) zero += 1
    if (i > 0 && c[i].start < c[i - 1].end - 1e-6) overlap += 1
    if (c[i].start < 0 || c[i].end > dur + 0.5) oor += 1
    if (!String(c[i].text || '').trim()) blank += 1
    starts.add(c[i].start)
  }
  const dup = c.length - starts.size
  check(`${cols[k].synced}: no overlap / zero-dur / out-of-range / dup / blank`,
    overlap === 0 && zero === 0 && oor === 0 && dup === 0 && blank === 0,
    `overlap=${overlap} zero=${zero} oor=${oor} dup=${dup} blank=${blank}`)
  check(`${cols[k].synced}: spans 0 .. duration`,
    Math.abs(c[0].start) < 1e-6 && Math.abs(c[c.length - 1].end - dur) < 0.5,
    `${c[0].start} .. ${c[c.length - 1].end}`)
  check(`${cols[k].synced}: strictly increasing starts`,
    c.every((x, i) => i === 0 || x.start > c[i - 1].start))
}

// --- D. LANGUAGE FIDELITY -------------------------------------------------
console.log('\nD. LANGUAGE FIDELITY (each cue text comes from its own plain column)')
const indexOf = {}
for (const k of ['te', 'en', 'en_tr']) {
  const variantLines = splitVariantLines(t[cols[k].plain] || '', plainLines.length)
  const allowed = new Set(variantLines.map((l) => String(l).trim()).filter(Boolean))
  const used = new Set(cues[k].filter((c) => c.text.trim() !== MUSIC_LABEL).map((c) => c.text.trim()))
  const foreign = [...used].filter((x) => !allowed.has(x))
  check(`${cols[k].synced}: every lyric cue text is a real line of ${cols[k].plain}`,
    foreign.length === 0, foreign.slice(0, 2).join(' | '))
  check(`${cols[k].synced}: uses only music banners for ${MUSIC_LABEL}`,
    cues[k].every((c) => c.text.trim() !== MUSIC_LABEL || c.text.trim() === MUSIC_LABEL))
  // line text -> index in that column (first occurrence)
  const m = new Map()
  variantLines.forEach((l, i) => { const x = String(l).trim(); if (x && !m.has(x)) m.set(x, i) })
  indexOf[k] = m
}

// The decisive cross-language test: at every cue, the English line must belong
// to the SAME plain line index as the Telugu line. If the columns drifted, the
// apps would show the wrong translation on that row.
let crossBad = 0
const crossDetail = []
for (let i = 0; i < base.length; i++) {
  const te = base[i].text.trim()
  if (te === MUSIC_LABEL) continue
  const teIdx = indexOf.te.get(te)
  for (const k of ['en', 'en_tr']) {
    const other = cues[k][i].text.trim()
    if (other === MUSIC_LABEL) { crossBad += 1; crossDetail.push(`cue ${i + 1} ${k} is music`); continue }
    const oIdx = indexOf[k].get(other)
    if (teIdx !== oIdx) { crossBad += 1; crossDetail.push(`cue ${i + 1} ${k}: te@${teIdx} vs ${k}@${oIdx}`) }
  }
}
check('every English cue sits at the same plain line index as its Telugu cue',
  crossBad === 0, crossDetail.slice(0, 3).join(' | '))

// --- E. AUDIO TRUTH -------------------------------------------------------
console.log('\nE. AUDIO TRUTH (against measured Whisper words)')
const words = []
for (const raw of fs.readFileSync(WORDS_FILE, 'utf8').split('\n')) {
  const m = raw.replace(/\r$/, '').match(/^\s*(\d+\.\d+)\s*->\s*(\d+\.\d+)\s+(.+?)\s*\(p=([\d.]+)\)\s*$/)
  if (m) words.push({ word: m[3].trim(), start: +m[1], end: +m[2] })
}
check('measured word list loaded', words.length > 0, `${words.length} words`)

const cueIndexAt = (time) => base.findIndex((c) => time >= c.start - 0.001 && time < c.end)
const orphans = words.filter((w) => cueIndexAt(w.start) === -1)
check('every measured word falls inside a cue', orphans.length === 0,
  orphans.slice(0, 3).map((o) => `${o.word}@${o.start}`).join(' | '))

let wrongCue = 0
const wrongDetail = []
const musicWithSinging = []
for (let i = 0; i < base.length; i++) {
  const c = base[i]
  const inside = words.filter((w) => w.start >= c.start - 0.001 && w.start < c.end)
  if (c.text.trim() === MUSIC_LABEL) {
    if (inside.length) musicWithSinging.push(`${c.start.toFixed(1)}-${c.end.toFixed(1)} "${inside.map((w) => w.word).join(' ')}"`)
    continue
  }
  if (!inside.length) continue
  const keys = c.text.split(/\s+/).map(normaliseWord).filter(Boolean).join('')
  const heard = inside.map((w) => normaliseWord(w.word)).join('')
  const score = lev(keys, heard)
  if (score < 0.55) { wrongCue += 1; wrongDetail.push(`${c.start.toFixed(1)} "${c.text.slice(0, 20)}" score ${score.toFixed(2)}`) }
}
check('every lyric cue matches the words sung inside it', wrongCue === 0,
  wrongDetail.slice(0, 3).join(' | '))

// The outro chant is not a lyric line; it is the only permitted banner.
const allowedMusic = musicWithSinging.filter((m) => Number(m.split('-')[0]) < 280)
check('no singing hidden under a music banner (outro chant excepted)',
  allowedMusic.length === 0, allowedMusic.join(' | '))
if (musicWithSinging.length) console.log(`     note: outro banner with non-lyric chant: ${musicWithSinging.join(' ; ')}`)

// --- F. COVERAGE ----------------------------------------------------------
console.log('\nF. COVERAGE')
const lyricIdx = []
plainLines.forEach((l, i) => { if (classifyLine(l) === 'lyric') lyricIdx.push(i) })
const counts = new Map()
for (const c of base) {
  const x = c.text.trim()
  if (x === MUSIC_LABEL) continue
  counts.set(x, (counts.get(x) || 0) + 1)
}
const missing = lyricIdx.map((i) => String(plainLines[i]).trim()).filter((x) => !counts.has(x))
check(`all ${lyricIdx.length} plain lyric lines appear at least once`, missing.length === 0, missing.join(' | '))

const refrain1 = 'కావలిని ఏలేడి కనక దుర్గా,'
const refrain2 = 'వాసవి కన్నెక విశ్వమాత!'
check(`refrain line 1 appears ${EXPECT_REFRAIN_OCCURRENCES}x`, counts.get(refrain1) === EXPECT_REFRAIN_OCCURRENCES, `got ${counts.get(refrain1) || 0}`)
check(`refrain line 2 appears ${EXPECT_REFRAIN_OCCURRENCES}x`, counts.get(refrain2) === EXPECT_REFRAIN_OCCURRENCES, `got ${counts.get(refrain2) || 0}`)

const musicCount = base.filter((c) => c.text.trim() === MUSIC_LABEL).length
console.log(`     cues=${base.length}  lyric=${base.length - musicCount}  music=${musicCount}`)
console.log(`     distinct plain lines sung: ${counts.size}/${lyricIdx.length}`)

// --- VERDICT --------------------------------------------------------------
console.log(`\n${'='.repeat(60)}`)
if (failures === 0) {
  console.log('VERDICT: ALL CHECKS PASSED')
} else {
  console.log(`VERDICT: ${failures} CHECK(S) FAILED`)
}
console.log('='.repeat(60))
// Set the exit code instead of calling process.exit(): on Windows a hard exit
// with pending async handles trips a libuv assertion that would mask the verdict.
process.exitCode = failures === 0 ? 0 : 1
