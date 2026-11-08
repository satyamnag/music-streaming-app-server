// ------------------------------------------------------------------
// Razorpay client for the web-subscription rail.
//
// Scope: this module is the ONLY place that talks to Razorpay, and it runs
// on the Node server. Nothing here may be bundled into the Android app: the
// key secret signs both payment verifications and API calls, so it must
// never leave the server (see docs/RAZORPAY-SUBSCRIPTIONS.md §2 and §8).
//
// Two independent proofs are implemented, and they use DIFFERENT secrets:
//
//   payment signature  HMAC_SHA256(payment_id + "|" + subscription_id, KEY_SECRET)
//                      - proves Checkout's success response is genuine
//                      - verified with the subscription id WE stored, not the
//                        one the client echoes back (Razorpay's own guidance,
//                        so a tampered client response cannot pick the pair)
//
//   webhook signature  HMAC_SHA256(raw_request_body, WEBHOOK_SECRET)
//                      - proves a lifecycle event came from Razorpay
//                      - computed over the RAW bytes; re-stringifying a parsed
//                        object changes the bytes and breaks the check
//
// Reference: https://razorpay.com/docs/payments/subscriptions/integration-guide
//            https://razorpay.com/docs/webhooks/validate-test
// ------------------------------------------------------------------

import crypto from 'node:crypto'

const DEFAULT_API_BASE = 'https://api.razorpay.com/v1'
const DEFAULT_TIMEOUT_MS = 15000

/** Plan slugs the app/server understand. Kept tiny on purpose: a typo must fail. */
export const PLAN_SLUGS = Object.freeze(['monthly', 'yearly'])

/**
 * Constant-time string comparison that never throws on length mismatch.
 * `crypto.timingSafeEqual` throws when the buffers differ in length, which
 * would turn a malformed signature into a 500 instead of a clean rejection.
 */
export function safeEqual(a, b) {
  const left = Buffer.from(String(a ?? ''), 'utf8')
  const right = Buffer.from(String(b ?? ''), 'utf8')
  if (left.length !== right.length || left.length === 0) return false
  try {
    return crypto.timingSafeEqual(left, right)
  } catch {
    return false
  }
}

/**
 * Verifies the signature Checkout returns on a successful subscription
 * authorisation.
 *
 * @param {object} args
 * @param {string} args.keySecret       Razorpay key secret (server-only).
 * @param {string} args.paymentId       `razorpay_payment_id` from Checkout.
 * @param {string} args.subscriptionId  The subscription id stored server-side.
 * @param {string} args.signature       `razorpay_signature` from Checkout.
 * @returns {boolean}
 */
export function verifyPaymentSignature({ keySecret, paymentId, subscriptionId, signature }) {
  if (!keySecret || !paymentId || !subscriptionId || !signature) return false
  const expected = crypto
    .createHmac('sha256', keySecret)
    .update(`${paymentId}|${subscriptionId}`)
    .digest('hex')
  return safeEqual(expected, signature)
}

/**
 * Verifies a Razorpay webhook.
 *
 * @param {object} args
 * @param {string} args.webhookSecret  The webhook secret set in the dashboard.
 * @param {Buffer|string} args.rawBody The exact request body bytes.
 * @param {string} args.signature      The `X-Razorpay-Signature` header.
 * @returns {boolean}
 */
export function verifyWebhookSignature({ webhookSecret, rawBody, signature }) {
  if (!webhookSecret || rawBody == null || !signature) return false
  const expected = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawBody)
    .digest('hex')
  return safeEqual(expected, signature)
}

/** Reverse lookup: plan_id (plan_...) -> 'monthly' | 'yearly'. */
export function planSlugForPlanId(plans, planId) {
  if (!plans || !planId) return null
  for (const slug of PLAN_SLUGS) {
    if (plans[slug] === planId) return slug
  }
  return null
}

/** Validates a client-supplied plan slug. */
export function normalisePlanSlug(value) {
  const slug = String(value ?? '').trim().toLowerCase()
  return PLAN_SLUGS.includes(slug) ? slug : null
}

/**
 * Total billing cycles for a plan. Razorpay caps a subscription at 10 years
 * (`end_time` must be within 946684800..4765046400), so a monthly plan is
 * 120 cycles and a yearly plan is 10 — the longest legal life for each.
 */
export function totalCountForPlan(slug) {
  return slug === 'yearly' ? 10 : 120
}

class RazorpayError extends Error {  constructor(message, { status = 0, description = '', code = '' } = {}) {
    super(message)
    this.name = 'RazorpayError'
    this.status = status
    this.description = description
    this.code = code
  }
}

/**
 * Builds the client. Every method fails loudly (throws) and never logs
 * secrets; callers translate failures into HTTP responses.
 *
 * @param {object} config
 * @param {string} config.keyId
 * @param {string} config.keySecret
 * @param {string} config.webhookSecret
 * @param {{monthly?: string, yearly?: string}} config.plans  plan_id per slug
 * @param {string} [config.apiBase]
 * @param {number} [config.timeoutMs]
 * @param {typeof fetch} [config.fetchImpl]
 */
