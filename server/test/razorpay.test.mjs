// Tests for the Razorpay rail (server/razorpay.mjs).
//
// Run: node test/razorpay.test.mjs
// No framework and no network: the client's fetch is injected, so every
// assertion here is deterministic and offline.

import crypto from 'node:crypto'
import {
  PLAN_SLUGS,
  safeEqual,
  verifyPaymentSignature,
  verifyWebhookSignature,
  planSlugForPlanId,
  normalisePlanSlug,
  totalCountForPlan,
  createRazorpayClient,
  createWebhookHandler,
} from '../razorpay.mjs'

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

const KEY_SECRET = 'test_key_secret_do_not_use'
const WEBHOOK_SECRET = 'test_webhook_secret_do_not_use'

function paymentSig(paymentId, subscriptionId, secret = KEY_SECRET) {
  return crypto
    .createHmac('sha256', secret)
    .update(`${paymentId}|${subscriptionId}`)
    .digest('hex')
}

function webhookSig(body, secret = WEBHOOK_SECRET) {
  return crypto.createHmac('sha256', secret).update(body).digest('hex')
}

// ------------------------------------------------------------------
// safeEqual
// ------------------------------------------------------------------
console.log('safeEqual')
check('equal strings compare equal', safeEqual('abc123', 'abc123'))
check('different strings are rejected', !safeEqual('abc123', 'abc124'))
check('length mismatch is rejected without throwing', !safeEqual('abc', 'abcd'))
check('empty values are rejected', !safeEqual('', '') && !safeEqual(null, 'x'))

// ------------------------------------------------------------------
// Payment signature
// ------------------------------------------------------------------
console.log('verifyPaymentSignature')
const PAYMENT_ID = 'pay_TestPayment000001'
const SUB_ID = 'sub_TestSubscription01'
const goodSig = paymentSig(PAYMENT_ID, SUB_ID)

check(
  'valid signature accepted',
  verifyPaymentSignature({
    keySecret: KEY_SECRET,
    paymentId: PAYMENT_ID,
    subscriptionId: SUB_ID,
    signature: goodSig,
  }),
)

check(
  'tampered payment id rejected',
  !verifyPaymentSignature({
    keySecret: KEY_SECRET,
    paymentId: 'pay_TestPayment000002',
    subscriptionId: SUB_ID,
    signature: goodSig,
  }),
)

check(
  'tampered subscription id rejected (client cannot swap the pair)',
  !verifyPaymentSignature({
    keySecret: KEY_SECRET,
    paymentId: PAYMENT_ID,
    subscriptionId: 'sub_TestSubscription02',
    signature: goodSig,
  }),
)

check(
  'signature from a different secret rejected',
  !verifyPaymentSignature({
    keySecret: 'another_secret',
    paymentId: PAYMENT_ID,
    subscriptionId: SUB_ID,
    signature: goodSig,
  }),
)

check(
  'wrong-length signature rejected without throwing',
  !verifyPaymentSignature({
    keySecret: KEY_SECRET,
    paymentId: PAYMENT_ID,
    subscriptionId: SUB_ID,
    signature: 'short',
  }),
)

check(
  'missing fields rejected',
  !verifyPaymentSignature({ keySecret: KEY_SECRET, paymentId: PAYMENT_ID }) &&
    !verifyPaymentSignature({ keySecret: '', paymentId: PAYMENT_ID, subscriptionId: SUB_ID, signature: goodSig }),
)

// ------------------------------------------------------------------
// Webhook signature
// ------------------------------------------------------------------
console.log('verifyWebhookSignature')
const rawBody = Buffer.from(JSON.stringify({ event: 'subscription.charged', payload: { n: 1 } }))
const goodWebhookSig = webhookSig(rawBody)

check(
  'valid webhook accepted',
  verifyWebhookSignature({
    webhookSecret: WEBHOOK_SECRET,
    rawBody,
    signature: goodWebhookSig,
  }),
)

check(
  'mutated body rejected',
  !verifyWebhookSignature({
    webhookSecret: WEBHOOK_SECRET,
    rawBody: Buffer.from(JSON.stringify({ event: 'subscription.charged', payload: { n: 2 } })),
    signature: goodWebhookSig,
  }),
)

// The documented failure mode: parsing and re-stringifying changes the bytes,
// so the HMAC must be computed over the raw buffer only.
const reparsed = Buffer.from(JSON.stringify(JSON.parse(rawBody.toString('utf8')), null, 2))
check(
  're-stringified (pretty-printed) body rejected',
  !verifyWebhookSignature({ webhookSecret: WEBHOOK_SECRET, rawBody: reparsed, signature: goodWebhookSig }),
)

