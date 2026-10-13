// ============================================================================
// In-memory Supabase stub for Partner Program integration tests
// ============================================================================
//
// Implements ONLY the client surface that server.js and partner_routes.mjs
// actually use:
//   - .from(table).select/insert/update/delete with eq/is/order/limit and
//     maybeSingle/single/then
//   - .rpc(name, params) for every partner_* function
//   - .storage.from(bucket).upload/download/remove
//
// The RPC implementations deliberately mirror the SQL semantics that the
// application depends on, so a test failure here means the ROUTE logic is
// wrong — not that the stub is a perfect database. The SQL remains the real
// authority and is reviewed separately.

import crypto from 'node:crypto'

export const db = {
  partners: new Map(),
  documents: new Map(),
  affiliates: new Map(),
  coupons: new Map(),
  // Audit rows are kept as a Map (so the table API works) and mirrored into a
  // flat array for convenient assertions in tests.
  audit_log: new Map(),
  audit: [],
  email_events: new Map(),
}

// PostgREST table-name aliases. The application queries `partner_documents`,
// `partner_audit_log` and `partner_email_events`; the RPC implementations below
// use the shorter internal names. Both must see the same rows.
export const TABLES = {
  partners: db.partners,
  partner_documents: db.documents,
  partner_audit_log: db.audit_log,
  partner_email_events: db.email_events,
  affiliates: db.affiliates,
  coupons: db.coupons,
}

export const state = {
  rpcLog: [],
  storageObjects: new Map(),
}

export function uuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === 'x' ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}

export function resetStub() {
  db.partners.clear()
  db.documents.clear()
  db.affiliates.clear()
  db.coupons.clear()
  db.audit_log.clear()
  db.email_events.clear()
  db.audit.length = 0
  state.rpcLog.length = 0
  state.storageObjects.clear()
}

function sha256hex(s) {
  return crypto.createHash('sha256').update(String(s), 'utf8').digest('hex')
}

