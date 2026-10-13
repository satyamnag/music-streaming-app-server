// ============================================================================
// Partner Program — KYC document encryption (application-level envelope)
// ============================================================================
//
// WHY THIS EXISTS
//   The dominant catastrophic failure mode for a KYC portal is that a single
//   mistake — a bucket flipped public, or a leaked Supabase service key —
//   discloses EVERY partner's identity documents at once. Storage-level
//   encryption does not help there: it protects against physical disk theft,
//   not against an application or credential compromise. OWASP Cryptographic
//   Storage states it directly: "hardware level encryption ... will provide
//   no protection if an attacker is able to compromise the server remotely."
//
//   So document bytes are encrypted HERE, in the app process, BEFORE they
//   leave for object storage. What lands in the bucket is AES-256-GCM
//   ciphertext. A leaked bucket or service key then yields unreadable bytes.
//
//   This is also what makes a real deletion guarantee possible. Supabase
//   signed URLs are NOT revocable (they are signed with a key separate from
//   the project JWT key, so rotation does not invalidate them), and object
//   storage may retain versions, so "delete the object" is not by itself
//   provable erasure. Destroying a partner's KEK-derived DEK makes every one
//   of their documents permanently unrecoverable regardless of any surviving
//   copy — crypto-shredding.
//
// DESIGN (envelope encryption, as documented by OWASP)
//   DEK  — Data Encryption Key. A fresh, random 32-byte AES-256 key PER
//          DOCUMENT. It encrypts that one document's bytes.
//   KEK  — Key Encryption Key. Comes from the server environment / secrets
//          manager (never from the database). It wraps each DEK.
//   The wrapped DEK is stored in Postgres next to the document metadata.
//   The KEK is never stored in Postgres. OWASP requires exactly this
//   separation: "the KEK must be stored separately from the DEK ... The KEK
//   should also be at least as strong as the DEK." Both are AES-256 here.
//
// ALGORITHM CHOICE
//   aes-256-gcm. OWASP: "Where available, authenticated modes should always
//   be used ... The most commonly used authenticated modes are GCM and CCM,
//   which should be used as a first preference." GCM is authenticated, so a
//   tampered ciphertext fails to decrypt rather than yielding modified
//   plaintext, and it is built into Node's crypto with no new dependency.
//
// IV HANDLING
//   A fresh random 12-byte IV is generated for every encryption, and the
//   GCM auth tag is stored alongside. Reusing an IV with the same key is
//   catastrophic for GCM, so the IV is never derived from anything
//   predictable and no IV is ever reused — a new DEK is minted per document
//   anyway, which further bounds the risk.
//
// KEY CONFIGURATION
//   The KEK is read from the live secrets object as `partner_kek`, expected
//   as 64 hex characters (32 bytes). Generate one with:
//       node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
//   Store it in Supabase Vault as `partner_kek` (the repo's existing secret
//   mechanism) or as a Render environment variable.
//
//   FAIL-CLOSED: if no KEK is configured, `encryptDocument` THROWS. Uploads
//   are refused rather than silently stored in the clear. A misconfigured
//   deployment must never quietly downgrade to plaintext KYC.

import {
  randomBytes,
  createCipheriv,
  createDecipheriv,
  createHash,
  timingSafeEqual,
} from 'node:crypto'

const ALG = 'aes-256-gcm'
const IV_BYTES = 12 // 96-bit nonce, the GCM standard
const KEY_BYTES = 32 // AES-256

/**
 * Reads and validates the KEK from the live secrets object.
 * Returns null when unconfigured; callers decide whether that is fatal.
 *
 * @param {() => Record<string,string>} getSecrets
 * @returns {Buffer|null}
 */
export function readKek(getSecrets) {
  const raw = (getSecrets() || {}).partner_kek
  if (!raw || typeof raw !== 'string') return null
  const trimmed = raw.trim()
  // Accept 64 hex chars (canonical) or 44-char base64.
  if (/^[0-9a-fA-F]{64}$/.test(trimmed)) {
    return Buffer.from(trimmed, 'hex')
  }
  try {
    const buf = Buffer.from(trimmed, 'base64')
    if (buf.length === KEY_BYTES) return buf
  } catch (_) { /* fall through */ }
  throw new Error(
    'partner_kek must be 32 bytes as 64 hex characters or base64; ' +
      'refusing to operate with a malformed key',
  )
}

/** True when document encryption is available. Used for health/diagnostics. */
export function encryptionReady(getSecrets) {
  try {
    return readKek(getSecrets) !== null
  } catch (_) {
    return false
  }
}

