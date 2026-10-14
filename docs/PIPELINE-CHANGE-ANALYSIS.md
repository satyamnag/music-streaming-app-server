# Pipeline Change — Decision Record

**Status: DECIDED — hybrid approach. Implementation begins.**

Supersedes the analysis in this file's earlier revision.

---

## The decision

```
Partner  ──►  Google Form  ──►  admin reviews request
              (name + email        │
               ONLY)               ▼
                          admin sends INVITE
                                   │
                                   ▼
                    partner completes KYC on YOUR portal
                    (consent recorded, documents encrypted,
                     every DB constraint enforced)
                                   │
                                   ▼
                   admin verifies documents in the admin panel
                                   │
                                   ▼
              approve ──► QR + referral code + discount code
                                   │
                                   ▼
        admin generates credentials ──► PARTNER DASHBOARD
                                        (QR, referral code,
                                         discount code, referrals,
                                         commissions)
```

**The Google Form carries no personal data beyond a name and an email address.**
Everything sensitive happens on the company's own portal, under the company's
own encryption, with the company's own consent record.

---

## Why documents were moved off Google Forms

Four findings, each verified from Google's own documentation (PRIMARY), make
document collection through Forms impossible to reconcile with the DPDP Act.

### 1. Erasure cannot be honoured — DPDP s.8(7), s.12

Google states verbatim:

> "Deleting responses from Forms does not delete attached files."

A partner exercising their right to erasure could not have it satisfied. **The
failure would be the company's**, under s.8(1), not Google's. No engineering on
our side can fix a limitation of the platform.

### 2. Consent evidence would be lost — DPDP s.6(10)

The Act places the **burden of proving** that valid notice was given and consent
obtained on the company, in any proceeding. The portal discharges this with a
consent version number and a server-side timestamp, per partner, per policy
revision.

A Google Forms response row does not. There is no record of *which* notice was
shown, and rule 3 requires the notice to link to **the company's own website or
app** — a Google Form URL does not satisfy that.

### 3. A processor contract is required — DPDP s.8(2)

Processing may occur "only under a valid contract". A **consumer @gmail.com**
Form has no Data Processing Addendum — only consumer Terms of Service. That is a
breach on its face. Workspace brings in the Cloud DPA, but a company-owned
Workspace account would then be mandatory.

### 4. Aadhaar exposure becomes criminal, not merely regulatory

Aadhaar Act s.8A(4)(b) is a **flat prohibition** on collecting *or* storing an
Aadhaar number for any purpose — consent does not cure it. A Google Form has
none of the structural exclusions the portal enforces (no Aadhaar document type,
no column, route refuses it).

Exposure: s.40 (up to 3 years / ₹1 lakh), s.43 (**directors and officers
personally liable**), and the s.47 proviso lets **an individual Aadhaar holder
file the complaint directly** — the company does not get a UIDAI-only gate.

### Additional operational findings

- Uploads land in the **form owner's personal My Drive** — shared drives are
  explicitly forbidden for file-upload questions.
- **Permissions cannot be restricted downward**: "You cannot give someone less
  access to a specific file than they have to its parent folder."
- Revocation spans **three unsynchronised surfaces** (form, sheet, Drive folder).
- If the owner's account is deleted, files live **20 days** and are recoverable
  only if the account is restored.

---

## The separate finding that would have blocked the Form anyway

**Respondents must sign in to a Google Account to upload a file.** Verified
verbatim from Google:

> "To answer this question, responders need to sign in to a Google Account."

Anonymous public collection is **impossible**. Every partner would need a Google
Account before they could apply — a real barrier for a public programme, and a
requirement we would have discovered only after building the form.

This makes the hybrid choice doubly correct: the intake Form asks only for a
name and an email, which requires no sign-in.

---

## Corrections this research produced

Two errors in earlier project documentation are corrected here and in the
affected files:

| Was | Is |
|---|---|
| "Aadhaar Act s.38A" | **s.40**. s.38A does not exist; the earlier citation referenced a non-existent provision. |
| s.8A(4)(b) described loosely | It is a **flat prohibition on collection and storage**, not a consent or tokenisation rule. The consent limb is s.8A(2)(a). |
| DPDP Rules r.8(3) one-year floor treated as settled | The text is verified, but it is tied to **Seventh Schedule purposes, all State-facing**. Scope is ambiguous — flagged UNVERIFIED, not asserted. |

