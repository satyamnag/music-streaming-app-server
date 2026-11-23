/**
 * HTTP contract for the affiliate/referral admin endpoints (migration 047).
 *
 * These endpoints expose per-customer revenue data, so the ONLY thing this file
 * asserts is that they are closed: without an admin session every one of them
 * must refuse. The SQL behaviour behind them is covered by
 * test/affiliate_admin.test.sql, which runs against a real PostgreSQL.
 *
 * Run: node test/partner-stub-register.mjs test/admin-referrals.e2e.mjs
 */

process.env.SUPABASE_URL = 'https://stub.supabase.co'
process.env.SUPABASE_SERVICE_KEY = 'stub-service-key'
process.env.PORT = '0'

import { resetStub } from './supabase-stub.mjs'

resetStub()

await import('../server.js')

await (async () => {
  for (let i = 0; i < 120; i++) {
    if (global.__SERVER_PORT) return
    await new Promise((r) => setTimeout(r, 50))
  }
  throw new Error('server did not start listening in time')
})()

const BASE = `http://127.0.0.1:${global.__SERVER_PORT}`

let pass = 0
let fail = 0
function check(name, cond) {
  if (cond) {
    pass++
    console.log('  PASS ' + name)
  } else {
    fail++
    console.log('  FAIL ' + name)
  }
}

const cases = [
  ['GET /api/admin/referrals', { method: 'GET', path: '/api/admin/referrals' }],
  ['GET /api/admin/referrals/:id', { method: 'GET', path: '/api/admin/referrals/user_abc' }],
  [
    'POST /api/admin/referrals/sync-directory',
    { method: 'POST', path: '/api/admin/referrals/sync-directory', body: '{}' },
  ],
  [
    'POST /api/admin/referrals/order',
    {
      method: 'POST',
      path: '/api/admin/referrals/order',
      body: JSON.stringify({
        referred_user_id: 'user_abc',
        order_id: 'GPA.test',
        product_id: 'soulful_yearly',
        rail: 'play',
      }),
    },
  ],
]

for (const [label, req] of cases) {
  const res = await fetch(BASE + req.path, {
    method: req.method,
    headers: req.body ? { 'Content-Type': 'application/json' } : undefined,
    body: req.body,
  })
  // 401 = no session; 503 = ADMIN_TOKEN not configured in this deployment.
  check(`${label} refuses an unauthenticated caller (${res.status})`, res.status === 401 || res.status === 503)
}

console.log(`\n${pass} passed, ${fail} failed`)
await new Promise((r) => setTimeout(r, 250))
process.exit(fail > 0 ? 1 : 0)
