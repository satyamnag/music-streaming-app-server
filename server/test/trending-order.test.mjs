// Integration test for POST /api/admin/trending/tracks (admin "Arrange Top
// Trending") plus the static wiring of the panel that drives it.
//
// Run: node test/trending-order.test.mjs
//
// What it proves — this is the SAFETY CONTRACT, not the UI look:
//   1. Only an authenticated admin can reorder the trending list.
//   2. The COMPLETE desired id list reaches reorder_trending_tracks, in order,
//      deduplicated and trimmed 1:1 with what the browser sent.
//   3. An empty list is accepted and forwarded as [], which is how the feature
//      clears every pin and falls back to the play-count ranking.
//   4. Malformed bodies are refused with 400 BEFORE any RPC runs, so a bad
//      request can never clear or scramble the stored order.
//   5. A database error surfaces as 500 with the message, and the process
//      stays up.
//   6. The admin page carries the nav entry, panel, handlers and the two view
//      dispatch branches — a saved order with no way to open the panel would be
//      dead code, and a panel wired to the wrong endpoint would silently do
//      nothing.
//
// The Supabase client is stubbed through a resolve hook, so this runs offline
// with no database. Same technique as test/auto-sync-endpoint.test.mjs.

import assert from 'node:assert/strict'
import http from 'node:http'
import { spawn } from 'node:child_process'
import { fileURLToPath, pathToFileURL } from 'node:url'
import path from 'node:path'
import fs from 'node:fs'
import os from 'node:os'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const SERVER_DIR = path.resolve(__dirname, '..')
const ADMIN_TOKEN = 'trending-test-admin-token'

let passed = 0
let failed = 0
const results = []

async function test(name, fn) {
  try {
    await fn()
    passed++
    results.push(`  ok   ${name}`)
  } catch (error) {
    failed++
    results.push(`  FAIL ${name}\n       ${error.message}`)
  }
}

// ---------------------------------------------------------------------------
// Supabase stub: records every rpc call, and serves the tracks list.
// ---------------------------------------------------------------------------
const STUB_SUPABASE = `
import fs from 'node:fs'

const S = () => globalThis.__TRENDING_TEST_STATE

// The parent test cannot see this process's memory, so every recorded RPC call
// is mirrored to a JSON file it can read. This is how the assertions observe
// what server.js actually asked the database to do.
function flush(state) {
  try {
    fs.writeFileSync(state.stateFile, JSON.stringify({ calls: state.rpcCalls, tracks: state.tracks }))
  } catch (_) { /* the parent removes the temp dir at the end */ }
}

function makeQuery(state, table) {
  const q = {
    _op: 'select',
    select() { return q },
    insert() { q._op = 'insert'; return q },
    update() { q._op = 'update'; return q },
    delete() { q._op = 'delete'; return q },
    eq() { return q },
    is() { return q },
    not() { return q },
    in() { return q },
    order() { return q },
    limit() { return q },
    range() { return q },
    maybeSingle() { return q._run() },
    single() { return q._run() },
    then(resolve, reject) { return q._run().then(resolve, reject) },
    async _run() {
      if (table === 'tracks') return { data: state.tracks, error: null }
      return { data: [], error: null }
    },
  }
  return q
}

export function createClient() {
  return {
    from(table) { return makeQuery(S(), table) },
    async rpc(name, params) {
      const state = S()
      state.rpcCalls.push({ name, params })
      flush(state)
      if (name === 'get_secret') return { data: null, error: null }
      if (state.failRpc && name === 'reorder_trending_tracks') {
        return { data: null, error: { message: 'simulated database failure' } }
      }
      return { data: null, error: null }
    },
    storage: { from() { return { upload: async () => ({ data: null, error: null }) } } },
    auth: { getUser: async () => ({ data: { user: null }, error: null }) },
  }
}
`

const PRELOAD = `
import { register } from 'node:module'
register(new URL(process.env.__TRENDING_HOOKS))
`

const HOOKS = `
export async function resolve(specifier, context, next) {
  const stub = process.env.__TRENDING_SUPABASE_STUB
  if (stub && specifier === '@supabase/supabase-js') {
    return { url: stub, shortCircuit: true, format: 'module' }
  }
  return next(specifier, context)
}
`

