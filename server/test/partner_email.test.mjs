// Unit tests for the partner email transport selection.
//
// The transport is chosen from whichever secret is configured. Getting this
// wrong is silent: a mis-selected provider produces "could not send" with no
// clue why. These tests pin the selection rules and the SMTP path's behaviour.
//
// Run: node test/partner_email.test.mjs

import assert from 'node:assert/strict'
import { describeTransport, sendEmail } from '../partner_email.mjs'

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

const S = (o) => () => o

console.log('\n=== transport selection ===\n')

await test('nothing configured -> no provider', async () => {
  const t = describeTransport(S({}))
  assert.equal(t.provider, null)
  assert.equal(t.ok, false)
})

await test('resend key selects resend', async () => {
  const t = describeTransport(S({ resend_api_key: 're_x', mail_from: 'a@b.com' }))
  assert.equal(t.provider, 'resend')
  assert.equal(t.ok, true)
})

await test('postmark token selects postmark', async () => {
  const t = describeTransport(S({ postmark_token: 'p_x', mail_from: 'a@b.com' }))
  assert.equal(t.provider, 'postmark')
})

await test('mailgun needs BOTH key and domain', async () => {
  assert.equal(describeTransport(S({ mailgun_api_key: 'k' })).provider, null)
  assert.equal(
    describeTransport(S({ mailgun_api_key: 'k', mailgun_domain: 'd' })).provider,
    'mailgun',
  )
})

await test('smtp needs host AND user AND password', async () => {
  assert.equal(describeTransport(S({ smtp_host: 'h' })).provider, null)
  assert.equal(describeTransport(S({ smtp_host: 'h', smtp_user: 'u' })).provider, null)
  assert.equal(
    describeTransport(S({ smtp_host: 'h', smtp_user: 'u', smtp_password: 'p' })).provider,
    'smtp',
  )
})

await test('smtp is selected last, so an HTTP provider wins if both are set', async () => {
  const t = describeTransport(S({
    resend_api_key: 're_x', smtp_host: 'h', smtp_user: 'u', smtp_password: 'p',
    mail_from: 'a@b.com',
  }))
  assert.equal(t.provider, 'resend', 'resend should take precedence')
})

await test('a provider with no From address reports not-ok', async () => {
  const t = describeTransport(S({ resend_api_key: 're_x' }))
  assert.equal(t.provider, 'resend')
  assert.equal(t.ok, false, 'ok must be false without mail_from')
})

console.log('\n=== sendEmail guard rails ===\n')

await test('unconfigured send fails cleanly and never throws', async () => {
  const r = await sendEmail(S({}), { to: 'a@b.com', subject: 's', text: 't', html: '<p>x</p>' })
  assert.equal(r.sent, false)
  assert.equal(r.reason, 'not_configured')
})

await test('missing From is refused before any network attempt', async () => {
  const r = await sendEmail(
    S({ resend_api_key: 're_x' }),
    { to: 'a@b.com', subject: 's', text: 't', html: '<p>x</p>' },
  )
  assert.equal(r.sent, false)
  assert.equal(r.reason, 'no_from_address')
})

await test('smtp with an unreachable host fails without throwing', async () => {
  // 127.0.0.1:1 is closed, so this exercises the failure path (and the
  // timeouts) rather than hanging the test run.
  const r = await sendEmail(
    S({
      smtp_host: '127.0.0.1',
      smtp_port: '1',
      smtp_user: 'u',
      smtp_password: 'p',
      mail_from: 'a@b.com',
    }),
    { to: 'a@b.com', subject: 's', text: 't', html: '<p>x</p>' },
  )
  assert.equal(r.sent, false, 'must not report success')
  assert.equal(r.provider, 'smtp')
  assert.ok(
    ['smtp_connection_failed', 'smtp_error', 'smtp_auth_failed'].includes(r.reason),
    'reason should be an smtp failure, got: ' + r.reason,
  )
})

console.log(`\n${pass} passed, ${fail} failed`)
if (fail) {
  console.log('\nFailures:')
  failures.forEach((f) => console.log('  - ' + f))
}
process.exit(fail ? 1 : 0)
