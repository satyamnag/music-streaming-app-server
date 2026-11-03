import fs from 'node:fs'
const j = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
console.log('whisper words:', j.words, '| model:', j.model)
const r = j.report
const bad = r.filter((x) => x.verdict !== 'OK')
console.log(`lines checked: ${r.length}   flagged: ${bad.length}\n`)
console.log('  #  in-span   best   aligned span        best match         verdict      text')
for (const x of r) {
  const mark = x.verdict !== 'OK' ? '  <==' : ''
  const bs = x.best_start != null ? `${x.best_start.toFixed(2)}-${x.best_end.toFixed(2)}` : '-'
  console.log(
    String(x.index).padStart(3) + '  ' + x.in_span.toFixed(3).padStart(6) + '  ' + x.best.toFixed(3).padStart(5) +
    '   ' + `${x.start.toFixed(2)}-${x.end.toFixed(2)}`.padStart(13) + '   ' + bs.padStart(13) +
    '   ' + x.verdict.padEnd(11) + '  ' + x.text.slice(0, 26) + mark,
  )
}
if (bad.length) {
  console.log('\nflagged detail:')
  for (const b of bad) {
    console.log(`  line ${b.index}: in-span ${b.in_span.toFixed(3)} vs best ${b.best.toFixed(3)} at ${b.best_start?.toFixed(2)}-${b.best_end?.toFixed(2)}`)
    console.log(`    text: ${b.text}`)
  }
}
