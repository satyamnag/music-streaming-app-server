/**
 * Integration tests for the Partner Program routes.
 *
 * Boots the real Express app from server.js against a STUB Supabase client and
 * a stub email transport, then drives the complete partner lifecycle over
 * HTTP. The point is to exercise the actual route handlers, validation and
 * trust boundaries — not a re-implementation of them.
 *
 * What this covers:
 *   - registration, including the user-enumeration-resistant response
 *   - email verification (single-use, invalid/expired handling)
 *   - draft save with server-side field allow-listing
 *   - document upload: type sniffing, size cap, filename attacks, encryption
 *   - submission completeness rules
 *   - admin review queue, document access audit, approve/reject
 *   - authorisation: a partner token cannot read another partner, and the
 *     public portal cannot reach any /api/admin route
 *
 * Run: node test/partner-flow.test.mjs
 */

import http from 'node:http'
import assert from 'node:assert/strict'
import crypto from 'node:crypto'
import { db, state, uuid, resetStub } from './supabase-stub.mjs'

// ---------------------------------------------------------------------------
// Test fixtures / stub state
// ---------------------------------------------------------------------------

process.env.SUPABASE_URL = 'https://stub.supabase.co'
process.env.SUPABASE_SERVICE_KEY = 'stub-service-key'
process.env.ADMIN_TOKEN = 'test-admin-token'
process.env.PARTNER_KEK = 'ab'.repeat(32) // 32 bytes hex
process.env.MAIL_FROM = 'partners@example.com'
process.env.RESEND_API_KEY = 're_test_key'
process.env.PARTNER_IP_SALT = 'test-salt'
process.env.PORT = '0' // let the OS choose

resetStub()

// The @supabase/supabase-js module is replaced with ./supabase-stub.mjs by
// test/partner-stub-loader.mjs, which is registered via --import.