/**
 * Encrypts a document with a fresh per-document DEK, then wraps that DEK
 * with the KEK. Returns base64 fields ready to store in Postgres.
 *
 * @throws when the KEK is missing or malformed — callers must treat this as
 *         a hard failure and refuse the upload.
 */
export function encryptDocument(plaintext, getSecrets) {
  const kek = readKek(getSecrets)
  if (!kek) {
    throw new Error('partner_kek is not configured; refusing to store KYC unencrypted')
  }

  // 1) Fresh data key for this document only.
  const dek = randomBytes(KEY_BYTES)

  // 2) Encrypt the document bytes with the DEK.
  const iv = randomBytes(IV_BYTES)
  const cipher = createCipheriv(ALG, dek, iv)
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()])
  const tag = cipher.getAuthTag()

  // 3) Wrap the DEK with the KEK so the DEK is never at rest in the clear.
  const dekIv = randomBytes(IV_BYTES)
  const dekCipher = createCipheriv(ALG, kek, dekIv)
  const dekWrapped = Buffer.concat([dekCipher.update(dek), dekCipher.final()])
  const dekTag = dekCipher.getAuthTag()

  // Best-effort scrub of the raw DEK from this scope.
  dek.fill(0)

  return {
    ciphertext,
    enc: {
      alg: ALG,
      iv: iv.toString('base64'),
      tag: tag.toString('base64'),
      dekWrapped: dekWrapped.toString('base64'),
      dekIv: dekIv.toString('base64'),
      dekTag: dekTag.toString('base64'),
    },
  }
}

/**
 * Reverses `encryptDocument`. Throws if the auth tag does not verify, which
 * is what makes tampering detectable.
 */
export function decryptDocument(ciphertext, enc, getSecrets) {
  const kek = readKek(getSecrets)
  if (!kek) throw new Error('partner_kek is not configured')

  if (!enc || !enc.dekWrapped || !enc.dekIv || !enc.dekTag || !enc.iv || !enc.tag) {
    throw new Error('incomplete encryption metadata')
  }

  // 1) Unwrap the DEK.
  const dekDecipher = createDecipheriv(
    ALG,
    kek,
    Buffer.from(enc.dekIv, 'base64'),
  )
  dekDecipher.setAuthTag(Buffer.from(enc.dekTag, 'base64'))
  const dek = Buffer.concat([
    dekDecipher.update(Buffer.from(enc.dekWrapped, 'base64')),
    dekDecipher.final(),
  ])

  // 2) Decrypt the document.
  const decipher = createDecipheriv(ALG, dek, Buffer.from(enc.iv, 'base64'))
  decipher.setAuthTag(Buffer.from(enc.tag, 'base64'))
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()])

  dek.fill(0)
  return plaintext
}

/** SHA-256 hex digest. Used for document integrity and token hashing. */
export function sha256Hex(buf) {
  return createHash('sha256').update(buf).digest('hex')
}

/** SHA-256 hex digest of a UTF-8 string. Mirrors the SQL `partner_token_hash`. */
export function sha256HexOfString(str) {
  return createHash('sha256').update(String(str), 'utf8').digest('hex')
}

/**
 * Constant-time string comparison. Used for any secret comparison so that
 * response timing cannot leak a token byte-by-byte (CWE-208).
 */
export function safeEqual(a, b) {
  const ba = Buffer.from(String(a == null ? '' : a))
  const bb = Buffer.from(String(b == null ? '' : b))
  if (ba.length !== bb.length) return false
  return timingSafeEqual(ba, bb)
}

/** Generates a URL-safe 256-bit token (ASVS 6.5.3: CSPRNG, >= 112 bits). */
export function generateToken() {
  return randomBytes(32).toString('base64url')
}

// ---------------------------------------------------------------------------
// File-type validation
// ---------------------------------------------------------------------------
//
// OWASP: the client-supplied Content-Type "cannot be trusted, as it is
// trivial to spoof", and magic-byte checking "should not be used on its own,
// as bypassing it is pretty common and easy." So the declared type, the
// sniffed type and the size cap are all enforced together, and the images an
// admin previews are re-encoded before display.
//
// The signatures below are the standard file-format magic numbers.
const SIGNATURES = [
  { mime: 'application/pdf', ext: 'pdf', bytes: [0x25, 0x50, 0x44, 0x46, 0x2d] }, // %PDF-
  { mime: 'image/jpeg', ext: 'jpg', bytes: [0xff, 0xd8, 0xff] },
  {
    mime: 'image/png',
    ext: 'png',
    bytes: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
  },
]

