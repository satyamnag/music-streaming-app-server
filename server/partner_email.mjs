// ============================================================================
// Partner Program — email transport
// ============================================================================
//
// The server previously had NO email capability: every outbound message in
// this product is either a Play/IAP receipt or the Supabase SMS/voice OTP
// hook. The Partner Program, however, requires email verification (an
// industry-standard control), so this module adds the SMALLEST transport
// that can send one transactional message.
//
// DESIGN CHOICES
//   * Zero new npm dependencies. It speaks the provider's HTTPS JSON API
//     directly with the built-in global `fetch` (Node 18+/Render's runtime).
//     Adding an SDK here would expand the supply-chain surface for one
//     call, which the repository's dependency policy discourages.
//   * Provider-agnostic. The transport is chosen from whatever secret is
//     configured (see `secrets` in server.js):
//       - RESEND_API_KEY   -> https://api.resend.com/emails
//       - POSTMARK_TOKEN   -> https://api.postmarkapp.com/email
//       - MAILGUN_API_KEY + MAILGUN_DOMAIN -> Mailgun messages API
//     Any one of these is enough. Configuration is read at call time (not
//     captured at import) so values loaded from Supabase Vault at startup
//     take effect without a restart-ordering bug.
//   * FAIL-CLOSED AND NON-FATAL. If nothing is configured, sending returns
//     `{ sent: false, reason: 'not_configured' }`. Registration still
//     succeeds and the partner sees "we could not send the email"; the
//     server logs loudly. It never throws into a request handler and never
//     pretends a message was delivered.
//   * NO SECRETS IN LOGS. Only the provider name and HTTP status are
//     logged; never the API key, the body, or the verification token.
//   * TEXT + HTML. Both bodies are provided, because a text/plain part
//     materially improves deliverability and is required by several
//     corporate mail filters.
//
// DELIVERABILITY NOTE (operational, not code)
//   Sending from a new domain requires the operator to publish SPF, DKIM
//   and DMARC DNS records and to verify the sending domain with the
//   provider. Until that is done, messages will be filtered. This is a
//   console/DNS task for the operator, and it is called out in the runbook
//   (docs/partner-program/README.md).

const TIMEOUT_MS = 10000

/**
 * Reads the current transport configuration from the live secrets object.
 * Passed in as a function so a Vault-loaded value is always honoured.
 *
 * @param {() => Record<string, string>} getSecrets
 */
export function describeTransport(getSecrets) {
  const s = getSecrets() || {}
  if (s.resend_api_key) return { provider: 'resend', ok: !!s.mail_from }
  if (s.postmark_token) return { provider: 'postmark', ok: !!s.mail_from }
  if (s.mailgun_api_key && s.mailgun_domain) {
    return { provider: 'mailgun', ok: !!s.mail_from }
  }
  // SMTP: send through an existing mailbox (Google Workspace, Microsoft 365)
  // rather than opening another vendor account. Requires host + user + password.
  if (s.smtp_host && s.smtp_user && s.smtp_password) {
    return { provider: 'smtp', ok: !!s.mail_from }
  }
  return { provider: null, ok: false }
}

/**
 * Sends one message over SMTP.
 *
 * WHY THIS EXISTS ALONGSIDE THE HTTP PROVIDERS
 * The HTTP providers each need a separate vendor account. Where the operator
 * already pays for a mailbox on their own domain (this project uses Google
 * Workspace — `MX: smtp.google.com`), sending through that mailbox avoids
 * adding a vendor while keeping SPF/DKIM alignment intact, because the
 * message is sent BY the domain that owns the mailbox.
 *
 * TRANSPORT DETAILS
 *   * `nodemailer` is imported LAZILY, inside this function. If it is not
 *     installed, the HTTP providers keep working and only this path fails —
 *     rather than the whole server failing to boot on a missing optional
 *     dependency.
 *   * `secure` is derived from the port: 465 is implicit TLS, 587 is
 *     STARTTLS. Getting this wrong hangs the connection rather than erroring.
 *   * Timeouts are set explicitly. A hung SMTP connection would otherwise
 *     hold the request open until the platform kills it.
 */