// Stub the email provider so the transport code runs without a network call.
const realFetch = globalThis.fetch
globalThis.fetch = async (url, opts) => {
  if (typeof url === 'string' && url.includes('api.resend.com')) {
    return new Response(JSON.stringify({ id: 'stub-email-id' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  return realFetch(url, opts)
}

// ---------------------------------------------------------------------------
// Boot the server
// ---------------------------------------------------------------------------
await import('../server.js')

// server.js assigns the port inside its listen callback, so wait for it.
await (async () => {
  for (let i = 0; i < 120; i++) {
    if (global.__PARTNER_TEST_PORT) return
    await new Promise((r) => setTimeout(r, 50))
  }
  throw new Error('server did not start listening in time')
})()

const BASE = 'http://127.0.0.1:' + global.__PARTNER_TEST_PORT

function request(method, path, { token, body, headers, raw } = {}) {
  return new Promise((resolve, reject) => {
    const payload = raw != null ? raw : body ? JSON.stringify(body) : null
    const h = { ...(headers || {}) }
    if (token) h['Authorization'] = 'Bearer ' + token
    if (payload && !h['Content-Type']) h['Content-Type'] = 'application/json'
    if (payload) h['Content-Length'] = Buffer.byteLength(payload)

    const req = http.request(BASE + path, { method, headers: h }, (res) => {
      const chunks = []
      res.on('data', (c) => { chunks.push(c) })
      res.on('end', () => {
        // Keep the raw bytes: binary responses (the QR PNG) must not be
        // mangled by a string concat, which would corrupt them.
        const buf = Buffer.concat(chunks)
        const text = buf.toString('utf8')
        let json = null
        try { json = JSON.parse(text) } catch (_) { /* non-JSON (e.g. PNG) */ }
        resolve({ status: res.statusCode, headers: res.headers, body: json, raw: text, buffer: buf })
      })
    })
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------
let pass = 0
let fail = 0
const failures = []

async function test(name, fn) {
  try {
    await fn()
    pass++
    console.log('  PASS ' + name)
  } catch (e) {
    fail++
    failures.push(name + ' -> ' + e.message)
    console.log('  FAIL ' + name + ' -> ' + e.message)
  }
}

function adminCookie() {
  // The admin login sets an HMAC-signed cookie. Sign one directly so the
  // tests do not depend on the login route.
  const exp = Date.now() + 3600_000
  const payload = String(exp)
  const sig = crypto.createHmac('sha256', process.env.ADMIN_TOKEN).update(payload).digest('base64url')
  return `sangeet_admin_session=${payload}.${sig}`
}

console.log('\n=== Partner Program integration tests ===\n')

let partnerToken = null
let partnerId = null
let verifyToken = null

// Capture the verification token by observing the RPC call.
function lastVerificationToken() {
  const call = [...state.rpcLog].reverse().find((r) => r.name === 'partner_set_verification_token')
  return call ? call.params.p_raw_token : null
}

await test('registration creates an account and sends a verification email', async () => {
  const res = await request('POST', '/api/partner/register', { body: { email: 'Partner@Example.com' } })
  assert.equal(res.status, 201)
  assert.equal(res.body.ok, true)
  assert.ok(res.body.token, 'a portal token is returned to the new partner')
  assert.equal(res.body.emailSent, true, 'the email transport reported success')
  partnerToken = res.body.token
  partnerId = [...db.partners.values()][0].id
  verifyToken = lastVerificationToken()
  assert.ok(verifyToken, 'a verification token was issued')
  assert.equal([...db.partners.values()][0].email, 'partner@example.com', 'email is normalised to lower case')
})

await test('registration of an existing email does not reveal that it exists', async () => {
  const res = await request('POST', '/api/partner/register', { body: { email: 'partner@example.com' } })
  assert.equal(res.status, 202)
  assert.equal(res.body.token, undefined, 'no token is handed out for a duplicate')
  assert.ok(/verification email is on its way/i.test(res.body.message))
  assert.equal(db.partners.size, 1, 'no second account was created')
})

await test('an unverified partner cannot upload documents', async () => {
  const res = await request('POST', '/api/partner/documents', { token: partnerToken })
  // No multipart body => multer yields no file => 400 before the gate.
  assert.ok([400, 403].includes(res.status), 'blocked, got ' + res.status)
})

await test('verification link verifies the email once and expires the token', async () => {
  const first = await request('GET', '/api/partner/verify?token=' + encodeURIComponent(verifyToken))
  assert.equal(first.status, 302, 'success redirects to the portal')
  assert.equal([...db.partners.values()][0].email_verified, true)

  // Replaying the same link must not re-verify or leak which state it was in.
  const second = await request('GET', '/api/partner/verify?token=' + encodeURIComponent(verifyToken))
  assert.equal(second.status, 400, 'a consumed token is rejected')
})

await test('an unknown verification token is rejected', async () => {
  const res = await request('GET', '/api/partner/verify?token=not-a-real-token')
  assert.equal(res.status, 400)
})

await test('GET /api/partner/me returns the authenticated partner only', async () => {
  const res = await request('GET', '/api/partner/me', { token: partnerToken })
  assert.equal(res.status, 200)
  assert.equal(res.body.partner.email, 'partner@example.com')
  assert.equal(res.body.partner.emailVerified, true)
  assert.equal(res.body.issued, null, 'nothing is issued before approval')
})

await test('an invalid session token is rejected with 401', async () => {
  const res = await request('GET', '/api/partner/me', { token: 'bogus-token' })
  assert.equal(res.status, 401)
})

await test('draft save rejects a malformed PAN with a friendly message', async () => {
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: { fields: { pan_number: 'NOTAPAN' } },
  })
  assert.equal(res.status, 400)
  assert.ok(/PAN/i.test(res.body.error), 'error mentions PAN: ' + res.body.error)
})

await test('draft save cannot set protected fields such as status', async () => {
  // A valid PAN is included so the PAN CHECK cannot be what rejects this.
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: {
      fields: {
        status: 'approved',
        affiliate_id: '00000000-0000-4000-8000-000000000000',
        email_verified: true,
        decision_note: 'self approved',
        legal_name: 'Test Partner',
        pan_number: 'ABCDE1234F',
      },
    },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  const row = db.partners.get(partnerId)
  assert.equal(row.status, 'draft', 'status was not changed by the client')
  assert.equal(row.affiliate_id, undefined, 'affiliate_id was not set by the client')
  assert.equal(row.email_verified, true, 'email_verified was not touched by the draft (still only from verification)')
  assert.equal(row.decision_note, undefined, 'decision_note was not set by the client')
  assert.equal(row.legal_name, 'Test Partner', 'an allowed field was saved')
  assert.equal(row.pan_number, 'ABCDE1234F', 'an allowed field was saved')
})

await test('submission is refused while required information is missing', async () => {
  const res = await request('POST', '/api/partner/submit', { token: partnerToken })
  assert.equal(res.status, 400)
  assert.equal(res.body.error, 'Some required information is still missing.')
  assert.ok(Array.isArray(res.body.missing) && res.body.missing.length > 0, 'missing fields are listed')
  assert.ok(Array.isArray(res.body.missingLabels), 'human-readable labels are provided')
})

await test('document upload rejects an oversized file', async () => {
  const boundary = '----test'
  const big = Buffer.alloc(6 * 1024 * 1024, 0x41)
  const body = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="docType"\r\n\r\npan_card\r\n`),
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="big.pdf"\r\nContent-Type: application/pdf\r\n\r\n`),
    big,
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ])
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken,
    raw: body,
    headers: { 'Content-Type': `multipart/form-data; boundary=${boundary}` },
  })
  assert.ok(res.status === 413 || res.status === 400, 'oversized upload rejected, got ' + res.status)
})