export const ALLOWED_DOC_MIME = SIGNATURES.map((s) => s.mime)

/**
 * Determines the authoritative type from the file's own bytes.
 * Returns null when nothing matches — the caller must reject.
 */
export function sniffDocumentType(buffer) {
  if (!buffer || buffer.length < 8) return null
  for (const sig of SIGNATURES) {
    if (buffer.length < sig.bytes.length) continue
    let match = true
    for (let i = 0; i < sig.bytes.length; i++) {
      if (buffer[i] !== sig.bytes[i]) {
        match = false
        break
      }
    }
    if (match) return { mime: sig.mime, ext: sig.ext }
  }
  return null
}

/**
 * Validates an uploaded document end-to-end.
 * Returns `{ ok: true, mime, ext }` or `{ ok: false, reason }`.
 *
 * The filename checks implement the OWASP rules that specifically prevent
 * the NTFS alternate-data-stream trick (reject any colon), null-byte
 * truncation, and path traversal. Note that Supabase itself PERMITS ':' in
 * object names — its allowed set is a floor, not a security policy, so the
 * stricter rule is applied here.
 */
export function validateDocumentUpload({ buffer, declaredMime, filename, maxBytes }) {
  const limit = maxBytes || 5 * 1024 * 1024

  if (!buffer || buffer.length === 0) {
    return { ok: false, reason: 'empty_file' }
  }
  if (buffer.length > limit) {
    return { ok: false, reason: 'file_too_large' }
  }

  const name = String(filename == null ? '' : filename)
  // Control characters and NUL bytes.
  if (/[\u0000-\u001F\u007F]/.test(name)) {
    return { ok: false, reason: 'invalid_filename' }
  }
  // NTFS alternate data streams (OWASP: reject any filename containing ':').
  if (name.includes(':')) {
    return { ok: false, reason: 'invalid_filename' }
  }
  if (name.length > 255) {
    return { ok: false, reason: 'invalid_filename' }
  }
  // Traversal and hidden-file prefixes.
  if (/(^|[\\/])\.\.([\\/]|$)/.test(name) || name.startsWith('.')) {
    return { ok: false, reason: 'invalid_filename' }
  }

  // Declared type must be in the allow-list (catches honest mistakes only).
  if (declaredMime && !ALLOWED_DOC_MIME.includes(declaredMime)) {
    return { ok: false, reason: 'unsupported_type' }
  }

  // The file's own bytes are authoritative.
  const sniffed = sniffDocumentType(buffer)
  if (!sniffed) {
    return { ok: false, reason: 'unsupported_type' }
  }

  // If the client declared a type, it must agree with reality. A mismatch is
  // a spoofing signal, not a mere inconvenience.
  if (declaredMime && declaredMime !== sniffed.mime) {
    return { ok: false, reason: 'type_mismatch' }
  }

  return { ok: true, mime: sniffed.mime, ext: sniffed.ext }
}

// ---------------------------------------------------------------------------
// Email / phone masking for display and logs
// ---------------------------------------------------------------------------

/**
 * Masks an email for display in logs and non-privileged UI.
 * OWASP Logging: government identifiers and PII should be masked or removed
 * rather than written to logs in the clear.
 */
export function maskEmail(email) {
  const s = String(email == null ? '' : email)
  const at = s.indexOf('@')
  if (at <= 0) return '***'
  const user = s.slice(0, at)
  const domain = s.slice(at + 1)
  const head = user.slice(0, Math.min(2, user.length))
  return `${head}${'*'.repeat(Math.max(1, user.length - head.length))}@${domain}`
}

/**
 * Masks a government identifier (PAN/GSTIN) for display. Shows only the
 * last 4 characters. Used in the admin review queue list view and in any
 * log line, so a full identifier is only ever visible on the detail screen
 * where it is actually needed for verification.
 */
export function maskGovernmentId(value) {
  const s = String(value == null ? '' : value)
  if (s.length <= 4) return '****'
  return `${'*'.repeat(s.length - 4)}${s.slice(-4)}`
}

/**
 * Hashes an IP for the audit log. Storing a raw IP is personal data under
 * the DPDP Act; a salted hash still lets abuse be correlated (the same
 * actor produces the same value) without retaining the address itself.
 */
export function hashIp(ip, salt) {
  if (!ip) return null
  return createHash('sha256')
    .update(`${salt || ''}|${ip}`)
    .digest('hex')
    .slice(0, 32)
}
