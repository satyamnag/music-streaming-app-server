/**
 * End-to-end test for the Superwall API sync (migration 046, self-heal).
 *
 * Boots the REAL Express app from server.js against the stub Supabase client
 * and a LOCAL mock of api.superwall.com, then drives POST /api/superwall/webhook
 * (Svix-signed). What this proves:
 *
 *   - before crediting a referred Play purchase, the server asks Superwall for
 *     the REFERRER's Play state and upserts it (pre-migration backfill);
 *   - non-Play (App Store) rows from the API are ignored;
 *   - the sync is throttled (one Superwall call per referrer);
 *   - a 401 from Superwall fails open: the webhook is still acknowledged and
 *     the referral credit is still attempted with the existing state;
 *   - a slow Superwall response aborts at the timeout and fails open.
 *
 * Run: node test/partner-stub-register.mjs test/superwall-api-sync.e2e.mjs
 */

import crypto from 'node:crypto'
import http from 'node:http'
import { db, state, resetStub } from './supabase-stub.mjs'

process.env.SUPABASE_URL = 'https://stub.supabase.co'
process.env.SUPABASE_SERVICE_KEY = 'stub-service-key'
process.env.SUPERWALL_WEBHOOK_SECRET =
  'whsec_' + Buffer.from('test-superwall-webhook-secret-32b!!').toString('base64')
process.env.SUPERWALL_API_KEY = 'test-superwall-api-key'
process.env.SUPERWALL_APPLICATION_ID = 'app_test_1'
process.env.SUPERWALL_API_TIMEOUT_MS = '200'
process.env.PORT = '0'

// --- Local mock of api.superwall.com ---------------------------------------
const mock = { requests: [], mode: 'ok' }
const mockServer = http.createServer((req, res) => {
  const m = /^\/v3\/users\/([^/]+)\/subscriptions/.exec(req.url || '')
  if (!m) {
    res.writeHead(404, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ error: 'not found' }))
    return
  }
  mock.requests.push({ userId: decodeURIComponent(m[1]), auth: req.headers.authorization })
  if (mock.mode === '401') {
    res.writeHead(401, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ error: 'unauthorized' }))
    return
  }
  if (mock.mode === 'slow') {
    setTimeout(() => {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify(subscriptionsFixture(decodeURIComponent(m[1]))))
    }, 1500)
    return
  }
  res.writeHead(200, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify(subscriptionsFixture(decodeURIComponent(m[1]))))
})
await new Promise((resolve) => mockServer.listen(0, '127.0.0.1', resolve))
process.env.SUPERWALL_API_BASE_URL = `http://127.0.0.1:${mockServer.address().port}`

function subscriptionsFixture(userId) {
  return {
    object: 'user_subscriptions',
    app_user_id: userId,
    data: [
      {
        subscription_id: 'sub_play_1',
        product_id: 'soulful_yearly',
        product_type: 'autorenewable',
        store: 'PLAY_STORE',
        transaction_id: 'GPA.1',
        state: 'active',
        is_active: true,
        is_lifetime: false,
        will_renew: true,
        offer_type: null,
        starts_at: '2026-01-01T00:00:00Z',
        renewed_at: null,
        expires_at: '2027-01-01T00:00:00Z',
        original_purchase_date: '2026-01-01T00:00:00Z',
        amount: 120,
        currency: 'INR',
        invoice_id: null,
        invoice_url: null,
        metadata: null,
      },
      {
        // Non-Play store row: must be ignored by the sync.
        subscription_id: 'sub_appstore_1',
        product_id: 'premium.monthly',
        product_type: 'autorenewable',
        store: 'APP_STORE',
        transaction_id: 'AS.1',
        state: 'active',
        is_active: true,
        is_lifetime: false,
        will_renew: true,
        offer_type: null,
        starts_at: '2026-01-01T00:00:00Z',
        renewed_at: null,
        expires_at: '2026-02-01T00:00:00Z',
        original_purchase_date: '2026-01-01T00:00:00Z',
        amount: 9.99,
        currency: 'USD',
        invoice_id: null,
        invoice_url: null,
        metadata: null,
      },
    ],
  }
}

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
const SECRET = Buffer.from(process.env.SUPERWALL_WEBHOOK_SECRET.split('_')[1], 'base64')

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

function svixHeaders(body) {
  const id = 'msg_' + crypto.randomBytes(8).toString('hex')
  const ts = String(Math.floor(Date.now() / 1000))
  const signed = `${id}.${ts}.${body}`
  const sig = crypto.createHmac('sha256', SECRET).update(signed).digest('base64')
  return {
    'Content-Type': 'application/json',
    'svix-id': id,
    'svix-timestamp': ts,
    'svix-signature': `v1,${sig}`,
  }
}

async function postEvent(data) {
  const body = JSON.stringify(data)
  return fetch(`${BASE}/api/superwall/webhook`, {
    method: 'POST',
    headers: svixHeaders(body),
    body,
  })
}

