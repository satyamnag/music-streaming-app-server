// ============================================================================
// END-TO-END PIPELINE TEST — real Express server + REAL PostgreSQL
// ============================================================================
//
// This is the strongest test in the repo. Unlike partner-flow.test.mjs (which
// runs against an in-memory stub), this boots the ACTUAL server.js and drives
// the COMPLETE partner lifecycle over HTTP against a GENUINE PostgreSQL
// database with the real migrations applied.
//
// What only this test can prove:
//   * the SQL functions actually execute (types, plpgsql, constraints)
//   * CHECK constraints fire through the real HTTP path
//   * SECURITY DEFINER + grants behave as authored
//   * document bytes round-trip through storage as real ciphertext
//   * the whole flow works with no stub standing in for business logic
//
// Run (from server/):
//   PARTNER_TEST_DB_URL=postgres://... \
//     node test/real-db-register.mjs test/partner-real-db.test.mjs
// ============================================================================

import http from 'node:http'
import assert from 'node:assert/strict'
import crypto from 'node:crypto'

const dbUrl = process.env.PARTNER_TEST_DB_URL
if (!dbUrl) {
  console.error('PARTNER_TEST_DB_URL is required')
  process.exit(2)
}

// ---------------------------------------------------------------------------
// Environment for server.js
// ---------------------------------------------------------------------------
process.env.SUPABASE_URL = 'https://ignored.invalid' // adapter uses PARTNER_TEST_DB_URL
process.env.SUPABASE_SERVICE_KEY = 'ignored'
process.env.ADMIN_TOKEN = 'real-db-admin-token'
process.env.PARTNER_KEK = 'cd'.repeat(32) // 32 bytes hex
process.env.MAIL_FROM = 'partners@example.com'
process.env.RESEND_API_KEY = 're_real_db_key'
process.env.PARTNER_IP_SALT = 'real-db-salt'
process.env.PORT = '0'

