/**
 * End-to-end test for the Razorpay webhook route.
 *
 * Boots the REAL Express app from server.js against the stub Supabase client,
 * then drives POST /api/razorpay/webhook over HTTP. What this proves that the
 * unit tests cannot:
 *
 *   - the route is registered BEFORE express.json(), so req.body is still the
 *     raw Buffer the HMAC needs (if the order regresses, test 2 fails);
 *   - initRazorpay() picks the configuration up from the environment;
 *   - a verified event is persisted with the owner taken from `notes`;
 *   - a retried delivery is deduped by x-razorpay-event-id;
 *   - a later event that omits `notes` still updates the right row;
 *   - an event for an unknown subscription is acknowledged but stores nothing.
 *
 * Run: node test/partner-stub-register.mjs test/razorpay-webhook.e2e.mjs
 */

import crypto from 'node:crypto'
import { db, resetStub } from './supabase-stub.mjs'

process.env.SUPABASE_URL = 'https://stub.supabase.co'
process.env.SUPABASE_SERVICE_KEY = 'stub-service-key'
process.env.RAZORPAY_KEY_ID = 'rzp_test_key_id'
process.env.RAZORPAY_KEY_SECRET = 'test_key_secret_do_not_use'
process.env.RAZORPAY_WEBHOOK_SECRET = 'test_webhook_secret_do_not_use'
process.env.RAZORPAY_PLAN_MONTHLY = 'plan_MonthlyTest'
process.env.RAZORPAY_PLAN_YEARLY = 'plan_YearlyTest'
process.env.PORT = '0'

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
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET

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

function sign(body) {
  return crypto.createHmac('sha256', WEBHOOK_SECRET).update(body).digest('hex')
}

async function postWebhook(eventId, body, { signature, contentType = 'application/json' } = {}) {
  const res = await fetch(`${BASE}/api/razorpay/webhook`, {
    method: 'POST',
    headers: {
      'Content-Type': contentType,
      'x-razorpay-signature': signature === undefined ? sign(body) : signature,
      'x-razorpay-event-id': eventId,
    },
    body,
  })
  const text = await res.text()
  let json = null
  try {
    json = JSON.parse(text)
  } catch {
    json = null
  }
  return { status: res.status, json }
}

function subscriptionEvent(name, entity) {
  return JSON.stringify({
    event: name,
    created_at: Math.floor(Date.now() / 1000),
    payload: { subscription: { entity } },
  })
}

const SUB = {
  id: 'sub_Test00000001',
  plan_id: 'plan_MonthlyTest',
  status: 'active',
  quantity: 1,
  total_count: 120,
  paid_count: 1,
  current_start: 1735689600, // 2025-01-01T00:00:00Z
  current_end: 1738368000, // 2025-02-01T00:00:00Z
  short_url: 'https://rzp.io/i/test',
  notes: { user_id: 'user_2testUser' },
}

// ------------------------------------------------------------------
console.log('webhook ordering / configuration')
{
  // A non-JSON content type is not parsed by express.raw(), so the handler
  // sees no Buffer body. A 400 here is the honest answer; the point of the
  // test is that the route exists before the global JSON parser.
  const res = await postWebhook('evt_probe', JSON.stringify({ event: 'probe' }), {
    contentType: 'text/plain',
  })
  check('route exists and rejects a non-raw body', res.status === 400)
}

// ------------------------------------------------------------------
console.log('signature enforcement')
{
  resetStub()
  const body = subscriptionEvent('subscription.charged', SUB)
  const res = await postWebhook('evt_bad_sig', body, { signature: 'deadbeef' })
  check('bad signature rejected', res.status === 400)
  check('nothing stored for a bad signature', db.razorpay_subscriptions.size === 0)
}

// ------------------------------------------------------------------
console.log('first verified event')
{
  resetStub()
  const body = subscriptionEvent('subscription.charged', SUB)
  const res = await postWebhook('evt_first', body)
  check('accepted with 200', res.status === 200 && res.json?.status === 'ok')

  const rows = Array.from(db.razorpay_subscriptions.values())
  check('exactly one subscription row stored', rows.length === 1)

  const row = rows[0]
  check('owner taken from notes.user_id', row.user_id === 'user_2testUser')
  check('plan slug resolved from plan_id', row.plan_slug === 'monthly')
  check('status stored', row.status === 'active')
  check('current_end converted from epoch seconds',
    row.current_end === new Date(1738368000 * 1000).toISOString())
  check('event id recorded on the row', row.last_event_id === 'evt_first')
  check(
    'webhook event logged for dedupe',
    Array.from(db.razorpay_webhook_events.values()).some((r) => r.event_id === 'evt_first'),
  )
}

// ------------------------------------------------------------------
console.log('idempotency')
{
  const body = subscriptionEvent('subscription.charged', SUB)
  const res = await postWebhook('evt_first', body)
  check('replayed event acknowledged as duplicate', res.status === 200 && res.json?.status === 'duplicate')
  check('replay did not create a second row', db.razorpay_subscriptions.size === 1)
}

// ------------------------------------------------------------------
console.log('later event without notes still updates the right row')
{
  const cancelled = { ...SUB, status: 'cancelled', notes: undefined }
  const body = subscriptionEvent('subscription.cancelled', cancelled)
  const res = await postWebhook('evt_cancelled', body)
  check('accepted', res.status === 200)

  const row = Array.from(db.razorpay_subscriptions.values())[0]
  check('owner preserved from the stored row', row.user_id === 'user_2testUser')
  check('status updated to cancelled', row.status === 'cancelled')
  check('still one row (updated, not inserted)', db.razorpay_subscriptions.size === 1)
}

// ------------------------------------------------------------------
console.log('unattributable event')
{
  const orphan = { ...SUB, id: 'sub_Orphan000001', notes: undefined }
  const body = subscriptionEvent('subscription.charged', orphan)
  const res = await postWebhook('evt_orphan', body)
  check('acknowledged so Razorpay stops retrying', res.status === 200)
  check('no row stored for an unknown owner', db.razorpay_subscriptions.size === 1)
}

// ------------------------------------------------------------------
console.log('')
console.log(`  ${pass} passed, ${fail} failed`)
// Let the in-flight undici sockets settle before tearing the process down;
// exiting mid-flight trips a libuv assertion on Windows.
await new Promise((r) => setTimeout(r, 250))
process.exit(fail > 0 ? 1 : 0)