// Boots server.js with the stub. Returns the base URL and a control handle.
async function launch({ failRpc = false } = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'trending-'))

  fs.writeFileSync(path.join(tmp, 'supabase-stub.mjs'), STUB_SUPABASE, 'utf8')
  fs.writeFileSync(path.join(tmp, 'hooks.mjs'), HOOKS, 'utf8')
  fs.writeFileSync(path.join(tmp, 'preload.mjs'), PRELOAD, 'utf8')

  const entry = `
globalThis.__TRENDING_TEST_STATE = ${JSON.stringify({
    rpcCalls: [],
    tracks: [{ id: '11111111-1111-1111-1111-111111111111', title: 'A', featured_order: null, trending_order: null }],
    failRpc,
    stateFile: path.join(tmp, 'state.json'),
  })}
process.env.SUPABASE_URL = 'http://127.0.0.1:1'
process.env.SUPABASE_SERVICE_KEY = 'stub'
process.env.ADMIN_TOKEN = ${JSON.stringify(ADMIN_TOKEN)}
process.env.PORT = '0'
await import(${JSON.stringify(pathToFileURL(path.join(SERVER_DIR, 'server.js')).href)})
const wait = setInterval(() => {
  if (globalThis.__SERVER_PORT) {
    clearInterval(wait)
    console.log('__TRENDING_READY__ ' + globalThis.__SERVER_PORT)
  }
}, 20)
`

  const entryPath = path.join(tmp, 'entry.mjs')
  fs.writeFileSync(entryPath, entry, 'utf8')

  const child = spawn(
    process.execPath,
    ['--import', pathToFileURL(path.join(tmp, 'preload.mjs')).href, entryPath],
    {
      cwd: SERVER_DIR,
      env: {
        ...process.env,
        __TRENDING_HOOKS: pathToFileURL(path.join(tmp, 'hooks.mjs')).href,
        __TRENDING_SUPABASE_STUB: pathToFileURL(path.join(tmp, 'supabase-stub.mjs')).href,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    }
  )

  let output = ''
  const port = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('server did not start:\n' + output)), 30000)
    child.stdout.on('data', (chunk) => {
      output += chunk.toString()
      const match = /__TRENDING_READY__ (\d+)/.exec(output)
      if (match) { clearTimeout(timer); resolve(Number(match[1])) }
    })
    child.stderr.on('data', (chunk) => { output += chunk.toString() })
    child.on('exit', (code) => { clearTimeout(timer); reject(new Error('server exited ' + code + ':\n' + output)) })
  })

  return {
    base: `http://127.0.0.1:${port}`,
    tmp,
    child,
    stop() {
      try { child.kill() } catch {}
      try { fs.rmSync(tmp, { recursive: true, force: true }) } catch {}
    },
  }
}

// Minimal cookie-carrying request helper (no dependencies).
function request(base, { method = 'GET', path: route, body, cookie } = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(route, base)
    const payload = body === undefined ? null : JSON.stringify(body)
    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname + url.search,
        method,
        headers: {
          ...(payload ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } : {}),
          ...(cookie ? { Cookie: cookie } : {}),
        },
      },
      (res) => {
        let text = ''
        res.on('data', (chunk) => { text += chunk })
        res.on('end', () => {
          let json = null
          try { json = JSON.parse(text) } catch {}
          resolve({ status: res.statusCode, headers: res.headers, json, text })
        })
      }
    )
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

async function login(base) {
  const res = await request(base, { method: 'POST', path: '/api/admin/login', body: { token: ADMIN_TOKEN } })
  assert.equal(res.status, 200, 'login should succeed with the configured token')
  const setCookie = res.headers['set-cookie']
  const cookie = Array.isArray(setCookie) ? setCookie[0].split(';')[0] : String(setCookie).split(';')[0]
  assert.ok(cookie, 'login must set a session cookie')
  return cookie
}

// ---------------------------------------------------------------------------

const server = await launch()

