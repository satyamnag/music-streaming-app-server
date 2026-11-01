// Tests for libs/openaiLyricSecondOpinion.mjs.
//
// Run: node test/openai-second-opinion.test.mjs
//
// No network and no API key: a local stub plays the Responses API. The point of
// these tests is the FAIL-CLOSED contract - every failure shape must degrade to
// `{ ok: false }` so the deterministic pipeline is unaffected - and the rule that
// a model answer can never move a line the aligner already measured.

import assert from 'node:assert/strict'
import http from 'node:http'
import {
  DEFAULT_MIN_AGREEMENT,
  applySecondOpinion,
  extractOutputText,
  secondOpinionPicks,
  segmentTranscript,
  validatePicks,
} from '../libs/openaiLyricSecondOpinion.mjs'

let passed = 0
let failed = 0
const tests = []
const test = (name, fn) => tests.push([name, fn])
const eq = (a, b, m) => assert.deepEqual(a, b, m)

// ---------------------------------------------------------------------------
// Stub Responses API
// ---------------------------------------------------------------------------

/** mode: 'ok' | 'http500' | 'refusal' | 'garbage' | 'hang' */
function startStub(mode = 'ok') {
  const state = { requests: 0, lastAuth: null, lastBody: null }
  const server = http.createServer((req, res) => {
    state.requests += 1
    state.lastAuth = req.headers.authorization || null
    let raw = ''
    req.on('data', (c) => { raw += c })
    req.on('end', () => {
      try { state.lastBody = JSON.parse(raw) } catch { state.lastBody = null }
      if (mode === 'hang') return                      // never answers
      if (mode === 'http500') {
        res.writeHead(500, { 'Content-Type': 'application/json' })
        return res.end(JSON.stringify({ error: { message: 'boom' } }))
      }
      const text = mode === 'refusal'
        ? null
        : mode === 'garbage'
          ? 'not json at all'
          : JSON.stringify({
              picks: [
                { line_index: 0, segment_index: 1, agreement: 0.93, reason: 'same line, respelled' },
                { line_index: 1, segment_index: -1, agreement: 0.2, reason: 'not sung' },
                { line_index: 99, segment_index: 0, agreement: 1, reason: 'out of range line' },
                { line_index: 0, segment_index: 0, agreement: 1, reason: 'duplicate line' },
                { line_index: 2, segment_index: 77, agreement: 1, reason: 'out of range segment' },
              ],
            })
      const content = mode === 'refusal'
        ? [{ type: 'refusal', refusal: 'cannot help with that' }]
        : [{ type: 'output_text', text }]
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ status: 'completed', output: [{ type: 'message', content }] }))
    })
  })
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, state, port: server.address().port }))
  })
}

const LINES = [
  { index: 0, text: 'ఎన్నెన్నో రూపముల వెలగేటి శక్తివి,' },
  { index: 1, text: 'ప్రేమ, కరుణా మూర్తి గౌరి భవాని.' },
  { index: 2, text: 'బెజవాడ దుర్గమ్మ, బ్రహ్మాండ నాయకి,' },
]

// ---------------------------------------------------------------------------
// Segmentation
// ---------------------------------------------------------------------------

test('segmentTranscript splits on silent gaps and keeps measured bounds', () => {
  const words = [
    { word: 'a', start: 1, end: 1.4 },
    { word: 'b', start: 1.4, end: 1.9 },
    { word: 'c', start: 9, end: 9.4 },     // 7.1 s gap -> new segment
    { word: 'd', start: 9.4, end: 9.9 },
  ]
  const segs = segmentTranscript(words, 2.5)
  eq(segs.length, 2)
  eq(segs[0], { index: 0, start: 1, end: 1.9, text: 'a b' })
  eq(segs[1], { index: 1, start: 9, end: 9.9, text: 'c d' })
})

test('segmentTranscript ignores malformed words instead of crashing', () => {
  const segs = segmentTranscript([null, { word: 'x' }, { word: 'y', start: 0, end: 1 }], 2.5)
  eq(segs.length, 1)
  eq(segs[0].text, 'y')
})

// ---------------------------------------------------------------------------
// Response parsing / validation
// ---------------------------------------------------------------------------

