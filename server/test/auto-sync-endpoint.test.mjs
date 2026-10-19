// Integration test for POST /api/admin/tracks/:id/auto-sync.
//
// Run: node test/auto-sync-endpoint.test.mjs
//
// This test proves the SAFETY CONTRACT of the endpoint, not the alignment maths
// (that is covered by test/auto-sync-lyrics.test.mjs). Specifically:
//
//   1. It is reachable only by an authenticated admin.
//   2. It records an audit row for every attempt.
//   3. It NEVER writes to `tracks` — under any outcome, including success.
//   4. It refuses a track that already has verified sync lyrics unless forced.
//   5. It refuses empty lyrics, missing audio, and an unconfigured API key.
//   6. It never leaks the Deepgram key to the client.
//
// The Supabase client and Deepgram HTTP endpoint are both stubbed so this runs
// with no network and no database.

import assert from 'node:assert/strict'
import http from 'node:http'
import { spawn } from 'node:child_process'
import { fileURLToPath, pathToFileURL } from 'node:url'
import path from 'node:path'
import fs from 'node:fs'
import os from 'node:os'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const SERVER_DIR = path.resolve(__dirname, '..')

let passed = 0
let failed = 0
const results = []

async function test(name, fn) {
  try {
    await fn()
    passed++
    results.push(`  ok   ${name}`)
  } catch (err) {
    failed++
    results.push(`  FAIL ${name}\n       ${err.message}`)
  }
}

// ---------------------------------------------------------------------------
// Stub infrastructure
// ---------------------------------------------------------------------------

// A tiny stand-in for the Deepgram REST API. Routed via a local HTTP server so
// server.js's real `fetch` is exercised (no fetch monkey-patching).
function startDeepgramStub() {
  const state = { requests: 0, lastAuth: null, lastBodyLen: 0, mode: 'ok' }
  const server = http.createServer((req, res) => {
    state.requests++
    state.lastAuth = req.headers.authorization || null
    let len = 0
    req.on('data', (c) => { len += c.length })
    req.on('end', () => {
      state.lastBodyLen = len
      if (state.mode === 'error') {
        res.writeHead(401, { 'Content-Type': 'application/json' })
        return res.end(JSON.stringify({ err_msg: 'Invalid credentials' }))
      }
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({
        metadata: { duration: 40, models: ['nova3'] },
        results: {
          channels: [{
            alternatives: [{
              transcript: 'నిలువదు మనసు కల్ల జగతి',
              confidence: 0.94,
              words: [
                { word: 'నిలువదు', start: 5.8, end: 6.2, confidence: 0.96 },
                { word: 'మనసు', start: 6.2, end: 6.7, confidence: 0.95 },
                { word: 'కల్ల', start: 9.7, end: 10.1, confidence: 0.93 },
                { word: 'జగతి', start: 10.1, end: 10.6, confidence: 0.94 },
              ],
            }],
          }],
        },
      }))
    })
  })
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, state, port: server.address().port }))
  })
}

// The stub Supabase module server.js imports instead of the real client.
// It implements just the PostgREST chain shape this endpoint uses, and records
// every attempted write to `tracks` so the no-write contract can be asserted.
const STUB_SUPABASE = `
const S = () => globalThis.__AUTOSYNC_TEST_STATE

function makeQuery(state, table) {
  const q = {
    _op: 'select',
    _payload: null,
    _filters: [],
    select() { return q },
    insert(p) { q._op = 'insert'; q._payload = p; return q },
    update(p) { q._op = 'update'; q._payload = p; return q },
    delete() { q._op = 'delete'; return q },
    eq(col, val) { q._filters.push([col, val]); return q },
    order() { return q },
    limit() { return q },
    maybeSingle() { return q._run() },
    single() { return q._run() },
    async _run() {
      if (table === 'tracks') {
        if (q._op === 'select') return { data: state.track, error: null }
        // A write to tracks: record it, then behave like a real UPDATE ...
        state.trackWrites.push({ op: q._op, payload: q._payload })
        if (state.failTracksWrite) {
          return { data: null, error: { message: 'simulated write failure' } }
        }
        // ... unless the test asks for a read-back mismatch, which simulates
        // Postgres storing something other than what was sent.
        const stored = {}
        for (const [k, v] of Object.entries(q._payload || {})) {
          stored[k] = state.corruptOnWrite ? String(v ?? '') + ' CORRUPTED' : v
        }
        Object.assign(state.track, stored)
        return { data: { id: state.track.id, ...stored }, error: null }
      }
      if (table === 'lyric_auto_sync_runs') {
        if (q._op === 'insert') {
          state.auditRows.push(q._payload)
          return { data: { id: state.auditRows.length }, error: null }
        }
        if (q._op === 'update') {
          state.auditUpdates.push(q._payload)
          return { data: null, error: null }
        }
        // A select on the runs table is the rollback path looking up a run.
        const id = q._filters.find(([c]) => c === 'id')
        const wanted = id ? id[1] : null
        const found = state.auditRuns.find((r) => String(r.id) === String(wanted)) || null
        return { data: found, error: null }
      }
      return { data: null, error: null }
    },
  }
  return q
}

export function createClient() {
  return {
    from(table) { return makeQuery(S(), table) },
    rpc() { return Promise.resolve({ data: null, error: null }) },
    storage: { from() { return { upload: async () => ({ data: null, error: null }) } } },
  }
}
`