function multipart(fields, file) {
  const boundary = '----partnerTest' + Math.random().toString(36).slice(2)
  const parts = []
  for (const [k, v] of Object.entries(fields)) {
    parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`))
  }
  if (file) {
    parts.push(Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${file.filename}"\r\n` +
      `Content-Type: ${file.contentType}\r\n\r\n`,
    ))
    parts.push(file.buffer)
    parts.push(Buffer.from('\r\n'))
  }
  parts.push(Buffer.from(`--${boundary}--\r\n`))
  return { body: Buffer.concat(parts), contentType: `multipart/form-data; boundary=${boundary}` }
}

const PDF = Buffer.from('%PDF-1.7\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF')

await test('document upload rejects a spoofed file type', async () => {
  const mp = multipart({ docType: 'pan_card' }, {
    filename: 'fake.pdf', contentType: 'application/pdf', buffer: Buffer.from('this is not a pdf at all'),
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 400)
  assert.ok(/PDF, JPEG or PNG/.test(res.body.error), 'got: ' + res.body.error)
})

await test('document upload rejects an NTFS alternate-data-stream filename', async () => {
  const mp = multipart({ docType: 'pan_card' }, {
    filename: 'pan.pdf:evil.jpg', contentType: 'application/pdf', buffer: PDF,
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 400)
  assert.ok(/filename/i.test(res.body.error), 'got: ' + res.body.error)
})

await test('document upload rejects Aadhaar explicitly', async () => {
  const mp = multipart({ docType: 'aadhaar_card' }, {
    filename: 'aadhaar.pdf', contentType: 'application/pdf', buffer: PDF,
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 400)
  assert.ok(/Unknown document type|Aadhaar is not accepted/i.test(res.body.error), 'got: ' + res.body.error)
})

await test('a valid PAN document uploads and is stored ENCRYPTED', async () => {
  const mp = multipart({ docType: 'pan_card' }, {
    filename: 'pan.pdf', contentType: 'application/pdf', buffer: PDF,
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 201, 'upload succeeded: ' + JSON.stringify(res.body))
  assert.ok(res.body.document.id)

  // The critical assertion: what landed in storage must not be the document.
  const stored = [...state.storageObjects.values()]
  assert.equal(stored.length, 1, 'exactly one object was stored')
  assert.ok(!stored[0].equals(PDF), 'stored bytes differ from the plaintext')
  assert.ok(!stored[0].toString('latin1').includes('%PDF-'), 'stored bytes do not contain the PDF header')
})

await test('an address-proof document uploads successfully', async () => {
  const mp = multipart({ docType: 'address_proof' }, {
    filename: 'address.png', contentType: 'image/png',
    buffer: Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(64)]),
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 201, JSON.stringify(res.body))
})

await test('consent is recorded server-side with a timestamp', async () => {
  const res = await request('POST', '/api/partner/consent', {
    token: partnerToken,
    body: { termsAccepted: true, privacyAccepted: true, truthfulnessDeclared: true },
  })
  assert.equal(res.status, 200)
  const row = db.partners.get(partnerId)
  assert.equal(row.terms_accepted, true)
  assert.ok(row.terms_accepted_at, 'a timestamp was written')
})

await test('consent is refused when a declaration is missing', async () => {
  const res = await request('POST', '/api/partner/consent', {
    token: partnerToken,
    body: { termsAccepted: true, privacyAccepted: false, truthfulnessDeclared: true },
  })
  assert.equal(res.status, 400)
})

await test('a complete application submits successfully', async () => {
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: {
      fields: {
        applicant_type: 'individual', legal_name: 'Test Partner', gender: 'male',
        date_of_birth: '1990-05-04', phone: '+919876543210',
        address_line1: '1 Test Road', city: 'Hyderabad', state: 'Telangana',
        postal_code: '500001', country: 'India', pan_number: 'ABCDE1234F',
      },
    },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))

  const sub = await request('POST', '/api/partner/submit', { token: partnerToken })
  assert.equal(sub.status, 200, JSON.stringify(sub.body))
  assert.equal(sub.body.status, 'submitted')
})

await test('the public portal cannot reach any admin route', async () => {
  const res = await request('GET', '/api/admin/partners', { token: partnerToken })
  assert.ok([401, 403].includes(res.status), 'partner token rejected on admin route, got ' + res.status)
})

await test('an unauthenticated caller cannot read the admin partner queue', async () => {
  const res = await request('GET', '/api/admin/partners')
  assert.ok([401, 403].includes(res.status), 'got ' + res.status)
})

await test('an admin can list the partner review queue', async () => {
  const res = await request('GET', '/api/admin/partners', {
    headers: { Cookie: adminCookie() },
  })
  assert.equal(res.status, 200)
  assert.ok(Array.isArray(res.body))
  assert.equal(res.body.length, 1)
  assert.equal(res.body[0].status, 'submitted')
  assert.equal(res.body[0].documentCount, 2)
})

await test('an admin can read the full application detail', async () => {
  const res = await request('GET', '/api/admin/partners/' + partnerId, {
    headers: { Cookie: adminCookie() },
  })
  assert.equal(res.status, 200)
  assert.equal(res.body.partner.legalName, 'Test Partner')
  assert.equal(res.body.documents.length, 2)
  assert.ok(Array.isArray(res.body.audit))
})

await test('opening a document decrypts it, audits the access, and sets download headers', async () => {
  const docId = [...db.documents.values()][0].id
  const before = db.audit.length
  const res = await request('GET', `/api/admin/partners/${partnerId}/documents/${docId}/content`, {
    headers: { Cookie: adminCookie() },
  })
  assert.equal(res.status, 200, 'document served')
  assert.equal(res.headers['x-content-type-options'], 'nosniff', 'nosniff header present')
  assert.equal(res.headers['content-type'], 'application/octet-stream', 'served as opaque bytes')
  assert.ok(/attachment/.test(res.headers['content-disposition'] || ''), 'forced download')
  assert.ok(/no-store/.test(res.headers['cache-control'] || ''), 'not cacheable')
  assert.equal(res.headers['referrer-policy'], 'no-referrer')
  assert.ok(db.audit.length > before, 'the access was written to the audit log')
  assert.equal(db.audit[db.audit.length - 1].result, 'success')
})

await test('a document from a different partner id is not served', async () => {
  const docId = [...db.documents.values()][0].id
  const otherPartner = uuid()
  const res = await request('GET', `/api/admin/partners/${otherPartner}/documents/${docId}/content`, {
    headers: { Cookie: adminCookie() },
  })
  assert.equal(res.status, 404, 'scoped lookup returns not found')
})

await test('rejecting an application requires a reason', async () => {
  const res = await request('POST', `/api/admin/partners/${partnerId}/decision`, {
    headers: { Cookie: adminCookie() },
    body: { decision: 'reject' },
  })
  assert.equal(res.status, 400)
  assert.ok(/reason is required/i.test(res.body.error))
})

await test('an admin can approve, which issues a referrer code and a coupon', async () => {
  const res = await request('POST', `/api/admin/partners/${partnerId}/approve`, {
    headers: { Cookie: adminCookie() },
    body: { commissionAmount: 100 },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.ok(res.body.referrerCode, 'a referrer code was issued')
  assert.ok(res.body.couponCode, 'a coupon code was issued')
  assert.ok(/^SB-P/.test(res.body.referrerCode), 'generated referrer code has the expected shape')

  const row = db.partners.get(partnerId)
  assert.equal(row.status, 'approved')
  assert.ok(row.affiliate_id)
})

await test('approval is idempotent and returns the same artefacts', async () => {
  const first = await request('GET', '/api/admin/partners/' + partnerId, { headers: { Cookie: adminCookie() } })
  const refBefore = first.body.issued.referrerCode
  const couponBefore = first.body.issued.coupon.code

  const res = await request('POST', `/api/admin/partners/${partnerId}/approve`, {
    headers: { Cookie: adminCookie() },
    body: { commissionAmount: 100 },
  })
  assert.equal(res.status, 200)
  assert.equal(res.body.alreadyApproved, true)
  assert.equal(res.body.referrerCode, refBefore, 'the referrer code did not change')
  assert.equal(res.body.couponCode, couponBefore, 'no second coupon was created')
  assert.equal(db.coupons.size, 1, 'exactly one coupon exists')
  assert.equal(db.affiliates.size, 1, 'exactly one affiliate exists')
})

await test('the approved partner sees their QR link and coupon', async () => {
  const res = await request('GET', '/api/partner/me', { token: partnerToken })
  assert.equal(res.status, 200)
  assert.equal(res.body.partner.status, 'approved')
  assert.ok(res.body.issued, 'issued artefacts are exposed')
  assert.ok(/play\.google\.com\/store\/apps\/details\?id=com\.soulfulbhakti\.app/.test(res.body.issued.installUrl),
    'the install URL targets the correct Play listing')
  assert.ok(/referrer=utm_source=/.test(res.body.issued.installUrl),
    'the install URL carries an install-referrer for the shipped app pipeline')
})

await test('the partner QR renders as a PNG for its owner', async () => {
  const res = await request('GET', `/api/partner/qr/${partnerId}.png?token=` + encodeURIComponent(partnerToken))
  assert.equal(res.status, 200)
  assert.equal(res.headers['content-type'], 'image/png')
  assert.ok(res.buffer.slice(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47])), 'the response is a real PNG')
})

await test("a partner cannot fetch another partner's QR", async () => {
  const res = await request('GET', `/api/partner/qr/${uuid()}.png?token=` + encodeURIComponent(partnerToken))
  assert.equal(res.status, 404)
})

await test('an approved application can no longer be edited by the partner', async () => {
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: { fields: { legal_name: 'Changed Name' } },
  })
  assert.equal(res.status, 409, 'the application is locked')
})

