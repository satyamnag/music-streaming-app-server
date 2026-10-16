// ============================================================================
// Partner credentials + login — HTTP integration against REAL PostgreSQL
// ============================================================================
//
// Proves the NEW pipeline over the real HTTP surface: the admin issues
// credentials, the partner signs in with them, that session works on the
// EXISTING unmodified routes, and the dashboard returns aggregates with no KYC.
//
// The SQL functions are covered by test/partner_auth.test.sql. This file exists
// to prove the ROUTES around them behave — status codes, no-enumeration
// responses, and that no password or hash ever leaks into a response body or
// the audit trail.
//
// Run (from server/):
//   PARTNER_TEST_DB_URL=postgres://... \
//     node test/real-db-register.mjs test/partner-auth-http.test.mjs
//
// NOTE: this follows the same manual harness as partner-real-db.test.mjs
// (plain top-level await + a `test()` collector) rather than node:test,
// because the register wrapper imports the file as a module into a process
// that keeps a listening server alive. node:test's own runner would leave the
// event loop open, and process.exit() must be called explicitly at the end.
// ============================================================================

import http from 'node:http'
import assert from 'node:assert/strict'
import crypto from 'node:crypto'

const dbUrl = process.env.PARTNER_TEST_DB_URL
if (!dbUrl) {
  console.error('PARTNER_TEST_DB_URL is required')
  process.exit(2)
}

process.env.SUPABASE_URL = 'https://ignored.invalid' // adapter uses PARTNER_TEST_DB_URL
process.env.SUPABASE_SERVICE_KEY = 'ignored'
process.env.ADMIN_TOKEN = 'auth-http-admin-token'
process.env.PARTNER_KEK = 'ef'.repeat(32)
process.env.MAIL_FROM = 'partners@example.com'
process.env.RESEND_API_KEY = 're_auth_http'
process.env.PARTNER_IP_SALT = 'auth-http-salt'
process.env.PORT = '0'

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

const pg = (await import('pg')).default
const pool = new pg.Pool({ connectionString: dbUrl, max: 5 })
async function q(sql, params) {
  const res = await pool.query(sql, params)
  return res.rows
}

// ---------------------------------------------------------------------------
// IMPORTANT: the admin token is read from VAULT at startup, and a vault value
// OVERRIDES the ADMIN_TOKEN env var (see VAULT_SECRET_KEYS /
// loadSecretsFromVault() in server.js). The server has already booted by this
// point, so rather than fight that, this suite asserts against the token the
// server ACTUALLY holds. Deriving it keeps the suite correct whether the vault
// is populated or empty, instead of silently depending on a leftover value
// from another suite's run.
// ---------------------------------------------------------------------------
const vaultRows = await q(
  `select decrypted_secret from vault.decrypted_secrets where name = 'admin_token'`,
).catch(() => [])
const EFFECTIVE_ADMIN_TOKEN =
  (vaultRows[0] && vaultRows[0].decrypted_secret) || process.env.ADMIN_TOKEN

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

function request(method, path, { token, body, headers } = {}) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null
    const h = { ...(headers || {}) }
    if (token) h['Authorization'] = 'Bearer ' + token
    if (payload) {
      h['Content-Type'] = 'application/json'
      h['Content-Length'] = Buffer.byteLength(payload)
    }
    const req = http.request(BASE + path, { method, headers: h }, (res) => {
      const chunks = []
      res.on('data', (c) => chunks.push(c))
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString('utf8')
        let json = null
        try { json = JSON.parse(text) } catch (_) { /* non-JSON */ }
        resolve({ status: res.statusCode, headers: res.headers, body: json, raw: text })
      })
    })
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

// Admin auth uses the same signed session cookie as the rest of the admin
// panel (verified against partner-real-db.test.mjs). Signed with the EFFECTIVE
// token, which is the vault value when one exists.
function adminCookie() {
  const exp = Date.now() + 3600_000
  const payload = String(exp)
  const sig = crypto
    .createHmac('sha256', EFFECTIVE_ADMIN_TOKEN)
    .update(payload)
    .digest('base64url')
  return `sangeet_admin_session=${payload}.${sig}`
}
const asAdmin = () => ({ Cookie: adminCookie() })