function event(purchaser, id) {
  return {
    object: 'event',
    type: 'initial_purchase',
    timestamp: Date.now(),
    data: {
      id,
      name: 'initial_purchase',
      store: 'PLAY_STORE',
      environment: 'PRODUCTION',
      productId: 'soulful_yearly',
      price: 1.49,
      priceInPurchasedCurrency: 120,
      periodType: 'NORMAL',
      originalAppUserId: purchaser,
      purchasedAt: Date.now() - 1000,
      expirationAt: Date.now() + 30 * 24 * 3600 * 1000,
      ts: Date.now(),
    },
  }
}

function rpcCalls(name) {
  return state.rpcLog.filter((c) => c.name === name)
}

function addAttribution(id, referrer, referred) {
  db.referral_attributions.set(id, {
    id,
    code: 'SBAPI0001',
    referrer_user_id: referrer,
    referred_user_id: referred,
  })
}

// ------------------------------------------------------------------
// 1. Referrer self-heal BEFORE the credit: the server asks Superwall for the
//    referrer and writes the Play row, then attempts the credit.
// ------------------------------------------------------------------
{
  addAttribution('att1', 'user_ref_play', 'user_friend1')
  const res = await postEvent(event('user_friend1', 'evt_sync_1'))
  check('1a: purchase webhook acknowledged (200)', res.status === 200)

  const askedFor = mock.requests.filter((r) => r.userId === 'user_ref_play')
  check('1b: Superwall asked for the REFERRER', askedFor.length === 1)
  check(
    '1c: API call carried the bearer key',
    askedFor[0]?.auth === `Bearer ${process.env.SUPERWALL_API_KEY}`,
  )

  const refUpserts = rpcCalls('play_subscription_upsert').filter(
    (c) => c.params?.p_user_id === 'user_ref_play',
  )
  check(
    '1d: referrer Play row upserted from the API (active, api_sync)',
    refUpserts.length === 1 &&
      refUpserts[0].params?.p_status === 'active' &&
      refUpserts[0].params?.p_last_event_name === 'api_sync' &&
      refUpserts[0].params?.p_product_id === 'soulful_yearly',
  )

  const upsertIdx = state.rpcLog.indexOf(refUpserts[0])
  const creditIdx = state.rpcLog.findIndex(
    (c) => c.name === 'credit_referral_commission' && c.params?.p_referred_user_id === 'user_friend1',
  )
  check('1e: referrer state is written BEFORE the credit is attempted', creditIdx > upsertIdx)
}

// ------------------------------------------------------------------
// 2. Throttle: a second purchase by another friend does not re-ask Superwall
//    for the same referrer.
// ------------------------------------------------------------------
{
  addAttribution('att2', 'user_ref_play', 'user_friend2')
  const res = await postEvent(event('user_friend2', 'evt_sync_2'))
  check('2a: second purchase webhook acknowledged (200)', res.status === 200)
  check(
    '2b: referrer sync throttled (still one Superwall request)',
    mock.requests.filter((r) => r.userId === 'user_ref_play').length === 1,
  )
}

// ------------------------------------------------------------------
// 3. Fail-open on 401: the webhook is acknowledged and the credit still runs
//    with the state the database already has.
// ------------------------------------------------------------------
{
  mock.mode = '401'
  addAttribution('att3', 'user_ref_bad', 'user_friend3')
  const res = await postEvent(event('user_friend3', 'evt_sync_3'))
  check('3a: 401 from Superwall does not break the webhook (200)', res.status === 200)
  check(
    '3b: credit still attempted for the purchase',
    rpcCalls('credit_referral_commission').some(
      (c) => c.params?.p_referred_user_id === 'user_friend3',
    ),
  )
  mock.mode = 'ok'
}

// ------------------------------------------------------------------
// 4. Fail-open on timeout: a slow Superwall answer aborts at the configured
//    timeout and the webhook is still acknowledged.
// ------------------------------------------------------------------
{
  mock.mode = 'slow'
  addAttribution('att4', 'user_ref_slow', 'user_friend4')
  const started = Date.now()
  const res = await postEvent(event('user_friend4', 'evt_sync_4'))
  const elapsed = Date.now() - started
  check('4a: slow sync does not break the webhook (200)', res.status === 200)
  check('4b: webhook finished well under the mock delay (aborted)', elapsed < 1200)
  check(
    '4c: credit still attempted for the purchase',
    rpcCalls('credit_referral_commission').some(
      (c) => c.params?.p_referred_user_id === 'user_friend4',
    ),
  )
  mock.mode = 'ok'
}

console.log(`\n${pass} passed, ${fail} failed`)
// Let the in-flight undici sockets settle before tearing the process down;
// exiting mid-flight trips a libuv assertion on Windows (same convention as
// razorpay-webhook.e2e.mjs).
await new Promise((r) => setTimeout(r, 250))
mockServer.close()
process.exit(fail > 0 ? 1 : 0)
