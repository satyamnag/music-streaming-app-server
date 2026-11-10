// Voice-note (pitch) tracker: accuracy + speed checks against signals whose
// fundamental frequency is known exactly.
//
// The tracker is NOT re-implemented here. Its functions and constants are
// extracted from the shipped `server/admin.html` and evaluated in a sandbox, so
// a green run is evidence about the code that actually reaches the browser. A
// test that runs its own copy of an algorithm proves nothing about the real one.
//
//   node server/tools/_voice_notes.test.mjs          # checks
//   node server/tools/_voice_notes.test.mjs --tune   # + the constant sweep
//
// The numbers this prints are the ones recorded in
// docs/LYRICS-SYNC-STUDIO.md, "Verification performed".
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const ADMIN = path.join(HERE, '..', 'admin.html')
const PAGE = fs.readFileSync(ADMIN, 'utf8')

/* ------------------------------------------------------------------ */
/* load the shipped code                                              */
/* ------------------------------------------------------------------ */

/** Slices a top-level `function name(...) { ... }` out of the page source. */
function fnSource(name) {
  const at = PAGE.indexOf('\n  function ' + name + '(')
  if (at < 0) throw new Error('function not found in admin.html: ' + name)
  let depth = 0
  for (let j = PAGE.indexOf('{', at); j < PAGE.length; j++) {
    if (PAGE[j] === '{') depth++
    else if (PAGE[j] === '}') {
      depth--
      if (depth === 0) return PAGE.slice(at + 1, j + 1)
    }
  }
  throw new Error('unbalanced braces in ' + name)
}

const CONST_RE = /^ {2}var (PITCH_[A-Z_]+|NOTE_TOLERANCE|ONSET_[A-Z_]+|NOTE_NAMES) = .*$/gm
const consts = [...PAGE.matchAll(CONST_RE)].map((m) => m[0]).join('\n')
if (!/PITCH_HOP/.test(consts) || !/NOTE_NAMES/.test(consts)) {
  throw new Error('could not read the tracker constants out of admin.html')
}

const make = new Function(`
  'use strict'
  ${consts}
  ${fnSource('noteName')}
  ${fnSource('peakAbs')}
  ${fnSource('yinFrame')}
  ${fnSource('pitchNotes')}
  ${fnSource('pitchOnsets')}
  return { noteName, noteNames: NOTE_NAMES, yinFrame, pitchNotes, pitchOnsets,
           PITCH_HOP, PITCH_WIN, PITCH_FMIN, PITCH_FMAX, NOTE_TOLERANCE,
           ONSET_ENV_MS, ONSET_FRAC, ONSET_RISE, ONSET_FLOOR, ONSET_MIN_GAP }
`)
const T = make()

/**
 * The job object `pitchStart` builds, reproduced here so the extracted functions
 * can be driven without a browser. The arithmetic mirrors `pitchStart` in
 * admin.html; `--tune` and the constants guard both fail loudly if it drifts.
 */
function makeJob(data, sr) {
  const win = Math.min(T.PITCH_WIN, Math.max(256, data.length - 1))
  const hopN = Math.max(32, Math.round(sr * T.PITCH_HOP))
  const tauMin = Math.max(2, Math.floor(sr / T.PITCH_FMAX))
  const tauMax = Math.min(win - 48, Math.ceil(sr / T.PITCH_FMIN))
  const frames = Math.max(0, Math.floor((data.length - win) / hopN) + 1)
  const job = {
    data, sr, win, hopN, tauMin, tauMax,
    terms: Math.max(16, win - tauMax),
    frames, frame: 0, phase: 0, peakRms: 0, gate: 0,
    midi: new Float32Array(frames),
    hz: new Float32Array(frames),
    clarity: new Float32Array(frames),
    rms: new Float32Array(frames),
    df: new Float64Array(tauMax + 2),
    dn: new Float64Array(tauMax + 2)
  }
  for (let f = 0; f < frames; f++) {
    const base = f * hopN
    let sum = 0
    for (let i = 0; i < win; i++) { const v = data[base + i]; sum += v * v }
    job.rms[f] = Math.sqrt(sum / win)
    if (job.rms[f] > job.peakRms) job.peakRms = job.rms[f]
  }
  job.gate = Math.max(0.0025, job.peakRms * 0.045)
  for (let f = 0; f < frames; f++) if (job.rms[f] >= job.gate) T.yinFrame(job, f)
  return job
}

