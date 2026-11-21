// ============================================================================
// Fix the END time of named cues in a synced column, and change nothing else.
//
// WHY THIS EXISTS
// ---------------
// An editor slip can leave a cue whose end is BEFORE its start: a dropped minute
// digit turns `06:05,380` into `05:06,380`. Such a column cannot become a valid
// SRT, so every downstream tool refuses it, and the whole repair is a few
// characters on one time line. Neither existing writer can do that job:
//   * `write-timeline-text.mjs` re-spells lyric TEXT and refuses banners;
//   * `finalize_payload.mjs`    gates on the literal `{{Music}}` marker, so it
//                               rejects a column carrying `{{ ♪ సంగీతం ♪ }}`.
//
// WHAT IT GUARANTEES (each asserted before a single byte is sent)
// --------------------------------------------------------------
//   * the cue count is unchanged;
//   * only the END half of a named cue's time line is replaced - the index line,
//     the start time and the text are copied through byte for byte;
//   * every cue that is not named is byte-identical;
//   * each new end is a valid SRT time and is after that cue's start;
//   * the number of changes equals the number of fixes supplied.
// ============================================================================

const TIME = /^(\d\d:\d\d:\d\d,\d\d\d) --> (\d\d:\d\d:\d\d,\d\d\d)$/

export const secs = (t) => {
  const [h, m, r] = String(t).split(':')
  const [s, ms] = r.split(',')
  return (+h) * 3600 + (+m) * 60 + (+s) + (+ms) / 1000
}

/** Split a column into blocks, keeping every byte except the block separators. */
export function splitCues(raw) {
  const text = String(raw ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
  return { blocks: text.replace(/\n\s*$/, '').split(/\n[ \t]*\n/), trailingNewline: /\n\s*$/.test(text) }
}

/**
 * @param {string} raw    the stored column
 * @param {object} fixes  { 48: '00:06:05,380', 59: '00:07:02,000' } keyed by 1-based cue number
 * @returns {{next:string, changed:Array, errors:Array}}
 */
export function fixCueEnds(raw, fixes) {
  const { blocks, trailingNewline } = splitCues(raw)
  const errors = []
  const changed = []
  const wanted = new Map(Object.entries(fixes).map(([k, v]) => [Number(k), String(v).trim()]))

  for (const n of wanted.keys()) {
    if (!Number.isInteger(n) || n < 1 || n > blocks.length) {
      errors.push(`cue ${n} does not exist (the column holds ${blocks.length} cues)`)
    }
  }

  const out = blocks.map((block, i) => {
    const n = i + 1
    if (!wanted.has(n)) return block
    const lines = block.split('\n')
    if (lines.length < 2) { errors.push(`cue ${n} has no time line`); return block }
    const m = TIME.exec(lines[1].trim())
    if (!m) { errors.push(`cue ${n} time line is not a valid SRT range: ${lines[1]}`); return block }
    const start = m[1]
    const before = m[2]
    const after = wanted.get(n)
    if (!/^\d\d:\d\d:\d\d,\d\d\d$/.test(after)) { errors.push(`cue ${n}: ${after} is not an SRT time`); return block }
    if (secs(after) <= secs(start)) { errors.push(`cue ${n}: the new end ${after} is not after the start ${start}`); return block }
    if (after === before) { errors.push(`cue ${n}: the end is already ${after} - nothing to change`); return block }
    lines[1] = `${start} --> ${after}`
    changed.push({ cue: n, before, after })
    return lines.join('\n')
  })

  if (changed.length !== wanted.size) {
    errors.push(`asked to change ${wanted.size} cue(s) but could only change ${changed.length}`)
  }

  return { next: out.join('\n\n') + (trailingNewline ? '\n' : ''), changed, errors }
}

/** Every difference between two columns must be a named cue's end time. */
export function assertOnlyEndsChanged(before, after, fixes) {
  const a = splitCues(before)
  const b = splitCues(after)
  const problems = []
  if (a.blocks.length !== b.blocks.length) problems.push(`cue count ${b.blocks.length} != ${a.blocks.length}`)
  const allowed = new Set(Object.keys(fixes).map(Number))
  for (let i = 0; i < Math.min(a.blocks.length, b.blocks.length); i += 1) {
    if (a.blocks[i] === b.blocks[i]) continue
    if (!allowed.has(i + 1)) { problems.push(`cue ${i + 1} changed but was not named`); continue }
    const la = a.blocks[i].split('\n')
    const lb = b.blocks[i].split('\n')
    if (la.length !== lb.length) { problems.push(`cue ${i + 1} line count changed`); continue }
    for (let k = 0; k < la.length; k += 1) {
      if (la[k] === lb[k]) continue
      if (k !== 1) { problems.push(`cue ${i + 1}: line ${k + 1} changed`); continue }
      const ma = TIME.exec(la[k].trim())
      const mb = TIME.exec(lb[k].trim())
      if (!ma || !mb) { problems.push(`cue ${i + 1}: time line is malformed`); continue }
      if (ma[1] !== mb[1]) problems.push(`cue ${i + 1}: the START moved`)
      if (mb[2] !== String(fixes[i + 1]).trim()) problems.push(`cue ${i + 1}: the end is ${mb[2]}, not the fix`)
    }
  }
  return problems
}