async function sendViaSmtp(s, { from, to, subject, text, html }) {
  let nodemailer
  try {
    nodemailer = (await import('nodemailer')).default
  } catch (_) {
    console.error('[partner-email] smtp requested but nodemailer is not installed')
    return { sent: false, provider: 'smtp', reason: 'nodemailer_not_installed' }
  }

  const port = Number(s.smtp_port || 587)
  const secure = port === 465 // 465 = implicit TLS; 587/25 = STARTTLS

  let transporter
  try {
    transporter = nodemailer.createTransport({
      host: s.smtp_host,
      port,
      secure,
      auth: { user: s.smtp_user, pass: s.smtp_password },
      // Without explicit timeouts a stalled connection holds the request open.
      connectionTimeout: TIMEOUT_MS,
      greetingTimeout: TIMEOUT_MS,
      socketTimeout: TIMEOUT_MS,
    })

    await transporter.sendMail({ from, to, subject, text, html })
    console.log('[partner-email] sent via smtp')
    return { sent: true, provider: 'smtp' }
  } catch (err) {
    // Never log the SMTP password or the full error object; the message can
    // echo the recipient address.
    const reason =
      err && /auth|credentials|535|534/i.test(String(err.message))
        ? 'smtp_auth_failed'
        : err && /timeout|ETIMEDOUT|ECONNECTION/i.test(String(err.message))
          ? 'smtp_connection_failed'
          : 'smtp_error'
    console.error(`[partner-email] smtp send failed: ${reason}`)
    return { sent: false, provider: 'smtp', reason }
  } finally {
    try { if (transporter) transporter.close() } catch (_) { /* ignore */ }
  }
}

/**
 * Sends one transactional email. Never throws.
 *
 * @returns {Promise<{sent: boolean, provider: string|null, reason?: string, status?: number}>}
 */
export async function sendEmail(getSecrets, { to, subject, text, html }) {
  const s = getSecrets() || {}
  const from = s.mail_from
  const transport = describeTransport(getSecrets)

  if (!transport.provider) {
    return { sent: false, provider: null, reason: 'not_configured' }
  }
  if (!from) {
    // A provider without a verified From address cannot send. Treat as
    // unconfigured rather than letting the provider 4xx confusingly.
    return { sent: false, provider: transport.provider, reason: 'no_from_address' }
  }

  // SMTP is a connection-oriented transport, not an HTTP call, so it takes its
  // own path rather than falling through to the fetch-based block below.
  if (transport.provider === 'smtp') {
    return sendViaSmtp(s, { from, to, subject, text, html })
  }

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)

  try {
    let url
    let headers
    let body

    if (transport.provider === 'resend') {
      url = 'https://api.resend.com/emails'
      headers = {
        Authorization: `Bearer ${s.resend_api_key}`,
        'Content-Type': 'application/json',
      }
      body = { from, to: [to], subject, text, html }
    } else if (transport.provider === 'postmark') {
      url = 'https://api.postmarkapp.com/email'
      headers = {
        'X-Postmark-Server-Token': s.postmark_token,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      }
      body = {
        From: from,
        To: to,
        Subject: subject,
        TextBody: text,
        HtmlBody: html,
        MessageStream: 'outbound',
      }
    } else {
      // Mailgun expects application/x-www-form-urlencoded.
      url = `https://api.mailgun.net/v3/${encodeURIComponent(s.mailgun_domain)}/messages`
      headers = {
        Authorization:
          'Basic ' + Buffer.from(`api:${s.mailgun_api_key}`).toString('base64'),
        'Content-Type': 'application/x-www-form-urlencoded',
      }
      body = new URLSearchParams({ from, to, subject, text, html }).toString()
    }

    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: typeof body === 'string' ? body : JSON.stringify(body),
      signal: controller.signal,
    })

    if (!res.ok) {
      // Read a bounded slice of the error for diagnosis. Provider error
      // bodies carry no secret, but they can echo the recipient address,
      // so only the status is logged and the (bounded) body is returned
      // to the caller for the admin log — never written to stdout.
      let detail = ''
      try {
        detail = (await res.text() || '').slice(0, 300)
      } catch (_) { /* ignore */ }
      console.error(`[partner-email] ${transport.provider} send failed: HTTP ${res.status}`)
      return {
        sent: false,
        provider: transport.provider,
        status: res.status,
        reason: 'provider_error',
        detail,
      }
    }

    console.log(`[partner-email] sent via ${transport.provider}`)
    return { sent: true, provider: transport.provider, status: res.status }
  } catch (err) {
    const reason = err && err.name === 'AbortError' ? 'timeout' : 'network_error'
    console.error(`[partner-email] ${transport.provider} send error: ${reason}`)
    return { sent: false, provider: transport.provider, reason }
  } finally {
    clearTimeout(timer)
  }
}

/**
 * Escapes a value for safe interpolation into the HTML email body.
 * The only interpolated values are the operator's brand name and a URL we
 * generated ourselves, but escaping costs nothing and removes the class of
 * bug entirely.
 */
export function escapeHtml(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}