/* ------------------------------------------------------------------ */
/* signals with a known answer                                        */
/* ------------------------------------------------------------------ */

const SR = 11025

function tone(hz, seconds, opts = {}) {
  const n = Math.round(SR * seconds)
  const out = new Float32Array(n)
  const harm = opts.harmonics || [1, 0.5, 0.3, 0.18, 0.1]
  const vib = opts.vibrato || 0
  const vibHz = opts.vibratoHz || 5.2
  const glideTo = opts.glideTo || 0
  // Phase must be INTEGRATED. sin(2*pi*f(t)*t) is not a frequency-modulated
  // tone; its instantaneous rate drifts with t*f'(t), which once produced a
  // 220 Hz "vibrato" whose real pitch swept 388 Hz.
  let phase = 0
  for (let i = 0; i < n; i++) {
    const frac = n > 1 ? i / (n - 1) : 0
    const base = glideTo ? hz + (glideTo - hz) * frac : hz
    const f = base * (1 + (vib ? vib * Math.sin(2 * Math.PI * vibHz * (i / SR)) : 0))
    phase += (2 * Math.PI * f) / SR
    let v = 0
    for (let k = 0; k < harm.length; k++) v += harm[k] * Math.sin((k + 1) * phase)
    out[i] = v * 0.22
  }
  return out
}

function silence(seconds) {
  return new Float32Array(Math.round(SR * seconds))
}

function noise(seconds, level, seed = 12345) {
  const n = Math.round(SR * seconds)
  const out = new Float32Array(n)
  let s = seed >>> 0
  for (let i = 0; i < n; i++) {
    s = (s * 1664525 + 1013904223) >>> 0
    out[i] = ((s / 4294967296) * 2 - 1) * level
  }
  return out
}

function concat(parts) {
  const n = parts.reduce((a, p) => a + p.length, 0)
  const out = new Float32Array(n)
  let o = 0
  for (const p of parts) { out.set(p, o); o += p.length }
  return out
}

/* ------------------------------------------------------------------ */
/* checks                                                             */
/* ------------------------------------------------------------------ */

let pass = 0
let fail = 0
const failures = []
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  PASS  ' + name + (detail ? ' - ' + detail : '')) }
  else { fail++; failures.push(name); console.log('  FAIL  ' + name + (detail ? ' - ' + detail : '')) }
}
const cents = (a, b) => 1200 * Math.log2(a / b)

function medianHz(job) {
  const v = []
  for (let i = 0; i < job.frames; i++) if (job.hz[i]) v.push(job.hz[i])
  if (!v.length) return 0
  v.sort((x, y) => x - y)
  return v[Math.floor(v.length / 2)]
}

console.log('=== the shipped constants ===')
{
  const expected = {
    PITCH_HOP: 0.04, PITCH_WIN: 640, PITCH_FMIN: 64, PITCH_FMAX: 1000,
    NOTE_TOLERANCE: 0.75, ONSET_ENV_MS: 24, ONSET_FRAC: 0.5,
    ONSET_RISE: 1.75, ONSET_FLOOR: 0.09, ONSET_MIN_GAP: 0.09
  }
  let ok = true
  for (const [k, v] of Object.entries(expected)) {
    if (T[k] !== v) { ok = false; console.log(`  ${k} = ${T[k]}, doc says ${v}`) }
  }
  check('the constants still match the documented, measured set', ok)
  check('the note-name table is the chromatic scale', T.noteNames.length === 12 && T.noteNames[9] === 'A')
  check('noteName(60) is middle C', T.noteName(60) === 'C4', T.noteName(60))
  check('noteName(69) is A4', T.noteName(69) === 'A4', T.noteName(69))
}

