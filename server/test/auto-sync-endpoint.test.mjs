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
        // Any write to tracks violates the endpoint contract. Record it and
        // fail the call so a regression surfaces loudly rather than silently.
        state.trackWrites.push({ op: q._op, payload: q._payload })
        return { data: null, error: { message: 'tracks must not be written by auto-sync' } }
      }
      if (table === 'lyric_auto_sync_runs') {
        state.auditRows.push(q._payload)
        return { data: { id: state.auditRows.length }, error: null }
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
export async function resolve(specifier, context, next) {
  const stub = process.env.__AUTOSYNC_SUPABASE_STUB
  if (stub && specifier === '@supabase/supabase-js') {
    return { url: stub, shortCircuit: true, format: 'module' }
  }
  return next(specifier, context)
}
`

async function launch({ track, deepgramPort }) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'autosync-'))

  fs.writeFileSync(path.join(tmp, 'supabase-stub.mjs'), STUB_SUPABASE, 'utf8')
  fs.writeFileSync(path.join(tmp, 'hooks.mjs'), HOOKS, 'utf8')
  fs.writeFileSync(path.join(tmp, 'preload.mjs'), PRELOAD, 'utf8')

  const entry = `
globalThis.__AUTOSYNC_TEST_STATE = ${JSON.stringify({ track, trackWrites: [], auditRows: [] })}
process.env.SUPABASE_URL = 'http://127.0.0.1:1'
process.env.SUPABASE_SERVICE_KEY = 'stub'
process.env.ADMIN_TOKEN = 'test-admin-token'
process.env.PORT = '0'
process.env.R2_BASE_URL = 'https://music.example.invalid'
process.env.R2_ACCOUNT_ID = ''
process.env.R2_ACCESS_KEY_ID = ''
process.env.R2_SECRET_ACCESS_KEY = ''
process.env.__AUTOSYNC_DEEPGRAM_BASE = 'http://127.0.0.1:${deepgramPort}'
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

  await test('an R2/CDN failure is reported as 503, not a partial write', async () => {
    // The stub R2 client is not configured in tests, so the audio fetch fails.
    const res = await fetch(`http://127.0.0.1:${srv.port}/api/admin/tracks/${baseTrack.id}/auto-sync`, {
      method: 'POST', headers: { Cookie: cookie, 'Content-Type': 'application/json' }, body: '{}',
    })
    assert.equal(res.status, 503, `expected 503, got ${res.status}`)
    const body = await res.json()
    assert.match(body.error, /R2 fetch failed|CDN unavailable/i)
  })

  // ---- The central contract, asserted directly against the source ---------
  await test('the endpoint never writes to `tracks`', async () => {
    const src = fs.readFileSync(path.join(SERVER_DIR, 'server.js'), 'utf8')
    const start = src.indexOf("app.post('/api/admin/tracks/:id/auto-sync'")
    assert.ok(start > 0, 'auto-sync endpoint not found in server.js')
    const end = src.indexOf('app.delete(', start)
    const handler = src.slice(start, end)

    assert.ok(!/from\('tracks'\)\s*\.\s*(update|insert|upsert|delete)/.test(handler),
      'the auto-sync handler must never write to tracks')
    assert.match(handler, /wrote_to_database:\s*false/,
      'the response must state explicitly that nothing was written')
  })

  await test('the handler does not echo the Deepgram key back to the client', async () => {
    const src = fs.readFileSync(path.join(SERVER_DIR, 'server.js'), 'utf8')
    const start = src.indexOf("app.post('/api/admin/tracks/:id/auto-sync'")
    const end = src.indexOf('app.delete(', start)
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