export function createRazorpayClient({
  keyId,
  keySecret,
  webhookSecret,
  plans = {},
  apiBase = DEFAULT_API_BASE,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  fetchImpl = globalThis.fetch,
}) {
  if (!keyId || !keySecret) {
    throw new Error('razorpay: keyId and keySecret are required')
  }
  if (typeof fetchImpl !== 'function') {
    throw new Error('razorpay: no fetch implementation available')
  }

  const authorisation = `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString('base64')}`
  const base = String(apiBase).replace(/\/+$/, '')

  async function call(pathname, { method = 'GET', body } = {}) {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeoutMs)
    let response
    try {
      response = await fetchImpl(`${base}${pathname}`, {
        method,
        headers: {
          Authorization: authorisation,
          'Content-Type': 'application/json',
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: controller.signal,
      })
    } catch (err) {
      // Abort (timeout) or a socket error: report the shape, never the secret.
      throw new RazorpayError(
        err?.name === 'AbortError' ? 'razorpay request timed out' : 'razorpay request failed',
        { status: 0 },
      )
    } finally {
      clearTimeout(timer)
    }

    let payload = null
    try {
      payload = await response.json()
    } catch {
      payload = null
    }

    if (!response.ok) {
      const description = payload?.error?.description || `HTTP ${response.status}`
      throw new RazorpayError(`razorpay ${method} ${pathname} failed: ${description}`, {
        status: response.status,
        description,
        code: payload?.error?.code || '',
      })
    }
    return payload
  }

  return {
    keyId,

    planIdFor(slug) {
      return plans[slug] || null
    },

    async createSubscription({ planId, userId, totalCount }) {
      if (!planId) throw new RazorpayError('razorpay: unknown plan')
      if (!userId) throw new RazorpayError('razorpay: missing user id')
      return call('/subscriptions', {
        method: 'POST',
        body: {
          plan_id: planId,
          total_count: totalCount,
          quantity: 1,
          // Razorpay emails/SMSes the customer about charges. On (1) by
          // default; a missing value would be treated as 0.
          customer_notify: 1,
          // `notes.user_id` is how every webhook is attributed back to a
          // Clerk user without trusting anything the client sends later.
          notes: { user_id: userId },
        },
      })
    },

    getSubscription(subscriptionId) {
      return call(`/subscriptions/${encodeURIComponent(subscriptionId)}`)
    },

    cancelSubscription(subscriptionId) {
      return call(`/subscriptions/${encodeURIComponent(subscriptionId)}/cancel`, {
        method: 'POST',
      })
    },

    verifyPaymentSignature(args) {
      return verifyPaymentSignature({ keySecret, ...args })
    },

    verifyWebhookSignature(args) {
      return verifyWebhookSignature({ webhookSecret, ...args })
    },
  }
}

/**
 * Builds the Express handler for POST /api/razorpay/webhook.
 *
 * Dependencies are injected so the handler can be tested without booting the
 * whole server: `recordEvent` must return 'recorded' | 'duplicate' | 'error',
 * `applyEvent` applies the (already verified) event, and `deleteEvent`
 * releases the dedupe row when applying fails.
 *
 * The handler expects the RAW body (a Buffer) — it is registered before the
 * global express.json() for exactly that reason.
 */
export function createWebhookHandler({
  getClient,
  recordEvent,
  deleteEvent,
  applyEvent,
  logger = console,
}) {
  return async function handleRazorpayWebhook(req, res) {
    const client = getClient?.() || null
    if (!client) {
      logger.error?.('[razorpay] webhook received but Razorpay is not configured')
      return res.status(503).json({ error: 'razorpay not configured' })
    }

    const signature = req.headers['x-razorpay-signature']
    const eventId = req.headers['x-razorpay-event-id']
    if (!Buffer.isBuffer(req.body) || !signature || !eventId) {
      return res.status(400).json({ error: 'missing body, signature or event id' })
    }

    if (!client.verifyWebhookSignature({ rawBody: req.body, signature })) {
      logger.warn?.('[razorpay] webhook rejected: signature verification failed')
      return res.status(400).json({ error: 'signature verification failed' })
    }

    let event
    try {
      event = JSON.parse(req.body.toString('utf8'))
    } catch {
      return res.status(400).json({ error: 'invalid json' })
    }

    const eventType = String(event?.event || 'unknown')
    let record
    try {
      record = await recordEvent(String(eventId), eventType)
    } catch (err) {
      logger.error?.('[razorpay] could not record webhook event:', err?.message)
      return res.status(500).json({ error: 'event log failed' })
    }
    // Idempotency: a retried delivery must not be applied twice.
    if (record === 'duplicate') return res.json({ status: 'duplicate' })
    if (record !== 'recorded') {
      logger.error?.('[razorpay] could not record webhook event')
      return res.status(500).json({ error: 'event log failed' })
    }

    try {
      await applyEvent(event, String(eventId))
      return res.json({ status: 'ok' })
    } catch (err) {
      logger.error?.('[razorpay] webhook apply failed:', err?.message)
      // Release the dedupe row so Razorpay's retry is not swallowed.
      try {
        await deleteEvent(String(eventId))
      } catch {
        // The retry will be treated as a duplicate if this fails; the next
        // delivery of a NEWER event still reconciles the state.
      }
      return res.status(500).json({ error: 'apply failed' })
    }
  }
}

export { RazorpayError }