console.log('\n=== 1. steady harmonically rich tones, C2 … A5 ===')
for (const hz of [65.41, 73.42, 82.41, 110, 146.83, 196, 220, 293.66, 440, 659.25, 880]) {
  const job = makeJob(tone(hz, 2), SR)
  const got = medianHz(job)
  const err = got ? cents(got, hz) : 9999
  check(`tone ${hz} Hz`, Math.abs(err) < 25, `${got.toFixed(2)} Hz (${err.toFixed(1)} cents)`)
}

console.log('\n=== 2. weak fundamental (harmonics louder than f0) ===')
for (const hz of [155, 233, 349, 523]) {
  const job = makeJob(tone(hz, 2, { harmonics: [0.25, 1, 0.6, 0.35, 0.2] }), SR)
  const got = medianHz(job)
  check(`weak-fundamental ${hz} Hz`, Math.abs(cents(got, hz)) < 30, `${got.toFixed(2)} Hz`)
}

console.log('\n=== 3. vibrato is one note, not a trill ===')
for (const [hz, depth, rate] of [[220, 0.018, 5.2], [392, 0.03, 6], [146.83, 0.012, 4.5]]) {
  const job = makeJob(tone(hz, 3, { vibrato: depth, vibratoHz: rate }), SR)
  const notes = T.pitchNotes(job)
  check(`vibrato ${hz} Hz median`, Math.abs(cents(medianHz(job), hz)) < 25, `${medianHz(job).toFixed(2)} Hz`)
  check(`vibrato ${hz} Hz stays ONE note`, notes.length === 1, `${notes.length} note(s)`)
}

console.log('\n=== 4. glide 200 -> 400 Hz ===')
{
  const job = makeJob(tone(200, 3, { glideTo: 400 }), SR)
  let first = 0
  let last = 0
  for (let i = 0; i < job.frames; i++) if (job.hz[i]) { first = job.hz[i]; break }
  for (let i = job.frames - 1; i >= 0; i--) if (job.hz[i]) { last = job.hz[i]; break }
  check('glide start ~ 200 Hz', Math.abs(cents(first, 200)) < 45, `${first.toFixed(1)} Hz`)
  check('glide end ~ 400 Hz', Math.abs(cents(last, 400)) < 45, `${last.toFixed(1)} Hz`)
  check('the glide becomes several notes', T.pitchNotes(job).length >= 2, `${T.pitchNotes(job).length} notes`)
}

console.log('\n=== 5. silence and noise are not voice ===')
{
  const quiet = makeJob(silence(2), SR)
  let voiced = 0
  for (let i = 0; i < quiet.frames; i++) if (quiet.midi[i]) voiced++
  check('silence -> 0 voiced frames', voiced === 0, `${voiced}`)
  const hiss = makeJob(noise(3, 0.25), SR)
  let v2 = 0
  for (let i = 0; i < hiss.frames; i++) if (hiss.midi[i]) v2++
  check('white noise -> under 15 % voiced', v2 / hiss.frames < 0.15, `${(v2 / hiss.frames * 100).toFixed(1)} %`)
}