// ---------------------------------------------------------------------------
// Clean slate — same table set the other suites truncate.
// ---------------------------------------------------------------------------
await q(`truncate table
  public.partner_audit_log,
  public.partner_email_events,
  public.partner_documents,
  public.partners,
  public.affiliate_commissions,
  public.affiliate_referrals,
  public.coupon_attributions,
  public.coupons,
  public.affiliates
  restart identity cascade`)

// Seed an applicant directly. In the new pipeline the ADMIN creates the
// account, so a bare row that never self-registered is the realistic start.
const seeded = await q(
  `insert into public.partners (email, portal_token_hash, status, applicant_type,
     legal_name, terms_accepted, privacy_accepted, truthfulness_declared)
   values ('http.partner@example.com', public.partner_token_hash('seed'), 'submitted',
     'individual', 'HTTP Partner', true, true, true)
   returning id`,
)
const PARTNER_ID = seeded[0].id

let loginId = null
let sessionToken = null
let issuedPassword = null
// The password the credentials ROUTE handed back. Kept separately from
// `issuedPassword` (which later tests rotate through change-password) so the
// login test can prove the route's own value works.
let issuedPasswordFromRoute = null

console.log('\n=== Partner credentials + login (HTTP, real DB) ===\n')

// ---------------------------------------------------------------------------
// 1. Admin-only issuance
// ---------------------------------------------------------------------------
await test('an unauthenticated caller cannot issue credentials', async () => {
  const res = await request('POST', `/api/admin/partners/${PARTNER_ID}/credentials`, { body: {} })
  assert.ok(res.status === 401 || res.status === 403, `expected 401/403, got ${res.status}`)

  const rows = await q('select login_id, password_hash from public.partners where id = $1', [PARTNER_ID])
  assert.equal(rows[0].login_id, null, 'no login id was written')
  assert.equal(rows[0].password_hash, null, 'no password hash was written')
})