function makeSupabaseStub() {
  const chain = (table) => {
    const st = { table, filters: [], op: 'select', payload: null }
    const api = {
      select() { st.op = 'select'; return api },
      insert(payload) { st.op = 'insert'; st.payload = payload; return api },
      update(payload) { st.op = 'update'; st.payload = payload; return api },
      delete() { st.op = 'delete'; return api },
      eq(col, val) { st.filters.push([col, val]); return api },
      is(col, val) { st.filters.push([col, val]); return api },
      order() { return api },
      limit() { return api },
      maybeSingle() { return run(true) },
      single() { return run(true) },
      then(resolve, reject) { return run(false).then(resolve, reject) },
    }

    function match(row) {
      return st.filters.every(([col, val]) =>
        val === null ? row[col] == null : row[col] === val,
      )
    }

    async function run(single) {
      const store = TABLES[st.table]
      if (!store) return { data: null, error: { message: 'unknown table ' + st.table } }

      if (st.op === 'insert') {
        const rows = Array.isArray(st.payload) ? st.payload : [st.payload]
        const inserted = rows.map((r) => {
          const row = { id: r.id || uuid(), created_at: new Date().toISOString(), ...r }
          store.set(row.id, row)
          // Mirror audit rows into the flat array so tests can assert on them
          // the same way the SQL trigger appends them.
          if (st.table === 'partner_audit_log') {
            db.audit.push({ ...row })
          }
          return row
        })
        return { data: single ? inserted[0] : inserted, error: null }
      }

      const rows = Array.from(store.values()).filter(match)

      if (st.op === 'update') {
        rows.forEach((r) => Object.assign(r, st.payload))
        return { data: single ? (rows[0] || null) : rows, error: null }
      }
      if (st.op === 'delete') {
        rows.forEach((r) => store.delete(r.id))
        return { data: rows, error: null }
      }
      return { data: single ? (rows[0] || null) : rows, error: null }
    }

    return api
  }

  return {
    from: (table) => chain(table),

    rpc: async (name, params) => {
      state.rpcLog.push({ name, params })
      const p = params || {}
      const hashOf = (tok) => sha256hex(tok)

      switch (name) {
        case 'partner_register': {
          const email = String(p.p_email || '').toLowerCase()
          const existing = Array.from(db.partners.values()).find(
            (r) => String(r.email).toLowerCase() === email,
          )
          // Mirrors the SQL: a duplicate returns the row with NO token.
          if (existing) {
            return { data: [{ partner_id: existing.id, portal_token: null, existing: true }], error: null }
          }
          const id = uuid()
          const token = 'tok_' + crypto.randomBytes(16).toString('hex')
          db.partners.set(id, {
            id,
            email,
            portal_token_hash: hashOf(token),
            email_verified: false,
            email_verify_token_hash: null,
            email_verify_expires_at: null,
            email_verify_attempts: 0,
            status: 'draft',
            country: 'India',
            social_links: {},
            // Mirrors the schema DEFAULT: the DPDP Rules r.8(3) one-year
            // minimum retention floor, set at creation.
            earliest_purge_at: new Date(Date.now() + 365 * 86400_000).toISOString(),
            created_at: new Date().toISOString(),
          })
          return { data: [{ partner_id: id, portal_token: token, existing: false }], error: null }
        }

        case 'partner_set_verification_token': {
          const row = db.partners.get(p.p_partner_id)
          if (!row || row.email_verified) return { data: false, error: null }
          row.email_verify_token_hash = hashOf(p.p_raw_token)
          row.email_verify_expires_at = new Date(Date.now() + 24 * 3600_000).toISOString()
          row.email_verify_attempts = 0
          return { data: true, error: null }
        }

        case 'partner_get_self': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          return { data: row ? [row] : [], error: null }
        }

        case 'partner_consume_verification': {
          const h = hashOf(p.p_raw_token)
          const row = Array.from(db.partners.values()).find((r) => r.email_verify_token_hash === h)
          if (!row) {
            return { data: [{ partner_id: null, email: null, ok: false, reason: 'invalid' }], error: null }
          }
          if (row.email_verified) {
            return { data: [{ partner_id: row.id, email: row.email, ok: true, reason: 'already_verified' }], error: null }
          }
          if (!row.email_verify_expires_at || new Date(row.email_verify_expires_at) < new Date()) {
            return { data: [{ partner_id: row.id, email: row.email, ok: false, reason: 'expired' }], error: null }
          }
          // Atomic single-use burn: clearing the hash is the SQL equivalent.
          row.email_verified = true
          row.email_verified_at = new Date().toISOString()
          row.email_verify_token_hash = null
          row.email_verify_expires_at = null
          return { data: [{ partner_id: row.id, email: row.email, ok: true, reason: 'verified' }], error: null }
        }

        case 'partner_prepare_verification': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: [{ can_send: false, reason: 'invalid_session' }], error: null }
          if (row.email_verified) {
            return { data: [{ partner_id: row.id, email: row.email, can_send: false, reason: 'already_verified' }], error: null }
          }
          return { data: [{ partner_id: row.id, email: row.email, status: row.status, can_send: true, reason: 'ok' }], error: null }
        }

        case 'partner_save_draft': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: 'invalid_session', error: null }
          if (!['draft', 'needs_info'].includes(row.status)) return { data: 'locked', error: null }

          // The SQL function's allow-list. A key outside it is IGNORED, which
          // is what makes the client unable to set status/affiliate_id.
          const allowed = [
            'applicant_type', 'legal_name', 'display_name', 'entity_type', 'gender',
            'date_of_birth', 'phone', 'address_line1', 'address_line2', 'city',
            'state', 'postal_code', 'country', 'pan_number', 'gstin',
            'aadhaar_last4', 'aadhaar_consent', 'bank_account_name',
            'bank_account_last4', 'bank_ifsc', 'audience_size', 'promotion_plan',
            'website_url', 'social_links',
          ]
          for (const [k, v] of Object.entries(p.p_fields || {})) {
            if (allowed.includes(k)) row[k] = v
          }
          // Reproduce the partners_pan_format CHECK.
          if (row.pan_number && !/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(row.pan_number)) {
            return {
              data: null,
              error: { code: '23514', message: 'violates check constraint "partners_pan_format"' },
            }
          }
          return { data: 'saved', error: null }
        }

        case 'partner_add_document': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: [{ ok: false, reason: 'invalid_session' }], error: null }
          if (!row.email_verified) return { data: [{ ok: false, reason: 'email_not_verified' }], error: null }
          if (!['draft', 'needs_info'].includes(row.status)) {
            return { data: [{ ok: false, reason: 'locked' }], error: null }
          }
          const live = Array.from(db.documents.values()).filter(
            (d) => d.partner_id === row.id && !d.superseded_at,
          )
          if (live.length >= 15) return { data: [{ ok: false, reason: 'too_many_documents' }], error: null }

          live.filter((d) => d.doc_type === p.p_doc_type)
            .forEach((d) => { d.superseded_at = new Date().toISOString() })

          const id = uuid()
          db.documents.set(id, {
            id,
            partner_id: row.id,
            doc_type: p.p_doc_type,
            object_key: p.p_object_key,
            original_filename: p.p_original_filename,
            mime_type: p.p_mime_type,
            sniffed_mime_type: p.p_sniffed_mime_type,
            size_bytes: p.p_size_bytes,
            sha256: p.p_sha256,
            enc_iv: p.p_enc_iv,
            enc_tag: p.p_enc_tag,
            dek_wrapped: p.p_dek_wrapped,
            dek_iv: p.p_dek_iv,
            dek_tag: p.p_dek_tag,
            review_status: 'pending',
            superseded_at: null,
            uploaded_at: new Date().toISOString(),
          })
          return { data: [{ ok: true, document_id: id, reason: 'ok' }], error: null }
        }

        case 'partner_list_documents': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: [], error: null }
          return {
            data: Array.from(db.documents.values())
              .filter((d) => d.partner_id === row.id && !d.superseded_at)
              .map((d) => ({ ...d })),
            error: null,
          }
        }

        case 'partner_delete_document': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: [{ ok: false, reason: 'invalid_session' }], error: null }
          if (!['draft', 'needs_info'].includes(row.status)) {
            return { data: [{ ok: false, reason: 'locked' }], error: null }
          }
          const doc = db.documents.get(p.p_document_id)
          if (!doc || doc.partner_id !== row.id) {
            return { data: [{ ok: false, reason: 'not_found' }], error: null }
          }
          db.documents.delete(p.p_document_id)
          return { data: [{ ok: true, object_key: doc.object_key, reason: 'ok' }], error: null }
        }

        case 'partner_submit': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: [{ ok: false, status: 'invalid_session', missing: ['session'] }], error: null }
          if (!row.email_verified) {
            return { data: [{ ok: false, status: 'email_not_verified', missing: ['email'] }], error: null }
          }
          if (['submitted', 'under_review', 'approved'].includes(row.status)) {
            return { data: [{ ok: true, status: row.status, missing: [] }], error: null }
          }
          if (['rejected', 'withdrawn'].includes(row.status)) {
            return { data: [{ ok: false, status: row.status, missing: ['application_closed'] }], error: null }
          }

          const missing = []
          if (!row.applicant_type) missing.push('applicant_type')
          if (!row.legal_name) missing.push('legal_name')
          if (!row.date_of_birth) missing.push('date_of_birth')
          if (!row.gender) missing.push('gender')
          if (!row.phone) missing.push('phone')
          if (!row.address_line1) missing.push('address_line1')
          if (!row.city) missing.push('city')
          if (!row.state) missing.push('state')
          if (!row.postal_code) missing.push('postal_code')
          if (!row.pan_number) missing.push('pan_number')
          if (row.applicant_type === 'business' && !row.entity_type) missing.push('entity_type')
          if (!row.terms_accepted || !row.privacy_accepted || !row.truthfulness_declared) {
            missing.push('consent')
          }

          const docs = Array.from(db.documents.values())
            .filter((d) => d.partner_id === row.id && !d.superseded_at)
          if (!docs.some((d) => d.doc_type === 'pan_card')) missing.push('doc:pan_card')
          if (!docs.some((d) => d.doc_type === 'address_proof')) missing.push('doc:address_proof')
          if (row.applicant_type === 'business') {
            const biz = ['gst_certificate', 'incorporation_certificate', 'udyam_certificate',
              'shop_establishment_licence', 'partnership_deed', 'trust_deed']
            if (!docs.some((d) => biz.includes(d.doc_type))) missing.push('doc:business_registration')
          }

          if (missing.length) return { data: [{ ok: false, status: 'incomplete', missing }], error: null }
          row.status = 'submitted'
          row.submitted_at = new Date().toISOString()
          return { data: [{ ok: true, status: 'submitted', missing: [] }], error: null }
        }

        case 'partner_admin_list': {
          const rows = Array.from(db.partners.values())
            .filter((r) => !p.p_status || r.status === p.p_status)
            .map((r) => ({
              id: r.id, email: r.email, legal_name: r.legal_name, display_name: r.display_name,
              applicant_type: r.applicant_type, entity_type: r.entity_type, status: r.status,
              email_verified: r.email_verified, submitted_at: r.submitted_at,
              created_at: r.created_at, affiliate_id: r.affiliate_id || null,
              referrer_code: r.affiliate_id
                ? db.affiliates.get(r.affiliate_id)?.referrer_code : null,
              coupon_code: r.affiliate_id
                ? Array.from(db.coupons.values()).find((c) => c.affiliate_id === r.affiliate_id)?.code
                : null,
              commission_amount: r.commission_amount || 0,
              document_count: Array.from(db.documents.values())
                .filter((d) => d.partner_id === r.id && !d.superseded_at).length,
              reviewed_by: r.reviewed_by || null,
            }))
          return { data: rows, error: null }
        }

        case 'partner_decide': {
          const row = db.partners.get(p.p_partner_id)
          if (!row) return { data: [{ ok: false, reason: 'not_found' }], error: null }
          if (row.status === 'approved') {
            return { data: [{ ok: false, status: row.status, reason: 'already_approved' }], error: null }
          }
          const map = {
            reject: 'rejected', needs_info: 'needs_info',
            under_review: 'under_review', withdraw: 'withdrawn',
          }
          row.status = map[p.p_decision]
          row.decision_note = p.p_note || null
          row.reviewed_by = p.p_admin
          row.reviewed_at = new Date().toISOString()

          // Mirror the SQL: a rejection/withdrawal schedules a purge, but
          // never before the DPDP Rules r.8(3) one-year retention floor.
          if (row.status === 'rejected' || row.status === 'withdrawn') {
            const days = Number.isInteger(p.p_purge_days) && p.p_purge_days > 0 ? p.p_purge_days : 90
            const floor = row.earliest_purge_at
              || new Date(Date.now() + 365 * 86400_000).toISOString()
            const wanted = new Date(Date.now() + days * 86400_000).toISOString()
            row.purge_after = wanted > floor ? wanted : floor
          } else {
            row.purge_after = null
          }

          return { data: [{ ok: true, status: row.status, reason: 'ok' }], error: null }
        }

        case 'partner_approve': {
          const row = db.partners.get(p.p_partner_id)
          if (!row) return { data: [{ ok: false, reason: 'not_found' }], error: null }

          // Idempotent, exactly like the SQL.
          if (row.status === 'approved' && row.affiliate_id) {
            const aff = db.affiliates.get(row.affiliate_id)
            const coupon = Array.from(db.coupons.values())
              .find((c) => c.affiliate_id === row.affiliate_id)
            return {
              data: [{
                ok: true, affiliate_id: row.affiliate_id,
                referrer_code: aff?.referrer_code, coupon_code: coupon?.code,
                reason: 'already_approved',
              }],
              error: null,
            }
          }
          if (!['submitted', 'under_review', 'needs_info'].includes(row.status)) {
            return { data: [{ ok: false, reason: 'invalid_state:' + row.status }], error: null }
          }
          if (!row.email_verified) {
            return { data: [{ ok: false, reason: 'email_not_verified' }], error: null }
          }
          if (p.p_referrer_code
            && Array.from(db.affiliates.values()).some((a) => a.referrer_code === p.p_referrer_code)) {
            return { data: [{ ok: false, reason: 'referrer_code_taken' }], error: null }
          }
          if (p.p_coupon_code
            && Array.from(db.coupons.values()).some((c) => c.code === p.p_coupon_code)) {
            return { data: [{ ok: false, reason: 'coupon_code_taken' }], error: null }
          }

          const affId = uuid()
          const ref = p.p_referrer_code
            || 'SB-P' + crypto.randomBytes(4).toString('hex').toUpperCase()
          db.affiliates.set(affId, {
            id: affId,
            name: row.display_name || row.legal_name || row.email,
            contact_email: row.email,
            commission_amount: p.p_commission_amount || 0,
            referrer_code: ref,
            status: 'active',
          })

          const couponCode = p.p_coupon_code
            || 'SB' + crypto.randomBytes(4).toString('hex').toUpperCase()
          db.coupons.set(uuid(), {
            id: uuid(), code: couponCode, affiliate_id: affId, status: 'active',
            max_redemptions: p.p_coupon_max_redemptions || null,
            redemption_count: 0,
            expires_at: p.p_coupon_expires_at || null,
          })

          row.status = 'approved'
          row.affiliate_id = affId
          row.approved_at = new Date().toISOString()
          row.commission_amount = p.p_commission_amount || 0
          return {
            data: [{ ok: true, affiliate_id: affId, referrer_code: ref, coupon_code: couponCode, reason: 'approved' }],
            error: null,
          }
        }

        case 'partner_withdraw': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: [{ ok: false, reason: 'invalid_session' }], error: null }
          if (row.status === 'withdrawn') {
            return { data: [{ ok: true, status: 'withdrawn', purge_after: row.purge_after, reason: 'already_withdrawn' }], error: null }
          }
          // Mirror the SQL: deletion is floored at earliest_purge_at (DPDP
          // Rules r.8(3) one-year minimum), even though processing stops now.
          const floor = row.earliest_purge_at || new Date(Date.now() + 365 * 86400_000).toISOString()
          const wanted = new Date(Date.now() + 90 * 86400_000).toISOString()
          row.purge_after = wanted > floor ? wanted : floor
          row.status = 'withdrawn'
          row.decision_note = p.p_reason || null
          row.portal_token_hash = 'withdrawn:' + row.id
          return { data: [{ ok: true, status: 'withdrawn', purge_after: row.purge_after, reason: 'ok' }], error: null }
        }

        case 'partner_accept_disclosure': {
          const h = hashOf(p.p_token)
          const row = Array.from(db.partners.values()).find((r) => r.portal_token_hash === h)
          if (!row) return { data: 'invalid_session', error: null }
          if (!['draft', 'needs_info'].includes(row.status)) return { data: 'locked', error: null }
          db.audit.push({
            id: uuid(), action: 'disclosure_obligation_accepted',
            detail: { version: p.p_version }, created_at: new Date().toISOString(),
          })
          return { data: 'ok', error: null }
        }

        case 'partner_log_document_access': {
          db.audit.push({
            id: uuid(),
            action: p.p_action, result: p.p_result,
            document_id: p.p_document_id, actor: p.p_admin,
            created_at: new Date().toISOString(),
          })
          return { data: null, error: null }
        }

        default:
          return { data: null, error: { message: 'unhandled rpc ' + name } }
      }
    },

    storage: {
      from: (bucket) => ({
        upload: async (key, body) => {
          state.storageObjects.set(bucket + '/' + key, Buffer.from(body))
          return { data: { path: key }, error: null }
        },
        download: async (key) => {
          const buf = state.storageObjects.get(bucket + '/' + key)
          if (!buf) return { data: null, error: { message: 'not found' } }
          return { data: new Blob([buf]), error: null }
        },
        remove: async (keys) => {
          for (const k of (Array.isArray(keys) ? keys : [keys])) {
            state.storageObjects.delete(bucket + '/' + k)
          }
          return { data: null, error: null }
        },
        getPublicUrl: () => ({ data: { publicUrl: 'https://example.invalid/x' } }),
      }),
    },
  }
}

export function createClient() {
  return makeSupabaseStub()
}

export default { createClient }