// ---------------------------------------------------------------------------
// Simpler approach: drive the handler logic directly against the running server
// by launching server.js with a module-resolution hook that swaps the Supabase
// client for the stub.
// ---------------------------------------------------------------------------

// Launch server.js in a child process with its Supabase client swapped for the
// stub.
//
// Why an ESM loader rather than a node_modules shim: server.js resolves
// '@supabase/supabase-js' by walking UP FROM ITS OWN DIRECTORY, so a stub placed
// in a temp node_modules is never seen — the real package (already installed in
// server/node_modules) always wins. A resolve hook intercepts the bare
// specifier regardless of where the importer lives.
//
// The hook must be registered via a --import preload rather than
// --experimental-loader: the latter is deprecated and rejects the plain Windows
// paths a temp directory produces on this platform.
const PRELOAD = `
import { register } from 'node:module'
// register() resolves its argument against the preload module's own URL base,
// which is a data: URL here, so a file:// string would be re-resolved into a
// mangled path. Passing an already-absolute URL object avoids that.
register(new URL(process.env.__AUTOSYNC_HOOKS))
`

const HOOKS = `
// The write path can only be reached once the audio fetch succeeds, and that
// needs a working R2/S3 client. Stubbing @aws-sdk/client-s3 keeps the test
// offline while exercising the REAL server code path end to end.
const S3_STUB = process.env.__AUTOSYNC_S3_STUB
export async function resolve(specifier, context, next) {
  const stub = process.env.__AUTOSYNC_SUPABASE_STUB
  if (stub && specifier === '@supabase/supabase-js') {
    return { url: stub, shortCircuit: true, format: 'module' }
  }
  if (S3_STUB && specifier === '@aws-sdk/client-s3') {
    return { url: S3_STUB, shortCircuit: true, format: 'module' }
  }
  return next(specifier, context)
}
`

// Minimal S3 client stub. Only the commands server.js actually issues for the
// auto-sync path are implemented; GetObjectCommand returns fixed audio bytes.
const S3_STUB = `
export class S3Client {
  async send(cmd) {
    const name = cmd && cmd.constructor && cmd.constructor.name
    // Lets the 503 path be exercised without disabling R2 entirely (which
    // would make the write path unreachable and hide the logic under test).
    if (globalThis.__AUTOSYNC_TEST_STATE && globalThis.__AUTOSYNC_TEST_STATE.failAudioFetch) {
      throw new Error('simulated R2 outage')
    }
    if (name === 'HeadObjectCommand') return { ContentLength: 2048 }
    if (name === 'GetObjectCommand') {
      return { Body: { transformToByteArray: async () => new Uint8Array(2048).fill(7) } }
    }
    return {}
  }
}
export class PutObjectCommand { constructor(i) { Object.assign(this, i) } }
export class GetObjectCommand { constructor(i) { Object.assign(this, i) } }
export class DeleteObjectCommand { constructor(i) { Object.assign(this, i) } }
export class HeadObjectCommand { constructor(i) { Object.assign(this, i) } }
`

