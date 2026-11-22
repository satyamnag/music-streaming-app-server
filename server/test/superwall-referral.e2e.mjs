/**
 * End-to-end test for the Superwall webhook route with the Play rail
 * (migration 046 wiring).
 *
 * Boots the REAL Express app from server.js against the stub Supabase client,
 * then drives POST /api/superwall/webhook over HTTP. What this proves that the
 * SQL test cannot:
 *
 *   - a verified initial_purchase for a Clerk user persists play state AND
 *     still falls through to the referral credit RPC;
 *   - a cancellation persists state even though it never earns commission;
 *   - a negative-price event persists as 'refunded';
 *   - anonymous (non-Clerk) users are never persisted;
 *   - sandbox events are dropped unless SUPERWALL_ALLOW_SANDBOX=1;
 *   - a tampered or missing Svix signature is refused with 400.
 *
 * Run: node test/partner-stub-register.mjs test/superwall-referral.e2e.mjs
 */

import crypto from 'node:crypto'
import { state, resetStub } from './supabase-stub.mjs'

process.env.SUPABASE_URL = 'https://stub.supabase.co'
process.env.SUPABASE_SERVICE_KEY = 'stub-service-key'
process.env.SUPERWALL_WEBHOOK_SECRET =
  'whsec_' + Buffer.from('test-superwall-webhook-secret-32b!!').toString('base64')
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

async function postEvent(data, headers) {
  const body = JSON.stringify(data)
  const res = await fetch(`${BASE}/api/superwall/webhook`, {
    method: 'POST',
    headers: headers === undefined ? svixHeaders(body) : headers,
    body,
  })
  return res
}

function rpcCalls(name) {
  return state.rpcLog.filter((c) => c.name === name)
}

function event(overrides = {}) {
  return {
    object: 'event',
    type: 'initial_purchase',
    timestamp: Date.now(),
    data: {
      id: 'evt_e2e_' + crypto.randomBytes(6).toString('hex'),
      name: 'initial_purchase',
      store: 'PLAY_STORE',
      environment: 'PRODUCTION',
      productId: 'soulful_yearly',
      price: 1.49,
      priceInPurchasedCurrency: 120,
      periodType: 'NORMAL',
      originalAppUserId: 'user_e2e_purchaser',
      purchasedAt: Date.now() - 1000,
      expirationAt: Date.now() + 30 * 24 * 3600 * 1000,
      ts: Date.now(),
      ...overrides,
    },
  }
}

// ------------------------------------------------------------------
// 1. initial_purchase persists ACTIVE state AND reaches the referral credit.
// ------------------------------------------------------------------
{
  const data = event()
  const res = await postEvent(data)
  check('1a: verified initial_purchase is acknowledged (200)', res.status === 200)

  const upserts = rpcCalls('play_subscription_upsert')
  const last = upserts[upserts.length - 1]
  check(
    '1b: play state persisted with status=active for the Clerk user',
    last?.params?.p_user_id === 'user_e2e_purchaser' &&
      last?.params?.p_product_id === 'soulful_yearly' &&
      last?.params?.p_status === 'active',
  )
  check(
    '1c: referral credit still attempted for the purchase',
    rpcCalls('credit_referral_commission').some(
      (c) => c.params?.p_referred_user_id === 'user_e2e_purchaser',
    ),
  )
}

// ------------------------------------------------------------------
// 2. cancellation persists CANCELLED state and never earns commission.
// ------------------------------------------------------------------
{
  const before = rpcCalls('credit_referral_commission').length
  const data = event({
    id: 'evt_e2e_cancel',
    name: 'cancellation',
    type: 'cancellation',
    price: 0,
    originalAppUserId: 'user_e2e_purchaser',
  })
  const res = await postEvent(data)
  check('2a: cancellation acknowledged (200)', res.status === 200)

  const upserts = rpcCalls('play_subscription_upsert')
  const last = upserts[upserts.length - 1]
  check(
    '2b: play state persisted with status=cancelled',
    last?.params?.p_user_id === 'user_e2e_purchaser' && last?.params?.p_status === 'cancelled',
  )
  check(
    '2c: cancellation attempted no referral credit',
    rpcCalls('credit_referral_commission').length === before,
  )
}

// ------------------------------------------------------------------
// 3. A negative-price event persists REFUNDED (never stays active).
// ------------------------------------------------------------------
{
  const data = event({
    id: 'evt_e2e_refund',
    name: 'initial_purchase',
    price: -1.49,
    originalAppUserId: 'user_e2e_purchaser',
  })
  const res = await postEvent(data)
  check('3a: refund event acknowledged (200)', res.status === 200)
  const upserts = rpcCalls('play_subscription_upsert')
  const last = upserts[upserts.length - 1]
  check('3b: refund persisted with status=refunded', last?.params?.p_status === 'refunded')
}

// ------------------------------------------------------------------
// 4. Anonymous (non-Clerk) users are never persisted.
// ------------------------------------------------------------------
{
  const before = rpcCalls('play_subscription_upsert').length
  const data = event({
    id: 'evt_e2e_anon',
    originalAppUserId: '$SuperwallAlias:44409AAF-244D-9F08-A18A-8F66B52FDZ01',
  })
  const res = await postEvent(data)
  check('4a: anonymous-user event acknowledged (200)', res.status === 200)
  check(
    '4b: no play state row written for an anonymous user',
    rpcCalls('play_subscription_upsert').length === before,
  )
}

// ------------------------------------------------------------------
// 5. Sandbox events are dropped (state and commission).
// ------------------------------------------------------------------
{
  const beforeState = rpcCalls('play_subscription_upsert').length
  const beforeCredit = rpcCalls('credit_referral_commission').length
  const data = event({
    id: 'evt_e2e_sandbox',
    environment: 'SANDBOX',
    originalAppUserId: 'user_e2e_purchaser',
  })
  const res = await postEvent(data)
  check('5a: sandbox event acknowledged (200)', res.status === 200)
  check(
    '5b: sandbox purchase persists nothing',
    rpcCalls('play_subscription_upsert').length === beforeState &&
      rpcCalls('credit_referral_commission').length === beforeCredit,
  )
}

// ------------------------------------------------------------------
// 6. A tampered signature is refused, a missing one too.
// ------------------------------------------------------------------
{
  const body = JSON.stringify(event())
  const good = svixHeaders(body)
  const res = await postEvent(JSON.parse(body), {
    'Content-Type': 'application/json',
    ...good,
    'svix-signature': 'v1,' + Buffer.from('wrong-signature-bytes-wrong-signature').toString('base64'),
  })
  check('6a: tampered Svix signature refused (400)', res.status === 400)

  const res2 = await postEvent(JSON.parse(body), { 'Content-Type': 'application/json' })
  check('6b: missing Svix headers refused (400)', res2.status === 400)
}

// ------------------------------------------------------------------
// 7. Non-Play stores persist nothing.
// ------------------------------------------------------------------
{
  const before = rpcCalls('play_subscription_upsert').length
  const data = event({ id: 'evt_e2e_stripe', store: 'STRIPE' })
  const res = await postEvent(data)
  check('7a: Stripe event acknowledged (200)', res.status === 200)
  check(
    '7b: non-Play store persists no play row',
    rpcCalls('play_subscription_upsert').length === before,
  )
}

console.log(`\n${pass} passed, ${fail} failed`)
// Let the in-flight undici sockets settle before tearing the process down;
// exiting mid-flight trips a libuv assertion on Windows (same convention as
// razorpay-webhook.e2e.mjs).
await new Promise((r) => setTimeout(r, 250))
process.exit(fail > 0 ? 1 : 0)
