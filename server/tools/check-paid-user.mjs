#!/usr/bin/env node
/**
 * Is this Clerk user a paid subscriber? — READ-ONLY check.
 *
 * Why this tool exists
 * --------------------
 * The Android app grants premium in two rails (`lib/modules/monetization/
 * premium_access.dart:65-67`):
 *
 *   1. Google Play Billing, through Superwall  -> `SubscriptionStatus.isActive`
 *      (a client-side SDK state; the server never sees it);
 *   2. Razorpay, sold outside the app          -> `GET /api/razorpay/entitlement`
 *      (a Postgres answer; see `docs/PAID-USER-VERIFICATION.md` for the SQL).
 *
 * This project's own Postgres therefore knows nothing about a Play purchase,
 * so "did user_X pay on Google Play?" can only be answered by Superwall (or
 * Google Play Console). This tool asks Superwall and prints the same facts the
 * app's gate is built on.
 *
 * Safety
 * ------
 *  - Every call is a GET except `POST /v2/users/query`, which is Superwall's
 *    read-only user search (it writes nothing).
 *  - The API key is read from the environment, never printed, never logged,
 *    and never written to disk.
 *  - No mutation endpoint is referenced anywhere in this file.
 *
 * Usage
 * -----
 *   SUPERWALL_API_KEY=... node server/tools/check-paid-user.mjs user_2ab... user_2cd...
 *
 * Optional:
 *   SUPERWALL_APPLICATION_ID=...   skip project discovery
 *   --verbose                      print each HTTP call and its status
 *
 * Create the key in the Superwall dashboard: Settings -> API keys (read scope
 * is enough). Exit codes: 0 = every user answered, 1 = at least one unknown,
 * 2 = configuration/usage problem.
 */

const API = 'https://api.superwall.com'
const BUNDLE_ID = 'com.soulfulbhakti.app'

const argv = process.argv.slice(2)
const verbose = argv.includes('--verbose')
const ids = argv.filter((a) => a.startsWith('user_'))

if (ids.length === 0 || argv.includes('--help') || argv.includes('-h')) {
  console.error(
    'usage: SUPERWALL_API_KEY=... node server/tools/check-paid-user.mjs <user_id> [user_id...] [--verbose]'
  )
  process.exit(2)
}

const key = (process.env.SUPERWALL_API_KEY || '').trim()
if (!key) {
  console.error(
    'SUPERWALL_API_KEY is not set.\n' +
      'Get a key from the Superwall dashboard (Settings -> API keys) and pass it\n' +
      'in the environment. It is never printed by this tool.'
  )
  process.exit(2)
}

async function call(method, path, body) {
  if (verbose) console.error(`  -> ${method} ${path}`)
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  const text = await res.text()
  let json = null
  if (text) {
    try {
      json = JSON.parse(text)
    } catch {
      /* non-JSON body: keep the raw text for the error message */
    }
  }
  if (verbose) console.error(`  <- ${res.status}`)
  return { status: res.status, json, text: text.slice(0, 300) }
}

function authFailure(status, json) {
  if (status !== 401 && status !== 403) return null
  return (
    `Superwall rejected the API key (HTTP ${status}` +
    `${json?.code ? `, ${json.code}` : ''}). ` +
    'Use a key from the same project/app, with read access.'
  )
}

async function resolveApplication() {
  const override = (process.env.SUPERWALL_APPLICATION_ID || '').trim()
  if (override) return { id: override, name: '(from SUPERWALL_APPLICATION_ID)', platform: '?' }

  const res = await call('GET', '/v2/projects?limit=50')
  const auth = authFailure(res.status, res.json)
  if (auth) throw new Error(auth)
  if (res.status !== 200) {
    throw new Error(`could not list projects: HTTP ${res.status} ${res.text}`)
  }

  const apps = (res.json?.data ?? []).flatMap((p) => p.applications ?? [])
  const app =
    apps.find((a) => (a.bundle_id || '') === BUNDLE_ID) ||
    apps.find((a) => /android/i.test(a.platform || ''))
  if (!app) {
    throw new Error(
      `no Android application found in this Superwall organization (looked for ${BUNDLE_ID}). ` +
        'Set SUPERWALL_APPLICATION_ID explicitly.'
    )
  }
  return app
}