console.log('\n=== 6. a known melody: D3 -> C5 -> G3 ===')
{
  const mono = concat([
    tone(146.83, 1), silence(0.3), tone(523.25, 1), silence(0.3), tone(196.0, 1)
  ])
  const job = makeJob(mono, SR)
  const notes = T.pitchNotes(job)
  check('three notes found', notes.length === 3, notes.map((n) => T.noteName(n.midi)).join(' '))
  if (notes.length === 3) {
    check('named D3 / C5 / G3',
      T.noteName(notes[0].midi) === 'D3' && T.noteName(notes[1].midi) === 'C5' && T.noteName(notes[2].midi) === 'G3',
      notes.map((n) => T.noteName(n.midi)).join(' '))
    check('the middle note is drawn HIGHER than the first', notes[1].midi > notes[0].midi)
    check('the last note is drawn LOWER than the middle', notes[2].midi < notes[1].midi)
    check('note starts are 0.00 / 1.30 / 2.60 s (+-60 ms)',
      Math.abs(notes[0].start - 0) < 0.06 && Math.abs(notes[1].start - 1.3) < 0.06 && Math.abs(notes[2].start - 2.6) < 0.06,
      notes.map((n) => n.start.toFixed(3)).join(' / '))
  }
}

console.log('\n=== 7. onset precision (what makes one-click cueing work) ===')
{
  const mono = concat([silence(0.5), tone(220, 0.8), silence(0.5), tone(330, 0.8)])
  const onsets = T.pitchOnsets(makeJob(mono, SR))
  check('exactly two onsets', onsets.length === 2, onsets.map((x) => x.toFixed(3)).join(', '))
  check('first onset = 0.500 s +-5 ms', onsets[0] != null && Math.abs(onsets[0] - 0.5) < 0.005,
    onsets[0] && onsets[0].toFixed(4))
  check('second onset = 1.800 s +-5 ms', onsets[1] != null && Math.abs(onsets[1] - 1.8) < 0.005,
    onsets[1] && onsets[1].toFixed(4))
}

console.log('\n=== 8. onset precision on a soft (swelled) onset ===')
{
  const body = tone(220, 1)
  const fade = 0.12
  for (let i = 0; i < Math.round(fade * SR); i++) body[i] *= i / (fade * SR)
  const mono = concat([silence(0.4), body])
  const onsets = T.pitchOnsets(makeJob(mono, SR))
  check('one onset found', onsets.length === 1, onsets.map((x) => x.toFixed(3)).join(', '))
  check('the onset lands inside the swell, not after it',
    onsets[0] != null && onsets[0] > 0.4 && onsets[0] < 0.55, onsets[0] && onsets[0].toFixed(4))
}

console.log('\n=== 9. melody over a steady drone (monophonic limit) ===')
{
  const drone = tone(146.83, 2, { harmonics: [1, 0.7, 0.5, 0.3] })
  const melody = tone(523.25, 1, { harmonics: [1, 0.4, 0.2] })
  for (let i = 0; i < drone.length; i++) drone[i] *= 0.35
  for (let i = 0; i < melody.length; i++) melody[i] *= 2.6
  const mono = concat([drone])
  for (let i = 0; i < melody.length; i++) mono[Math.round(0.5 * SR) + i] += melody[i]
  const job = makeJob(mono, SR)
  const at = (sec) => {
    const f = Math.round(sec / (job.hopN / job.sr))
    return job.hz[Math.min(job.frames - 1, f)] || 0
  }
  check('the drone-only stretch reads D3', Math.abs(cents(at(0.2), 146.83)) < 40, `${at(0.2).toFixed(1)} Hz`)
  check('the melody-over-drone stretch reads C5', Math.abs(cents(at(1.2), 523.25)) < 45, `${at(1.2).toFixed(1)} Hz`)
}