await test('admin issues credentials and the password IS returned once, bounded', async () => {
  // THE CONTRACT CHANGED DELIBERATELY. READ BEFORE "FIXING" THIS TEST.
  //
  // This test was named "the password is NOT in the response" and asserted
  // `!("password" in res.body)`. That was correct while the credential was
  // emailed to the partner. Automatic email has since been removed from the
  // portal, which makes the admin the ONLY party who can relay a credential —
  // so withholding it would leave every newly issued password undeliverable,
  // which is strictly worse than emailing it.
  //
  // The property worth protecting is no longer "it never appears" (that is now
  // false by design). It is that the exposure is BOUNDED:
  //   * returned by THIS route only, and flagged as shown-once;
  //   * never logged, and never recoverable afterwards (only a bcrypt hash is
  //     stored, so there is no second read);
  //   * the stored credential is STILL a hash, never the plaintext.
  // Asserting the bounds is stronger than the old absence check, which would now
  // simply be wrong.
  const res = await request('POST', `/api/admin/partners/${PARTNER_ID}/credentials`, {
    headers: asAdmin(),
    body: {},
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.ok, true)
  assert.ok(res.body.loginId, 'a login id is returned')
  assert.equal(res.body.emailTo, 'http.partner@example.com')

  loginId = res.body.loginId

  // BOUND 1: the password is returned, and is usable.
  assert.equal(typeof res.body.password, 'string', 'the credential must be returned for the admin to relay')
  assert.ok(res.body.password.length >= 16, 'the returned password meets the enforced minimum length')
  issuedPasswordFromRoute = res.body.password

  // BOUND 2: the response says plainly that this is a one-shot reveal.
  assert.equal(res.body.passwordShownOnce, true, 'the response flags the password as shown once')

  // BOUND 3: it does not claim an email was sent — no email exists.
  assert.equal(res.body.emailSent, false, 'emailSent must be false: no automatic email exists')
  assert.ok(
    !/emailed/i.test(String(res.body.note || '')),
    'the note must not claim the credential was emailed',
  )

  // BOUND 4: NOTHING is stored in plaintext. This is the assertion that would
  // catch the genuinely dangerous regression — a change that persisted the
  // password, or returned a value that was not the one hashed.
  const rows = await q(
    `select login_id, password_hash, must_change_password, failed_login_count
     from public.partners where id = $1`,
    [PARTNER_ID],
  )
  assert.equal(rows[0].login_id, loginId)
  assert.match(rows[0].password_hash, /^\$2[aby]\$/, 'a bcrypt hash is stored')
  assert.notEqual(rows[0].password_hash, res.body.password, 'the plaintext is never stored')
  assert.ok(
    !rows[0].password_hash.includes(res.body.password),
    'the stored value must not contain the plaintext password',
  )
  assert.equal(rows[0].must_change_password, true, 'the forced change is set')
  assert.equal(Number(rows[0].failed_login_count), 0)

  // BOUND 5: it is not written to the audit trail either.
  const audit = await q(
    `select count(*)::int as n from public.partner_audit_log
      where partner_id = $1 and detail::text ilike '%' || $2 || '%'`,
    [PARTNER_ID, res.body.password],
  )
  assert.equal(audit[0].n, 0, 'the password must never appear in the audit log')
})

// ---------------------------------------------------------------------------
// 2. Login, and no enumeration
// ---------------------------------------------------------------------------
await test('login with a wrong password is rejected generically', async () => {
  const res = await request('POST', '/api/partner/login', {
    body: { loginId, password: 'totally-the-wrong-password' },
  })
  assert.equal(res.status, 401)
  assert.equal(res.body.error, 'Incorrect partner ID or password.')
})

await test('an unknown handle returns the IDENTICAL response (no enumeration)', async () => {
  const res = await request('POST', '/api/partner/login', {
    body: { loginId: 'SB-ZZZZZZ', password: 'totally-the-wrong-password' },
  })
  assert.equal(res.status, 401)
  assert.equal(
    res.body.error,
    'Incorrect partner ID or password.',
    'an unknown handle must be indistinguishable from a wrong password',
  )
})

await test('a malformed login request is rejected without revealing validity', async () => {
  const res = await request('POST', '/api/partner/login', { body: { loginId: '', password: '' } })
  assert.equal(res.status, 400)
})

await test('a valid login yields a session token stored only as a hash', async () => {
  // STRONGER THAN BEFORE, now that the credential route returns its password.
  //
  // This used to have to invent a password and set it through the DB function,
  // because the issued one could not be read back — which meant the admin route
  // and this login were never verified against the SAME value. It now uses the
  // password the route actually returned, so this is a true end-to-end check:
  // the value handed to the admin is the value that logs in.
  assert.ok(issuedPasswordFromRoute, 'the credentials route returned a password to log in with')

  const res = await request('POST', '/api/partner/login', {
    body: { loginId, password: issuedPasswordFromRoute },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.ok, true)
  assert.ok(res.body.token, 'a session token is returned')
  assert.equal(res.body.mustChangePassword, true, 'the forced change is reported')

  sessionToken = res.body.token
  issuedPassword = issuedPasswordFromRoute

  const rows = await q('select portal_token_hash from public.partners where id = $1', [PARTNER_ID])
  assert.notEqual(rows[0].portal_token_hash, sessionToken, 'the raw token is not stored')
  assert.equal(
    rows[0].portal_token_hash,
    crypto.createHash('sha256').update(sessionToken).digest('hex'),
    'only the SHA-256 of the session token is stored',
  )
})

// ---------------------------------------------------------------------------
// 3. The new session works on EXISTING, unmodified routes
// ---------------------------------------------------------------------------
await test('the login session works on the existing /api/partner/me route', async () => {
  const res = await request('GET', '/api/partner/me', { token: sessionToken })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.partner.email, 'http.partner@example.com')
})

await test('a forged session token is rejected', async () => {
  const res = await request('GET', '/api/partner/me', { token: 'not-a-real-session-token' })
  assert.equal(res.status, 401)
})

// ---------------------------------------------------------------------------
// 4. Dashboard
// ---------------------------------------------------------------------------
await test('the dashboard is scoped to the caller and exposes no KYC', async () => {
  const res = await request('GET', '/api/partner/dashboard', { token: sessionToken })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.loginId, loginId)
  assert.equal(res.body.status, 'submitted')

  assert.equal(res.body.performance.referrals, 0)
  assert.equal(res.body.performance.conversions, 0)
  assert.equal(res.body.commissions.total, 0)
  assert.equal(res.body.commissions.currency, 'INR')

  // CRITICAL: no KYC field may appear anywhere in the payload.
  const serialised = JSON.stringify(res.body)
  for (const forbidden of [
    'legal_name', 'legalName', 'pan_number', 'panNumber', 'gstin',
    'aadhaar', 'bank_', 'address', 'date_of_birth',
  ]) {
    assert.ok(!serialised.includes(forbidden), `the dashboard must not expose "${forbidden}"`)
  }
})

