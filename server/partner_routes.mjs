// ============================================================================
// Partner Program — public portal API + admin review API
// ============================================================================
//
// Mounted from server.js via `registerPartnerRoutes(app, deps)`. Kept in its
// own module so the (already large) server.js gains one import and one call
// rather than several hundred lines.
//
// ---------------------------------------------------------------------------
// THREAT MODEL AND TRUST BOUNDARIES
// ---------------------------------------------------------------------------
//
// The partner portal is a PUBLIC, unauthenticated surface that collects
// government identity documents. That makes it the most sensitive public
// endpoint in this product, so the boundaries are explicit:
//
//   1. A partner authenticates with a 256-bit bearer token issued at
//      registration. Only its SHA-256 hash is stored. Every partner-facing
//      call passes that token, and the database resolves the row FROM THE
//      HASH — the portal never sends a partner id, so it can never address
//      another partner's row. There is no IDOR surface by construction.
//
//   2. NO anon/authenticated RLS policy exists on any partner table, and the
//      KYC storage bucket is private with no storage policy. Even if the app
//      bundle's anon key leaks, it reads nothing. All access is brokered by
//      this service-role server.
//
//   3. Admin access reuses the existing `requireAdmin` middleware, so the
//      Partner review queue inherits the same Clerk-domain / ADMIN_TOKEN
//      session protection as the rest of the admin panel.
//
//   4. Documents are encrypted at the application layer before upload
//      (partner_crypto.mjs). Admins never receive a public URL: the bytes
//      are proxied through this server so the OWASP-prescribed download
//      headers are actually enforceable, and every single access is written
//      to an append-only audit log.
//
//   5. Input is validated server-side against an authoritative allow-list.
//      The client's Content-Type is treated as a hint, never as fact.
//
// ---------------------------------------------------------------------------
// PRIVACY / LEGAL POSITION (evidence in migrations/033_partner_program.sql)
// ---------------------------------------------------------------------------
//   * Aadhaar is NOT collected or stored (Aadhaar Act 2016 s.8A(4)(b) as
//     inserted in 2019 prohibits collecting/storing an Aadhaar number for
//     offline verification; s.33A carries penalties up to Rs 1 crore).
//   * Consent is explicit, purpose-limited and recorded with the policy
//     version the partner agreed to (DPDP Act 2023 s.6).
//   * PII is masked in logs; IPs are stored only as salted hashes.
//   * Rejected/withdrawn applications get a purge deadline set in the DB.
//
// NOTE ON EMAIL: the server previously had no email capability. Partner
// email verification needs one, so partner_email.mjs provides a minimal,
// dependency-free, fail-closed transport. If it is unconfigured, the portal
// says so plainly rather than pretending a message was sent.

import multer from 'multer'
import { rateLimit, ipKeyGenerator } from 'express-rate-limit'
import QRCode from 'qrcode'

import {
  encryptDocument,
  decryptDocument,
  validateDocumentUpload,
  generateToken,
  generatePartnerPassword,
  sha256Hex,
  sha256HexOfString,
  hashIp,
  encryptionReady,
  ALLOWED_DOC_MIME,
} from './partner_crypto.mjs'

import { sendEmail, escapeHtml, describeTransport } from './partner_email.mjs'

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const KYC_BUCKET = 'partner-kyc'
const MAX_DOC_BYTES = 5 * 1024 * 1024 // 5 MB per document
const MAX_DOCS_PER_PARTNER = 15
const PORTAL_TOKEN_BYTES = 32 // 256 bits
const VERIFY_TOKEN_TTL_MINUTES = 24 * 60 // 24 hours
const VERIFY_RESEND_COOLDOWN_SECONDS = 60

// The Play listing the partner QR points at. Kept identical to the existing
// affiliate QR route so the SHIPPED Android install-referrer pipeline keeps
// working unchanged (zero app changes — a hard requirement).
const PLAY_PACKAGE = 'com.soulfulbhakti.app'
const PLAY_URL = `https://play.google.com/store/apps/details?id=${PLAY_PACKAGE}`

// Required document sets, mirrored from the SQL `partner_submit` validation.
// Kept here too so the UI can tell the partner what is still missing WITHOUT
// a round trip, while the database remains the authority.
const REQUIRED_DOCS = {
  individual: ['pan_card', 'address_proof'],
  business: [
    'pan_card',
    'address_proof',
    'business_registration', // satisfied by ANY of the business doc types
  ],
}

const BUSINESS_REGISTRATION_DOCS = [
  'gst_certificate',
  'incorporation_certificate',
  'udyam_certificate',
  'shop_establishment_licence',
  'partnership_deed',
  'trust_deed',
]