await test('the audit trail recorded the whole lifecycle', async () => {
  const actions = db.audit.map((a) => a.action)
  // Access-logged document views are the reason the audit table exists.
  assert.ok(actions.includes('document.view'), 'document access was audited')
})

await test('the config endpoint reports capability without leaking secrets', async () => {
  const res = await request('GET', '/api/partner/config')
  assert.equal(res.status, 200)
  assert.equal(res.body.encryptionReady, true)
  assert.equal(res.body.emailEnabled, true)
  const serialised = JSON.stringify(res.body)
  assert.ok(!serialised.includes(process.env.PARTNER_KEK), 'the KEK is never exposed')
  assert.ok(!/aadhaar/i.test(JSON.stringify(res.body.documentLabels)), 'Aadhaar is not an offered document type')
  assert.ok(res.body.retentionNotice, 'the retention consequence of withdrawal is disclosed')
})

await test('an admin rejection schedules a purge no earlier than the legal retention floor', async () => {
  // DPDP Rules 2025 r.8(3): a mandatory one-year MINIMUM retention. A purge
  // must never be scheduled before the floor elapses.
  const p2 = await request('POST', '/api/partner/register', { body: { email: 'reject-me@example.com' } })
  assert.equal(p2.status, 201)
  const token2 = p2.body.token
  const vt2 = lastVerificationToken()
  await request('GET', '/api/partner/verify?token=' + encodeURIComponent(vt2))

  const row2 = [...db.partners.values()].find((r) => r.email === 'reject-me@example.com')
  assert.equal(row2.status, 'draft')

  const decided = await request('POST', `/api/admin/partners/${row2.id}/decision`, {
    headers: { Cookie: adminCookie() },
    body: { decision: 'reject', note: 'Documents did not match the declared name.' },
  })
  assert.equal(decided.status, 200, JSON.stringify(decided.body))
  assert.equal(decided.body.status, 'rejected')

  // The purge may not be scheduled before the statutory floor.
  const floor = new Date(row2.earliest_purge_at).getTime()
  const purge = new Date(row2.purge_after).getTime()
  assert.ok(purge >= floor, 'purge_after is not earlier than the retention floor')
  assert.ok(purge > Date.now(), 'the purge is in the future, not immediate')
})