test('extractOutputText reads the REST shape (output[].content[].output_text)', () => {
  const payload = { output: [{ type: 'message', content: [{ type: 'output_text', text: '{"picks":[]}' }] }] }
  eq(extractOutputText(payload), { text: '{"picks":[]}' })
})

test('extractOutputText surfaces a refusal instead of guessing', () => {
  const payload = { output: [{ type: 'message', content: [{ type: 'refusal', refusal: 'no' }] }] }
  eq(extractOutputText(payload).refusal, 'no')
})

test('validatePicks drops out-of-range and duplicate answers', () => {
  const raw = JSON.stringify({
    picks: [
      { line_index: 0, segment_index: 1, agreement: 0.9, reason: 'ok' },
      { line_index: 0, segment_index: 2, agreement: 0.5, reason: 'duplicate line' },
      { line_index: 9, segment_index: 0, agreement: 1, reason: 'bad line' },
      { line_index: 2, segment_index: 99, agreement: 1, reason: 'bad segment' },
      { line_index: 1, segment_index: -1, agreement: 0.1, reason: 'unsung' },
    ],
  })
  const picks = validatePicks(raw, { lineCount: 3, segmentCount: 3 })
  eq(picks.map((p) => [p.lineIndex, p.segmentIndex]), [[0, 1], [1, -1]])
})

test('validatePicks clamps agreement into 0..1 and never throws on garbage', () => {
  const picks = validatePicks(JSON.stringify({
    picks: [{ line_index: 0, segment_index: 0, agreement: 42, reason: 'x' }],
  }), { lineCount: 1, segmentCount: 1 })
  eq(picks[0].agreement, 1)
  eq(validatePicks('not json', { lineCount: 1, segmentCount: 1 }), [])
})

// ---------------------------------------------------------------------------
// The call itself - every failure mode fails closed
// ---------------------------------------------------------------------------

test('a successful call normalises the answer and posts a strict schema', async () => {
  const stub = await startStub('ok')
  try {
    const r = await secondOpinionPicks({
      apiKey: 'test-key', lines: LINES,
      segments: segmentTranscript([{ word: 'x', start: 0, end: 1 }]),
      baseUrl: `http://127.0.0.1:${stub.port}`,
    })
    assert.equal(r.ok, true)
    // Out-of-range and duplicate picks were filtered by validatePicks.
    eq(r.picks.map((p) => p.lineIndex), [0, 1])
    // The request really used Strict Structured Outputs.
    assert.equal(stub.state.lastBody.text.format.type, 'json_schema')
    assert.equal(stub.state.lastBody.text.format.strict, true)
    assert.equal(stub.state.lastBody.temperature, 0)
    assert.match(stub.state.lastAuth, /^Bearer test-key$/)
  } finally { stub.server.close() }
})

test('an HTTP error fails closed', async () => {
  const stub = await startStub('http500')
  try {
    const r = await secondOpinionPicks({
      apiKey: 'k', lines: LINES, segments: [{ index: 0, start: 0, end: 1, text: 'x' }],
      baseUrl: `http://127.0.0.1:${stub.port}`,
    })
    assert.equal(r.ok, false)
    assert.match(r.reason, /http_500/)
  } finally { stub.server.close() }
})

test('a model refusal fails closed', async () => {
  const stub = await startStub('refusal')
  try {
    const r = await secondOpinionPicks({
      apiKey: 'k', lines: LINES, segments: [{ index: 0, start: 0, end: 1, text: 'x' }],
      baseUrl: `http://127.0.0.1:${stub.port}`,
    })
    assert.equal(r.ok, false)
    assert.equal(r.reason, 'model_refusal')
  } finally { stub.server.close() }
})

test('unparseable output fails closed instead of inventing picks', async () => {
  const stub = await startStub('garbage')
  try {
    const r = await secondOpinionPicks({
      apiKey: 'k', lines: LINES, segments: [{ index: 0, start: 0, end: 1, text: 'x' }],
      baseUrl: `http://127.0.0.1:${stub.port}`,
    })
    assert.equal(r.ok, false)
    assert.equal(r.reason, 'no_valid_picks')
  } finally { stub.server.close() }
})