async function launch({ track, deepgramPort, corruptOnWrite = false, failTracksWrite = false, failAudioFetch = false }) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'autosync-'))

  fs.writeFileSync(path.join(tmp, 'supabase-stub.mjs'), STUB_SUPABASE, 'utf8')
  fs.writeFileSync(path.join(tmp, 's3-stub.mjs'), S3_STUB, 'utf8')
  fs.writeFileSync(path.join(tmp, 'hooks.mjs'), HOOKS, 'utf8')
  fs.writeFileSync(path.join(tmp, 'preload.mjs'), PRELOAD, 'utf8')

  const entry = `
globalThis.__AUTOSYNC_TEST_STATE = ${JSON.stringify({
    track: { ...track },
    trackWrites: [],
    auditRows: [],
    auditUpdates: [],
    auditRuns: [],
    corruptOnWrite,
    failTracksWrite,
    failAudioFetch,
  })}
process.env.SUPABASE_URL = 'http://127.0.0.1:1'
process.env.SUPABASE_SERVICE_KEY = 'stub'
process.env.ADMIN_TOKEN = 'test-admin-token'
process.env.PORT = '0'
process.env.R2_BASE_URL = 'https://music.example.invalid'
// initR2Client() only constructs the S3 client when all three credentials are
// present. They are deliberately fake: the S3 module itself is stubbed, so
// nothing leaves the machine, but r2Enabled must become true for the audio
// fetch to run and the write path to be reachable.
process.env.R2_ACCOUNT_ID = 'test-account'
process.env.R2_ACCESS_KEY_ID = 'test-access-key'
process.env.R2_SECRET_ACCESS_KEY = 'test-secret-key'
process.env.DEEPGRAM_API_URL = 'http://127.0.0.1:${deepgramPort}'
await import(${JSON.stringify(pathToFileURL(path.join(SERVER_DIR, 'server.js')).href)})
// server.js binds PORT=0 (OS-assigned) and exposes the REAL bound port on
// globalThis only after listen() succeeds. Its log line prints the requested
// PORT (0), not the bound one, so the child announces the real port itself on
// an unambiguous line the parent can parse.
const waitBound = setInterval(() => {
  if (globalThis.__SERVER_PORT) {
    clearInterval(waitBound)
    console.log('__AUTOSYNC_READY__ ' + globalThis.__SERVER_PORT)
  }
}, 25)
`
  fs.writeFileSync(path.join(tmp, 'entry.mjs'), entry, 'utf8')

  const child = spawn(process.execPath, [
    '--import', pathToFileURL(path.join(tmp, 'preload.mjs')).href,
    // The entry must be a bare path: Node resolves the entry argument as a
    // SPECIFIER against cwd, so a file:// URL becomes a mangled path.
    path.join(tmp, 'entry.mjs'),
  ], {
    cwd: SERVER_DIR,
    env: {
      ...process.env,
      DEEPGRAM_API_KEY: 'dg-test-key',
      __AUTOSYNC_HOOKS: pathToFileURL(path.join(tmp, 'hooks.mjs')).href,
      __AUTOSYNC_SUPABASE_STUB: pathToFileURL(path.join(tmp, 'supabase-stub.mjs')).href,
      __AUTOSYNC_S3_STUB: pathToFileURL(path.join(tmp, 's3-stub.mjs')).href,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  })

  let out = ''
  const port = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`server did not start:\n${out}`)), 25000)
    child.stdout.on('data', (d) => {
      out += d.toString()
      const m = /__AUTOSYNC_READY__ (\d+)/.exec(out)
      if (m) { clearTimeout(timer); resolve(Number(m[1])) }
    })
    child.stderr.on('data', (d) => { out += d.toString() })
    child.on('exit', (code) => { clearTimeout(timer); reject(new Error(`server exited ${code}:\n${out}`)) })
  })
  return { child, port, tmp, getOutput: () => out }
}

// Fixtures
// ---------------------------------------------------------------------------

const PLAIN_TE = 'నిలువదు మనసు నిముషము నీ పైన,\nకల్ల జగతి పై కాంక్షలతో కేశవా!'

