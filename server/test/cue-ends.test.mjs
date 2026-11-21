// Tests for the cue-end repair: the only differences it may make are the END halves
// of the cues it is told about. Measured on Raja Rajeshwari, where an editor slip
// turned `06:05,380` into `05:06,380` and left a cue ending 26.96 s before it starts.
import assert from 'node:assert/strict'
import test from 'node:test'
import { fixCueEnds, assertOnlyEndsChanged, splitCues, secs } from '../libs/cueEnds.mjs'

const COL = [
  '1',
  '00:00:00,000 --> 00:00:12,540',
  '{{ ♪ సంగీతం ♪ }}',
  '',
  '2',
  '00:00:12,540 --> 00:00:18,000',
  'కదిలింది నేడు, కనక దుర్గ తేరు,',
  '',
  '3',
  '00:05:33,340 --> 00:05:06,380',
  '{{ ♪ సంగీతం ♪ }}',
  '',
].join('\n')

test('the end of the named cue is replaced, and only that', () => {
  const { next, changed, errors } = fixCueEnds(COL, { 3: '00:06:05,380' })
  assert.deepEqual(errors, [])
  assert.deepEqual(changed, [{ cue: 3, before: '00:05:06,380', after: '00:06:05,380' }])
  assert.ok(next.includes('00:05:33,340 --> 00:06:05,380'))
  assert.deepEqual(assertOnlyEndsChanged(COL, next, { 3: '00:06:05,380' }), [])
  // every other cue is byte-identical
  const a = splitCues(COL).blocks
  const b = splitCues(next).blocks
  assert.equal(a.length, b.length)
  assert.equal(a[0], b[0])
  assert.equal(a[1], b[1])
  assert.notEqual(a[2], b[2])
})

test('a fix that would not move the end forward is refused', () => {
  const { errors } = fixCueEnds(COL, { 3: '00:05:00,000' })
  assert.ok(errors.some((e) => /not after the start/.test(e)), errors.join(' | '))
})

test('a fix for a cue that does not exist is refused', () => {
  const { errors } = fixCueEnds(COL, { 99: '00:06:05,380' })
  assert.ok(errors.some((e) => /does not exist/.test(e)), errors.join(' | '))
})

test('an unchanged end is refused rather than silently accepted', () => {
  const { errors } = fixCueEnds(COL, { 2: '00:00:18,000' })
  assert.ok(errors.some((e) => /already/.test(e)), errors.join(' | '))
})

test('a malformed replacement is refused', () => {
  const { errors } = fixCueEnds(COL, { 3: '6:05' })
  assert.ok(errors.some((e) => /not an SRT time/.test(e)), errors.join(' | '))
})

test('the guard sees an index line or a start time that moved', () => {
  const moved = COL.replace('00:05:33,340 --> 00:05:06,380', '00:05:34,340 --> 00:06:05,380')
  const problems = assertOnlyEndsChanged(COL, moved, { 3: '00:06:05,380' })
  assert.ok(problems.some((p) => /START moved/.test(p)))
})

test('the guard sees text that changed on an unnamed cue', () => {
  const edited = COL.replace('కదిలింది నేడు, కనక దుర్గ తేరు,', 'something else')
  const problems = assertOnlyEndsChanged(COL, edited, { 3: '00:06:05,380' })
  assert.ok(problems.some((p) => /cue 2 changed but was not named/.test(p)))
})

test('two fixes in one column both apply', () => {
  const col = COL.replace('00:00:12,540 --> 00:00:18,000', '00:00:12,540 --> 00:00:10,000')
  const { changed, errors } = fixCueEnds(col, { 2: '00:00:18,000', 3: '00:06:05,380' })
  assert.deepEqual(errors, [])
  assert.equal(changed.length, 2)
})

test('seconds parse the way the tool compares them', () => {
  assert.equal(secs('00:06:05,380'), 365.38)
  assert.equal(secs('00:05:06,380'), 306.38)
})