test('a hung request times out and fails closed', async () => {
  const stub = await startStub('hang')
  try {
    const r = await secondOpinionPicks({
      apiKey: 'k', lines: LINES, segments: [{ index: 0, start: 0, end: 1, text: 'x' }],
      baseUrl: `http://127.0.0.1:${stub.port}`, timeoutMs: 300,
    })
    assert.equal(r.ok, false)
    assert.equal(r.reason, 'timeout')
  } finally { stub.server.close() }
})

test('a missing key never makes a network call', async () => {
  const stub = await startStub('ok')
  try {
    const r = await secondOpinionPicks({
      apiKey: '', lines: LINES, segments: [{ index: 0, start: 0, end: 1, text: 'x' }],
      baseUrl: `http://127.0.0.1:${stub.port}`,
    })
    assert.equal(r.ok, false)
    assert.equal(r.reason, 'no_api_key')
    eq(stub.state.requests, 0)
  } finally { stub.server.close() }
})

// ---------------------------------------------------------------------------
// Applying picks - the safety rules
// ---------------------------------------------------------------------------

test('only unplaced lines are positioned, and never above the confidence cap', () => {
  const alignment = {
    lines: [
      { lineIndex: 0, text: 'a', startSeconds: 12.5, endSeconds: 15, confidence: 0.88 },
      { lineIndex: 1, text: 'b', startSeconds: null, endSeconds: null, confidence: 0 },
    ],
  }
  const segments = [
    { index: 0, start: 12.5, end: 15, text: 'a' },
    { index: 1, start: 40, end: 43, text: 'b' },
  ]
  const picks = [
    { lineIndex: 0, segmentIndex: 1, agreement: 1, reason: 'would move a measured line' },
    { lineIndex: 1, segmentIndex: 1, agreement: 0.95, reason: 'unplaced line' },
  ]
  const out = applySecondOpinion(alignment, picks, segments)
  eq(out.placed, 1)

  // The measured line is untouched.
  eq(alignment.lines[0].startSeconds, 12.5)
  eq(alignment.lines[0].confidence, 0.88)
  assert.equal(alignment.lines[0].llmAssisted, undefined)

  // The unplaced line gets the SEGMENT's measured time, at a low confidence.
  eq(alignment.lines[1].startSeconds, 40)
  eq(alignment.lines[1].endSeconds, 43)
  assert.ok(alignment.lines[1].confidence <= 0.5)
  assert.equal(alignment.lines[1].llmAssisted, true)
})

test('picks below the agreement floor and -1 answers are ignored', () => {
  const alignment = { lines: [{ lineIndex: 0, text: 'a', startSeconds: null, confidence: 0 }] }
  const segments = [{ index: 0, start: 1, end: 2, text: 'a' }]
  const low = applySecondOpinion(alignment, [{ lineIndex: 0, segmentIndex: 0, agreement: DEFAULT_MIN_AGREEMENT - 0.01, reason: '' }], segments)
  eq(low.placed, 0)
  eq(alignment.lines[0].startSeconds, null)

  const unsung = applySecondOpinion(alignment, [{ lineIndex: 0, segmentIndex: -1, agreement: 1, reason: '' }], segments)
  eq(unsung.placed, 0)
  eq(alignment.lines[0].startSeconds, null)
})

test('a pick for a missing segment is ignored', () => {
  const alignment = { lines: [{ lineIndex: 0, text: 'a', startSeconds: null, confidence: 0 }] }
  const out = applySecondOpinion(alignment, [{ lineIndex: 0, segmentIndex: 5, agreement: 1, reason: '' }], [{ index: 0, start: 1, end: 2, text: 'a' }])
  eq(out.placed, 0)
  eq(alignment.lines[0].startSeconds, null)
})

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

for (const [name, fn] of tests) {
  try {
    await fn()
    passed++
    console.log(`  ok   ${name}`)
  } catch (err) {
    failed++
    console.error(`  FAIL ${name}`)
    console.error(`       ${err.message}`)
  }
}

console.log(`\n${passed} passed, ${failed} failed, ${passed + failed} total`)
process.exit(failed ? 1 : 0)