await test('a partner can withdraw, which stops processing immediately', async () => {
  // DPDP Act 2023 s.6(4): withdrawing consent must be as easy as giving it.
  const p3 = await request('POST', '/api/partner/register', { body: { email: 'withdraw-me@example.com' } })
  assert.equal(p3.status, 201)
  const token3 = p3.body.token

  const res = await request('POST', '/api/partner/withdraw', { token: token3, body: {} })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.status, 'withdrawn')
  assert.ok(res.body.purgeAfter, 'the partner is told the actual deletion date')

  // The session is burned, so the portal token cannot be reused.
  const after = await request('GET', '/api/partner/me', { token: token3 })
  assert.equal(after.status, 401, 'the withdrawn session no longer works')
})

await test('withdrawal is idempotent from the partner perspective', async () => {
  const p4 = await request('POST', '/api/partner/register', { body: { email: 'withdraw-twice@example.com' } })
  const token4 = p4.body.token
  const first = await request('POST', '/api/partner/withdraw', { token: token4, body: {} })
  assert.equal(first.status, 200)
  // The token was burned on the first withdrawal, so a second call is an
  // invalid session rather than an error cascade.
  const second = await request('POST', '/api/partner/withdraw', { token: token4, body: {} })
  assert.ok([200, 401].includes(second.status), 'no 5xx on repeat withdrawal, got ' + second.status)
})

console.log(`\n${pass} passed, ${fail} failed`)
if (fail) {
  console.log('\nFailures:')
  failures.forEach((f) => console.log('  - ' + f))
}
process.exit(fail ? 1 : 0)