await test('the dashboard requires a session', async () => {
  const res = await request('GET', '/api/partner/dashboard')
  assert.equal(res.status, 401)
})

// ---------------------------------------------------------------------------
// 5. Forced password change
// ---------------------------------------------------------------------------
await test('changing the password requires the current one', async () => {
  const res = await request('POST', '/api/partner/change-password', {
    token: sessionToken,
    body: { currentPassword: 'wrong-current-password', newPassword: 'ChosenHttpPassword9876' },
  })
  assert.equal(res.status, 401, JSON.stringify(res.body))
})

await test('a too-short new password is refused', async () => {
  const res = await request('POST', '/api/partner/change-password', {
    token: sessionToken,
    body: { currentPassword: issuedPassword, newPassword: 'short' },
  })
  assert.equal(res.status, 400)
  assert.match(res.body.error, /16 characters/i)
})

await test('reusing the current password is refused', async () => {
  const res = await request('POST', '/api/partner/change-password', {
    token: sessionToken,
    body: { currentPassword: issuedPassword, newPassword: issuedPassword },
  })
  assert.equal(res.status, 400)
})

await test('a valid change rotates the session and the password', async () => {
  const res = await request('POST', '/api/partner/change-password', {
    token: sessionToken,
    body: { currentPassword: issuedPassword, newPassword: 'ChosenHttpPassword9876' },
  })
  assert.equal(res.status, 200, JSON.stringify(res.body))
  assert.equal(res.body.ok, true)
  assert.ok(res.body.token, 'a fresh session token is handed back')
  assert.notEqual(res.body.token, sessionToken, 'the session was rotated')

  // The pre-change token is dead: rotating the password invalidates the
  // session that performed the change.
  const old = await request('GET', '/api/partner/me', { token: sessionToken })
  assert.equal(old.status, 401, 'the pre-change session token is invalidated')

  const fresh = await request('GET', '/api/partner/me', { token: res.body.token })
  assert.equal(fresh.status, 200, 'the fresh token works')
  sessionToken = res.body.token

  // The admin-issued password no longer works; the chosen one does.
  const oldPw = await request('POST', '/api/partner/login', {
    body: { loginId, password: issuedPassword },
  })
  assert.equal(oldPw.status, 401, 'the admin-issued password stops working')

  const newPw = await request('POST', '/api/partner/login', {
    body: { loginId, password: 'ChosenHttpPassword9876' },
  })
  assert.equal(newPw.status, 200)
  assert.equal(newPw.body.mustChangePassword, false, 'the forced change is cleared')
})