check(
  'webhook secret is not the payment secret',
  !verifyWebhookSignature({ webhookSecret: KEY_SECRET, rawBody, signature: goodWebhookSig }),
)

check(
  'missing signature rejected',
  !verifyWebhookSignature({ webhookSecret: WEBHOOK_SECRET, rawBody, signature: '' }),
)

check(
  'missing secret rejected (fail closed)',
  !verifyWebhookSignature({ webhookSecret: '', rawBody, signature: goodWebhookSig }),
)

// ------------------------------------------------------------------
// Plans
// ------------------------------------------------------------------
console.log('plans')
const plans = { monthly: 'plan_Monthly123', yearly: 'plan_Yearly456' }
check('slug list is stable', PLAN_SLUGS.length === 2 && PLAN_SLUGS.includes('monthly'))
check('monthly plan resolves', planSlugForPlanId(plans, 'plan_Monthly123') === 'monthly')
check('yearly plan resolves', planSlugForPlanId(plans, 'plan_Yearly456') === 'yearly')
check('unknown plan resolves to null', planSlugForPlanId(plans, 'plan_Other') === null)
check('no plans configured resolves to null', planSlugForPlanId(null, 'plan_Monthly123') === null)
check('slug normalisation accepts mixed case', normalisePlanSlug(' Yearly ') === 'yearly')
check('unknown slug rejected', normalisePlanSlug('weekly') === null && normalisePlanSlug(undefined) === null)
check('monthly uses 120 cycles (10y cap)', totalCountForPlan('monthly') === 120)
check('yearly uses 10 cycles (10y cap)', totalCountForPlan('yearly') === 10)

// ------------------------------------------------------------------
// Client behaviour (injected fetch, no network)
// ------------------------------------------------------------------
console.log('client')

let missingKeysThrew = false
try {
  createRazorpayClient({ keyId: '', keySecret: '' })
} catch {
  missingKeysThrew = true
}
check('client refuses to build without keys', missingKeysThrew)

const calls = []
const fakeFetch = async (url, init) => {
  calls.push({ url, init })
  // Echo a minimal subscription entity the way Razorpay does.
  return {
    ok: true,
    status: 200,
    json: async () => ({
      id: 'sub_Created0001',
      plan_id: 'plan_Monthly123',
      status: 'created',
      short_url: 'https://rzp.io/i/abc123',
      notes: { user_id: 'user_2abc' },
    }),
  }
}

const client = createRazorpayClient({
  keyId: 'rzp_test_key',
  keySecret: KEY_SECRET,
  webhookSecret: WEBHOOK_SECRET,
  plans,
  fetchImpl: fakeFetch,
})

const created = await client.createSubscription({
  planId: plans.monthly,
  userId: 'user_2abc',
  totalCount: 120,
})

check('create uses POST /subscriptions', calls[0].url.endsWith('/subscriptions') && calls[0].init.method === 'POST')
check(
  'create sends HTTP Basic auth, never the secret in the body',
  calls[0].init.headers.Authorization ===
    'Basic ' + Buffer.from(`rzp_test_key:${KEY_SECRET}`).toString('base64'),
)
const sentBody = JSON.parse(calls[0].init.body)
check('create attaches user_id in notes', sentBody.notes?.user_id === 'user_2abc')
check('create uses the configured plan id', sentBody.plan_id === 'plan_Monthly123')
check('create does not send an amount (plan owns it)', !('amount' in sentBody))
check('created subscription id returned', created.id === 'sub_Created0001' && created.short_url)

check(
  'client verifyPaymentSignature delegates with its own secret',
  client.verifyPaymentSignature({
    paymentId: PAYMENT_ID,
    subscriptionId: SUB_ID,
    signature: goodSig,
  }),
)

// Error path: Razorpay rejects the call -> typed error with status, no secrets.
const failingClient = createRazorpayClient({
  keyId: 'rzp_test_key',
  keySecret: KEY_SECRET,
  webhookSecret: WEBHOOK_SECRET,
  plans,
  fetchImpl: async () => ({
    ok: false,
    status: 400,
    json: async () => ({ error: { code: 'BAD_REQUEST_ERROR', description: 'plan is invalid' } }),
  }),
})

let failure = null
try {
  await failingClient.createSubscription({ planId: 'plan_Invalid', userId: 'user_2abc', totalCount: 1 })
} catch (err) {
  failure = err
}
check('API error surfaces as a typed error with status', failure?.status === 400 && failure?.name === 'RazorpayError')
check('API error message does not leak the key secret', !String(failure?.message).includes(KEY_SECRET))

// ------------------------------------------------------------------
// Webhook handler (the raw-body + idempotency contract)
// ------------------------------------------------------------------
console.log('webhook handler')