const DOC_LABELS = {
  pan_card: 'PAN card',
  passport: 'Passport',
  voter_id: 'Voter ID',
  driving_licence: 'Driving licence',
  address_proof: 'Address proof',
  gst_certificate: 'GST certificate',
  incorporation_certificate: 'Certificate of incorporation',
  udyam_certificate: 'Udyam (MSME) certificate',
  shop_establishment_licence: 'Shop & Establishment licence',
  partnership_deed: 'Partnership deed',
  trust_deed: 'Trust deed',
  bank_proof: 'Bank proof (cancelled cheque / statement)',
  authorised_signatory_proof: 'Authorised signatory proof',
  other: 'Other supporting document',
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

export function registerPartnerRoutes(app, deps) {
  const {
    supabase,
    secrets,
    requireAdmin,
    requireClerkAdmin,
    publicBaseUrl,
    log = console,
  } = deps

  // Live reads so Vault-loaded values are honoured.
  const getSecrets = () => secrets

  // -------------------------------------------------------------------------
  // Rate limiters
  // -------------------------------------------------------------------------
  //
  // `trust proxy` is already set to 1 in server.js (verified requirement for
  // Render, which fronts the service with a load balancer). `ipv6Subnet`
  // defaults to 56 in express-rate-limit, which matters here: Indian mobile
  // ISPs commonly delegate a large IPv6 prefix, so a per-address limit alone
  // is trivially bypassed by walking the range.
  //
  // NOTE ON THE DEFAULT STORE: MemoryStore resets on restart and multiplies
  // across instances. These limits are therefore a coarse abuse floor, not a
  // hard quota. The authoritative limits are the per-partner document cap and
  // the resend window enforced in Postgres.

  const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: 'Too many registration attempts. Please try again later.' },
  })

  const verifyLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 20,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: 'Too many attempts. Please try again later.' },
  })

  // Sign-in is the credential-stuffing target, so it is limited harder than
  // the general verify bucket. This is a COARSE IP-level floor only: the
  // authoritative throttle is the per-account lockout in partner_login(),
  // which follows the account rather than the source address and therefore
  // also defeats a distributed attempt against one handle.
  const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    ipv6Subnet: 56,
    message: { error: 'Too many sign-in attempts. Please try again later.' },
  })

  const resendLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 5,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: 'Too many resend requests. Please wait.' },
  })

  const uploadLimiterSubnet = rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 60,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    ipv6Subnet: 56,
    message: { error: 'Too many uploads from this network.' },
  })

  const submitLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 30,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: 'Too many attempts. Please try again later.' },
  })

  // Multer: memory storage only. Uploads are never written to the app
  // container's filesystem (OWASP: store outside the webroot / on a separate
  // host), and the byte cap is enforced by the parser itself so an oversized
  // body is rejected before it becomes a memory problem.
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: MAX_DOC_BYTES, files: 1, fields: 12 },
  })

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  const ipHashSalt = () => secrets.partner_ip_salt || secrets.admin_token || 'sb'

  function clientIpHash(req) {
    return hashIp(req.ip, ipHashSalt())
  }

  /** Bounded, control-character-stripped User-Agent for the audit log. */
  function safeUserAgent(req) {
    return String(req.headers['user-agent'] || '')
      .replace(/[\u0000-\u001F\u007F]/g, '')
      .slice(0, 300)
  }

  /**
   * The base URL used to build the emailed verification link.
   *
   * `PARTNER_PUBLIC_BASE_URL` is the single source of truth when set. It is the
   * branded public origin (https://soulfulbhakti.com), so the link a partner
   * receives shows the domain they recognise rather than the infrastructure
   * host. That origin serves /partner via the marketing website, which forwards
   * to this portal — so the link works whichever end the partner starts from.
   *
   * Falling back to the request host keeps local development and any
   * un-configured deployment working without special-casing.
   */
  function resolveBaseUrl(req) {
    if (publicBaseUrl) return publicBaseUrl.replace(/\/+$/, '')
    // Derive from the request. `trust proxy` is set, so protocol/host reflect
    // the external origin rather than the internal Render address.
    return `${req.protocol}://${req.get('host')}`
  }

  /**
   * The origin that actually SERVES the portal API, which is where the
   * verification link must ultimately land.
   *
   * When the branded origin is a different host (soulfulbhakti.com forwards to
   * the portal), pointing the emailed link straight at the serving host avoids
   * depending on that forward staying in place for a one-time security token.
   * The branded path is still used when it IS the serving host, so local dev
   * and single-host deployments are unaffected.
   */
  function resolveVerifyBaseUrl(req) {
    const serving = `${req.protocol}://${req.get('host')}`
    if (!publicBaseUrl) return serving
    try {
      const branded = new URL(publicBaseUrl)
      const s = new URL(serving)
      // Same host (the common case): use the branded base verbatim.
      if (branded.host === s.host) return publicBaseUrl.replace(/\/+$/, '')
      // Different host: the token must reach the server that can consume it.
      return serving
    } catch (_) {
      return serving
    }
  }

  /**
   * Extracts the portal bearer token. Accepts an Authorization header or a
   * JSON body field, so both fetch() callers and simple form posts work.
   */
  function portalToken(req) {
    const auth = req.headers.authorization || ''
    if (auth.startsWith('Bearer ')) return auth.slice(7).trim()
    if (req.body && typeof req.body.token === 'string') return req.body.token.trim()
    if (req.query && typeof req.query.token === 'string') return req.query.token.trim()
    return ''
  }

  /** Uniform shape returned to the portal for the partner's own record. */
  function publicPartnerView(row) {
    if (!row) return null
    // Only fields the partner is allowed to see about themselves. Lifecycle
    // and admin-only fields (decision_note is partner-visible by design, but
    // reviewed_by / affiliate internals are not) are filtered here rather
    // than relying on the UI to hide them.
    return {
      id: row.id,
      email: row.email,
      emailVerified: !!row.email_verified,
      status: row.status,
      applicantType: row.applicant_type,
      legalName: row.legal_name,
      displayName: row.display_name,
      entityType: row.entity_type,
      gender: row.gender,
      dateOfBirth: row.date_of_birth,
      phone: row.phone,
      addressLine1: row.address_line1,
      addressLine2: row.address_line2,
      city: row.city,
      state: row.state,
      postalCode: row.postal_code,
      country: row.country,
      panNumber: row.pan_number,
      gstin: row.gstin,
      aadhaarLast4: row.aadhaar_last4,
      aadhaarConsent: row.aadhaar_consent,
      bankAccountName: row.bank_account_name,
      bankAccountLast4: row.bank_account_last4,
      bankIfsc: row.bank_ifsc,
      audienceSize: row.audience_size,
      promotionPlan: row.promotion_plan,
      websiteUrl: row.website_url,
      socialLinks: row.social_links || {},
      termsAccepted: row.terms_accepted,
      termsVersion: row.terms_version,
      privacyAccepted: row.privacy_accepted,
      privacyVersion: row.privacy_version,
      truthfulnessDeclared: row.truthfulness_declared,
      submittedAt: row.submitted_at,
      decisionNote: row.decision_note,
      approvedAt: row.approved_at,
      createdAt: row.created_at,
      // Issued artefacts are only exposed once approved.
      ...(row.status === 'approved'
        ? {
            commissionAmount: row.commission_amount,
          }
        : {}),
    }
  }

  /**
   * Audit helper for partner-initiated actions that are not already logged
   * inside a SQL function.
   */
  async function auditPartner(partnerId, action, detail, req) {
    try {
      await supabase.from('partner_audit_log').insert({
        partner_id: partnerId,
        actor_type: 'partner',
        action,
        detail: detail || {},
        ip_hash: req ? clientIpHash(req) : null,
        user_agent: req ? safeUserAgent(req) : null,
      })
    } catch (err) {
      // Never let an audit write failure break a user-facing request; it is
      // logged loudly for investigation instead.
      log.error('[partner] audit write failed:', err && err.message)
    }
  }

  // -------------------------------------------------------------------------
  // Public: program info + health
  // -------------------------------------------------------------------------

  // What the portal needs to render its initial state: whether email can be
  // sent at all, and whether document upload is available. Both are
  // non-secret booleans, and surfacing them lets the UI disable a flow that
  // cannot succeed rather than failing confusingly later.
  app.get('/api/partner/config', (req, res) => {
    res.json({
      emailEnabled: !!describeTransport(getSecrets).provider,
      encryptionReady: encryptionReady(getSecrets),
      maxDocumentBytes: MAX_DOC_BYTES,
      allowedDocumentMime: ALLOWED_DOC_MIME,
      requiredDocuments: REQUIRED_DOCS,
      businessRegistrationDocuments: BUSINESS_REGISTRATION_DOCS,
      documentLabels: DOC_LABELS,
      consentVersion: secrets.partner_consent_version || '2026-01',
      disclosureVersion: secrets.partner_disclosure_version || '2026-01',
      // Shown to the partner so withdrawal is informed: processing stops at
      // once, but deletion is bounded by the statutory retention floor.
      retentionNotice:
        'If you withdraw, we stop processing your application immediately. ' +
        'We keep your information for a minimum period required by Indian data ' +
        'protection law, after which it is deleted.',
    })
  })

  // -------------------------------------------------------------------------
  // Public: register
  // -------------------------------------------------------------------------

  app.post('/api/partner/register', registerLimiter, async (req, res, next) => {
    try {
      const email = String((req.body && req.body.email) || '').trim().toLowerCase()

      // Basic shape check. Deliberately permissive: a stricter regex rejects
      // valid addresses, and the only thing that actually proves an address
      // works is delivering to it.
      if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return res.status(400).json({ error: 'Enter a valid email address.' })
      }

      const { data, error } = await supabase.rpc('partner_register', {
        p_email: email,
        p_ip_hash: clientIpHash(req),
      })
      if (error) {
        log.error('[partner] register rpc failed:', error.message)
        return res.status(503).json({ error: 'Registration is temporarily unavailable.' })
      }

      const row = Array.isArray(data) ? data[0] : data
      const partnerId = row && row.partner_id
      const rawToken = row && row.portal_token
      const existing = !!(row && row.existing)

      // ---- USER-ENUMERATION RESISTANCE (ASVS 6.3.8) ----------------------
      // The response is identical whether or not this email was already
      // registered. For a duplicate we do NOT return a token and we do NOT
      // send a verification link; instead the real owner is emailed a notice
      // that someone attempted registration. An attacker therefore cannot
      // use this endpoint to discover which addresses are enrolled.
      if (existing || !rawToken) {
        if (existing && partnerId) {
          // Best-effort courtesy notice to the address owner. Sent
          // asynchronously and never surfaced to the caller.
          notifyDuplicateRegistration(partnerId, email).catch(() => {})
        }
        return res.status(202).json({
          ok: true,
          message: 'If this address can be registered, a verification email is on its way.',
        })
      }

      // ---- Issue and send the verification email ------------------------
      const verifyToken = generateToken()
      const { data: setOk, error: setErr } = await supabase.rpc(
        'partner_set_verification_token',
        {
          p_partner_id: partnerId,
          p_raw_token: verifyToken,
          p_ttl_minutes: VERIFY_TOKEN_TTL_MINUTES,
        },
      )
      if (setErr || setOk === false) {
        log.error('[partner] set verification token failed:', setErr && setErr.message)
        // The account exists; the partner can retry the resend endpoint.
        return res.status(202).json({
          ok: true,
          token: rawToken,
          emailSent: false,
          message: 'Account created, but we could not send the verification email yet.',
        })
      }

      const sent = await sendVerificationEmail({
        email,
        token: verifyToken,
        baseUrl: resolveVerifyBaseUrl(req),
      })

      // The portal token IS returned here — it is the credential the partner
      // now holds. It is never emailed and never logged.
      res.status(201).json({
        ok: true,
        token: rawToken,
        emailSent: sent.sent,
        emailReason: sent.sent ? null : sent.reason,
        message: sent.sent
          ? 'Check your inbox for a verification link.'
          : 'Account created, but we could not send the verification email yet.',
      })
    } catch (err) {
      next(err)
    }
  })

  // -------------------------------------------------------------------------
  // Email verification
  // -------------------------------------------------------------------------

  /**
   * Sends the verification email. Returns the transport result; never throws.
   */
  async function sendVerificationEmail({ email, token, baseUrl }) {
    const link = `${baseUrl}/partner/verify?token=${encodeURIComponent(token)}`
    const brand = secrets.partner_brand_name || 'Soulful Bhakti'
    const subject = `Verify your email to continue your ${brand} Partner application`

    const text = [
      `Namaste,`,
      ``,
      `Thank you for your interest in the ${brand} Partner Program.`,
      ``,
      `Please confirm your email address by opening this link:`,
      link,
      ``,
      `This link can be used once and expires in 24 hours.`,
      ``,
      `If you did not request this, you can safely ignore this email — no`,
      `account will be activated and no further messages will be sent.`,
      ``,
      `— ${brand}`,
    ].join('\n')

    const html = `<!doctype html>
<html><body style="margin:0;padding:24px;background:#f6f4ef;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#2b2b2b;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;border:1px solid #e8e2d6;">
    <h1 style="margin:0 0 8px;font-size:20px;">${escapeHtml(brand)} Partner Program</h1>
    <p style="margin:0 0 20px;color:#6b6b6b;font-size:14px;">Confirm your email address</p>
    <p style="margin:0 0 20px;font-size:15px;line-height:1.6;">Namaste,<br>Thank you for your interest in the ${escapeHtml(brand)} Partner Program. Please confirm your email address to continue your application.</p>
    <p style="margin:0 0 24px;"><a href="${escapeHtml(link)}" style="display:inline-block;background:#8a6d3b;color:#ffffff;text-decoration:none;padding:12px 22px;border-radius:8px;font-weight:600;font-size:15px;">Verify my email</a></p>
    <p style="margin:0 0 8px;font-size:13px;color:#6b6b6b;">Or paste this link into your browser:</p>
    <p style="margin:0 0 24px;font-size:12px;word-break:break-all;color:#8a6d3b;">${escapeHtml(link)}</p>
    <p style="margin:0;font-size:13px;color:#6b6b6b;line-height:1.6;">This link can be used once and expires in 24 hours. If you did not request it, you can safely ignore this email.</p>
  </div>
</body></html>`

    return sendEmail(getSecrets, { to: email, subject, text, html })
  }

  /**
   * Courtesy notice for a duplicate registration attempt. Deliberately
   * contains no token and no account details — it only tells the real owner
   * that someone tried, which is the safe direction to leak.
   */
  async function notifyDuplicateRegistration(partnerId, email) {
    const brand = secrets.partner_brand_name || 'Soulful Bhakti'
    const subject = `Someone tried to register with your email on ${brand}`
    const text = [
      `Namaste,`,
      ``,
      `Someone entered this email address while starting a ${brand} Partner`,
      `Program application. Because this address is already registered, we`,
      `did not create a second account and we sent no verification link.`,
      ``,
      `If this was you, simply continue with your existing application —`,
      `your original verification email is still valid.`,
      ``,
      `If this was not you, no action is needed.`,
      ``,
      `— ${brand}`,
    ].join('\n')

    const result = await sendEmail(getSecrets, {
      to: email,
      subject,
      text,
      html: `<p>Namaste,</p><p>Someone entered this email address while starting a ${escapeHtml(brand)} Partner Program application. Because this address is already registered, we did not create a second account and sent no verification link.</p><p>If this was you, continue with your existing application.</p><p>If this was not you, no action is needed.</p><p>— ${escapeHtml(brand)}</p>`,
    })
    await auditPartner(partnerId, 'duplicate_registration_notice', {
      sent: result.sent,
      reason: result.reason || null,
    })
    return result
  }

  // Resend the verification email. Rate-limited per IP and additionally
  // windowed per account (a resend also invalidates the previous link).
  app.post('/api/partner/resend-verification', resendLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const { data, error } = await supabase.rpc('partner_prepare_verification', {
        p_token: token,
        p_ip_hash: clientIpHash(req),
      })
      if (error) {
        log.error('[partner] prepare verification failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }

      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.can_send) {
        const reason = (row && row.reason) || 'invalid_session'
        if (reason === 'already_verified') {
          return res.json({ ok: true, message: 'This email is already verified.' })
        }
        if (reason === 'rate_limited') {
          // Per-account window (5/hour) rather than the coarser IP limiter.
          return res.status(429).json({
            error: 'We have already sent several emails. Please check your inbox and spam folder.',
          })
        }
        return res.status(401).json({ error: 'Invalid or expired session.' })
      }

      const verifyToken = generateToken()
      const { data: setOk, error: setErr } = await supabase.rpc(
        'partner_set_verification_token',
        {
          p_partner_id: row.partner_id,
          p_raw_token: verifyToken,
          p_ttl_minutes: VERIFY_TOKEN_TTL_MINUTES,
        },
      )
      if (setErr || setOk === false) {
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }

      const sent = await sendVerificationEmail({
        email: row.email,
        token: verifyToken,
        baseUrl: resolveVerifyBaseUrl(req),
      })

      await auditPartner(row.partner_id, 'verification_resent', {
        sent: sent.sent,
        reason: sent.reason || null,
      }, req)

      if (!sent.sent) {
        return res.status(503).json({
          error: 'We could not send the email right now. Please try again shortly.',
        })
      }
      res.json({ ok: true, message: 'Verification email sent.' })
    } catch (err) {
      next(err)
    }
  })

  // Consume the verification link. This endpoint is what the emailed URL
  // hits, so it must be safe to open from a mail client and must never leak
  // whether a token merely expired versus never existed.
  app.get('/api/partner/verify', verifyLimiter, async (req, res, next) => {
    try {
      const raw = String(req.query.token || '')
      if (!raw) return renderVerifyPage(res, false, 'This verification link is not valid.')
      if (raw.length > 200) return renderVerifyPage(res, false, 'This verification link is not valid.')

      const { data, error } = await supabase.rpc('partner_consume_verification', {
        p_raw_token: raw,
      })
      if (error) {
        log.error('[partner] consume verification failed:', error.message)
        return renderVerifyPage(res, false, 'We could not verify this link right now. Please try again.')
      }

      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        const reason = (row && row.reason) || 'invalid'
        const message =
          reason === 'expired'
            ? 'This verification link has expired. Open your application and request a new one.'
            : reason === 'already_used'
              ? 'This link has already been used. You can continue with your application.'
              : 'This verification link is not valid or has already been used.'
        return renderVerifyPage(res, false, message)
      }

      // Success. The portal reads its session from localStorage/cookie, so
      // send the partner to the portal rather than to a dead-end page.
      return res.redirect(302, '/partner/verified')
    } catch (err) {
      next(err)
    }
  })

  function renderVerifyPage(res, ok, message) {
    res
      .status(ok ? 200 : 400)
      .type('html')
      .send(`<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Partner email verification</title></head>
<body style="margin:0;padding:40px 20px;background:#f6f4ef;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#2b2b2b;">
<div style="max-width:520px;margin:0 auto;background:#fff;border:1px solid #e8e2d6;border-radius:12px;padding:32px;text-align:center;">
<h1 style="font-size:19px;margin:0 0 12px;">${ok ? 'Email verified' : 'Verification problem'}</h1>
<p style="font-size:15px;line-height:1.6;color:#555;margin:0 0 20px;">${escapeHtml(message)}</p>
<p><a href="/partner" style="display:inline-block;background:#8a6d3b;color:#fff;text-decoration:none;padding:11px 20px;border-radius:8px;font-weight:600;">Go to the Partner Portal</a></p>
</div></body></html>`)
  }

  // -------------------------------------------------------------------------
  // Partner self-service (session-token authenticated)
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Public: partner login (admin-issued credentials)
  // -------------------------------------------------------------------------
  //
  // PIPELINE CHANGE: partners no longer self-register a public account. The
  // admin creates the account and issues a login id + password. This endpoint
  // exchanges those for a session token of exactly the shape the rest of the
  // portal already uses, so no downstream route changed.
  //
  // The DB function deliberately returns the SAME generic reason for an
  // unknown handle, a wrong password and a locked account, and burns
  // comparable CPU on each, so this endpoint is not a user-enumeration
  // oracle. The response below preserves that: one message for every failure.
  app.post('/api/partner/login', loginLimiter, async (req, res, next) => {
    try {
      const body = req.body || {}
      const loginId = String(body.loginId || '').trim()
      const password = String(body.password || '')

      // Shape checks only. Deliberately NOT a policy check: telling the
      // caller "your password is too short" would reveal that the handle was
      // otherwise valid.
      if (!loginId || loginId.length > 64 || !password || password.length > 512) {
        return res.status(400).json({ error: 'Enter your partner ID and password.' })
      }

      const { data, error } = await supabase.rpc('partner_login', {
        p_login_id: loginId,
        p_password: password,
        p_ip_hash: clientIpHash(req),
      })
      if (error) {
        log.error('[partner] login rpc failed:', error.message)
        return res.status(503).json({ error: 'Sign-in is temporarily unavailable.' })
      }

      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        // ONE message for every failure mode. Do not add detail here: any
        // distinction reintroduces the enumeration oracle the DB avoids.
        return res.status(401).json({ error: 'Incorrect partner ID or password.' })
      }

      res.json({
        ok: true,
        token: row.portal_token,
        partnerId: row.partner_id,
        mustChangePassword: !!row.must_change,
      })
    } catch (err) {
      next(err)
    }
  })

  // The partner's own read-only dashboard. Authorised by session token and
  // scoped to the caller's own row inside the DB (the affiliate is resolved
  // FROM the partner row, never accepted as a parameter).
  app.get('/api/partner/dashboard', verifyLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const { data, error } = await supabase.rpc('partner_dashboard', { p_token: token })
      if (error) {
        log.error('[partner] dashboard rpc failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }
      const row = Array.isArray(data) ? data[0] : data
      // No row => the session is not valid. Same response as an expired
      // session so the two are indistinguishable.
      if (!row) return res.status(401).json({ error: 'Invalid or expired session.' })

      res.json({
        // NOTE: no KYC data crosses this boundary by design. The dashboard
        // shows artefacts and aggregates only.
        //
        // partnerId is included because the partner's own QR image is
        // addressed by id (/api/partner/qr/:id), and that route verifies the
        // id matches the CALLER'S OWN session before returning anything — so
        // exposing it here grants no additional reach.
        partnerId: row.partner_id,
        status: row.status,
        loginId: row.login_id,
        mustChangePassword: !!row.must_change_password,
        approvedAt: row.approved_at,
        partner: {
          referrerCode: row.referrer_code || null,
          installUrl: row.install_url || null,
          couponCode: row.coupon_code || null,
          couponStatus: row.coupon_status || null,
          couponMaxRedemptions: row.coupon_max_redemptions,
          couponRedemptionCount: row.coupon_redemption_count,
          couponExpiresAt: row.coupon_expires_at,
        },
        performance: {
          commissionRate: row.commission_rate,
          referrals: Number(row.referral_count || 0),
          conversions: Number(row.conversion_count || 0),
          firstReferralAt: row.first_referral_at,
          lastReferralAt: row.last_referral_at,
        },
        // COMMISSIONS ARE DISPLAY-ONLY (client decision): the amount is
        // recorded and shown, and payment is settled outside this system.
        // There is no payout endpoint, by design.
        commissions: {
          pending: Number(row.commission_pending || 0),
          credited: Number(row.commission_credited || 0),
          paid: Number(row.commission_paid || 0),
          total: Number(row.commission_total || 0),
          currency: 'INR',
        },
      })
    } catch (err) {
      next(err)
    }
  })

  // The partner sets their OWN password. Used for the forced first-login
  // change (an admin-issued password is known to the admin, so it must not
  // remain a long-term secret).
  app.post('/api/partner/change-password', verifyLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const body = req.body || {}
      const current = String(body.currentPassword || '')
      const next = String(body.newPassword || '')

      if (next.length < 16) {
        return res.status(400).json({
          error: 'Choose a password of at least 16 characters.',
        })
      }
      if (next.length > 512) {
        return res.status(400).json({ error: 'That password is too long.' })
      }
      if (next === current) {
        return res.status(400).json({
          error: 'Choose a password different from the one you were given.',
        })
      }

      // Re-authenticate with the CURRENT password before rotating. A stolen
      // session token alone must not be enough to lock the real partner out
      // of their own account.
      const { data: self } = await supabase.rpc('partner_get_self', { p_token: token })
      const selfRow = Array.isArray(self) ? self[0] : self
      if (!selfRow) return res.status(401).json({ error: 'Invalid or expired session.' })

      if (!current) {
        return res.status(400).json({ error: 'Enter your current password.' })
      }
      const { data: check, error: checkErr } = await supabase.rpc('partner_login', {
        p_login_id: selfRow.login_id || '',
        p_password: current,
        p_ip_hash: clientIpHash(req),
      })
      const checkRow = Array.isArray(check) ? check[0] : check
      if (checkErr || !checkRow || !checkRow.ok) {
        return res.status(401).json({ error: 'Your current password is incorrect.' })
      }

      const { data, error } = await supabase.rpc('partner_change_password', {
        p_token: checkRow.portal_token,
        p_new_password: next,
      })
      if (error) {
        log.error('[partner] change_password rpc failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        const messages = {
          password_too_short: 'Choose a password of at least 16 characters.',
          invalid_session: 'Invalid or expired session.',
          invalid_bcrypt_cost: 'Temporarily unavailable.',
        }
        return res.status(row && row.reason === 'invalid_session' ? 401 : 400).json({
          error: messages[row && row.reason] || 'Could not update your password.',
        })
      }

      // The change ROTATES and invalidates the session used to perform it
      // (deliberate: if that token leaked, rotating is the remedy). Hand the
      // caller a fresh token so the UI can continue without a re-login.
      const { data: relogin } = await supabase.rpc('partner_login', {
        p_login_id: selfRow.login_id || '',
        p_password: next,
        p_ip_hash: clientIpHash(req),
      })
      const reloginRow = Array.isArray(relogin) ? relogin[0] : relogin

      res.json({
        ok: true,
        token: reloginRow && reloginRow.portal_token ? reloginRow.portal_token : null,
      })
    } catch (err) {
      next(err)
    }
  })

  app.get('/api/partner/me', verifyLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const { data, error } = await supabase.rpc('partner_get_self', { p_token: token })
      if (error) {
        log.error('[partner] get_self failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row) return res.status(401).json({ error: 'Invalid or expired session.' })

      const { data: docs } = await supabase.rpc('partner_list_documents', { p_token: token })

      // Issued artefacts (QR + coupon) are only meaningful once approved.
      let issued = null
      if (row.status === 'approved' && row.affiliate_id) {
        issued = await loadIssuedArtefacts(row.affiliate_id)
      }

      res.json({
        partner: publicPartnerView(row),
        documents: (docs || []).map((d) => ({
          id: d.id,
          docType: d.doc_type,
          label: DOC_LABELS[d.doc_type] || d.doc_type,
          originalFilename: d.original_filename,
          mimeType: d.mime_type,
          sizeBytes: Number(d.size_bytes),
          uploadedAt: d.uploaded_at,
          reviewStatus: d.review_status,
          reviewNote: d.review_note,
        })),
        issued,
        requiredDocuments: REQUIRED_DOCS[row.applicant_type || 'individual'] || [],
      })
    } catch (err) {
      next(err)
    }
  })

  /** Loads the partner's referrer code + coupon, for display after approval. */
  async function loadIssuedArtefacts(affiliateId) {
    const [{ data: aff }, { data: coupons }] = await Promise.all([
      supabase
        .from('affiliates')
        .select('id, name, referrer_code, commission_amount, status')
        .eq('id', affiliateId)
        .maybeSingle(),
      supabase
        .from('coupons')
        .select('code, status, max_redemptions, redemption_count, expires_at')
        .eq('affiliate_id', affiliateId)
        .order('created_at', { ascending: true })
        .limit(1),
    ])
    if (!aff) return null
    const coupon = (coupons && coupons[0]) || null
    return {
      referrerCode: aff.referrer_code,
      affiliateName: aff.name,
      affiliateStatus: aff.status,
      commissionAmount: aff.commission_amount,
      coupon: coupon
        ? {
            code: coupon.code,
            status: coupon.status,
            maxRedemptions: coupon.max_redemptions,
            redemptionCount: coupon.redemption_count,
            expiresAt: coupon.expires_at,
          }
        : null,
      installUrl: `${PLAY_URL}&referrer=utm_source=${encodeURIComponent(aff.referrer_code || '')}`,
    }
  }

  // Save the draft. The SQL function enforces the allow-list of editable
  // columns, so even a hand-crafted body cannot set `status` or `affiliate_id`.
  app.post('/api/partner/draft', submitLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const fields = (req.body && req.body.fields) || {}
      if (typeof fields !== 'object' || Array.isArray(fields)) {
        return res.status(400).json({ error: 'Invalid payload.' })
      }

      const clean = sanitizeDraftFields(fields)

      const { data, error } = await supabase.rpc('partner_save_draft', {
        p_token: token,
        p_fields: clean,
      })
      if (error) {
        // A CHECK-constraint violation is the partner's data being wrong
        // (e.g. a malformed PAN), so surface it as a 400 rather than a 500.
        if (error.code === '23514' || /check constraint/i.test(error.message)) {
          return res.status(400).json({ error: friendlyConstraintError(error.message) })
        }
        log.error('[partner] save_draft failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }

      const result = Array.isArray(data) ? data[0] : data
      if (result === 'invalid_session') return res.status(401).json({ error: 'Invalid or expired session.' })
      if (result === 'locked') {
        return res.status(409).json({ error: 'Your application is locked while it is being reviewed.' })
      }
      res.json({ ok: true })
    } catch (err) {
      next(err)
    }
  })

  /**
   * Normalises and bounds the editable draft fields. The database is the
   * authority on business rules; this layer exists to reject junk early and
   * to keep oversized payloads out of the database.
   */
  function sanitizeDraftFields(fields) {
    const out = {}
    const str = (v, max) => {
      if (v === null || v === undefined) return null
      const s = String(v).trim()
      return s.slice(0, max)
    }

    const allowedStringKeys = [
      ['applicant_type', 20],
      ['legal_name', 160],
      ['display_name', 160],
      ['entity_type', 40],
      ['gender', 20],
      ['date_of_birth', 10],
      ['phone', 20],
      ['address_line1', 200],
      ['address_line2', 200],
      ['city', 80],
      ['state', 80],
      ['postal_code', 10],
      ['country', 60],
      ['pan_number', 10],
      ['gstin', 15],
      ['aadhaar_last4', 4],
      ['bank_account_name', 160],
      ['bank_account_last4', 4],
      ['bank_ifsc', 11],
      ['audience_size', 40],
      ['promotion_plan', 2000],
      ['website_url', 300],
    ]
    for (const [key, max] of allowedStringKeys) {
      if (Object.prototype.hasOwnProperty.call(fields, key)) {
        out[key] = str(fields[key], max)
      }
    }

    if (Object.prototype.hasOwnProperty.call(fields, 'aadhaar_consent')) {
      out.aadhaar_consent = fields.aadhaar_consent === true
    }

    // Social links: a small, flat map of strings only.
    if (fields.social_links && typeof fields.social_links === 'object' && !Array.isArray(fields.social_links)) {
      const links = {}
      for (const [k, v] of Object.entries(fields.social_links).slice(0, 10)) {
        const key = String(k).slice(0, 40)
        links[key] = String(v == null ? '' : v).slice(0, 300)
      }
      out.social_links = links
    }

    // Normalise identifiers to the canonical upper-case form so the DB CHECK
    // constraints match what the partner actually typed.
    if (out.pan_number) out.pan_number = out.pan_number.toUpperCase().replace(/\s+/g, '')
    if (out.gstin) out.gstin = out.gstin.toUpperCase().replace(/\s+/g, '')
    if (out.bank_ifsc) out.bank_ifsc = out.bank_ifsc.toUpperCase().replace(/\s+/g, '')

    return out
  }

  function friendlyConstraintError(message) {
    const m = String(message || '')
    if (/partners_pan_format/.test(m)) return 'That PAN does not look right. The format is ABCDE1234F.'
    if (/partners_gstin_format/.test(m)) return 'That GSTIN does not look right. Please check it against your GST certificate.'
    if (/partners_adult_check/.test(m)) return 'You must be at least 18 years old to join the Partner Program.'
    if (/partners_business_entity_check/.test(m)) return 'Please choose the type of your business.'
    if (/partners_aadhaar_consent_check/.test(m)) return 'Please confirm your consent before providing Aadhaar digits.'
    if (/partners_aadhaar_last4_check/.test(m)) return 'Enter only the last 4 digits.'
    return 'Some of the information could not be saved. Please check the highlighted fields.'
  }

  // Record consent with the exact policy version shown to the partner.
  app.post('/api/partner/consent', submitLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const body = req.body || {}
      if (
        body.termsAccepted !== true ||
        body.privacyAccepted !== true ||
        body.truthfulnessDeclared !== true
      ) {
        return res.status(400).json({
          error: 'Please accept all three declarations before continuing.',
        })
      }

      const version = String(body.version || secrets.partner_consent_version || '2026-01').slice(0, 40)

      // Written directly (not via the draft allow-list) because these are
      // consent assertions that must be timestamped server side.
      const { data: self } = await supabase.rpc('partner_get_self', { p_token: token })
      const row = Array.isArray(self) ? self[0] : self
      if (!row) return res.status(401).json({ error: 'Invalid or expired session.' })

      const now = new Date().toISOString()
      const { error } = await supabase
        .from('partners')
        .update({
          terms_accepted: true,
          terms_version: version,
          terms_accepted_at: now,
          privacy_accepted: true,
          privacy_version: version,
          privacy_accepted_at: now,
          truthfulness_declared: true,
        })
        .eq('id', row.id)
      if (error) {
        log.error('[partner] consent write failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }

      await auditPartner(row.id, 'consent_recorded', { version }, req)
      res.json({ ok: true, version })
    } catch (err) {
      next(err)
    }
  })

  // -------------------------------------------------------------------------
  // Withdrawal and disclosure
  // -------------------------------------------------------------------------

  // Partner-initiated withdrawal. DPDP Act 2023 s.6(4) requires that
  // withdrawing consent be as easy as giving it, so this is a single call
  // from the portal — never a "contact support" instruction.
  //
  // It is deliberately honest about timing: processing stops immediately, but
  // deletion is bounded by the DPDP Rules 2025 r.8(3) one-year retention
  // floor. The response tells the partner the actual purge date.
  app.post('/api/partner/withdraw', submitLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const reason = req.body && req.body.reason
        ? String(req.body.reason).slice(0, 500)
        : null

      const { data, error } = await supabase.rpc('partner_withdraw', {
        p_token: token,
        p_reason: reason,
      })
      if (error) {
        log.error('[partner] withdraw failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        if (row && row.reason === 'already_withdrawn') {
          return res.json({ ok: true, status: 'withdrawn', purgeAfter: row.purge_after })
        }
        return res.status(401).json({ error: 'Invalid or expired session.' })
      }

      res.json({
        ok: true,
        status: row.status,
        purgeAfter: row.purge_after,
        message:
          'Your application has been withdrawn and we have stopped processing it. ' +
          'We keep your information for a minimum period required by law, after which it is deleted.',
      })
    } catch (err) {
      next(err)
    }
  })

  // Records that the partner was shown the affiliate-disclosure obligation.
  // CCPA Guidelines 2022 para 14 makes the disclosure legally mandatory, so
  // this evidence matters.
  app.post('/api/partner/disclosure', submitLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })
      const version = (req.body && req.body.version) || '2026-01'

      const { data, error } = await supabase.rpc('partner_accept_disclosure', {
        p_token: token,
        p_version: String(version),
      })
      if (error) {
        log.error('[partner] disclosure accept failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }
      const result = Array.isArray(data) ? data[0] : data
      if (result === 'invalid_session') {
        return res.status(401).json({ error: 'Invalid or expired session.' })
      }
      if (result === 'locked') return res.status(409).json({ error: 'Your application is locked.' })
      res.json({ ok: true })
    } catch (err) {
      next(err)
    }
  })

  // -------------------------------------------------------------------------
  // Document upload
  // -------------------------------------------------------------------------

  app.post(
    '/api/partner/documents',
    uploadLimiterSubnet,
    upload.single('file'),
    async (req, res, next) => {
      try {
        const token = portalToken(req)
        if (!token) return res.status(401).json({ error: 'Missing session.' })

        if (!req.file) return res.status(400).json({ error: 'No file was uploaded.' })

        const docType = String((req.body && req.body.docType) || '').trim()

        // Aadhaar is checked FIRST, before the generic allow-list test.
        // `aadhaar_card` is deliberately absent from DOC_LABELS, so ordering
        // this after the generic check would make it unreachable and the
        // partner would see a useless "Unknown document type" instead of the
        // explanation (and the alternatives the Aadhaar Act s.8(3) requires
        // them to be offered).
        if (/aadhaar/i.test(docType)) {
          return res.status(400).json({
            error:
              'Aadhaar is not accepted for the Partner Program. Please upload a PAN card, or a passport, voter ID or driving licence.',
          })
        }

        if (!docType || !Object.prototype.hasOwnProperty.call(DOC_LABELS, docType)) {
          return res.status(400).json({ error: 'Unknown document type.' })
        }

        // --- Defence in depth on file type -------------------------------
        const check = validateDocumentUpload({
          buffer: req.file.buffer,
          declaredMime: req.file.mimetype,
          filename: req.file.originalname,
          maxBytes: MAX_DOC_BYTES,
        })
        if (!check.ok) {
          return res.status(400).json({ error: documentError(check.reason) })
        }

        if (!encryptionReady(getSecrets)) {
          // Fail closed: never store KYC in the clear because a key is absent.
          log.error('[partner] upload refused: partner_kek not configured')
          return res.status(503).json({
            error: 'Document upload is temporarily unavailable. Please try again later.',
          })
        }

        // --- Encrypt BEFORE the bytes leave this process -----------------
        const { ciphertext, enc } = encryptDocument(req.file.buffer, getSecrets)

        // Resolve the partner first so the object key can be namespaced by
        // partner id (useful for bulk lifecycle operations later).
        const { data: selfData, error: selfErr } = await supabase.rpc('partner_get_self', {
          p_token: token,
        })
        if (selfErr) {
          log.error('[partner] get_self during upload failed:', selfErr.message)
          return res.status(503).json({ error: 'Temporarily unavailable.' })
        }
        const self = Array.isArray(selfData) ? selfData[0] : selfData
        if (!self) return res.status(401).json({ error: 'Invalid or expired session.' })
        if (!self.email_verified) {
          return res.status(403).json({
            error: 'Please verify your email address before uploading documents.',
          })
        }
        if (!['draft', 'needs_info'].includes(self.status)) {
          return res.status(409).json({
            error: 'Your application is locked while it is being reviewed.',
          })
        }

        const key = `${self.id}/${cryptoRandomHex()}.${check.ext}.enc`
        const { error: upErr } = await supabase.storage
          .from(KYC_BUCKET)
          .upload(key, ciphertext, {
            // Always opaque: the stored object is ciphertext, so declaring
            // the real type would be both wrong and a needless hint.
            contentType: 'application/octet-stream',
            upsert: false,
          })
        if (upErr) {
          log.error('[partner] storage upload failed:', upErr.message)
          return res.status(503).json({ error: 'Upload failed. Please try again.' })
        }

        const { data: added, error: addErr } = await supabase.rpc('partner_add_document', {
          p_token: token,
          p_doc_type: docType,
          p_object_key: key,
          p_original_filename: req.file.originalname || '',
          p_mime_type: check.mime,
          p_sniffed_mime_type: check.mime,
          p_size_bytes: req.file.buffer.length,
          p_sha256: sha256Hex(req.file.buffer),
          p_enc_iv: enc.iv,
          p_enc_tag: enc.tag,
          p_dek_wrapped: enc.dekWrapped,
          p_dek_iv: enc.dekIv,
          p_dek_tag: enc.dekTag,
        })
        if (addErr) {
          // The metadata write failed, so the object is orphaned. Remove it
          // so storage does not accumulate unreferenced ciphertext.
          await supabase.storage.from(KYC_BUCKET).remove([key]).catch(() => {})
          log.error('[partner] add_document failed:', addErr.message)
          return res.status(503).json({ error: 'Upload failed. Please try again.' })
        }

        const row = Array.isArray(added) ? added[0] : added
        if (!row || !row.ok) {
          await supabase.storage.from(KYC_BUCKET).remove([key]).catch(() => {})
          const reason = (row && row.reason) || 'unknown'
          if (reason === 'email_not_verified') {
            return res.status(403).json({ error: 'Please verify your email address first.' })
          }
          if (reason === 'too_many_documents') {
            return res.status(400).json({
              error: `You can keep at most ${MAX_DOCS_PER_PARTNER} documents. Remove one to upload another.`,
            })
          }
          if (reason === 'locked') {
            return res.status(409).json({ error: 'Your application is locked while it is being reviewed.' })
          }
          return res.status(400).json({ error: 'That document could not be saved.' })
        }

        res.status(201).json({
          ok: true,
          document: {
            id: row.document_id,
            docType,
            label: DOC_LABELS[docType],
            sizeBytes: req.file.buffer.length,
            mimeType: check.mime,
          },
        })
      } catch (err) {
        next(err)
      }
    },
  )

  function documentError(reason) {
    switch (reason) {
      case 'file_too_large':
        return 'That file is too large. Please upload a file under 5 MB.'
      case 'unsupported_type':
        return 'Only PDF, JPEG or PNG files are accepted.'
      case 'type_mismatch':
        return 'That file does not match its extension. Please upload the original document.'
      case 'invalid_filename':
        return 'That filename is not allowed. Please rename the file and try again.'
      case 'empty_file':
        return 'That file appears to be empty.'
      default:
        return 'That file could not be accepted.'
    }
  }

  /**
   * A server-generated 32-hex-character object name. The partner's own
   * filename never reaches storage, which structurally eliminates path
   * traversal, the NTFS short-name alias attack and the ADS colon trick —
   * there is simply nothing attacker-controlled left to traverse with.
   */
  function cryptoRandomHex() {
    return sha256HexOfString(generateToken()).slice(0, 32)
  }

  app.delete('/api/partner/documents/:id', submitLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })
      const id = String(req.params.id || '')
      if (!/^[0-9a-f-]{36}$/i.test(id)) return res.status(400).json({ error: 'Invalid document.' })

      const { data, error } = await supabase.rpc('partner_delete_document', {
        p_token: token,
        p_document_id: id,
      })
      if (error) {
        log.error('[partner] delete_document failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        const reason = (row && row.reason) || 'unknown'
        if (reason === 'locked') {
          return res.status(409).json({ error: 'Your application is locked while it is being reviewed.' })
        }
        return res.status(404).json({ error: 'That document was not found.' })
      }

      // Remove the ciphertext now that the row is gone.
      const { error: rmErr } = await supabase.storage.from(KYC_BUCKET).remove([row.object_key])
      if (rmErr) {
        // The row is gone but the object remains. Logged for the operator;
        // the object is unreadable ciphertext and unreferenced.
        log.error('[partner] orphan object after delete:', rmErr.message)
      }

      res.json({ ok: true })
    } catch (err) {
      next(err)
    }
  })

  // -------------------------------------------------------------------------
  // Submit the application
  // -------------------------------------------------------------------------

  app.post('/api/partner/submit', submitLimiter, async (req, res, next) => {
    try {
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      const { data, error } = await supabase.rpc('partner_submit', {
        p_token: token,
        p_ip_hash: clientIpHash(req),
      })
      if (error) {
        log.error('[partner] submit failed:', error.message)
        return res.status(503).json({ error: 'Temporarily unavailable.' })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row) return res.status(503).json({ error: 'Temporarily unavailable.' })

      if (!row.ok) {
        if (row.status === 'email_not_verified') {
          return res.status(403).json({ error: 'Please verify your email address before applying.' })
        }
        if (row.status === 'rejected' || row.status === 'withdrawn') {
          return res.status(409).json({ error: 'This application is closed.' })
        }
        if (row.status === 'incomplete') {
          return res.status(400).json({
            error: 'Some required information is still missing.',
            missing: row.missing || [],
            missingLabels: (row.missing || []).map(missingLabel),
          })
        }
        return res.status(400).json({ error: 'Your application could not be submitted.' })
      }

      // Notify the admin team that a new application is waiting.
      await notifyAdminsOfSubmission(row.status).catch(() => {})

      res.json({
        ok: true,
        status: row.status,
        message:
          row.status === 'submitted'
            ? 'Your application has been submitted. Our team will review it and contact you.'
            : 'Your application has already been submitted.',
      })
    } catch (err) {
      next(err)
    }
  })

  function missingLabel(key) {
    const map = {
      applicant_type: 'Whether you are an individual or a business',
      legal_name: 'Your legal name',
      date_of_birth: 'Your date of birth',
      gender: 'Your gender',
      phone: 'Your phone number',
      address_line1: 'Your address',
      city: 'Your city',
      state: 'Your state',
      postal_code: 'Your PIN code',
      pan_number: 'Your PAN',
      entity_type: 'Your business type',
      consent: 'The declarations at the end of the form',
      email: 'Email verification',
      application_closed: 'This application is closed',
      session: 'Your session',
      'doc:pan_card': 'A copy of your PAN card',
      'doc:address_proof': 'A proof of address',
      'doc:business_registration': 'Your business registration document',
    }
    return map[key] || key
  }

  /** Emails the operating team that a new application needs review. */
  async function notifyAdminsOfSubmission(status) {
    const to = secrets.partner_admin_alert_email
    if (!to) return { sent: false, reason: 'not_configured' }
    const brand = secrets.partner_brand_name || 'Soulful Bhakti'
    return sendEmail(getSecrets, {
      to,
      subject: `${brand}: a new Partner application is ready for review`,
      text: `A partner application has been submitted and is waiting in the admin review queue.\n\nOpen ${publicBaseUrl || ''}/admin and go to "Partner Applications".`,
      html: `<p>A partner application has been submitted and is waiting in the admin review queue.</p><p>Open the <b>Partner Applications</b> section of the admin panel to review it.</p>`,
    })
  }

  // -------------------------------------------------------------------------
  // Admin: review queue
  // -------------------------------------------------------------------------

  app.get('/api/admin/partners', requireAdmin, async (req, res, next) => {
    try {
      const status = typeof req.query.status === 'string' && req.query.status
        ? req.query.status
        : null
      const { data, error } = await supabase.rpc('partner_admin_list', { p_status: status })
      if (error) {
        log.error('[admin] partner list failed:', error.message)
        return res.status(500).json({ error: error.message })
      }
      res.json(
        (data || []).map((r) => ({
          id: r.id,
          email: r.email,
          legalName: r.legal_name,
          displayName: r.display_name,
          applicantType: r.applicant_type,
          entityType: r.entity_type,
          status: r.status,
          emailVerified: r.email_verified,
          submittedAt: r.submitted_at,
          createdAt: r.created_at,
          affiliateId: r.affiliate_id,
          referrerCode: r.referrer_code,
          couponCode: r.coupon_code,
          commissionAmount: r.commission_amount,
          documentCount: Number(r.document_count || 0),
          reviewedBy: r.reviewed_by,
        })),
      )
    } catch (err) {
      next(err)
    }
  })

  // Full application detail, including the masked identifiers the reviewer
  // needs for a first pass and the document list (metadata only — bytes are
  // fetched separately and individually audited).
  app.get('/api/admin/partners/:id', requireAdmin, async (req, res, next) => {
    try {
      const id = req.params.id
      if (!/^[0-9a-f-]{36}$/i.test(id)) return res.status(400).json({ error: 'Invalid id' })

      const { data, error } = await supabase
        .from('partners')
        .select('*')
        .eq('id', id)
        .maybeSingle()
      if (error) return res.status(500).json({ error: error.message })
      if (!data) return res.status(404).json({ error: 'not found' })

      const { data: docs } = await supabase
        .from('partner_documents')
        .select('id, doc_type, original_filename, mime_type, sniffed_mime_type, size_bytes, sha256, uploaded_at, review_status, review_note, reviewed_at, reviewed_by')
        .eq('partner_id', id)
        .is('superseded_at', null)
        .order('uploaded_at', { ascending: false })

      const { data: audit } = await supabase
        .from('partner_audit_log')
        .select('id, actor_type, actor, action, from_status, to_status, detail, created_at')
        .eq('partner_id', id)
        .order('created_at', { ascending: false })
        .limit(100)

      let issued = null
      if (data.affiliate_id) issued = await loadIssuedArtefacts(data.affiliate_id)

      res.json({
        partner: {
          id: data.id,
          email: data.email,
          emailVerified: data.email_verified,
          emailVerifiedAt: data.email_verified_at,
          status: data.status,
          applicantType: data.applicant_type,
          entityType: data.entity_type,
          legalName: data.legal_name,
          displayName: data.display_name,
          gender: data.gender,
          dateOfBirth: data.date_of_birth,
          phone: data.phone,
          addressLine1: data.address_line1,
          addressLine2: data.address_line2,
          city: data.city,
          state: data.state,
          postalCode: data.postal_code,
          country: data.country,
          panNumber: data.pan_number,
          gstin: data.gstin,
          aadhaarLast4: data.aadhaar_last4,
          aadhaarConsent: data.aadhaar_consent,
          bankAccountName: data.bank_account_name,
          bankAccountLast4: data.bank_account_last4,
          bankIfsc: data.bank_ifsc,
          audienceSize: data.audience_size,
          promotionPlan: data.promotion_plan,
          websiteUrl: data.website_url,
          socialLinks: data.social_links || {},
          termsAccepted: data.terms_accepted,
          termsVersion: data.terms_version,
          termsAcceptedAt: data.terms_accepted_at,
          privacyVersion: data.privacy_version,
          privacyAcceptedAt: data.privacy_accepted_at,
          truthfulnessDeclared: data.truthfulness_declared,
          submittedAt: data.submitted_at,
          reviewedAt: data.reviewed_at,
          reviewedBy: data.reviewed_by,
          decisionNote: data.decision_note,
          commissionAmount: data.commission_amount,
          affiliateId: data.affiliate_id,
          approvedAt: data.approved_at,
          purgeAfter: data.purge_after,
          createdAt: data.created_at,
        },
        documents: (docs || []).map((d) => ({
          id: d.id,
          docType: d.doc_type,
          label: DOC_LABELS[d.doc_type] || d.doc_type,
          originalFilename: d.original_filename,
          mimeType: d.mime_type,
          sniffedMimeType: d.sniffed_mime_type,
          sizeBytes: Number(d.size_bytes),
          sha256: d.sha256,
          uploadedAt: d.uploaded_at,
          reviewStatus: d.review_status,
          reviewNote: d.review_note,
          reviewedAt: d.reviewed_at,
          reviewedBy: d.reviewed_by,
        })),
        audit: audit || [],
        issued,
        requiredDocuments: REQUIRED_DOCS[data.applicant_type || 'individual'] || [],
      })
    } catch (err) {
      next(err)
    }
  })

  // Stream ONE document to an authenticated admin.
  //
  // The bytes are proxied through this server rather than handed out as a
  // Supabase signed URL, for three reasons the research established:
  //   1. Supabase signed URLs are NOT revocable and survive JWT key rotation,
  //      so a leaked URL is a bearer credential for its whole lifetime.
  //   2. Response headers on a signed URL are set by Supabase's CDN, so the
  //      OWASP-prescribed download headers cannot be enforced on that path.
  //   3. Proxying gives a single chokepoint where every access is audited.
  // Because the object is application-encrypted ciphertext, a signed URL
  // would not have disclosed readable data anyway — but proxying makes the
  // access log authoritative and the headers real.
  app.get('/api/admin/partners/:id/documents/:docId/content', requireAdmin, async (req, res, next) => {
    const { id: partnerId, docId } = req.params
    let logged = false
    try {
      if (!/^[0-9a-f-]{36}$/i.test(partnerId) || !/^[0-9a-f-]{36}$/i.test(docId)) {
        return res.status(400).json({ error: 'Invalid id' })
      }

      const { data: doc, error } = await supabase
        .from('partner_documents')
        .select('*')
        .eq('id', docId)
        .eq('partner_id', partnerId)
        .maybeSingle()

      if (error || !doc) {
        await logDocAccess(partnerId, docId, req, 'denied', 'not_found')
        logged = true
        return res.status(404).json({ error: 'Document not found' })
      }

      const { data: blob, error: dlErr } = await supabase.storage
        .from(KYC_BUCKET)
        .download(doc.object_key)
      if (dlErr || !blob) {
        await logDocAccess(partnerId, docId, req, 'denied', 'storage_error')
        logged = true
        return res.status(502).json({ error: 'Could not read the stored document' })
      }

      const ciphertext = Buffer.from(await blob.arrayBuffer())
      let plaintext
      try {
        plaintext = decryptDocument(ciphertext, {
          iv: doc.enc_iv,
          tag: doc.enc_tag,
          dekWrapped: doc.dek_wrapped,
          dekIv: doc.dek_iv,
          dekTag: doc.dek_tag,
        }, getSecrets)
      } catch (decErr) {
        // Either the KEK changed or the object was tampered with. Both are
        // serious, so they are audited and reported rather than glossed over.
        log.error('[admin] document decrypt failed:', decErr.message)
        await logDocAccess(partnerId, docId, req, 'denied', 'decrypt_failed')
        logged = true
        return res.status(500).json({
          error: 'This document could not be decrypted. It may have been encrypted with a previous key.',
        })
      }

      // Integrity: the delivered bytes must match what was submitted. A
      // mismatch means the object was altered in storage.
      const actual = sha256Hex(plaintext)
      if (doc.sha256 && actual !== doc.sha256) {
        log.error('[admin] document checksum mismatch for', docId)
        await logDocAccess(partnerId, docId, req, 'denied', 'checksum_mismatch')
        logged = true
        return res.status(500).json({ error: 'The stored document failed its integrity check.' })
      }

      await logDocAccess(partnerId, docId, req, 'success', null)
      logged = true

      // OWASP secure-download headers. `attachment` forces a download rather
      // than inline rendering, so a crafted PDF cannot script against the
      // admin's session in this origin.
      const safeName = `${doc.doc_type}-${doc.id}.${mimeExt(doc.sniffed_mime_type || doc.mime_type)}`
      res.setHeader('Content-Type', 'application/octet-stream')
      res.setHeader('X-Content-Type-Options', 'nosniff')
      res.setHeader('Content-Disposition', `attachment; filename="${safeName}"`)
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private')
      res.setHeader('Pragma', 'no-cache')
      res.setHeader('Referrer-Policy', 'no-referrer')
      res.send(plaintext)
    } catch (err) {
      if (!logged) {
        try { await logDocAccess(partnerId, docId, req, 'denied', 'error') } catch (_) {}
      }
      next(err)
    }
  })

  function mimeExt(mime) {
    if (mime === 'application/pdf') return 'pdf'
    if (mime === 'image/png') return 'png'
    if (mime === 'image/jpeg') return 'jpg'
    return 'bin'
  }

  /** Writes an immutable audit row recording who read which document. */
  /**
   * Writes an immutable audit row recording who read which document.
   *
   * Deliberately never throws. Two reasons:
   *   * an audit-write failure must not turn a successful, authorised read into
   *     an error for the reviewer; and
   *   * a DENIED access for a partner id that does not exist cannot be logged
   *     against that partner (the FK would reject it) — the denial is still
   *     logged to the server console so probing is visible, but it is not
   *     attributed to a row that is not there.
   */
  async function logDocAccess(partnerId, docId, req, result, reason) {
    try {
      const admin = await adminIdentity(req)

      // Verify the partner row exists before attributing an audit entry to it.
      const { data: exists } = await supabase
        .from('partners')
        .select('id')
        .eq('id', partnerId)
        .maybeSingle()
      if (!exists) {
        log.warn(
          `[admin] document access denied for unknown partner (${result}${reason ? ': ' + reason : ''})`,
        )
        return
      }

      const { error } = await supabase.rpc('partner_log_document_access', {
        p_partner_id: partnerId,
        p_document_id: docId,
        p_admin: admin,
        p_action: 'document.view',
        p_result: result,
        p_reason: reason,
        p_ip_hash: clientIpHash(req),
        p_user_agent: safeUserAgent(req),
      })
      if (error) log.error('[admin] document access log failed:', error.message)
    } catch (err) {
      log.error('[admin] document access log threw:', err && err.message)
    }
  }

  /**
   * Best-effort stable identity for the acting admin, for the audit trail.
   *
   * Who reviewed a partner's documents is the single most important field in
   * the audit log, so this resolves the Clerk session to an email where one is
   * available and otherwise records that the shared token was used. It never
   * throws: an identity failure must not block the audit write itself.
   */
  async function adminIdentity(req) {
    if (req.__partnerAdminIdentity) return req.__partnerAdminIdentity
    let identity = 'admin-token'
    try {
      if (typeof requireClerkAdmin === 'function') {
        const claims = await requireClerkAdmin(req)
        if (claims) {
          const email = claims.emailAddress || claims.email || claims.sub
          if (email) identity = String(email).slice(0, 200)
        }
      }
    } catch (_) { /* fall through to the token identity */ }
    // Cache per request so a single action does not verify the token twice.
    req.__partnerAdminIdentity = identity
    return identity
  }

  // Mark an individual document accepted/rejected during review.
  app.put('/api/admin/partners/:id/documents/:docId', requireAdmin, async (req, res, next) => {
    try {
      const { id: partnerId, docId } = req.params
      const { status, note } = req.body || {}
      if (!['accepted', 'rejected', 'pending'].includes(status)) {
        return res.status(400).json({ error: "status must be 'accepted', 'rejected' or 'pending'" })
      }
      if (!/^[0-9a-f-]{36}$/i.test(partnerId) || !/^[0-9a-f-]{36}$/i.test(docId)) {
        return res.status(400).json({ error: 'Invalid id' })
      }

      const { data, error } = await supabase
        .from('partner_documents')
        .update({
          review_status: status,
          review_note: note ? String(note).slice(0, 500) : null,
          reviewed_at: new Date().toISOString(),
          reviewed_by: await adminIdentity(req),
        })
        .eq('id', docId)
        .eq('partner_id', partnerId)
        .select('id, review_status, review_note')
        .maybeSingle()
      if (error) return res.status(500).json({ error: error.message })
      if (!data) return res.status(404).json({ error: 'Document not found' })

      await auditAdmin(partnerId, req, 'document_reviewed', {
        document_id: docId,
        status,
      })
      res.json(data)
    } catch (err) {
      next(err)
    }
  })

  async function auditAdmin(partnerId, req, action, detail) {
    const admin = await adminIdentity(req)
    const { error } = await supabase.from('partner_audit_log').insert({
      partner_id: partnerId,
      actor_type: 'admin',
      actor: admin,
      action,
      detail: detail || {},
      ip_hash: clientIpHash(req),
      user_agent: safeUserAgent(req),
    })
    if (error) log.error('[admin] audit write failed:', error.message)
  }

  // Move an application into review / request more info / reject.
  app.post('/api/admin/partners/:id/decision', requireAdmin, async (req, res, next) => {
    try {
      const id = req.params.id
      if (!/^[0-9a-f-]{36}$/i.test(id)) return res.status(400).json({ error: 'Invalid id' })
      const { decision, note, purgeDays } = req.body || {}
      if (!['reject', 'needs_info', 'under_review'].includes(decision)) {
        return res.status(400).json({ error: 'invalid decision' })
      }
      if (decision === 'reject' && !String(note || '').trim()) {
        // A rejection must be explainable — both for the applicant and for
        // our own due-diligence record.
        return res.status(400).json({ error: 'A reason is required when rejecting an application.' })
      }

      const { data, error } = await supabase.rpc('partner_decide', {
        p_partner_id: id,
        p_admin: await adminIdentity(req),
        p_decision: decision,
        p_note: note || null,
        p_purge_days: Number.isInteger(purgeDays) ? purgeDays : 90,
      })
      if (error) {
        log.error('[admin] decision failed:', error.message)
        return res.status(500).json({ error: error.message })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        const reason = (row && row.reason) || 'unknown'
        if (reason === 'already_approved') {
          return res.status(409).json({ error: 'This application is already approved.' })
        }
        return res.status(400).json({ error: 'The decision could not be recorded.' })
      }
      res.json({ ok: true, status: row.status })
    } catch (err) {
      next(err)
    }
  })

  // Approve: creates the affiliate, the QR referrer code and the coupon.
  app.post('/api/admin/partners/:id/approve', requireAdmin, async (req, res, next) => {
    try {
      const id = req.params.id
      if (!/^[0-9a-f-]{36}$/i.test(id)) return res.status(400).json({ error: 'Invalid id' })

      const body = req.body || {}
      const commission = body.commissionAmount === undefined || body.commissionAmount === null || body.commissionAmount === ''
        ? 0
        : Number(body.commissionAmount)
      if (!Number.isFinite(commission) || commission < 0) {
        return res.status(400).json({ error: 'Commission must be a non-negative number.' })
      }

      const referrerCode = body.referrerCode ? String(body.referrerCode).trim().toUpperCase() : null
      if (referrerCode && !/^[A-Z0-9][A-Z0-9-]{2,31}$/.test(referrerCode)) {
        return res.status(400).json({
          error: 'Referrer code must be 3-32 letters, numbers or hyphens.',
        })
      }
      const couponCode = body.couponCode ? String(body.couponCode).trim().toUpperCase() : null
      if (couponCode && !/^[A-Z0-9][A-Z0-9-]*$/.test(couponCode)) {
        return res.status(400).json({
          error: 'Coupon code must be letters, numbers or hyphens.',
        })
      }

      let maxRedemptions = null
      if (body.maxRedemptions !== undefined && body.maxRedemptions !== null && body.maxRedemptions !== '') {
        const n = Number(body.maxRedemptions)
        if (!Number.isInteger(n) || n <= 0) {
          return res.status(400).json({ error: 'Max redemptions must be a positive whole number.' })
        }
        maxRedemptions = n
      }

      let expiresAt = null
      if (body.expiresAt) {
        const d = new Date(body.expiresAt)
        if (Number.isNaN(d.getTime())) {
          return res.status(400).json({ error: 'Invalid expiry date.' })
        }
        expiresAt = d.toISOString()
      }

      const { data, error } = await supabase.rpc('partner_approve', {
        p_partner_id: id,
        p_admin: await adminIdentity(req),
        p_commission_amount: commission,
        p_referrer_code: referrerCode,
        p_coupon_code: couponCode,
        p_coupon_max_redemptions: maxRedemptions,
        p_coupon_expires_at: expiresAt,
      })
      if (error) {
        log.error('[admin] approve failed:', error.message)
        return res.status(500).json({ error: error.message })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        const reason = (row && row.reason) || 'unknown'
        const messages = {
          not_found: 'Application not found.',
          email_not_verified: 'The applicant has not verified their email address yet.',
          referrer_code_taken: 'That referrer code is already in use by another affiliate.',
          invalid_referrer_code: 'That referrer code format is not accepted.',
          coupon_code_taken: 'That coupon code is already in use.',
          invalid_coupon_code: 'That coupon code format is not accepted.',
        }
        if (reason.startsWith('invalid_state:')) {
          return res.status(409).json({
            error: `This application is "${reason.split(':')[1]}" and cannot be approved.`,
          })
        }
        return res.status(400).json({ error: messages[reason] || 'Approval failed.' })
      }

      // Congratulate the partner with their issued QR + coupon.
      await sendApprovalEmail(id).catch(() => {})

      res.json({
        ok: true,
        affiliateId: row.affiliate_id,
        referrerCode: row.referrer_code,
        couponCode: row.coupon_code,
        alreadyApproved: row.reason === 'already_approved',
      })
    } catch (err) {
      next(err)
    }
  })

  /**
   * Tells the partner they were approved and gives them their QR link and
   * coupon code. Best-effort: a mail failure must not undo an approval that
   * is already committed.
   */
  async function sendApprovalEmail(partnerId) {
    const { data: p } = await supabase
      .from('partners')
      .select('email, legal_name, display_name, affiliate_id')
      .eq('id', partnerId)
      .maybeSingle()
    if (!p || !p.affiliate_id) return { sent: false, reason: 'not_found' }

    const issued = await loadIssuedArtefacts(p.affiliate_id)
    if (!issued) return { sent: false, reason: 'no_artefacts' }

    const brand = secrets.partner_brand_name || 'Soulful Bhakti'
    const name = p.display_name || p.legal_name || 'Partner'
    const couponLine = issued.coupon ? issued.coupon.code : '(issued in your dashboard)'

    const text = [
      `Namaste ${name},`,
      ``,
      `Welcome to the ${brand} Partner Program. Your application has been approved.`,
      ``,
      `Your partner QR code link:`,
      issued.installUrl,
      ``,
      `Share this QR with your audience. When someone scans it, they are taken`,
      `to the Google Play listing and, after installing and signing in, they`,
      `are attributed to you.`,
      ``,
      `Your discount coupon code: ${couponLine}`,
      ``,
      `Share the coupon with your audience. They enter it in the app to`,
      `register their support for you.`,
      ``,
      `You can see both any time in your partner dashboard.`,
      ``,
      `— ${brand}`,
    ].join('\n')

    const html = `<!doctype html><html><body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#2b2b2b;padding:24px;background:#f6f4ef;">
<div style="max-width:560px;margin:0 auto;background:#fff;border:1px solid #e8e2d6;border-radius:12px;padding:32px;">
<h1 style="font-size:20px;margin:0 0 16px;">Welcome to the ${escapeHtml(brand)} Partner Program</h1>
<p style="font-size:15px;line-height:1.6;">Namaste ${escapeHtml(name)}, your application has been approved.</p>
<h2 style="font-size:15px;margin:24px 0 8px;">Your partner link</h2>
<p style="font-size:13px;word-break:break-all;"><a href="${escapeHtml(issued.installUrl)}">${escapeHtml(issued.installUrl)}</a></p>
<p style="font-size:13px;color:#6b6b6b;">Share your QR code with your audience. After installing and signing in, they are attributed to you.</p>
<h2 style="font-size:15px;margin:24px 0 8px;">Your discount coupon</h2>
<p style="font-size:22px;font-weight:700;letter-spacing:1px;color:#8a6d3b;">${escapeHtml(couponLine)}</p>
<p style="font-size:13px;color:#6b6b6b;">Share this code with your audience. They enter it in the app to register their support for you.</p>
<p style="font-size:13px;color:#6b6b6b;margin-top:24px;">You can see both any time in your partner dashboard.</p>
</div></body></html>`

    return sendEmail(getSecrets, {
      to: p.email,
      subject: `Welcome to the ${brand} Partner Program — your QR and coupon are ready`,
      text,
      html,
    })
  }

  // The partner's own QR image, addressed by the PARTNER's own id and
  // authorised by the partner's session token. The client uses this so the
  // admin-only route never has to be exposed to the public portal.
  //
  // Note the deliberate information asymmetry: an unauthorised caller learns
  // only "not found", never whether that partner id exists or is approved.
  app.get('/api/partner/qr/:id', verifyLimiter, async (req, res, next) => {
    try {
      // NOTE ON THE TOKEN IN THE QUERY STRING: an <img src> cannot set an
      // Authorization header, so this one endpoint also accepts ?token=.
      // That is a deliberate, bounded trade-off: the response is a QR image
      // the partner already owns and displays publicly, the route reveals
      // nothing about any other partner, and the request is rate-limited.
      // The token is NOT accepted in the query for any endpoint that returns
      // personal data or documents — those require the bearer header.
      const token = portalToken(req)
      if (!token) return res.status(401).json({ error: 'Missing session.' })

      // Express does not treat ":id.png" as a suffix, so the ".png" is
      // stripped explicitly here.
      const requestedId = String(req.params.id || '').replace(/\.png$/i, '')
      if (!/^[0-9a-f-]{36}$/i.test(requestedId)) {
        return res.status(404).json({ error: 'Not found.' })
      }

      // Resolve the caller's OWN row; the requested id must match it. This is
      // why the portal cannot fetch another partner's QR by guessing an id.
      const { data: selfData } = await supabase.rpc('partner_get_self', { p_token: token })
      const self = Array.isArray(selfData) ? selfData[0] : selfData
      if (!self || self.id !== requestedId) {
        return res.status(404).json({ error: 'Not found.' })
      }
      if (self.status !== 'approved' || !self.affiliate_id) {
        return res.status(404).json({ error: 'No QR code has been issued yet.' })
      }

      const { data: aff } = await supabase
        .from('affiliates')
        .select('referrer_code')
        .eq('id', self.affiliate_id)
        .maybeSingle()
      if (!aff || !aff.referrer_code) {
        return res.status(404).json({ error: 'No QR code has been issued yet.' })
      }

      // Shares the exact URL shape the shipped Android install-referrer
      // pipeline already parses, so no app change is required.
      const installUrl = `${PLAY_URL}&referrer=utm_source=${encodeURIComponent(aff.referrer_code)}`
      const png = await QRCode.toBuffer(installUrl, {
        width: 512,
        margin: 1,
        errorCorrectionLevel: 'M',
      })
      res.set('Content-Type', 'image/png')
      res.set('Cache-Control', 'no-store')
      res.set('X-Content-Type-Options', 'nosniff')
      res.send(png)
    } catch (err) {
      next(err)
    }
  })

  /**
   * Sends the partner their admin-issued login credentials.
   *
   * SECURITY: this is the ONLY place the plaintext password exists outside the
   * admin request that generated it. It is placed in the email body and
   * nowhere else — not logged, not stored, and not returned by the API.
   *
   * The email tells the partner plainly that the password was issued by an
   * administrator and must be changed at first sign-in, because an
   * admin-issued password is known to the admin and must not remain a
   * long-term secret.
   */
  async function sendCredentialsEmail(partner, loginId, password, req) {
    const brand = secrets.partner_brand_name || 'Soulful Bhakti'
    const name = partner.display_name || partner.legal_name || 'Partner'

    // The portal URL the partner should actually visit. resolveBaseUrl()
    // already handles the branded-vs-serving-host distinction.
    const portalUrl = `${resolveBaseUrl(req)}/partner`

    const text = [
      `Namaste ${name},`,
      ``,
      `Your ${brand} Partner Program account has been created.`,
      ``,
      `Partner ID: ${loginId}`,
      `Password:   ${password}`,
      ``,
      `Sign in here: ${portalUrl}`,
      ``,
      `IMPORTANT: This password was issued by our team, so please change it`,
      `immediately after your first sign-in. You will be asked to do this.`,
      ``,
      `Keep this email confidential. Anyone with these details can access your`,
      `partner dashboard. If you did not expect this email, please contact us`,
      `and we will reissue your credentials.`,
      ``,
      `— ${brand}`,
    ].join('\n')

    const html = `<!doctype html><html><body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#2b2b2b;padding:24px;background:#f6f4ef;">
<div style="max-width:560px;margin:0 auto;background:#fff;border:1px solid #e8e2d6;border-radius:12px;padding:32px;">
<h1 style="font-size:20px;margin:0 0 16px;">Your ${escapeHtml(brand)} Partner account</h1>
<p style="font-size:15px;line-height:1.6;">Namaste ${escapeHtml(name)}, your partner account has been created.</p>
<table style="font-size:15px;margin:20px 0;border-collapse:collapse;">
<tr><td style="padding:6px 16px 6px 0;color:#6b6b6b;">Partner ID</td><td style="padding:6px 0;font-weight:700;letter-spacing:1px;">${escapeHtml(loginId)}</td></tr>
<tr><td style="padding:6px 16px 6px 0;color:#6b6b6b;">Password</td><td style="padding:6px 0;font-family:ui-monospace,Menlo,Consolas,monospace;font-weight:700;">${escapeHtml(password)}</td></tr>
</table>
<p style="font-size:15px;"><a href="${escapeHtml(portalUrl)}" style="background:#8a6d3b;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none;display:inline-block;">Sign in to your dashboard</a></p>
<p style="font-size:13px;color:#8a5a00;background:#fdf6e3;border:1px solid #f0e0b0;border-radius:8px;padding:12px;margin-top:20px;"><strong>Please change this password immediately after your first sign-in.</strong> It was issued by our team, so it should not be kept as your long-term password.</p>
<p style="font-size:13px;color:#6b6b6b;margin-top:20px;">Keep this email confidential — anyone with these details can access your partner dashboard.</p>
</div></body></html>`

    return sendEmail(getSecrets, {
      to: partner.email,
      subject: `Your ${brand} Partner account — sign-in details`,
      text,
      html,
    })
  }

  // The ADMIN's view of a partner's QR image, for the review UI. Requires
  // requireAdmin — unlike /api/partner/qr/:id, which the partner calls for
  // their own dashboard and which authorises by partner session token
  // instead. Kept as two routes on purpose: the admin must be able to render
  // a QR before the partner has ever logged in.
  app.get('/api/admin/partners/:id/qr.png', requireAdmin, async (req, res, next) => {
    try {
      const id = req.params.id
      if (!/^[0-9a-f-]{36}$/i.test(id)) return res.status(400).json({ error: 'Invalid id' })

      const { data: p } = await supabase
        .from('partners')
        .select('affiliate_id')
        .eq('id', id)
        .maybeSingle()
      if (!p || !p.affiliate_id) {
        return res.status(404).json({ error: 'This partner has no issued QR code yet.' })
      }
      const { data: aff } = await supabase
        .from('affiliates')
        .select('referrer_code')
        .eq('id', p.affiliate_id)
        .maybeSingle()
      if (!aff || !aff.referrer_code) {
        return res.status(404).json({ error: 'No referrer code issued.' })
      }

      const installUrl = `${PLAY_URL}&referrer=utm_source=${encodeURIComponent(aff.referrer_code)}`
      const png = await QRCode.toBuffer(installUrl, {
        width: 320,
        margin: 1,
        errorCorrectionLevel: 'M',
      })
      res.set('Content-Type', 'image/png')
      res.set('Cache-Control', 'no-store')
      res.send(png)
    } catch (err) {
      next(err)
    }
  })

  // Issue (or re-issue) a partner's login credentials.
  //
  // ADMIN ONLY. The admin does not choose the password: the SERVER generates
  // it from a CSPRNG and emails it. That means a weak or reused password
  // cannot be introduced by hand, and the password exists in plaintext only
  // inside this request — it is never stored, never logged, and never
  // returned in the response.
  //
  // Re-issuing is also the recovery path when a partner is locked out: the
  // DB function clears the failure counter and the lockout.
  app.post('/api/admin/partners/:id/credentials', requireAdmin, async (req, res, next) => {
    try {
      const id = req.params.id
      if (!/^[0-9a-f-]{36}$/i.test(id)) return res.status(400).json({ error: 'Invalid id' })

      const { data: partner } = await supabase
        .from('partners')
        .select('id, email, legal_name, display_name, status')
        .eq('id', id)
        .maybeSingle()
      if (!partner) return res.status(404).json({ error: 'Application not found.' })

      // 24 chars over a 62-char alphabet ~= 143 bits. Far beyond bcrypt's
      // 72-byte input limit, so the whole password is always significant and
      // no entropy is silently discarded.
      const password = generatePartnerPassword(24)

      const { data, error } = await supabase.rpc('partner_set_credentials', {
        p_partner_id: id,
        p_password: password,
        p_bcrypt_cost: Number(secrets.partner_bcrypt_cost || 10),
      })
      if (error) {
        log.error('[admin] set_credentials failed:', error.message)
        return res.status(500).json({ error: error.message })
      }
      const row = Array.isArray(data) ? data[0] : data
      if (!row || !row.ok) {
        const messages = {
          password_too_short: 'Generated password was rejected.',
          invalid_bcrypt_cost: 'Configured bcrypt cost is out of range.',
          not_found: 'Application not found.',
        }
        return res.status(400).json({ error: messages[row && row.reason] || 'Could not issue credentials.' })
      }

      // Email is best-effort: the credentials ARE issued in the database at
      // this point, so a mail failure must not report the whole action as
      // failed. The admin is told plainly that delivery did not happen, and
      // can re-issue (which rotates the password and retries the email).
      const mail = await sendCredentialsEmail(partner, row.login_id, password, req)
        .catch((e) => ({ sent: false, reason: e && e.message ? e.message : 'send_failed' }))

      res.json({
        ok: true,
        loginId: row.login_id,
        emailSent: !!mail.sent,
        // Deliberately NOT returning the password in the API response. It is
        // delivered to the partner's mailbox, not to whoever holds the admin
        // session. If the email fails, re-issue rather than reading it here.
        emailTo: partner.email,
        note: mail.sent
          ? 'Credentials emailed to the partner. They must change the password at first sign-in.'
          : 'Credentials were issued but the email could NOT be sent. Re-issue to retry delivery.',
      })
    } catch (err) {
      next(err)
    }
  })

  // Small dashboard summary for the admin landing area.
  app.get('/api/admin/partners/stats/summary', requireAdmin, async (req, res, next) => {    try {
      const { data, error } = await supabase.from('partners').select('status')
      if (error) return res.status(500).json({ error: error.message })
      const counts = {}
      for (const row of data || []) {
        counts[row.status] = (counts[row.status] || 0) + 1
      }
      res.json({
        counts,
        pendingReview: (counts.submitted || 0) + (counts.under_review || 0),
        approved: counts.approved || 0,
        rejected: counts.rejected || 0,
        total: (data || []).length,
      })
    } catch (err) {
      next(err)
    }
  })

  log.log(
    `[partner] routes registered (email=${describeTransport(getSecrets).provider || 'NOT CONFIGURED'}, ` +
      `encryption=${encryptionReady(getSecrets) ? 'ready' : 'NOT CONFIGURED'})`,
  )
}

export { DOC_LABELS, REQUIRED_DOCS, BUSINESS_REGISTRATION_DOCS, MAX_DOC_BYTES }
