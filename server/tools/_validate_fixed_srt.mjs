import fs from 'node:fs'

const FIXED = 'D:/albums/soulful-bhakti-apk/Peru Teliyakunna.fixed.srt'
const SUPPLIED = 'inputs/Peru-Teliyakunna.source.srt'
const MUSIC = '{{Music}}'
const DURATION = 291

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

const fixed = parse(FIXED)
const supplied = parse(SUPPLIED)
const sung = fixed.filter((c) => c.text !== MUSIC)
const music = fixed.filter((c) => c.text === MUSIC)
let fail = 0
const check = (ok, label, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '   [' + detail + ']' : ''}`)
  if (!ok) fail++
}

check(Math.abs(fixed[0].start) < 1e-6, 'starts at 0', fixed[0].start)
check(Math.abs(fixed[fixed.length - 1].end - DURATION) < 1e-3, 'ends at the track duration', fixed[fixed.length - 1].end)
let gaps = 0, zero = 0, dup = 0
const starts = new Set()
for (let i = 0; i < fixed.length; i++) {
  if (!(fixed[i].end > fixed[i].start)) zero++
  starts.add(fixed[i].start)
  if (i > 0 && Math.abs(fixed[i].start - fixed[i - 1].end) > 1e-3) gaps++
}
check(gaps === 0, 'contiguous: no gap, no overlap', `${gaps}`)
check(zero === 0, 'no zero-length cue', `${zero}`)
check(fixed.length - starts.size === 0, 'no duplicate start', `${fixed.length - starts.size}`)
check(sung.length === 40, 'all 40 supplied lines are present', `${sung.length}`)
check(sung.length === supplied.length && sung.every((c, i) => c.text === supplied[i].text),
  'cue text is byte-identical to the supplied SRT, in the same order')
check(music.length === 3, 'music cues present', `${music.length}: ` + music.map((m) => `${m.start.toFixed(2)}-${m.end.toFixed(2)}`).join(', '))
check(sung.every((c) => c.start >= 0 && c.end <= DURATION + 1e-6), 'every cue inside the track')
check(fixed.length === 43, 'cue count', `${fixed.length}`)

const longest = sung.reduce((a, b) => (b.end - b.start > a.end - a.start ? b : a))
const shortest = sung.reduce((a, b) => (b.end - b.start < a.end - a.start ? b : a))
check(shortest.end - shortest.start > 3.0, 'no implausibly short sung cue', `shortest ${(shortest.end - shortest.start).toFixed(2)}s`)
check(longest.end - longest.start < 20, 'no implausibly long sung cue', `longest ${(longest.end - longest.start).toFixed(2)}s`)

// per-line deviation from the supplied timings
const deltas = sung.map((c, i) => ({ i: i + 1, d: c.start - supplied[i].start }))
const absmax = deltas.reduce((a, b) => (Math.abs(b.d) > Math.abs(a.d) ? b : a))
const moved = deltas.filter((x) => Math.abs(x.d) > 0.8)
console.log(`\ndeviation from the supplied timings: max ${absmax.d.toFixed(2)}s (line ${absmax.i}); lines moving >0.8s: ${moved.length}`)
for (const m of moved) console.log(`  line ${m.i}: ${m.d >= 0 ? '+' : ''}${m.d.toFixed(2)}s`)

console.log(`\n${fail ? fail + ' FINDING(S)' : 'ALL CHECKS PASSED'}`)
process.exitCode = fail ? 1 : 0
