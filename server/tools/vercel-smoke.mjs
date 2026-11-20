// Smoke test for a deployed admin server. Works against any base URL, so it can
// validate a Vercel preview deployment before DNS is touched, and re-validate
// production afterwards.
//
//   node server/tools/vercel-smoke.mjs https://admin.soulfulbhakti.com
//   node server/tools/vercel-smoke.mjs https://<project>.vercel.app
//
// Read-only: no admin token needed and nothing is written. The one POST carries
// no session, so it must be refused, which is exactly what is asserted.
import process from 'node:process'

const base = (process.argv[2] || '').replace(/\/+$/, '')
if (!/^https?:\/\//.test(base)) {
  console.error('usage: node server/tools/vercel-smoke.mjs <base-url>')
  process.exit(2)
}

let pass = 0
let fail = 0
const failures = []

function check(name, ok, detail) {
  if (ok) { pass++; console.log(`  PASS  ${name}${detail ? ' - ' + detail : ''}`) }
  else { fail++; failures.push(name + (detail ? ' - ' + detail : '')); console.log(`  FAIL  ${name}${detail ? ' - ' + detail : ''}`) }
}

async function get(path) {
  const response = await fetch(base + path, { redirect: 'manual' })
  const text = await response.text()
  return { status: response.status, text, headers: response.headers }
}

console.log(`smoke testing ${base}\n`)

// 1. The panel itself must render, and be the CURRENT build: these markers come
// from features added late, so an older deployment fails here rather than
// looking fine on a bare 200.
const admin = await get('/admin')
check('/admin answers 200', admin.status === 200, `status ${admin.status}`)
check('/admin serves the SRT Maker panel', /Song Sync Lyrics SRT Maker/.test(admin.text), `${admin.text.length} bytes`)
check('/admin serves the voice graph', /ssNoteChip/.test(admin.text))
check('/admin serves the trending arranger', /trendingTracksList/.test(admin.text))

const partner = await get('/partner')
check('/partner answers 200', partner.status === 200, `status ${partner.status}`)
check('/partner serves the portal', /Soulful Bhakti Partner Program/.test(partner.text))
check('/partner keeps Aadhaar out', /We do not accept Aadhaar/.test(partner.text))

// 2. Auth boundary. A read that must be refused and a write that must be
// refused, plus the session probe the panel uses on load.
const session = await get('/api/admin/session')
check('/api/admin/session answers 200', session.status === 200, `status ${session.status}`)
let sessionJson = null
try { sessionJson = JSON.parse(session.text) } catch {}
check('/api/admin/session returns JSON', sessionJson !== null)
check('/api/admin/session is unauthenticated without a cookie', sessionJson && sessionJson.authenticated === false,
  sessionJson ? `authenticated=${sessionJson.authenticated}` : 'unparseable')

const tracks = await get('/api/admin/tracks')
check('/api/admin/tracks is guarded (401)', tracks.status === 401, `status ${tracks.status}`)

const trending = await fetch(base + '/api/admin/trending/tracks', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ ids: [] }),
})
check('/api/admin/trending/tracks is guarded (401)', trending.status === 401, `status ${trending.status}`)

// 3. The login route must reject a wrong token with 401 rather than 500. This
// proves the route reached its comparison, which means the secret is loaded and
// the body parser works, without needing the real token.
const badLogin = await fetch(base + '/api/admin/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ token: 'definitely-not-the-token' }),
})
check('/api/admin/login rejects a wrong token with 401', badLogin.status === 401, `status ${badLogin.status}`)

// 4. The partner API surface must be guarded too.
const partnerMe = await get('/api/partner/me')
check('/api/partner/me is guarded (401)', partnerMe.status === 401, `status ${partnerMe.status}`)

console.log(`\n=== ${pass} passed, ${fail} failed ===`)
if (fail) {
  console.log('failures:')
  for (const item of failures) console.log('  - ' + item)
}
process.exitCode = fail ? 1 : 0
