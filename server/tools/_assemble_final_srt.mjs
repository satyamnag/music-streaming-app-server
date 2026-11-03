// Assemble the final SRT for Peru Teliyakunna from the two independent sources,
// using each where it is corroborated, and derive the {{Music}} cues.
//
//   lines 1..38   WhisperX forced-alignment boundaries (character-level, scores
//                 0.63-0.88) - they agree with the supplied SRT to within +/-0.7 s
//   lines 39..40  the supplied timings, because whisper ASR independently places
//                 the third refrain pair at 272.36-287.32 and the whole-track
//                 alignment had wrongly compressed it into the 266.80-272.36
//                 interlude
//   {{Music}}     0 -> first line, any inter-line gap >= 3 s, last line -> duration
import fs from 'node:fs'

const ALIGNED = 'wx3/whisperx-out/Peru-Teliyakunna.aligned.srt'
const SUPPLIED = 'inputs/Peru-Teliyakunna.source.srt'
const DURATION = 291
const MUSIC = '{{Music}}'
const MUSIC_MIN_GAP = 3.0
// first line whose WhisperX placement is not corroborated by the ASR cross-check
const TAIL_FROM = 39

const t = (s) => {
  const ms = Math.round(s * 1000)
  const h = Math.floor(ms / 3600000), m = Math.floor((ms % 3600000) / 60000)
  const sec = Math.floor((ms % 60000) / 1000), r = ms % 1000
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')},${String(r).padStart(3, '0')}`
}
const parse = (p) => {
  const out = []
  for (const block of fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n').trim().split(/\n\n+/)) {
    const lines = block.split('\n').filter((l) => l.trim())
    const ti = lines.findIndex((l) => l.includes('-->'))
    if (ti < 0) continue
    const m = lines[ti].match(/(\d+):(\d+):(\d+),(\d+) --> (\d+):(\d+):(\d+),(\d+)/)
    out.push({
      start: +m[1] * 3600 + +m[2] * 60 + +m[3] + +m[4] / 1000,
      end: +m[5] * 3600 + +m[6] * 60 + +m[7] + +m[8] / 1000,
      text: lines.slice(ti + 1).join(' ').trim(),
    })
  }
  return out
}

const aligned = parse(ALIGNED).filter((c) => c.text !== MUSIC)
const supplied = parse(SUPPLIED).filter((c) => c.text !== MUSIC)
if (aligned.length !== 40 || supplied.length !== 40) throw new Error(`expected 40 lines, got ${aligned.length}/${supplied.length}`)
for (let i = 0; i < 40; i++) {
  if (aligned[i].text !== supplied[i].text) throw new Error(`line ${i + 1} text differs between sources`)
}

// lyric timeline: measured boundary where corroborated, supplied where not
const lyricCues = []
for (let i = 0; i < 40; i++) {
  const fromSupplied = i + 1 >= TAIL_FROM
  lyricCues.push({
    text: aligned[i].text,
    start: fromSupplied ? supplied[i].start : aligned[i].start,
    end: fromSupplied ? supplied[i].end : aligned[i].end,
    source: fromSupplied ? 'supplied+ASR' : 'whisperx',
    delta: +(aligned[i].start - supplied[i].start).toFixed(2),
  })
}

// music cues from the gaps
const timeline = []
if (lyricCues[0].start > 0.05) timeline.push({ kind: 'music', text: MUSIC, start: 0, end: lyricCues[0].start, source: 'gap' })
for (const c of lyricCues) {
  const prevEnd = timeline.length ? timeline[timeline.length - 1].end : 0
  if (c.start - prevEnd >= MUSIC_MIN_GAP) {
    timeline.push({ kind: 'music', text: MUSIC, start: prevEnd, end: c.start, source: 'gap' })
  }
  timeline.push({ kind: 'lyric', text: c.text, start: c.start, end: c.end, source: c.source })
}
const last = timeline[timeline.length - 1]
if (DURATION - last.end > 0.05) timeline.push({ kind: 'music', text: MUSIC, start: last.end, end: DURATION, source: 'gap' })

// structural invariants
timeline[0].start = 0
timeline[timeline.length - 1].end = DURATION
for (let i = 1; i < timeline.length; i++) timeline[i].start = timeline[i - 1].end
let bad = 0
for (const e of timeline) if (!(e.end > e.start) || !e.text.trim()) bad++
if (bad) throw new Error(`${bad} invalid cue(s)`)

const srt = timeline.map((e, i) => `${i + 1}\n${t(e.start)} --> ${t(e.end)}\n${e.text}\n`).join('\n')
const outPath = 'D:/albums/soulful-bhakti-apk/Peru Teliyakunna.fixed.srt'
fs.writeFileSync(outPath, srt, 'utf8')

console.log(`cues: ${timeline.length}  (${timeline.filter((e) => e.kind === 'lyric').length} sung, ${timeline.filter((e) => e.kind === 'music').length} music)`)
console.log(`span: ${timeline[0].start} -> ${timeline[timeline.length - 1].end}\n`)
timeline.forEach((e, i) => {
  console.log(`${String(i + 1).padStart(3)}  ${e.start.toFixed(3).padStart(8)} - ${e.end.toFixed(3).padStart(8)}  ${(e.end - e.start).toFixed(2).padStart(6)}s  ${e.kind === 'music' ? '[music]' : e.source.padEnd(14)} ${e.kind === 'music' ? '' : e.text.slice(0, 32)}`)
})
fs.writeFileSync('_final-timeline.json', JSON.stringify({ timeline, lyricCues }, null, 1), 'utf8')
console.log(`\nwrote ${outPath}`)