function fakeRes() {
  const res = { statusCode: 200, body: null }
  res.status = (code) => {
    res.statusCode = code
    return res
  }
  res.json = (body) => {
    res.body = body
    return res
  }
  return res
}

function makeHandler(overrides = {}) {
  const state = {
    applied: [],
    recorded: [],
    deleted: [],
    client: {
      verifyWebhookSignature: ({ rawBody, signature }) =>
        verifyWebhookSignature({ webhookSecret: WEBHOOK_SECRET, rawBody, signature }),
    },
    recordEvent: async (id, type) => {
      state.recorded.push({ id, type })
      return 'recorded'
    },
    deleteEvent: async (id) => {
      state.deleted.push(id)
    },
    applyEvent: async (event, id) => {
      state.applied.push({ event, id })
    },
    ...overrides,
  }
  const handler = createWebhookHandler({
    getClient: () => state.client,
    recordEvent: state.recordEvent,
    deleteEvent: state.deleteEvent,
    applyEvent: state.applyEvent,
    logger: { warn() {}, error() {} },
  })
  return { handler, state }
}

const validEvent = { event: 'subscription.charged', payload: { subscription: { entity: { id: 'sub_X' } } } }
const validRaw = Buffer.from(JSON.stringify(validEvent))
const validSig = webhookSig(validRaw)
function goodReq(extra = {}) {
  return {
    headers: { 'x-razorpay-signature': validSig, 'x-razorpay-event-id': 'evt_1' },
    body: validRaw,
    ...extra,
  }
}

{
  const { handler } = makeHandler({ client: null })
  const res = fakeRes()
  await handler(goodReq(), res)
  check('503 when Razorpay is not configured', res.statusCode === 503)
}

{
  const { handler } = makeHandler()
  const res = fakeRes()
  // What would happen if the route were registered AFTER express.json():
  // the body is a plain object, so the HMAC cannot be computed.
  await handler(goodReq({ body: validEvent }), res)
  check('400 when the body is not raw (json parser ran first)', res.statusCode === 400)
}

{
  const { handler } = makeHandler()
  const res = fakeRes()
  await handler(goodReq({ headers: { 'x-razorpay-event-id': 'evt_1' } }), res)
  check('400 when the signature header is missing', res.statusCode === 400)
}

{
  const { handler } = makeHandler()
  const res = fakeRes()
  await handler(goodReq({ headers: { 'x-razorpay-signature': validSig } }), res)
  check('400 when the event id header is missing', res.statusCode === 400)
}

{
  const { handler, state } = makeHandler()
  const res = fakeRes()
  await handler(goodReq({ headers: { 'x-razorpay-signature': 'deadbeef', 'x-razorpay-event-id': 'evt_1' } }), res)
  check('400 on a bad signature', res.statusCode === 400 && state.applied.length === 0)
}

{
  const { handler, state } = makeHandler()
  const res = fakeRes()
  const junk = Buffer.from('not json at all')
  await handler(
    { headers: { 'x-razorpay-signature': webhookSig(junk), 'x-razorpay-event-id': 'evt_2' }, body: junk },
    res,
  )
  check('400 on a correctly-signed but non-JSON body', res.statusCode === 400 && state.applied.length === 0)
}

{
  const { handler, state } = makeHandler()
  const res = fakeRes()
  await handler(goodReq(), res)
  check('200 and applies a verified event', res.statusCode === 200 && state.applied.length === 1)
  check('the applied event carries its event id', state.applied[0].id === 'evt_1')
  check('the event type is recorded', state.recorded[0].type === 'subscription.charged')
}

{
  const { handler, state } = makeHandler({ recordEvent: async () => 'duplicate' })
  const res = fakeRes()
  await handler(goodReq(), res)
  check(
    'duplicate delivery acknowledged without re-applying',
    res.statusCode === 200 && res.body.status === 'duplicate' && state.applied.length === 0,
  )
}

{
  const { handler } = makeHandler({ recordEvent: async () => 'error' })
  const res = fakeRes()
  await handler(goodReq(), res)
  check('500 when the event log write fails (so Razorpay retries)', res.statusCode === 500)
}

{
  const { handler, state } = makeHandler({
    applyEvent: async () => {
      throw new Error('db down')
    },
  })
  const res = fakeRes()
  await handler(goodReq(), res)
  check('500 when applying fails', res.statusCode === 500)
  check('the dedupe row is released so the retry is not swallowed', state.deleted.includes('evt_1'))
}

console.log('')
console.log(`  ${pass} passed, ${fail} failed`)
if (fail > 0) process.exit(1)
