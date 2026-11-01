// Tests for libs/awsSecrets.mjs.
//
// Run: node test/aws-secrets.test.mjs
//
// No AWS account and no network: the client is injected, which is exactly why
// loadAwsSecrets takes one. The property under test is FAIL-CLOSED - every
// failure shape must return an empty/partial result with a short reason and
// never throw, so a dead AWS cannot keep the server from booting.

import assert from 'node:assert/strict'
import { AWS_REGION_FALLBACK, loadAwsSecrets, resolveAwsNames, resolveAwsRegion } from '../libs/awsSecrets.mjs'

let passed = 0
let failed = 0
const tests = []
const test = (name, fn) => tests.push([name, fn])
const eq = (a, b, m) => assert.deepEqual(a, b, m)

/** Minimal command class the loader only ever constructs. */
class FakeCommand {
  constructor(input) { this.input = input }
}

/** behaviour: map of secretName -> 'ok' | {error} | 'empty' | 'hang' */
function fakeClient(behaviour) {
  return {
    sent: [],
    async send(cmd) {
      const name = cmd.input.SecretId
      this.sent.push(name)
      const b = behaviour[name] ?? 'ok'
      if (b === 'hang') return new Promise(() => {})
      if (b === 'empty') return { SecretString: '' }
      if (b && b.error) { const e = new Error(b.error); e.name = b.error; throw e }
      return { SecretString: `value-of-${name}` }
    },
  }
}

test('loads every requested secret and reports the names, never the values', async () => {
  const client = fakeClient({})
  const res = await loadAwsSecrets({
    names: ['deepgram_api_key', 'openai_api_key'],
    client, GetSecretValueCommand: FakeCommand,
  })
  eq(res.loaded, ['deepgram_api_key', 'openai_api_key'])
  eq(res.failed, [])
  eq(res.values.deepgram_api_key, 'value-of-deepgram_api_key')
  eq(client.sent, ['deepgram_api_key', 'openai_api_key'])
})

test('one denied secret does not stop the others loading', async () => {
  const client = fakeClient({ deepgram_api_key: { error: 'AccessDeniedException' } })
  const res = await loadAwsSecrets({
    names: ['deepgram_api_key', 'openai_api_key'],
    client, GetSecretValueCommand: FakeCommand,
  })
  eq(res.loaded, ['openai_api_key'])
  eq(res.failed, [{ name: 'deepgram_api_key', reason: 'AccessDeniedException' }])
  eq(res.values.deepgram_api_key, undefined)
})

test('a missing secret reports ResourceNotFound and keeps going', async () => {
  const client = fakeClient({ openai_api_key: { error: 'ResourceNotFoundException' } })
  const res = await loadAwsSecrets({
    names: ['deepgram_api_key', 'openai_api_key'],
    client, GetSecretValueCommand: FakeCommand,
  })
  eq(res.loaded, ['deepgram_api_key'])
  assert.equal(res.failed[0].reason, 'ResourceNotFoundException')
})

test('an empty or binary-only secret is rejected rather than stored blank', async () => {
  const client = fakeClient({ openai_api_key: 'empty' })
  const res = await loadAwsSecrets({
    names: ['openai_api_key'], client, GetSecretValueCommand: FakeCommand,
  })
  eq(res.loaded, [])
  eq(res.failed, [{ name: 'openai_api_key', reason: 'empty_or_binary' }])
  eq(res.values.openai_api_key, undefined)
})

test('a hung call times out and the loader still returns', async () => {
  const client = fakeClient({ openai_api_key: 'hang' })
  const started = Date.now()
  const res = await loadAwsSecrets({
    names: ['openai_api_key'], client, GetSecretValueCommand: FakeCommand, timeoutMs: 200,
  })
  eq(res.loaded, [])
  eq(res.failed, [{ name: 'openai_api_key', reason: 'timeout' }])
  assert.ok(Date.now() - started < 3000, 'the timeout must actually bound the wait')
})

test('a missing client or SDK fails closed without throwing', async () => {
  const noClient = await loadAwsSecrets({ names: ['a'], client: null, GetSecretValueCommand: FakeCommand })
  eq(noClient.loaded, [])
  eq(noClient.failed, [{ name: 'a', reason: 'no_client' }])

  const noCommand = await loadAwsSecrets({ names: ['a'], client: fakeClient({}) })
  eq(noCommand.failed, [{ name: 'a', reason: 'no_client' }])

  const noNames = await loadAwsSecrets({ names: [], client: fakeClient({}), GetSecretValueCommand: FakeCommand })
  eq(noNames, { values: {}, loaded: [], failed: [] })
})

test('region resolves env-first, then the region the secrets live in', () => {
  eq(resolveAwsRegion({ AWS_REGION: 'eu-west-1' }), 'eu-west-1')
  eq(resolveAwsRegion({ AWS_DEFAULT_REGION: 'us-east-2' }), 'us-east-2')
  eq(resolveAwsRegion({ AWS_SECRETS_REGION: 'ap-south-1' }), 'ap-south-1')
  eq(resolveAwsRegion({}), AWS_REGION_FALLBACK)
})

test('internal keys are translated to the account service/api-key convention', () => {
  // The rest of the account stores secrets as `superwall/api-key`,
  // `onesignal/api-key`, `posthog/api-key`. These two follow the same shape
  // while the server keeps its original internal names.
  const mapped = resolveAwsNames(['deepgram_api_key', 'openai_api_key', 'admin_token'])
  eq(mapped, [
    { internal: 'deepgram_api_key', aws: 'deepgram/api-key' },
    { internal: 'openai_api_key', aws: 'openai/api-key' },
    { internal: 'admin_token', aws: 'admin_token' },
  ])
  eq(resolveAwsNames([]), [])
  eq(resolveAwsNames(null), [])
})

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

for (const [name, fn] of tests) {
  try {
    await fn()
    passed++
    console.log(`  ok   ${name}`)
  } catch (err) {
    failed++
    console.error(`  FAIL ${name}`)
    console.error(`       ${err.message}`)
  }
}

console.log(`\n${passed} passed, ${failed} failed, ${passed + failed} total`)
process.exit(failed ? 1 : 0)