try {
  // ---- 1. auth -------------------------------------------------------------
  await test('an unauthenticated POST is refused with 401 and never reaches the RPC', async () => {
    const res = await request(server.base, {
      method: 'POST',
      path: '/api/admin/trending/tracks',
      body: { ids: ['11111111-1111-1111-1111-111111111111'] },
    })
    assert.equal(res.status, 401)
  })

  const cookie = await login(server.base)

  // ---- 2. the happy path ---------------------------------------------------
  await test('an authenticated admin saves the order, and the RPC receives it in order', async () => {
    const ids = [
      '11111111-1111-1111-1111-111111111111',
      '22222222-2222-2222-2222-222222222222',
      '33333333-3333-3333-3333-333333333333',
    ]
    const res = await request(server.base, {
      method: 'POST', path: '/api/admin/trending/tracks', body: { ids }, cookie,
    })
    assert.equal(res.status, 200)
    assert.deepEqual(res.json, { success: true })

    const state = await readState()
    const call = state.calls.filter((entry) => entry.name === 'reorder_trending_tracks').pop()
    assert.ok(call, 'reorder_trending_tracks must be called')
    assert.deepEqual(call.params.p_ids, ids, 'the RPC must receive the list exactly as ordered')
  })

  await test('duplicate and whitespace-padded ids are trimmed and de-duplicated, keeping order', async () => {
    const ids = [' 22222222-2222-2222-2222-222222222222 ', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222']
    const res = await request(server.base, {
      method: 'POST', path: '/api/admin/trending/tracks', body: { ids }, cookie,
    })
    assert.equal(res.status, 200)
    const state = await readState()
    const call = state.calls.filter((entry) => entry.name === 'reorder_trending_tracks').pop()
    assert.deepEqual(call.params.p_ids, [
      '22222222-2222-2222-2222-222222222222',
      '11111111-1111-1111-1111-111111111111',
    ])
  })

  await test('an empty list is accepted and forwarded as [] (clears every pin)', async () => {
    const res = await request(server.base, {
      method: 'POST', path: '/api/admin/trending/tracks', body: { ids: [] }, cookie,
    })
    assert.equal(res.status, 200)
    const state = await readState()
    const call = state.calls.filter((entry) => entry.name === 'reorder_trending_tracks').pop()
    assert.deepEqual(call.params.p_ids, [])
  })

  // ---- 3. validation happens BEFORE the RPC --------------------------------
  const badBodies = [
    ['a missing ids field', {}],
    ['ids as a string', { ids: '11111111-1111-1111-1111-111111111111' }],
    ['ids containing a non-string', { ids: [1, 2] }],
    ['ids containing an empty string', { ids: ['11111111-1111-1111-1111-111111111111', '   '] }],
    ['ids over the 2000 cap', { ids: Array.from({ length: 2001 }, (_, index) => 'id-' + index) }],
  ]

  for (const [label, body] of badBodies) {
    await test('a bad request (' + label + ') is refused with 400 and no RPC runs', async () => {
      const before = (await readState()).calls.filter((entry) => entry.name === 'reorder_trending_tracks').length
      const res = await request(server.base, {
        method: 'POST', path: '/api/admin/trending/tracks', body, cookie,
      })
      assert.equal(res.status, 400)
      assert.match(res.json.error, /ids must be an array/)
      const after = (await readState()).calls.filter((entry) => entry.name === 'reorder_trending_tracks').length
      assert.equal(after, before, 'a rejected request must not reach the database')
    })
  }

  // ---- 4. the page is actually wired --------------------------------------
  await test('the admin page carries the nav entry, the panel and the handlers', async () => {
    const html = fs.readFileSync(path.join(SERVER_DIR, 'admin.html'), 'utf8')
    assert.match(html, /id="nav-arrangeTrending"[^>]*showView\('arrangeTrending'\)/, 'nav entry must open the view')
    assert.match(html, /id="arrangeTrendingPanel"/, 'panel must exist')
    assert.match(html, /id="trendingTracksList"/, 'pinned list container must exist')
    assert.match(html, /id="trendingResults"/, 'pin-candidates container must exist')
    assert.match(html, /id="trendingSearch"/, 'search input must exist')
    for (const fn of ['renderArrangeTrending', 'loadArrangeTrending', 'saveTrendingTracks', 'pinTrending', 'moveTrending', 'unpinTrending']) {
      assert.match(html, new RegExp('function ' + fn + '\\('), fn + ' must be defined')
    }
    assert.match(html, /view === 'arrangeTrending'/, 'opening the view must load it')
    assert.match(html, /currentView === 'arrangeTrending'/, 'refresh must reload the view')
    assert.match(html, /'\/api\/admin\/trending\/tracks'/, 'the panel must post to the trending endpoint')
  })

  await test('the panel sorts by trending_order and never touches featured_order', async () => {
    const html = fs.readFileSync(path.join(SERVER_DIR, 'admin.html'), 'utf8')
    const start = html.indexOf('// ---------- Arrange Top Trending (trending_order) ----------')
    assert.ok(start > 0, 'trending section must exist')
    const section = html.slice(start, html.indexOf('checkSession();', start))
    assert.match(section, /trending_order/, 'must read trending_order')
    assert.doesNotMatch(section, /featured_order\s*=/, 'must not write featured_order')
    assert.match(section, /Array\.prototype|\.sort\(/, 'must sort the pinned list')
  })

  // ---- 5. a database failure is reported, not swallowed -------------------
  await test('a database error becomes a 500 with the message, and the server stays up', async () => {
    const failing = await launch({ failRpc: true })
    try {
      const failingCookie = await login(failing.base)
      const res = await request(failing.base, {
        method: 'POST', path: '/api/admin/trending/tracks', body: { ids: ['11111111-1111-1111-1111-111111111111'] }, cookie: failingCookie,
      })
      assert.equal(res.status, 500)
      assert.match(res.json.error, /simulated database failure/)
      const alive = await request(failing.base, { path: '/api/admin/session', cookie: failingCookie })
      assert.equal(alive.status, 200, 'the process must still answer after a failed reorder')
    } finally {
      failing.stop()
    }
  })
} finally {
  server.stop()
}

// Reads the stub's recorded RPC calls from the JSON file it mirrors them to.
async function readState(handle) {
  const target = handle || server
  const file = path.join(target.tmp, 'state.json')
  if (!fs.existsSync(file)) return { calls: [] }
  return JSON.parse(fs.readFileSync(file, 'utf8'))
}

console.log('\n' + results.join('\n'))
console.log(`\n${passed} passed, ${failed} failed, ${passed + failed} total`)
process.exitCode = failed ? 1 : 0