// Stub ONLY the outbound email provider: everything else is real.
const realFetch = globalThis.fetch
globalThis.fetch = async (url, opts) => {
  if (typeof url === 'string' && url.includes('api.resend.com')) {
    return new Response(JSON.stringify({ id: 'stub-email' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  return realFetch(url, opts)
}

// ---------------------------------------------------------------------------
// Boot the real server
// ---------------------------------------------------------------------------
await import('../server.js')

await (async () => {
  for (let i = 0; i < 120; i++) {
    if (global.__PARTNER_TEST_PORT) return
    await new Promise((r) => setTimeout(r, 50))
  }
  throw new Error('server did not start listening in time')
})()

const BASE = 'http://127.0.0.1:' + global.__PARTNER_TEST_PORT

// Direct database access for setup and assertions.
const pg = (await import('pg')).default
const pool = new pg.Pool({ connectionString: dbUrl, max: 5 })

async function q(sql, params) {
  const res = await pool.query(sql, params)
  return res.rows
}

// ---------------------------------------------------------------------------
// HTTP helper
// ---------------------------------------------------------------------------
function request(method, path, { token, body, headers, raw } = {}) {
  return new Promise((resolve, reject) => {
    const payload = raw != null ? raw : body ? JSON.stringify(body) : null
    const h = { ...(headers || {}) }
    if (token) h['Authorization'] = 'Bearer ' + token
    if (payload && !h['Content-Type']) h['Content-Type'] = 'application/json'
    if (payload) h['Content-Length'] = Buffer.byteLength(payload)

    const req = http.request(BASE + path, { method, headers: h }, (res) => {
      const chunks = []
      res.on('data', (c) => chunks.push(c))
      res.on('end', () => {
        const buf = Buffer.concat(chunks)
        const text = buf.toString('utf8')
        let json = null
        try { json = JSON.parse(text) } catch (_) { /* binary */ }
        resolve({ status: res.statusCode, headers: res.headers, body: json, raw: text, buffer: buf })
      })
    })
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

function adminCookie() {
  const exp = Date.now() + 3600_000
  const payload = String(exp)
  const sig = crypto.createHmac('sha256', process.env.ADMIN_TOKEN).update(payload).digest('base64url')
  return `sangeet_admin_session=${payload}.${sig}`
}

function multipart(fields, file) {
  const boundary = '----realDb' + Math.random().toString(36).slice(2)
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

const PDF_PLAINTEXT = Buffer.from('%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF\n')

// ---------------------------------------------------------------------------
// Harness
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

// ---------------------------------------------------------------------------
console.log('\n=== END-TO-END PIPELINE: real server + real PostgreSQL ===\n')

// Start from a clean database.
await q(`truncate table
  public.partner_audit_log, public.partner_email_events, public.partner_documents,
  public.partners, public.affiliate_commissions, public.affiliate_referrals,
  public.coupon_attributions, public.coupons, public.affiliates,
  public.test_only_storage_objects restart identity cascade`)

console.log('Database truncated; starting lifecycle.\n')

let partnerToken = null
let partnerId = null
// NOTE: `verifyToken` was removed with the emailed-link flow. Verification is
// an admin attestation and has no token.

// The server mints the verification token internally, so read its hash target
// from the database and instead drive verification through the resend path,
// which returns success and lets us confirm via the DB.
// Email verification is now an ADMIN ATTESTATION, not an emailed link. The
// old fetchVerificationToken() helper is gone with the token flow; this calls
// the real RPC the admin route calls.
async function attestPartnerEmail(partnerRowId) {
  await q(
    `select public.partner_attest_email($1, 'test-admin@soulfulbhakti.com',
       'admin_attested', 'integration test')`,
    [partnerRowId],
  )
}

// ---------------------------------------------------------------------------
// 1. Registration
// ---------------------------------------------------------------------------
await test('POST /api/partner/register creates a real row', async () => {
  const res = await request('POST', '/api/partner/register', {
    body: { email: 'Real.Partner@Example.com' },
  })
  assert.equal(res.status, 201, JSON.stringify(res.body))
  assert.equal(res.body.ok, true)
  assert.ok(res.body.token, 'a portal token is returned')

  partnerToken = res.body.token

  const rows = await q('select id, email, portal_token_hash, status, earliest_purge_at from public.partners')
  assert.equal(rows.length, 1, 'exactly one row exists in the REAL database')
  partnerId = rows[0].id
  assert.equal(rows[0].email, 'real.partner@example.com', 'email normalised by SQL')
  assert.notEqual(rows[0].portal_token_hash, partnerToken, 'raw token is not stored')
  assert.equal(
    rows[0].portal_token_hash,
    crypto.createHash('sha256').update(partnerToken).digest('hex'),
    'stored hash matches SHA-256 of the token',
  )
  assert.equal(rows[0].status, 'draft')
})

await test('duplicate registration does not leak account existence', async () => {
  const res = await request('POST', '/api/partner/register', {
    body: { email: 'real.partner@example.com' },
  })
  assert.equal(res.status, 202)
  assert.equal(res.body.token, undefined, 'no token for a duplicate')
  const rows = await q('select count(*)::int as n from public.partners')
  assert.equal(rows[0].n, 1, 'still exactly one row')
})

await test('an unverified partner is blocked from uploading (real DB gate)', async () => {
  const mp = multipart({ docType: 'pan_card' }, {
    filename: 'pan.pdf', contentType: 'application/pdf', buffer: PDF_PLAINTEXT,
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 403, JSON.stringify(res.body))
  assert.ok(/verify your email/i.test(res.body.error))
})

// ---------------------------------------------------------------------------
// 2. Email verification via ADMIN ATTESTATION (replaces the emailed link)
// ---------------------------------------------------------------------------
await test('the partner is blocked until an admin attests the address', async () => {
  // Still unverified at this point, so submission must be refused. This proves
  // the gate is real before we open it. The route answers 403 (forbidden),
  // not 400 — the request is well-formed but not permitted yet.
  const res = await request('POST', '/api/partner/submit', { token: partnerToken, body: {} })
  assert.equal(res.status, 403, JSON.stringify(res.body))
  assert.ok(/verify your email/i.test(res.body.error), 'the gate names email verification')
})

await test('POST /api/admin/partners/:id/attest-email verifies the REAL row', async () => {
  // The admin route, exactly as the admin panel calls it.
  const res = await request('POST', `/api/admin/partners/${partnerId}/attest-email`, {
    headers: { Cookie: adminCookie() },
    body: { method: 'admin_attested', note: 'integration test' },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.ok, true)

  const rows = await q(
    `select email_verified, email_verified_by, email_verified_method, email_verified_at
     from public.partners where id=$1`,
    [partnerId],
  )
  assert.equal(rows[0].email_verified, true, 'the REAL row is marked verified')
  assert.equal(rows[0].email_verified_by, 'admin-token', 'the attesting admin is recorded')
  assert.equal(rows[0].email_verified_method, 'admin_attested', 'the method is recorded')
  assert.ok(rows[0].email_verified_at, 'the timestamp is recorded')
})

await test('attestation requires admin auth', async () => {
  const res = await request('POST', `/api/admin/partners/${partnerId}/attest-email`, {
    body: { method: 'admin_attested' },
  })
  assert.ok(res.status === 401 || res.status === 403, `expected 401/403, got ${res.status}`)
})

await test('the email-verification endpoints NO LONGER EXIST', async () => {
  // The emailed-link flow was removed. Asserting the absence keeps it from
  // being reintroduced by accident.
  const verify = await request('GET', '/api/partner/verify?token=anything')
  assert.equal(verify.status, 404, 'the verification-link endpoint is gone')

  const resend = await request('POST', '/api/partner/resend-verification', { body: {} })
  assert.equal(resend.status, 404, 'the resend endpoint is gone')
})

await test('GET /api/partner/me returns the real row', async () => {
  const res = await request('GET', '/api/partner/me', { token: partnerToken })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.partner.email, 'real.partner@example.com')
  assert.equal(res.body.partner.emailVerified, true)
})

// ---------------------------------------------------------------------------
// 3. Draft save + real CHECK constraints
// ---------------------------------------------------------------------------
await test('draft save persists to the real database', async () => {
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: {
      fields: {
        applicant_type: 'individual',
        legal_name: 'Real DB Partner',
        gender: 'female',
        date_of_birth: '1992-03-15',
        phone: '+919000000001',
        address_line1: '42 Real Street',
        city: 'Bengaluru',
        state: 'Karnataka',
        postal_code: '560001',
        country: 'India',
      },
    },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  const rows = await q('select legal_name, city, gender from public.partners where id=$1', [partnerId])
  assert.equal(rows[0].legal_name, 'Real DB Partner')
  assert.equal(rows[0].city, 'Bengaluru')
})

await test('a malformed PAN is rejected by the REAL check constraint', async () => {
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: { fields: { pan_number: 'BADPAN' } },
  })
  assert.equal(res.status, 400, JSON.stringify(res.body))
  assert.ok(/PAN/i.test(res.body.error), 'friendly PAN message: ' + res.body.error)
})

await test('an under-18 applicant is rejected by the REAL check constraint', async () => {
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: { fields: { date_of_birth: '2015-01-01' } },
  })
  assert.equal(res.status, 400, JSON.stringify(res.body))
  assert.ok(/18/.test(res.body.error), 'age message: ' + res.body.error)
})

await test('a client cannot set protected columns through the real DB', async () => {
  const res = await request('POST', '/api/partner/draft', {
    token: partnerToken,
    body: {
      fields: {
        pan_number: 'ABCDE1234F',
        status: 'approved',
        affiliate_id: '00000000-0000-4000-8000-000000000000',
      },
    },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  const rows = await q('select status, affiliate_id from public.partners where id=$1', [partnerId])
  assert.equal(rows[0].status, 'draft', 'status unchanged in the REAL database')
  assert.equal(rows[0].affiliate_id, null, 'affiliate_id unchanged')
})

// ---------------------------------------------------------------------------
// 4. Documents: real encryption round-trip through real storage
// ---------------------------------------------------------------------------
await test('a PAN upload stores CIPHERTEXT in the real storage table', async () => {
  const mp = multipart({ docType: 'pan_card' }, {
    filename: 'pan.pdf', contentType: 'application/pdf', buffer: PDF_PLAINTEXT,
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 201, JSON.stringify(res.body))

  const objs = await q('select name, data, content_type from public.test_only_storage_objects')
  assert.equal(objs.length, 1, 'one object stored')
  const stored = Buffer.from(objs[0].data)

  assert.ok(!stored.equals(PDF_PLAINTEXT), 'stored bytes differ from the plaintext')
  assert.ok(!stored.toString('latin1').includes('%PDF-'), 'no PDF header in storage')
  assert.equal(objs[0].content_type, 'application/octet-stream', 'stored as opaque bytes')

  // The metadata row must carry the encryption envelope.
  const docs = await q(
    'select enc_iv, enc_tag, dek_wrapped, dek_iv, dek_tag, sha256, doc_type from public.partner_documents',
  )
  assert.equal(docs.length, 1)
  for (const col of ['enc_iv', 'enc_tag', 'dek_wrapped', 'dek_iv', 'dek_tag']) {
    assert.ok(docs[col] || docs[0][col], `${col} is populated`)
  }
  assert.equal(
    docs[0].sha256,
    crypto.createHash('sha256').update(PDF_PLAINTEXT).digest('hex'),
    'the stored SHA-256 is of the PLAINTEXT (integrity check basis)',
  )
})

await test('an Aadhaar document type is refused with an EXPLANATORY message', async () => {
  const mp = multipart({ docType: 'aadhaar_card' }, {
    filename: 'aadhaar.pdf', contentType: 'application/pdf', buffer: PDF_PLAINTEXT,
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 400, JSON.stringify(res.body))
  // REGRESSION: the Aadhaar check must run BEFORE the generic allow-list test.
  // `aadhaar_card` is intentionally absent from DOC_LABELS, so ordering it
  // after the generic check made this branch unreachable and the partner saw
  // a useless "Unknown document type" instead of the explanation plus the
  // alternatives the Aadhaar Act s.8(3) requires them to be offered.
  assert.ok(/aadhaar/i.test(res.body.error), 'error names Aadhaar: ' + res.body.error)
  assert.ok(
    /PAN card/i.test(res.body.error) && /passport|voter ID|driving licence/i.test(res.body.error),
    'error offers the accepted alternatives: ' + res.body.error,
  )
  assert.ok(!/Unknown document type/i.test(res.body.error), 'not the generic message')

  const objs = await q('select count(*)::int as n from public.test_only_storage_objects')
  assert.equal(objs[0].n, 1, 'no Aadhaar object was stored')
})

await test('an address proof uploads', async () => {
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    Buffer.alloc(128, 7),
  ])
  const mp = multipart({ docType: 'address_proof' }, {
    filename: 'addr.png', contentType: 'image/png', buffer: png,
  })
  const res = await request('POST', '/api/partner/documents', {
    token: partnerToken, raw: mp.body, headers: { 'Content-Type': mp.contentType },
  })
  assert.equal(res.status, 201, JSON.stringify(res.body))
})

// ---------------------------------------------------------------------------
// 5. Consent + submission
// ---------------------------------------------------------------------------
await test('consent is recorded with a real server-side timestamp', async () => {
  const res = await request('POST', '/api/partner/consent', {
    token: partnerToken,
    body: { termsAccepted: true, privacyAccepted: true, truthfulnessDeclared: true },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  const rows = await q('select terms_accepted, terms_accepted_at, privacy_accepted from public.partners where id=$1', [partnerId])
  assert.equal(rows[0].terms_accepted, true)
  assert.ok(rows[0].terms_accepted_at, 'a real timestamp exists')
})

await test('submission succeeds against the real database', async () => {
  const res = await request('POST', '/api/partner/submit', { token: partnerToken })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.status, 'submitted')
  const rows = await q('select status, submitted_at from public.partners where id=$1', [partnerId])
  assert.equal(rows[0].status, 'submitted')
  assert.ok(rows[0].submitted_at)
})

await test('the admin queue reflects the real row', async () => {
  const res = await request('GET', '/api/admin/partners', { headers: { Cookie: adminCookie() } })
  assert.equal(res.status, 200)
  assert.equal(res.body.length, 1)
  assert.equal(res.body[0].status, 'submitted')
  assert.equal(res.body[0].documentCount, 2)
  assert.equal(res.body[0].emailVerified, true)
})

// ---------------------------------------------------------------------------
// 6. Document review: decrypt through the real HTTP route
// ---------------------------------------------------------------------------
await test('opening a document decrypts it correctly end to end', async () => {
  const docs = await q('select id from public.partner_documents where doc_type=$1', ['pan_card'])
  const docId = docs[0].id

  const res = await request('GET', `/api/admin/partners/${partnerId}/documents/${docId}/content`, {
    headers: { Cookie: adminCookie() },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.headers['x-content-type-options'], 'nosniff')
  assert.equal(res.headers['content-type'], 'application/octet-stream')
  assert.ok(/attachment/.test(res.headers['content-disposition'] || ''))
  assert.ok(/no-store/.test(res.headers['cache-control'] || ''))

  // THE decisive assertion: the bytes returned are the ORIGINAL document,
  // decrypted from real ciphertext held in a real database.
  assert.ok(res.buffer.equals(PDF_PLAINTEXT),
    'the served bytes are byte-identical to the uploaded PDF')

  // ...and the access was audited in the real audit log.
  const audit = await q(
    "select count(*)::int as n from public.partner_audit_log where partner_id=$1 and action='document.view' and detail->>'result'='success'",
    [partnerId],
  )
  assert.ok(audit[0].n >= 1, 'the document view is audited with result=success')
})

await test('a document is refused under a different partner id', async () => {
  const docs = await q('select id from public.partner_documents limit 1')
  const res = await request(
    'GET',
    `/api/admin/partners/00000000-0000-4000-8000-000000000000/documents/${docs[0].id}/content`,
    { headers: { Cookie: adminCookie() } },
  )
  assert.equal(res.status, 404, 'scoped lookup returns not found')
})

// ---------------------------------------------------------------------------
// 7. Approval: creates the affiliate + QR + coupon in the real DB
// ---------------------------------------------------------------------------
let issuedRef = null
let issuedCoupon = null

await test('approval issues the partner kit in one real transaction', async () => {
  const res = await request('POST', `/api/admin/partners/${partnerId}/approve`, {
    headers: { Cookie: adminCookie() },
    body: { commissionAmount: 150, maxRedemptions: 250 },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.ok(res.body.referrerCode, 'a referrer code was issued')
  assert.ok(res.body.couponCode, 'a coupon code was issued')
  issuedRef = res.body.referrerCode
  issuedCoupon = res.body.couponCode

  const aff = await q('select id, name, referrer_code, commission_amount, status from public.affiliates')
  assert.equal(aff.length, 1, 'exactly one affiliate exists')
  assert.equal(aff[0].referrer_code, issuedRef)
  assert.equal(Number(aff[0].commission_amount), 150)
  assert.equal(aff[0].status, 'active', 'active — the shipped app pipeline requires this')

  const cps = await q('select code, affiliate_id, max_redemptions, status from public.coupons')
  assert.equal(cps.length, 1)
  assert.equal(cps[0].code, issuedCoupon)
  assert.equal(cps[0].affiliate_id, aff[0].id, 'the coupon is linked to the affiliate')
  assert.equal(cps[0].max_redemptions, 250)
})

await test('the referrer code works with the SHIPPED app RPC (bind_affiliate_referral)', async () => {
  // This is the critical compatibility proof: the QR a partner receives must
  // be consumable by the affiliate-binding function the Android app already
  // calls. If this passes, no app change is needed.
  const rows = await q('select public.bind_affiliate_referral($1, $2) as status', [issuedRef, 'clerk_user_real_1'])
  assert.equal(rows[0].status, 'bound', 'the app can bind a user to this referrer code')

  const ref = await q('select referrer_code, affiliate_id from public.affiliate_referrals where purchaser_user_id=$1', ['clerk_user_real_1'])
  assert.equal(ref.length, 1)
  assert.equal(ref[0].referrer_code, issuedRef)
})

await test('the coupon works with the SHIPPED app RPCs (validate + redeem)', async () => {
  const v = await q('select * from public.validate_coupon($1)', [issuedCoupon])
  assert.equal(v[0].valid, true, 'the app can validate this coupon')
  assert.equal(v[0].affiliate_name, 'Real DB Partner', 'the affiliate display name is exposed')

  const r = await q('select public.redeem_coupon($1, $2) as status', [issuedCoupon, 'clerk_user_real_1'])
  assert.equal(r[0].status, 'redeemed', 'the app can redeem this coupon')

  const after = await q('select redemption_count from public.coupons where code=$1', [issuedCoupon])
  assert.equal(Number(after[0].redemption_count), 1, 'the redemption is counted')
})

await test('an approved partner sees their QR link and coupon over HTTP', async () => {
  const res = await request('GET', '/api/partner/me', { token: partnerToken })
  assert.equal(res.status, 200)
  assert.equal(res.body.partner.status, 'approved')
  assert.ok(res.body.issued)
  assert.equal(res.body.issued.referrerCode, issuedRef)
  assert.equal(res.body.issued.coupon.code, issuedCoupon)
  assert.ok(
    res.body.issued.installUrl.includes('com.soulfulbhakti.app'),
    'the install URL targets the correct Play listing',
  )
  assert.ok(
    res.body.issued.installUrl.includes('utm_source=' + issuedRef),
    'the install URL carries the install-referrer the app parses',
  )
})

await test('the partner QR renders as a real PNG', async () => {
  const res = await request('GET', `/api/partner/qr/${partnerId}.png?token=` + encodeURIComponent(partnerToken))
  assert.equal(res.status, 200)
  assert.equal(res.headers['content-type'], 'image/png')
  assert.ok(res.buffer.slice(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47])), 'a real PNG')
})

await test('re-approval is idempotent against the real DB', async () => {
  const res = await request('POST', `/api/admin/partners/${partnerId}/approve`, {
    headers: { Cookie: adminCookie() },
    body: { commissionAmount: 150 },
  })
  assert.equal(res.status, 200)
  assert.equal(res.body.alreadyApproved, true)
  assert.equal(res.body.referrerCode, issuedRef, 'the same referrer code')
  assert.equal(res.body.couponCode, issuedCoupon, 'the same coupon')

  const a = await q('select count(*)::int as n from public.affiliates')
  const c = await q('select count(*)::int as n from public.coupons')
  assert.equal(a[0].n, 1, 'still exactly one affiliate')
  assert.equal(c[0].n, 1, 'still exactly one coupon')
})

// ---------------------------------------------------------------------------
// 8. Rejection path + retention floor
// ---------------------------------------------------------------------------
await test('a rejected application gets a purge after the legal retention floor', async () => {
  const ins = await q(`insert into public.partners
      (email, portal_token_hash, status, email_verified,
       terms_accepted, privacy_accepted, truthfulness_declared)
    values ('reject-real@example.com', encode(digest('rj','sha256'),'hex'), 'submitted', true, true, true, true)
    returning id`)
  const rid = ins[0].id

  const res = await request('POST', `/api/admin/partners/${rid}/decision`, {
    headers: { Cookie: adminCookie() },
    body: { decision: 'reject', note: 'Documents did not match the declared name.' },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))

  const rows = await q('select purge_after, earliest_purge_at, status from public.partners where id=$1', [rid])
  assert.equal(rows[0].status, 'rejected')
  assert.ok(rows[0].purge_after, 'a purge is scheduled')
  assert.ok(
    new Date(rows[0].purge_after) >= new Date(rows[0].earliest_purge_at),
    'the purge respects the DPDP one-year floor',
  )
})

// ---------------------------------------------------------------------------
// 9. Withdrawal (DPDP s.6(4))
// ---------------------------------------------------------------------------
await test('withdrawal through HTTP works against the real DB', async () => {
  const reg = await request('POST', '/api/partner/register', { body: { email: 'withdraw-real@example.com' } })
  assert.equal(reg.status, 201)
  const tok = reg.body.token

  const res = await request('POST', '/api/partner/withdraw', { token: tok, body: {} })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.status, 'withdrawn')
  assert.ok(res.body.purgeAfter, 'the partner is told the purge date')

  const after = await request('GET', '/api/partner/me', { token: tok })
  assert.equal(after.status, 401, 'the burned session no longer resolves')
})

// ---------------------------------------------------------------------------
// 10. Audit trail integrity (real trigger)
// ---------------------------------------------------------------------------
await test('the real append-only trigger blocks tampering', async () => {
  const rows = await q('select id from public.partner_audit_log limit 1')
  let blockedUpdate = false
  let blockedDelete = false
  try {
    await q('update public.partner_audit_log set action=$1 where id=$2', ['tampered', rows[0].id])
  } catch (e) { blockedUpdate = true }
  try {
    await q('delete from public.partner_audit_log where id=$1', [rows[0].id])
  } catch (e) { blockedDelete = true }

  assert.ok(blockedUpdate, 'UPDATE is blocked by the trigger')
  assert.ok(blockedDelete, 'DELETE is blocked by the trigger')
})

await test('the full lifecycle left a complete audit trail', async () => {
  const rows = await q(
    'select action, count(*)::int as n from public.partner_audit_log group by action order by action',
  )
  const actions = rows.map((r) => r.action)
  // NOTE: 'email_verified' became 'email_attested' when the emailed-link flow
  // was replaced by admin attestation.
  for (const expected of ['register', 'email_attested', 'submit', 'approve', 'document_uploaded']) {
    assert.ok(actions.includes(expected), `audit contains "${expected}" (got: ${actions.join(', ')})`)
  }
})

// ---------------------------------------------------------------------------
// 11. Config endpoint
// ---------------------------------------------------------------------------
await test('the config endpoint is accurate against the real deployment', async () => {
  const res = await request('GET', '/api/partner/config')
  assert.equal(res.status, 200)
  assert.equal(res.body.encryptionReady, true)
  // emailEnabled is a hardcoded false, not a capability probe: this portal sends
  // no automatic email at all. Asserting false is deliberate — if a transport is
  // ever reintroduced, this fails and forces that to be a conscious decision.
  assert.equal(res.body.emailEnabled, false, 'emailEnabled must be false: no automatic email exists')
  assert.ok(!JSON.stringify(res.body).includes(process.env.PARTNER_KEK), 'the KEK is never exposed')
  assert.ok(!/aadhaar/i.test(JSON.stringify(res.body.documentLabels)), 'Aadhaar is not offered')
})

console.log(`\n${pass} passed, ${fail} failed`)
if (fail) {
  console.log('\nFailures:')
  failures.forEach((f) => console.log('  - ' + f))
}
await pool.end()
process.exit(fail ? 1 : 0)