const fmt = (v) => (v === null || v === undefined || v === '' ? '-' : String(v))

async function checkUser(app, id) {
  const q = `?application_id=${encodeURIComponent(app.id)}`
  const enc = encodeURIComponent(id)

  const summary = await call('GET', `/v2/users/${enc}/subscription-summary${q}`)
  const auth = authFailure(summary.status, summary.json)
  if (auth) throw new Error(auth)

  const entitlements = await call('GET', `/v2/users/${enc}/active-entitlements${q}`)

  // Read-only user search: tells us whether Superwall has ever seen this id,
  // and under which app_user_id it is stored.
  const search = await call('POST', '/v2/users/query', {
    application_id: app.id,
    search_term: id,
  })

  if (summary.status === 404) {
    return {
      id,
      known: false,
      verdict: 'NO RECORD',
      detail:
        'Superwall has never seen this Clerk id. A Play purchase made under this ' +
        'id would be recorded there, so either the purchase was made under a ' +
        'different Clerk user, or the app never reached Superwall on this account.',
    }
  }
  if (summary.status !== 200) {
    return {
      id,
      known: null,
      verdict: 'UNKNOWN',
      detail: `subscription-summary returned HTTP ${summary.status}: ${summary.text}`,
    }
  }

  const s = summary.json || {}
  const ents = entitlements.json?.entitlements ?? []
  const active = s.has_active_subscription === true

  // The app's gate reads Superwall's subscription status, not entitlements
  // (`premium_access.dart:65-67`), so the verdict mirrors that rule exactly.
  const verdict = active ? 'PAID' : 'NOT PAID'

  const rows = search.json?.rows ?? []
  const searchOk = search.status === 200

  return {
    id,
    known: true,
    verdict,
    detail: [
      `status               : ${fmt(s.subscription_status)}`,
      `has_active_subscription: ${active}`,
      `auto-renew           : ${fmt(s.auto_renew_enabled)}`,
      `products             : ${(s.active_product_ids ?? []).join(', ') || '-'}`,
      `store                : ${fmt(s.primary_store)}`,
      `first purchase       : ${fmt(s.first_purchase_date)}`,
      `expires              : ${fmt(s.expiration_date)}`,
      `next renewal         : ${fmt(s.next_renewal_date)}`,
      `active entitlements  : ${ents.length}${ents.length ? ' (' + ents.map((e) => e.identifier || e.id).join(', ') + ')' : ''}`,
      `found in user search : ${searchOk ? (rows.length > 0 ? 'yes' : 'no') : `unavailable (HTTP ${search.status})`}`,
      `latest event         : ${fmt(s.latest_event)} @ ${fmt(s.latest_event_ts)}`,
    ].join('\n'),
  }
}

async function main() {
  const app = await resolveApplication()
  console.log(`Superwall application: ${app.name}  (id ${app.id}, platform ${app.platform || '?'})`)
  console.log(`Google Play layer only. The Razorpay/web rail is NOT visible here; see`)
  console.log(`docs/PAID-USER-VERIFICATION.md for the SQL that answers that rail.\n`)

  let unknown = 0
  for (const id of ids) {
    const result = await checkUser(app, id)
    if (result.known === null) unknown++
    console.log(`${id}`)
    console.log(`  verdict: ${result.verdict}`)
    if (result.known === false || result.known === null) {
      console.log(`  ${result.detail}`)
    } else {
      console.log(
        result.detail
          .split('\n')
          .map((l) => `  ${l}`)
          .join('\n')
      )
    }
    console.log()
  }
  return unknown > 0 ? 1 : 0
}

// `process.exitCode` (not `process.exit`) so pending HTTP handles drain and the
// process never dies mid-socket — on Windows that surfaces as a libuv
// assertion instead of a clean exit status.
main()
  .then((code) => {
    process.exitCode = code
  })
  .catch((err) => {
    console.error(`FATAL: ${err.message}`)
    process.exitCode = 2
  })