Also noted: the DPDP Rules commence in stages. Rules 3, 5–16, 22 and 23 —
including rules 6, 7 and 8 — commence **18 months after 13 November 2025**, so
around **May 2027**. They are not yet in force, which reduces urgency but does
not change the design.

---

## What is being built

| Component | Scope |
|---|---|
| **Portal becomes admin-only** | Public `/partner` routes removed; the whole surface moves behind `requireAdmin` |
| **Partner credentials** | Admin generates a partner ID and password; hashed properly; forced change on first login |
| **Partner dashboard** | QR, referral code, discount code, referrals, commissions — **read-only** |
| **Commission display only** | No payout execution. Keeps the s.194H TDS question dormant. |
| **Google Form intake (optional)** | Name + email only. A separate decision; nothing sensitive depends on it. |

### Dashboard data — already present

| Element | Source | Status |
|---|---|---|
| QR code | `affiliates.referrer_code` | ✅ exists |
| Referral code | same | ✅ exists |
| Discount code | `coupons.code` | ✅ exists |
| Coupon redemptions | `coupons.redemption_count` | ✅ exists |
| Referrals | `affiliate_referrals` | ✅ exists |
| Commission earned | `affiliate_commissions.commission_amount` | ✅ exists |
| Commission status | `affiliate_commissions.status` | ✅ exists |

Only partner authentication and the dashboard UI are genuinely new.

---

## Honest residual risks

1. **The intake Form still involves Google.** Name and email only, so no
   sensitive category is processed — but it is still a third-party processor for
   that limited data. Low risk; worth a line in the privacy notice.
2. **Rule 8(3)'s scope is ambiguous.** The one-year retention floor is retained
   in the schema — retaining longer than required is safe, retaining less would
   not be.
3. **Commencement of DPDP Act ss.5, 6 and 8 could not be verified** from a
   fetched primary source. Worth confirming with counsel.

> This is engineering analysis informed by research, **not legal advice**. The
> Aadhaar findings in particular warrant review by qualified Indian counsel
> before launch.

---

# AS BUILT — what was actually implemented

The section above is the plan. This section records what shipped, so the
document does not drift from the code.

## Credential model: one session credential, not two

The requirement was "we (admin) will provide them generated user ID and
password". The `partners` table already had `portal_token_hash`, and **14
SECURITY DEFINER functions authenticate against it**. Adding a parallel
password check to each would have meant 14 hand-edited auth paths, where a
mistake in any one is a silent privilege bug.

So instead: **login exchanges (login_id, password) for a freshly minted opaque
session token of exactly the same shape `partner_register` already produced.**
Every existing function kept working with **zero modification**, and the
password never reaches them. The only new anonymous auth surface is one
function, `partner_login`.

This is asserted, not assumed: `partner_auth.test.sql` proves a token from the
new login drives the pre-existing `partner_get_self` unchanged, and the HTTP
suite proves the same session works on `/api/partner/me`.

## What was added

| Layer | Object | Purpose |
|---|---|---|
| Schema | 8 columns on `partners` | `login_id`, `password_hash`, `must_change_password`, `password_set_at`, `password_changed_at`, `failed_login_count`, `locked_until`, `last_login_at` |
| Schema | `partners_login_id_key` (unique, `upper(login_id)`) | One handle per partner, case-insensitively; NULLs may repeat |
| Schema | `partners_login_id_format`, `partners_credentials_paired` | A malformed handle cannot be written, and a password without a handle (a silently unusable account) cannot exist |
| Function | `sb_crypt`, `sb_gen_salt` | Schema-resolved pgcrypto wrappers, matching the existing `sb_digest`/`sb_random_bytes` pattern |
| Function | `partner_gen_login_id()` | `SB-XXXXXX` over a 31-char alphabet with no vowels and no look-alikes (0/O, 1/I/L) |
| Function | `partner_set_credentials(...)` | **service_role only.** Writes the handle + bcrypt hash |
| Function | `partner_change_password(...)` | Partner sets their own password via a live session |
| Function | `partner_login(...)` | The only new anon surface. Mints a session |
| Function | `partner_dashboard(token)` | Read-only artefacts + aggregates |
| Route | `POST /api/admin/partners/:id/credentials` | Admin issues; server generates the password; emails it |
| Route | `POST /api/partner/login` | Sign in |
| Route | `POST /api/partner/change-password` | Forced first-login change |
| Route | `GET /api/partner/dashboard` | Dashboard data |
| UI | `viewLogin`, `viewChangePw`, `viewDashboard` in `partner.html` | Sign-in, forced change, dashboard |
| UI | "Issue sign-in credentials" in `admin.html` | Admin action + lockout recovery |