// ---------------------------------------------------------------------------
// 6. Lockout through HTTP, and admin recovery
// ---------------------------------------------------------------------------
await test('repeated failures are throttled, and an admin reissue is the recovery path', async () => {
  // NOTE ON WHY THE LOCK ITSELF IS DRIVEN VIA SQL HERE.
  //
  // The lockout threshold is a DB property, proven exhaustively by
  // partner_auth.test.sql (8 failures -> locked, the CORRECT password still
  // refused, reissue clears it). It cannot be reproduced end-to-end over HTTP
  // in a single test run, because the route's own loginLimiter (10 attempts /
  // 15 min / IP) throws 429 long before 8 failures accumulate — which is
  // itself the desired behaviour, not a defect.
  //
  // So this test asserts the two things that ARE observable over HTTP:
  //   1. a flood of attempts is throttled (429), and
  //   2. the admin reissue route clears a locked row, so a locked-out partner
  //      can actually get back in.
  let throttled = false
  for (let i = 0; i < 16; i++) {
    const r = await request('POST', '/api/partner/login', {
      body: { loginId, password: `wrong-password-attempt-${i}` },
    })
    if (r.status === 429) { throttled = true; break }
    assert.equal(r.status, 401, `attempt ${i} should be a generic 401 or 429`)
  }
  assert.ok(throttled, 'a flood of login attempts is throttled with 429')

  // Put the row into the locked state 8 genuine failures would produce.
  await q(
    `update public.partners
     set failed_login_count = 8, locked_until = now() + interval '15 minutes'
     where id = $1`,
    [PARTNER_ID],
  )

  // The recovery must clear BOTH the lock and the counter, or the reissue
  // would appear to succeed while the partner still could not sign in.
  const reissue = await request('POST', `/api/admin/partners/${PARTNER_ID}/credentials`, {
    headers: asAdmin(),
    body: {},
  })
  assert.equal(reissue.status, 200, JSON.stringify(reissue.body))
  assert.equal(reissue.body.loginId, loginId, 'the handle is unchanged by a reissue')

  const after = await q(
    'select locked_until, failed_login_count, password_hash from public.partners where id = $1',
    [PARTNER_ID],
  )
  assert.equal(after[0].locked_until, null, 'the reissue cleared the lock')
  assert.equal(Number(after[0].failed_login_count), 0, 'the counter was reset')
  assert.match(after[0].password_hash, /^\$2[aby]\$/, 'a fresh bcrypt hash was set')
})

// ---------------------------------------------------------------------------
// 7. Nothing sensitive in the audit trail
// ---------------------------------------------------------------------------
await test('no password or hash appears in the audit trail', async () => {
  const rows = await q('select action, detail::text as detail from public.partner_audit_log order by id')
  assert.ok(rows.length > 0, 'the audit trail is populated')

  for (const r of rows) {
    assert.ok(
      !r.detail.includes('ChosenHttpPassword9876') && !r.detail.includes('KnownHttpPassword1234'),
      `audit action "${r.action}" leaked a password`,
    )
    assert.ok(
      !r.detail.includes('$2a$') && !r.detail.includes('$2b$') && !r.detail.includes('$2y$'),
      `audit action "${r.action}" leaked a password hash`,
    )
  }

  const actions = rows.map((r) => r.action)
  assert.ok(actions.includes('credentials_issued'), 'credential issuance was audited')
  assert.ok(actions.includes('login'), 'a successful login was audited')
  assert.ok(actions.includes('login_failed'), 'a failed login was audited')
  assert.ok(actions.includes('password_changed'), 'the password change was audited')
})

// The rate-limiter flood above leaves keep-alive sockets mid-flight. Let them
// settle before tearing the pool down, otherwise process.exit() can race the
// pg client's teardown on Windows (observed as an access violation AFTER all
// assertions have already passed).
await new Promise((r) => setTimeout(r, 250))
await pool.end()
console.log(`\n${pass} passed, ${fail} failed`)
if (fail) {
  console.log('\nFailures:')
  failures.forEach((f) => console.log('  - ' + f))
}
process.exit(fail ? 1 : 0)