console.log('\n=== 10. speed (60 s of audio) ===')
{
  const parts = []
  for (let i = 0; i < 40; i++) {
    parts.push(tone([130.81, 164.81, 196, 220, 261.63, 329.63][i % 6], 1.4, { vibrato: 0.01 }))
    parts.push(silence(0.1))
  }
  const mono = concat(parts)
  const t0 = process.hrtime.bigint()
  const job = makeJob(mono, SR)
  const ms = Number(process.hrtime.bigint() - t0) / 1e6
  console.log(`  ${(mono.length / SR).toFixed(0)} s -> ${job.frames} frames in ${ms.toFixed(0)} ms ` +
    `(${(ms * 1000 / job.frames).toFixed(0)} us/frame)`)
  check('a 60 s track analyses in under 700 ms', ms < 700, `${ms.toFixed(0)} ms`)
  const notes = T.pitchNotes(job)
  check('note count is plausible (30-90)', notes.length >= 30 && notes.length <= 90, `${notes.length}`)
  const t1 = process.hrtime.bigint()
  const onsets = T.pitchOnsets(job)
  const oms = Number(process.hrtime.bigint() - t1) / 1e6
  check('onsets are found and never closer than 90 ms', onsets.length >= 30 &&
    onsets.slice(1).every((x, i) => x - onsets[i] >= 0.085 - 1e-9),
    `${onsets.length} onsets in ${oms.toFixed(1)} ms`)
}

/* ------------------------------------------------------------------ */
/* optional: how the constants were derived                           */
/* ------------------------------------------------------------------ */

if (process.argv.includes('--tune')) {
  console.log('\n=== constant sweep: onset refinement vs ground truth ===')
  const LEADS = [0.5, 0.5237, 0.4891, 0.6113, 0.4509]
  const cases = []
  for (const hz of [82.41, 110, 146.83, 220, 329.63, 440, 659.25, 880]) {
    for (const lead of LEADS) {
      for (const level of [1, 0.3]) {
        const body = tone(hz, 0.7)
        for (let i = 0; i < body.length; i++) body[i] *= level
        cases.push({ mono: concat([silence(lead), body, silence(0.25)]), truth: Math.round(lead * SR) / SR })
      }
    }
  }
  const rows = []
  for (const envMs of [4, 6, 8, 12, 16, 24]) {
    for (const frac of [0.1, 0.2, 0.35, 0.5]) {
      for (const corr of [0, 0.5, 1]) {
        let sum = 0
        let worst = 0
        let n = 0
        for (const c of cases) {
          const job = makeJob(c.mono, SR)
          const coarse = T.pitchOnsets(job)
          if (!coarse.length) continue
          // Same refinement as pitchOnsets, with this row's parameters.
          const w = Math.max(8, Math.round(SR * envMs / 1000))
          const step = Math.max(1, Math.round(SR * 0.001))
          const centre = Math.round(coarse[0] * SR)
          const from = Math.max(0, centre - job.win)
          const to = Math.min(c.mono.length - w - 1, centre + job.win)
          let peakE = 0
          let peakAt = -1
          for (let i = from; i <= to; i += step) {
            const m = T.peakAbs(c.mono, i, w)
            if (m > peakE) { peakE = m; peakAt = i }
          }
          let at = peakAt
          while (at - step >= from) {
            if (T.peakAbs(c.mono, at - step, w) < peakE * frac) break
            at -= step
          }
          const est = (at + w * corr) / SR
          const err = Math.abs(est - c.truth) * 1000
          sum += err
          worst = Math.max(worst, err)
          n++
        }
        if (n) rows.push({ envMs, frac, corr, mean: sum / n, worst })
      }
    }
  }
  rows.sort((a, b) => a.mean - b.mean)
  console.log(`  ${cases.length} ground-truth onsets, best 6 parameter sets:`)
  for (const r of rows.slice(0, 6)) {
    console.log(`    env ${String(r.envMs).padStart(2)} ms  frac ${String(r.frac).padEnd(4)} corr ${String(r.corr).padEnd(3)}` +
      ` -> mean ${r.mean.toFixed(2)} ms, worst ${r.worst.toFixed(2)} ms`)
  }
}

console.log(`\n=== ${pass} passed, ${fail} failed ===`)
if (fail) {
  console.log('failures:')
  for (const f of failures) console.log('  - ' + f)
}
process.exitCode = fail ? 1 : 0