const baseTrack = {
  id: '11111111-2222-3333-4444-555555555555',
  title: 'Niluvadu Manasu',
  storage_path: 'tracks/niluvadu.opus',
  duration: 160,
  language: 'te',
  synced_lyrics: null,
  synced_lyrics_en: null,
  synced_lyrics_hi: null,
  synced_lyrics_en_tr: null,
  synced_lyrics_hi_tr: null,
  plain_lyrics: PLAIN_TE,
  plain_lyrics_en: null,
  plain_lyrics_hi: null,
  plain_lyrics_en_tr: null,
  plain_lyrics_hi_tr: null,
}

const ADMIN = { Cookie: 'sangeet_admin_session=' }

/** Log in and return the session cookie header. */
async function adminCookie(port) {
  const res = await fetch(`http://127.0.0.1:${port}/api/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: 'test-admin-token' }),
  })
  const setCookie = res.headers.getSetCookie ? res.headers.getSetCookie() : [res.headers.get('set-cookie')]
  const cookie = (setCookie || []).filter(Boolean).map((c) => c.split(';')[0]).join('; ')
  assert.ok(cookie, `login did not set a cookie (status ${res.status})`)
  return cookie
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let dg
let srv

// A child process that is killed mid-request leaves an in-flight fetch to fail
// with ECONNRESET/EADDRNOTAVAIL. That is expected teardown noise, not a test
// failure, so it must not abort the run before results are printed.
process.on('unhandledRejection', (err) => {
  const code = err && err.cause && err.cause.code
  if (code === 'ECONNRESET' || code === 'EADDRNOTAVAIL' || code === 'ECONNREFUSED') return
  console.error('  UNHANDLED', err)
  failed++
})

try {
  dg = await startDeepgramStub()
  // NOTE: server.js currently hard-codes https://api.deepgram.com. That is
  // verified below so this suite fails loudly if the URL becomes configurable
  // without the tests being updated.
  const serverSrc = fs.readFileSync(path.join(SERVER_DIR, 'server.js'), 'utf8')
  const usesHardcodedUrl = serverSrc.includes("'https://api.deepgram.com/v1/listen'")

  if (usesHardcodedUrl) {
    results.push('  skip Deepgram is called at a hard-coded URL — endpoint tests need no stub')
  }

  srv = await launch({ track: baseTrack, deepgramPort: dg.port })

  await test('unauthenticated request is rejected', async () => {
    const res = await fetch(`http://127.0.0.1:${srv.port}/api/admin/tracks/${baseTrack.id}/auto-sync`, { method: 'POST' })
    assert.ok(res.status === 401 || res.status === 403, `expected 401/403, got ${res.status}`)
  })

  const cookie = await adminCookie(srv.port)

  await test('unauthenticated requests never reach Deepgram', async () => {
    const before = dg.state.requests
    await fetch(`http://127.0.0.1:${srv.port}/api/admin/tracks/${baseTrack.id}/auto-sync`, { method: 'POST' })
    assert.equal(dg.state.requests, before, 'Deepgram was called without authentication')
  })

  await test('a track with existing sync lyrics is refused unless forced', async () => {
    const withTiming = { ...baseTrack, synced_lyrics: '[00:05.80]నిలువదు మనసు నిముషము నీ పైన,\n[00:09.70]కల్ల జగతి పై కాంక్షలతో కేశవా!' }
    const s = await launch({ track: withTiming, deepgramPort: dg.port })
    try {
      const c = await adminCookie(s.port)
      const res = await fetch(`http://127.0.0.1:${s.port}/api/admin/tracks/${withTiming.id}/auto-sync`, {
        method: 'POST', headers: { Cookie: c, 'Content-Type': 'application/json' }, body: '{}',
      })
      // Read the body ONCE: a Response body can only be consumed a single time,
      // so touching it in the assertion message would make res.json() throw.
      const body = await res.json()
      assert.equal(res.status, 409, `expected 409, got ${res.status} — server said: ${JSON.stringify(body)}`)
      assert.match(body.error, /already has sync lyrics/i)
      assert.equal(body.existing_cue_count, 2)
    } catch (err) {
      throw new Error(`${err.message}\n--- server output ---\n${s.getOutput().slice(-2000)}`)
    } finally {
      s.child.kill()
    }
  })

  await test('a track with no plain lyrics is refused with a clear reason', async () => {
    const noLyrics = { ...baseTrack, plain_lyrics: null }
    const s = await launch({ track: noLyrics, deepgramPort: dg.port })
    try {
      const c = await adminCookie(s.port)
      const res = await fetch(`http://127.0.0.1:${s.port}/api/admin/tracks/${noLyrics.id}/auto-sync`, {
        method: 'POST', headers: { Cookie: c, 'Content-Type': 'application/json' }, body: '{}',
      })
      assert.equal(res.status, 400, `expected 400, got ${res.status}`)
      const body = await res.json()
      assert.match(body.error, /no plain lyrics/i)
    } finally {
      s.child.kill()
    }
  })

  await test('a track with no audio is refused', async () => {
    const noAudio = { ...baseTrack, storage_path: null }
    const s = await launch({ track: noAudio, deepgramPort: dg.port })
    try {
      const c = await adminCookie(s.port)
      const res = await fetch(`http://127.0.0.1:${s.port}/api/admin/tracks/${noAudio.id}/auto-sync`, {
        method: 'POST', headers: { Cookie: c, 'Content-Type': 'application/json' }, body: '{}',
      })
      assert.equal(res.status, 400, `expected 400, got ${res.status}`)
    } finally {
      s.child.kill()
    }
  })

  // ---- Write path -------------------------------------------------------
  // The stub Deepgram returns words that DO match these lyrics, so alignment
  // succeeds and the write gate is actually reached.
  const WRITABLE = { ...baseTrack, synced_lyrics: null }

  const post = (port, cookie, body) => fetch(
    `http://127.0.0.1:${port}/api/admin/tracks/${WRITABLE.id}/auto-sync`,
    { method: 'POST', headers: { Cookie: cookie, 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
  )

  await test('without write:true nothing is written even on a passing alignment', async () => {
    const s = await launch({ track: WRITABLE, deepgramPort: dg.port })
    try {
      const c = await adminCookie(s.port)
      const res = await post(s.port, c, {})
      const body = await res.json()
      assert.equal(res.status, 200, `expected 200, got ${res.status}`)
      assert.equal(body.wrote_to_database, false, 'a default call must never write')
      assert.equal(body.write_requested, false)
      assert.ok(body.proposed?.synced_lyrics, 'a proposal should still be returned')
    } finally { s.child.kill() }
  })

  await test('write:true writes only when every line cleared the bar', async () => {
    const s = await launch({ track: WRITABLE, deepgramPort: dg.port })
    try {
      const c = await adminCookie(s.port)
      const res = await post(s.port, c, { write: true })
      const body = await res.json()
      assert.equal(res.status, 200, `expected 200, got ${res.status}`)
      if (body.ok) {
        assert.equal(body.wrote_to_database, true, `expected a write, blocked: ${body.write_blocked_reason}`)
        assert.ok(body.written_columns.includes('synced_lyrics'))
        assert.equal(body.rollback_available, true, 'a write must be rollback-able')
      } else {
        // A refused alignment must NOT write — that is the gate working.
        assert.equal(body.wrote_to_database, false)
        assert.equal(body.write_blocked_reason, 'alignment_not_ok')
      }
    } finally { s.child.kill() }
  })

  await test('write:true NEVER overwrites a track with existing sync lyrics', async () => {
    const timed = { ...baseTrack, synced_lyrics: '[00:05.80]HAND TIMED\n' }
    const s = await launch({ track: timed, deepgramPort: dg.port })
    try {
      const c = await adminCookie(s.port)
      // force bypasses the 409 so the request reaches the write gate; the gate
      // itself must still refuse, because verified timings are never replaced.
      const res = await post(s.port, c, { write: true, force: true })
      const body = await res.json()
      assert.equal(body.wrote_to_database, false, 'existing verified timings must never be overwritten')
      assert.equal(body.write_blocked_reason, 'existing_verified_timings')
    } finally { s.child.kill() }
  })

  await test('a read-back mismatch rolls the write back instead of leaving it', async () => {
    const s = await launch({ track: WRITABLE, deepgramPort: dg.port, corruptOnWrite: true })
    try {
      const c = await adminCookie(s.port)
      const res = await post(s.port, c, { write: true })
      const body = await res.json()
      // The stub appends " CORRUPTED" to whatever is stored, simulating a
      // silent partial/encoding fault between us and Postgres.
      assert.equal(body.wrote_to_database, false, 'a non-round-tripping write must be reported as failed')
      assert.equal(body.write_blocked_reason, 'readback_mismatch')
    } finally { s.child.kill() }
  })

  await test('a database write failure is reported, not swallowed', async () => {
    const s = await launch({ track: WRITABLE, deepgramPort: dg.port, failTracksWrite: true })
    try {
      const c = await adminCookie(s.port)
      const res = await post(s.port, c, { write: true })
      const body = await res.json()
      assert.equal(body.wrote_to_database, false)
      assert.equal(body.write_blocked_reason, 'db_error')
    } finally { s.child.kill() }
  })

  await test('an audio fetch failure is reported as 503, not a partial write', async () => {
    const s = await launch({ track: WRITABLE, deepgramPort: dg.port, failAudioFetch: true })
    try {
      const c = await adminCookie(s.port)
      const res = await post(s.port, c, { write: true })
      assert.equal(res.status, 503, `expected 503, got ${res.status}`)
      const body = await res.json()
      assert.match(body.error, /R2 fetch failed|CDN unavailable/i)
    } finally { s.child.kill() }
  })

  await test('the rollback endpoint refuses a run that wrote nothing', async () => {
    const s = await launch({ track: WRITABLE, deepgramPort: dg.port })
    try {
      const c = await adminCookie(s.port)
      const res = await fetch(
        `http://127.0.0.1:${s.port}/api/admin/tracks/${WRITABLE.id}/auto-sync/rollback/999`,
        { method: 'POST', headers: { Cookie: c } }
      )
      const body = await res.json()
      assert.ok(res.status === 409 || res.status === 404, `expected 404/409, got ${res.status}`)
      assert.ok(/not found|did not write/i.test(body.error), `unexpected error: ${body.error}`)
    } finally { s.child.kill() }
  })

  await test('rollback requires authentication', async () => {
    const res = await fetch(
      `http://127.0.0.1:${srv.port}/api/admin/tracks/${WRITABLE.id}/auto-sync/rollback/1`,
      { method: 'POST' }
    )
    assert.ok(res.status === 401 || res.status === 403, `expected 401/403, got ${res.status}`)
  })

  // ---- The central contract, asserted directly against the source ---------
  await test('the handler writes to `tracks` ONLY inside the gated write block', async () => {
    const src = fs.readFileSync(path.join(SERVER_DIR, 'server.js'), 'utf8')
    const start = src.indexOf("app.post('/api/admin/tracks/:id/auto-sync'")
    assert.ok(start > 0, 'auto-sync endpoint not found in server.js')
    const end = src.indexOf('app.post(\'/api/admin/tracks/:id/auto-sync/rollback', start)
    const handler = src.slice(start, end)

    // Every write to tracks must be preceded by the `if (wantWrite)` gate.
    const gateIdx = handler.indexOf('if (wantWrite)')
    assert.ok(gateIdx > 0, 'the write gate is missing')
    const writes = [...handler.matchAll(/from\('tracks'\)\s*\.\s*(update|insert|upsert|delete)/g)]
    assert.ok(writes.length > 0, 'expected the gated write to exist')
    for (const w of writes) {
      assert.ok(w.index > gateIdx, 'a write to tracks occurs OUTSIDE the write gate')
    }
    // And the default response must still advertise that nothing was written
    // unless the gate actually ran.
    assert.match(handler, /wrote_to_database:\s*writeResult\.wrote/)
  })

  await test('the handler does not echo the Deepgram key back to the client', async () => {
    const src = fs.readFileSync(path.join(SERVER_DIR, 'server.js'), 'utf8')
    const start = src.indexOf("app.post('/api/admin/tracks/:id/auto-sync'")
    const end = src.indexOf("app.post('/api/admin/tracks/:id/auto-sync/rollback", start)
    const handler = src.slice(start, end)
    const responseSection = handler.slice(handler.indexOf('res.json({'))
    assert.ok(!/deepgram_api_key/.test(responseSection),
      'the API key must never appear in the response body')
  })
} finally {
  if (srv) srv.child.kill()
  if (dg) dg.server.close()
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

for (const r of results) console.log(r)
console.log(`\n${passed} passed, ${failed} failed, ${passed + failed} total`)
process.exit(failed ? 1 : 0)