## Security properties, each with its test

| Property | How it is enforced | Proven by |
|---|---|---|
| The admin can never choose or read a partner password | Server generates it from a CSPRNG; it is emailed and never returned by the API | `partner-auth-http.test.mjs`: response has no `password` field |
| No user enumeration | Unknown handle, wrong password and lockout all return the identical `invalid_credentials`, and an unknown handle still burns one bcrypt verification so the timing matches | DB + HTTP suites assert the exact same message for both |
| Passwords are strong and unbiased | 24 chars from `[A-Za-z0-9]`, rejection-sampled so `% 62` cannot skew the alphabet, and 24 bytes keeps clear of bcrypt's 72-byte silent-truncation limit | `partner_crypto.test.mjs`: all 62 characters reachable over 62k draws |
| Credential stuffing is throttled | Per-account lockout counted in the DB (survives restart), plus a coarser IP limiter on the route | DB suite drives 8 failures; HTTP suite asserts 429 on a flood |
| A leaked password does not survive | Every login rotates the session token; changing the password also invalidates the session that performed it | DB + HTTP suites assert the old token and old password both die |
| The dashboard leaks no KYC | The function returns no identity column at all, asserted against the declared signature | DB suite asserts the return type has no KYC field; HTTP suite asserts no KYC key in the payload |
| A session cannot read another partner | The affiliate is resolved FROM the partner row; no id is accepted as a parameter | DB suite asserts zero rows for a foreign token hash |
| No secret reaches the audit trail | Credential events are logged without the password or its hash | DB + HTTP suites scan every audit row |

## Two bugs this work found and fixed

1. **Install-URL drift.** The first version of `partner_dashboard` built the QR
   link as `...&referrer=<code>`. Every other construction site in the codebase
   (twice in `partner_routes.mjs`, once in `server.js`) uses the Google Play
   Install Referrer form `...&referrer=utm_source=<code>`, which is what the
   shipped app actually parses. The wrong form would have produced a QR that
   silently attributed nothing. Corrected, and the test now asserts the exact
   `utm_source` form.

2. **A misleading comment on the admin QR route.** It described the route as
   partner-authorised, when it is in fact `requireAdmin`. Corrected, since a
   wrong trust-boundary comment is how a future editor introduces a real hole.

## Notes for whoever picks this up

- **`admin_token` is read from Vault and OVERRIDES the `ADMIN_TOKEN` env var**
  at startup (`VAULT_SECRET_KEYS` / `loadSecretsFromVault()` in `server.js`).
  A test that assumes the env value will pass or fail depending on what a
  previous run left in `vault.decrypted_secrets`. `partner-auth-http.test.mjs`
  reads the effective value instead of assuming.
- **Run the partner suites with their documented wrappers.** `partner-flow`
  needs `partner-stub-register.mjs` and the real-DB suites need
  `real-db-register.mjs`; running `node --test` directly boots the real
  Supabase client and fails with `fetch failed` for reasons unrelated to the code.
- **`partner-audit_log.partner_id` is NOT NULL** and FK-bound to `partners(id)`,
  so an unknown-handle login attempt is deliberately **not** audited there —
  there is no partner to attribute, and inventing one would write a false
  identity. Those attempts are covered by the route's rate limiter instead.

## Verification totals at the time of writing

| Suite | Result |
|---|---|
| `partner_db.test.sql` | 131 assertions, all passed |
| `partner_auth.test.sql` (new) | 103 assertions, all passed |
| `partner_crypto.test.mjs` | 42 passed, 0 failed |
| `partner_email.test.mjs` | 10 passed, 0 failed |
| `partner-flow.test.mjs` (stub HTTP) | 37 passed, 0 failed |
| `partner-real-db.test.mjs` (real PG over HTTP) | 29 passed, 0 failed |
| `partner-auth-http.test.mjs` (new) | 16 passed, 0 failed |
| `partner-verify.cjs` (static/security) | all checks passed |

