// Make a segmented timeline span exactly 0 -> duration by adding {{Music}} cues.
// The greedy segmenter only emits cues where singing was matched, so the head and tail
// of the track would otherwise be uncovered - the apps expect a contiguous timeline.
import fs from 'node:fs'
import { parseSrtTimeline, renderCuesToSrt, MUSIC_LABEL } from '../libs/autoSyncLyrics.mjs'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i === -1 ? d : process.argv[i + 1]
}
const SRT = arg('srt')
const DURATION = Number(arg('duration'))
const OUT = arg('out')
if (!SRT || !(DURATION > 0) || !OUT) {
  console.error('--srt <file> --duration <seconds> --out <file> required')
  process.exit(2)
}

const cues = parseSrtTimeline(fs.readFileSync(SRT, 'utf8'))
if (!cues.length) { console.error('no cues in ' + SRT); process.exit(1) }

const out = []
if (cues[0].start > 0.05) out.push({ kind: 'music', text: MUSIC_LABEL, start: 0, end: cues[0].start })
for (const c of cues) {
  const prevEnd = out.length ? out[out.length - 1].end : 0
  // the segmenter already inserts its own music gaps; this only closes a hole it left
  if (c.start - prevEnd > 0.05) out.push({ kind: 'music', text: MUSIC_LABEL, start: prevEnd, end: c.start })
  out.push({ kind: 'lyric', text: c.text, start: c.start, end: c.end })
}
const last = out[out.length - 1]
if (DURATION - last.end > 0.05) out.push({ kind: 'music', text: MUSIC_LABEL, start: last.end, end: DURATION })
out[0].start = 0
out[out.length - 1].end = DURATION
for (let i = 1; i < out.length; i++) out[i].start = out[i - 1].end

const bad = out.filter((e) => !(e.end > e.start) || !String(e.text).trim())
if (bad.length) { console.error(`${bad.length} invalid cue(s) after covering`); process.exit(1) }

fs.writeFileSync(OUT, renderCuesToSrt(out), 'utf8')
const music = out.filter((e) => e.text === MUSIC_LABEL)
const longest = music.reduce((a, b) => (b.end - b.start > a.end - a.start ? b : a), { start: 0, end: 0 })
console.log(`cues: ${out.length} (${out.length - music.length} lyric, ${music.length} music), 0 -> ${DURATION}s`)
console.log(`longest music: ${(longest.end - longest.start).toFixed(2)}s (${(((longest.end - longest.start) / DURATION) * 100).toFixed(1)}%)`)
console.log(`wrote ${OUT}`)
