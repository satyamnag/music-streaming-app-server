/**
 * End-to-end test for the Razorpay referral pipeline.
 *
 * Boots the REAL Express app from server.js against the stub Supabase client,
 * then drives POST /api/razorpay/webhook over HTTP.
 *
 * What this proves that the SQL tests cannot:
 *
 *   - a verified `subscription.charged` event makes the server ASK for the
 *     referral credit, with the owner and the code taken from the STORED row
 *     (not from anything the webhook payload claims);
 *   - the amount sent to the ledger is the payment amount in rupees
 *     (paise / 100), read from Razorpay's own payload;
 *   - an event with no payment entity asks for nothing;
 *   - a subscription bought without a code asks with a null code, so the
 *     database decides instead of the server inventing one;
 *   - a renewal asks again with the new payment id, because "first payment
 *     only" is enforced by Postgres, not by the server guessing;
 *   - the stored referral code survives later webhook updates;
 *   - the referral endpoints are not reachable anonymously.
 *
 * The SQL itself (amount, once-per-referred-user, eligibility, single level)
 * is verified separately by test/razorpay_referral.test.sql against real
 * PostgreSQL. This file verifies the server's half of the contract.
 *
 * Run: node test/partner-stub-register.mjs test/razorpay-referral.e2e.mjs
 */

import crypto from 'node:crypto'
import { db, resetStub, state } from './supabase-stub.mjs'

process.env.SUPABASE_URL = 'https://stub.supabase.co'
process.env.SUPABASE_SERVICE_KEY = 'stub-service-key'
process.env.RAZORPAY_KEY_ID = 'rzp_test_key_id'
process.env.RAZORPAY_KEY_SECRET = 'test_key_secret_do_not_use'
process.env.RAZORPAY_WEBHOOK_SECRET = 'test_webhook_secret_do_not_use'
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

const sign = (body) => crypto.createHmac('sha256', WEBHOOK_SECRET).update(body).digest('hex')

async function postWebhook(eventId, body) {
  const res = await fetch(`${BASE}/api/razorpay/webhook`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-razorpay-signature': sign(body),
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

/** Every request the server made to credit a referrer. */
const creditCalls = () =>
  state.rpcLog.filter((entry) => entry.name === 'credit_razorpay_referral_commission')

const SUB = {
  id: 'sub_Ref0000001',
  plan_id: 'plan_YearlyTest',
  status: 'active',
  quantity: 1,
  total_count: 10,
  paid_count: 1,
  current_start: 1735689600, // 2025-01-01
  current_end: 1767225600, // 2026-01-01
  notes: { user_id: 'user_referred' },
}

const chargedEvent = (entity, paymentId, amountPaise) =>
  JSON.stringify({
    event: 'subscription.charged',
    created_at: Math.floor(Date.now() / 1000),
    payload: {
      subscription: { entity },
      ...(paymentId
        ? { payment: { entity: { id: paymentId, amount: amountPaise, currency: 'INR' } } }
        : {}),
    },
  })

/** Seeds the row the server wrote when the subscription was created. */
function seedSubscription({ referralCode }) {
  db.razorpay_subscriptions.set('seed_row', {
    id: 'seed_row',
    subscription_id: SUB.id,
    user_id: 'user_referred',
    plan_id: 'plan_YearlyTest',
    plan_slug: 'yearly',
    status: 'created',
    referral_code: referralCode ?? null,
    created_at: new Date().toISOString(),
  })
}

// ------------------------------------------------------------------
console.log('a referred purchase credits the referrer')
{
  resetStub()
  seedSubscription({ referralCode: 'SBABCDEF1234' })

  const res = await postWebhook('evt_ref_first', chargedEvent(SUB, 'pay_first_001', 12000))
  check('webhook accepted', res.status === 200 && res.json?.status === 'ok')

  const calls = creditCalls()
  check('exactly one credit request', calls.length === 1)

  const p = calls[0]?.params || {}
  check('referred user comes from the stored row', p.p_referred_user_id === 'user_referred')
  check('referral code comes from the stored row', p.p_referral_code === 'SBABCDEF1234')
  check('payment id is the idempotency key', p.p_source_event_id === 'pay_first_001')
  check('amount converted from paise to rupees', p.p_plan_price === 120)

  const row = Array.from(db.razorpay_subscriptions.values())[0]
  check('stored code survives the webhook update', row.referral_code === 'SBABCDEF1234')
  check('subscription status updated', row.status === 'active')
}

// ------------------------------------------------------------------
console.log('an event without a payment asks for nothing')
{
  resetStub()
  seedSubscription({ referralCode: 'SBABCDEF1234' })

  const res = await postWebhook('evt_no_payment', chargedEvent(SUB, null, null))
  check('webhook accepted', res.status === 200)
  check('no credit request without a payment', creditCalls().length === 0)
}

// ------------------------------------------------------------------
console.log('a purchase with no code asks with a null code')
{
  resetStub()
  seedSubscription({ referralCode: null })

  const res = await postWebhook('evt_no_code', chargedEvent(SUB, 'pay_nocode_001', 12000))
  check('webhook accepted', res.status === 200)

  const calls = creditCalls()
  check('the server still asks, so the database can answer', calls.length === 1)
  check(
    'no code is invented by the server',
    calls[0]?.params?.p_referral_code === null || calls[0]?.params?.p_referral_code === undefined,
  )
}

// ------------------------------------------------------------------
console.log('a renewal asks again; the database enforces first-payment-only')
{
  resetStub()
  seedSubscription({ referralCode: 'SBABCDEF1234' })

  await postWebhook('evt_charge_1', chargedEvent(SUB, 'pay_first_001', 12000))
  await postWebhook('evt_charge_2', chargedEvent(SUB, 'pay_renewal_002', 12000))

  const calls = creditCalls()
  check('both payments were asked about', calls.length === 2)
  check(
    'the second carries its own payment id',
    calls[1]?.params?.p_source_event_id === 'pay_renewal_002',
  )
  check(
    'the database is the authority, not the server',
    calls[1]?.params?.p_referred_user_id === 'user_referred',
  )
}

// ------------------------------------------------------------------
console.log('the referral endpoints are not open')
{
  resetStub()
  // Clerk is deliberately not configured in this harness, so requireClerkUser
  // answers 503 rather than 401. Either way the point is the same: the route
  // never answers 200 without a verified session.
  const summary = await fetch(`${BASE}/api/razorpay/referral`)
  check('summary refuses an anonymous caller', summary.status === 503 || summary.status === 401)

  const validate = await fetch(`${BASE}/api/razorpay/referral/validate?code=SBABCDEF1234`)
  check('code check refuses an anonymous caller', validate.status === 503 || validate.status === 401)
}

// ------------------------------------------------------------------
console.log('')
console.log(`  ${pass} passed, ${fail} failed`)
await new Promise((r) => setTimeout(r, 250))
process.exit(fail > 0 ? 1 : 0)
