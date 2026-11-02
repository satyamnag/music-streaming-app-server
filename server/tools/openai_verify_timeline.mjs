// Read-only OpenAI verification of a STORED timeline.
//
// The model is used as an independent adjudicator, never as a timing source: it may
// only choose among the measured cue spans we hand it (same contract as
// server/libs/openaiLyricSecondOpinion.mjs). It answers "which of these measured
// segments sings this lyric line", and we then check whether the segment it picks
// is one that OUR timeline already assigns to that line.
//
//   node openai_verify_timeline.mjs <trackId> [out.json]
import fs from 'node:fs'
import { secondOpinionPicks, OPENAI_DEFAULT_MODEL } from '../libs/openaiLyricSecondOpinion.mjs'
import {
  splitLyricLines, classifyLine, normaliseWord, parseSrtTimeline, MUSIC_LABEL,
} from '../libs/autoSyncLyrics.mjs'

const ID = process.argv[2]
const OUT = process.argv[3] || 'openai-verify.json'
const KEY = process.env.OPENAI_API_KEY
const SUPA = 'https://ngemrcsdfxufxnazeqke.supabase.co'
const SKEY = process.env.SUPABASE_ANON_KEY
if (!KEY) { console.error('OPENAI_API_KEY required'); process.exit(2) }
if (!SKEY) { console.error('SUPABASE_ANON_KEY required'); process.exit(2) }

const UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
const row = (await (await fetch(`${SUPA}/rest/v1/tracks?id=eq.${ID}&select=title,plain_lyrics,synced_lyrics`, {
  headers: { apikey: SKEY, Authorization: `Bearer ${SKEY}`, 'User-Agent': UA },
})).json())[0]
const wrec = JSON.parse(fs.readFileSync('whisper-words.json', 'utf8')).find((w) => w.id === ID)

const lines = splitLyricLines(row.plain_lyrics)
  .map((l) => String(l).trim())
  .filter((l) => classifyLine(l) === 'lyric')
  .map((text, index) => ({ index, text }))

const cues = parseSrtTimeline(row.synced_lyrics).filter((c) => c.text.trim() !== MUSIC_LABEL)
const words = wrec.words
const segments = cues.map((c, index) => ({
  index,
  start: c.start,
  end: c.end,
  text: words.filter((w) => w.start >= c.start - 0.05 && w.start < c.end).map((w) => String(w.word).trim()).join(' '),
}))

console.log(`${row.title}: ${lines.length} lyric lines, ${segments.length} measured segments`)
const res = await secondOpinionPicks({ apiKey: KEY, lines, segments, model: OPENAI_DEFAULT_MODEL })
console.log(`model ${res.model}  ok=${res.ok}  reason=${res.reason || '-'}  picks=${res.picks.length}  ${res.elapsed_ms}ms`)
if (!res.ok) {
  fs.writeFileSync(OUT, JSON.stringify({ ok: false, reason: res.reason, model: res.model }, null, 1), 'utf8')
  process.exit(1)
}

// For each lyric line: which segments does OUR timeline assign to it?
const oursForLine = new Map()
cues.forEach((c, i) => {
  const li = lines.findIndex((l) => l.text === c.text.trim())
  if (li < 0) return
  if (!oursForLine.has(li)) oursForLine.set(li, [])
  oursForLine.get(li).push(i)
})

const perLine = lines.map((l) => {
  // validatePicks() returns camelCase: { lineIndex, segmentIndex, agreement, reason }
  const pick = res.picks.find((p) => p.lineIndex === l.index) || null
  const ours = oursForLine.get(l.index) || []
  const agrees = pick ? (pick.segmentIndex === -1 ? 'never_sung' : (ours.includes(pick.segmentIndex) ? 'agrees' : 'disagrees')) : 'no_pick'
  return {
    line_index: l.index,
    text: l.text,
    model_segment: pick ? pick.segmentIndex : null,
    model_agreement: pick ? pick.agreement : null,
    model_reason: pick ? pick.reason : null,
    our_segments: ours,
    verdict: agrees,
  }
})

const tally = perLine.reduce((a, p) => { a[p.verdict] = (a[p.verdict] || 0) + 1; return a }, {})
for (const p of perLine) {
  const s = p.model_segment !== null && p.model_segment >= 0 ? segments[p.model_segment] : null
  console.log(`  ${p.verdict.padEnd(11)} L${String(p.line_index).padStart(2)} model seg ${String(p.model_segment).padStart(3)}${s ? ` @${s.start.toFixed(1)}s` : '        '}  ours [${p.our_segments.join(',') || '-'}]  ${p.text.slice(0, 30)}`)
}
console.log(`\nverdicts: ${JSON.stringify(tally)}`)
const total = perLine.length
const agrees = tally.agrees || 0
console.log(`independent agreement on placed lines: ${agrees}/${total} (${((agrees / Math.max(1, total)) * 100).toFixed(0)}%)`)

fs.writeFileSync(OUT, JSON.stringify({ id: ID, title: row.title, model: res.model, tally, picks: res.picks, perLine }, null, 1), 'utf8')
console.log(`wrote ${OUT}`)
