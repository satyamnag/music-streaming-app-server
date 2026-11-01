// ============================================================================
// AWS Secrets Manager loader (optional, default OFF).
//
// WHY
// ---
// The API keys now live in AWS Secrets Manager (ap-south-1). The server must be
// able to read them from there instead of the deployment env, so a leaked Render
// env no longer hands over billable third-party credentials.
//
// SAFETY CONTRACT
// ---------------
//   * Disabled unless AWS_SECRETS_ENABLED=1. With it unset this module is never
//     even imported, and the server behaves exactly as before.
//   * FAIL CLOSED, NEVER FATAL: a missing SDK, a timeout, AccessDenied or a
//     missing secret all leave `values` empty and the caller keeps whatever it
//     already had (Supabase Vault, then env). Boot never crashes because AWS is
//     unreachable.
//   * VALUES ARE NEVER LOGGED. Only names, and only as "loaded" / error code.
//   * Per-name isolation: one denied secret cannot stop the others loading.
// ============================================================================

export const AWS_DEFAULT_TIMEOUT_MS = 3000
export const AWS_REGION_FALLBACK = 'ap-south-1'

/**
 * Load secret names from AWS Secrets Manager.
 *
 * @param {object} args
 * @param {string[]} args.names            secret names, exact match
 * @param {object}   args.client           any client with .send() (injected: testable without AWS)
 * @param {Function} args.GetSecretValueCommand  command constructor from the SDK
 * @param {number}   [args.timeoutMs]
 * @returns {Promise<{values: Record<string,string>, loaded: string[], failed: Array<{name:string, reason:string}>}>}
 *          Never rejects.
 */
export async function loadAwsSecrets({
  names,
  client,
  GetSecretValueCommand,
  timeoutMs = AWS_DEFAULT_TIMEOUT_MS,
}) {
  const values = {}
  const loaded = []
  const failed = []

  if (!Array.isArray(names) || !names.length) return { values, loaded, failed }
  if (!client || typeof client.send !== 'function' || typeof GetSecretValueCommand !== 'function') {
    return { values, loaded, failed: names.map((name) => ({ name, reason: 'no_client' })) }
  }

  for (const name of names) {
    let timer = null
    try {
      const call = client.send(new GetSecretValueCommand({ SecretId: name }))
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => {
          const e = new Error('timeout')
          e.name = 'TimeoutError'
          e.code = 'timeout'
          reject(e)
        }, timeoutMs)
      })
      const res = await Promise.race([call, timeout])
      // SecretString is what we store (plain string). SecretBinary is not used.
      const secret = res && typeof res.SecretString === 'string' ? res.SecretString : ''
      if (!secret) { failed.push({ name, reason: 'empty_or_binary' }); continue }
      values[name] = secret
      loaded.push(name)
    } catch (err) {
      // Keep the reason short and free of any secret material. `code` wins
      // because AWS SDK errors carry it, while a plain Error only has a generic
      // name ("Error") that would say nothing useful.
      const code = (err && (err.code || err.Code || err.name)) || 'error'
      failed.push({ name, reason: String(code).slice(0, 60) })
    } finally {
      if (timer) clearTimeout(timer)
    }
  }

  return { values, loaded, failed }
}

/**
 * Best-effort region resolution. The Render env is authoritative; the fallback
 * matches where the secrets were actually created.
 */
export function resolveAwsRegion(env = process.env) {
  return env.AWS_REGION || env.AWS_DEFAULT_REGION || env.AWS_SECRETS_REGION || AWS_REGION_FALLBACK
}

/**
 * Build the real SDK client.
 *
 * The import is dynamic and guarded so that a missing dependency degrades to a
 * logged warning instead of preventing the server from booting.
 *
 * @returns {Promise<{client:object, GetSecretValueCommand:Function}|null>}
 */
export async function createAwsSecretsClient({ region } = {}) {
  try {
    const mod = await import('@aws-sdk/client-secrets-manager')
    const client = new mod.SecretsManagerClient({ region: region || resolveAwsRegion() })
    return { client, GetSecretValueCommand: mod.GetSecretValueCommand }
  } catch (err) {
    return null
  }
}
