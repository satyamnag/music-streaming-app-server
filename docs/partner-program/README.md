# Soulful Bhakti Partner Program

Self-service partner onboarding, due diligence, and issuance of the partner's
QR code and discount coupon — for the Android app, **with zero changes to the
Android app**.

---

## 1. What this is, and the one architectural decision that matters

The partner journey is:

```
register  ->  verify email  ->  KYC form  ->  upload documents  ->  APPLY
                                                                      |
                                              admin due diligence  <--+
                                                      |
                              approve  ->  affiliate + QR referrer code + discount coupon
```

The important design decision is in that last line.

**Approval does not create a parallel marketing system.** It creates a row in
the **existing `public.affiliates` table** that the affiliate program has used
since migrations 004/008/009, and links it back via `partners.affiliate_id`.

That is deliberate, and it is what delivers the "no Android changes"
requirement. The shipped app already contains the whole downstream pipeline:

- it reads the Google Play **install referrer** on first launch
  (`lib/services/install_referrer/referrer_service.dart`),
- it binds the user to the affiliate via the `bind_affiliate_referral` RPC on
  first sign-in,
- it validates and redeems coupons via `validate_coupon` / `redeem_coupon`,
- commission is credited only from **verified Superwall webhooks**.

Because an approved partner *is* an affiliate, all of that works unchanged.
The QR this program issues encodes exactly the same URL shape the existing
admin "Affiliate & QR Code" screen produces:

```
https://play.google.com/store/apps/details?id=com.soulfulbhakti.app&referrer=utm_source=<REFERRER_CODE>
```

---

## 2. Components added

| File | Purpose |
|---|---|
| `server/migrations/033_partner_program.sql` | Schema, RLS posture, all RPCs, private KYC bucket |
| `server/partner_routes.mjs` | Public portal API + admin review API |
| `server/partner_crypto.mjs` | Envelope encryption, file validation, masking |
| `server/partner_email.mjs` | Minimal, dependency-free, fail-closed email transport |
| `server/partner.html` | Partner-facing portal (public) |
| `server/admin.html` | *(modified)* new "Partner Applications" review section |
| `server/server.js` | *(modified)* imports, secrets, route registration, multer error mapping |

Tests: `npm run test:partner` (see §8).

---

## 3. Deployment steps

### 3.0 URLs: where the portal lives

There are **two hosts** involved, and the split is deliberate:

| URL | Served by | Purpose |
|---|---|---|
| `https://soulfulbhakti.com/partner` | The marketing website (Next.js on Cloudflare) | The **public front door** partners are given. It forwards to the portal. |
| `https://admin.soulfulbhakti.com/partner` | This Express server on Render | The **portal itself** — the application, its API, and the encrypted document store. |

The root domain is served by the website, which is a different deployment and
never reaches Render — so the portal cannot be *served* from the root domain.
The website therefore owns the `/partner` route and forwards to the portal.
That keeps the recognisable branded URL in partners' hands while the portal
keeps running on the infrastructure that owns the partner database and the
admin review queue.

**`PARTNER_PUBLIC_BASE_URL`** (see §3.3) controls the branded origin used in
partner-facing copy. Verification emails deliberately link to the **serving**
host so a one-time security token never depends on the forward staying in
place; the code detects whether the two hosts differ and picks accordingly.

Both `/partner/terms` and `/partner/privacy` are exposed on **both** hosts for
consistency.

### 3.1 Apply the migration

Open the Supabase dashboard → SQL Editor → run
`server/migrations/033_partner_program.sql` in full.

It is written to be **re-runnable** (`create table if not exists`,
`create or replace function`, `drop trigger if exists`). It creates:

- `partners`, `partner_documents`, `partner_audit_log`, `partner_email_events`
- the private storage bucket **`partner-kyc`** (`public = false`)
- 17 functions, all with `search_path` pinned

Verify at the end of the script (it prints these):
- 4 tables present
- `partner-kyc` bucket with `public = false`
- all `partner_*` functions listed

### 3.2 Generate the document encryption key

Document encryption is **fail-closed**: without a key, uploads are refused
rather than stored in the clear.

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

> **Back this key up somewhere durable and separate from Supabase.**
> If it is lost, every uploaded document becomes permanently unreadable —
> that is the same property that makes deletion verifiable (§5.4), but it
> cuts both ways.

### 3.3 Configure secrets

Store these in **Supabase Vault** (preferred — the server already loads
secrets from Vault at startup via the `get_secret` RPC) or as Render
environment variables:

| Secret | Required | Notes |
|---|---|---|
| `partner_kek` | **yes** | 64 hex chars. Enables document upload. |
| `mail_from` | **yes** | A From: address on a domain you have verified with your email provider. |
| `resend_api_key` *or* `postmark_token` *or* `mailgun_api_key` + `mailgun_domain` | **yes** | One provider is enough. |
| `partner_ip_salt` | recommended | Salt for hashing IPs in the audit log. Falls back to `admin_token`. |
| `partner_admin_alert_email` | recommended | Receives a notice when a new application is submitted. |

Non-secret presentation config (Render env is fine):

| Variable | Default |
|---|---|
| `PARTNER_BRAND_NAME` | `Soulful Bhakti` |
| `PARTNER_CONSENT_VERSION` | `2026-01` |
| `PARTNER_PUBLIC_BASE_URL` | derived from the request |
| `PARTNER_DISCLOSURE_VERSION` | `2026-01` |

Set `PARTNER_PUBLIC_BASE_URL=https://soulfulbhakti.com` in production so the
branded origin appears in partner-facing copy.

### 3.4 Publish email DNS records

**Do this before launch.** Mail from an unauthenticated domain goes to spam or
is rejected outright. With your provider, verify the sending domain and publish:

- **SPF** — authorises the provider's servers to send for your domain
- **DKIM** — cryptographically signs your messages
- **DMARC** — tells receivers what to do when SPF/DKIM fail

Until this is done, partners will not reliably receive verification links.
The portal detects an unconfigured mail service and says so plainly rather
than silently failing.

### 3.5 Deploy and verify

```bash
cd server
npm ci --ignore-scripts
npm start
```

Startup logs the partner subsystem state — confirm both are configured:

```
[partner] routes registered (email=resend, encryption=ready)
```

Then check:

- `GET /api/partner/config` → `emailEnabled: true`, `encryptionReady: true`
- `https://<host>/partner` → the portal loads
- `https://<host>/admin` → **Partner Applications** appears in the sidebar

### 3.6 Publish the legal pages

`partner.html` links to `/partner/terms` and `/partner/privacy`. **These pages
do not exist yet and must be written and published before launch** — the
consent the partner gives is only meaningful if the documents it references
are real and reachable. See §5.1 for what they must cover.

---

## 4. Operating the review queue

**Admin panel → Partner Applications.**

Actionable items sort to the top (`submitted` → `under_review` →
`needs_info`). Open one to see the full application.

### 4.1 Due diligence checklist

The panel displays this inline, because the whole control depends on a human
actually doing it:

1. Open **every** document and confirm it is legible, unexpired, and belongs
   to the applicant.
2. Confirm the **legal name matches the PAN**, and the **address matches the
   address proof**.
3. For a **business**, confirm the registration document proves the entity
   exists and that the applicant is authorised to act for it.
4. Confirm the PAN is valid in format and belongs to the declared name.
5. Check the promotion plan is legitimate and Play-policy compliant — no
   incentivised installs, no misleading claims.

> **The displayed PAN, GSTIN, name and address are the applicant's claims.**
> The system validates *format*, never *truth*. The document check is the
> control. This is stated in the UI so it cannot be mistaken for verification.

### 4.2 Decisions

| Action | Effect |
|---|---|
| **Start review** | `submitted` → `under_review` (signals work in progress) |
| **Request more information** | → `needs_info`; the applicant can edit and resubmit. A note is shown to them. |
| **Reject** | → `rejected`. **A reason is required** and is shown to the applicant. Schedules a KYC purge. |
| **Approve & issue QR + coupon** | → `approved`. Creates the affiliate, the referrer code and the discount coupon **in one transaction**. |

Approval options: commission per yearly sale, and optionally your own referrer
code, coupon code, redemption cap and coupon expiry. **Leave the codes blank to
have them generated securely** — that is the safer default, since you are not
guessing at uniqueness.

**Approval is idempotent.** Re-approving returns the *same* referrer code and
coupon rather than issuing a second set. There is no way to accidentally create
two QR codes for one partner.

### 4.3 What to do if you see an Aadhaar card

Aadhaar is **not an accepted document** in this program and cannot be recorded
against a partner (the database rejects the document type). If one is uploaded
anyway:

1. **Do not approve.**
2. Request more information, asking for a **PAN card** or a passport / voter ID
   / driving licence instead.
3. Note it, because the file exists in storage and must be deleted rather than
   retained — see §5.4.

---

## 5. Compliance position

> **This section records the engineering decisions and their sources. It is not
> legal advice, and it does not substitute for review by qualified Indian
> counsel for your operating entity. Get that review before launch.**
>
> The full, source-cited research is in
> `PARTNER_PROGRAM_COMPLIANCE_REPORT.md` at the workspace root, with deeper
> per-topic reports alongside it. Every claim below is tagged with the
> instrument it comes from.

### 5.1 The regulatory timeline (build to this)

- **DPDP Rules 2025** were notified by **G.S.R. 846(E) dated 13 November 2025**.
  They are **staged**: the substantive duties (rules 3, 5–16 — notice content,
  security, breach, retention) commence **18 months after publication**, i.e.
  around **mid-May 2027**. You are not in breach today for having no DPDP
  programme, but the build window is real and this implementation is already
  built to it.
- **Consumer Protection (E-Commerce) (Amendment) Rules 2026** come into force
  **1 January 2027** — sponsored-listing disclosure, a 30-day "prior price"
  rule, and dark-pattern self-audit.
- **CERT-In Directions (28 April 2022)** are **already in force** and are a
  *separate* instrument from the DPDP Rules.

> **Do not conflate the two breach clocks.** DPDP Rule 7 requires a detailed
> report to the Data Protection Board **within 72 hours**, plus "without delay"
> notification to the Board and to each affected person. **There is no 6-hour
> DPDP deadline** — the 6-hour figure belongs to **CERT-In**, which carries its
> own penalty under s.70B(7). Both may apply to the same incident.

### 5.2 Consent and notice (DPDP Act 2023 ss.5–6; Rule 3)

- The portal collects **explicit, specific, informed** consent, recorded with
  the **policy version** agreed to and a **server-side timestamp**
  (`terms_version`, `terms_accepted_at`, `privacy_version`,
  `privacy_accepted_at`). The burden of proving consent is on you (s.6(10)),
  which is exactly what these fields exist to discharge.
- **Consent must not be pre-ticked** and must not be bundled. The three
  declarations are separate checkboxes, all unticked by default, and all three
  are required before applying.
- **Rule 3 requires an itemised notice** — each data element listed with its
  specific purpose, presented standalone. A generic "we collect your data to
  provide services" notice does **not** satisfy it. The privacy notice must
  enumerate: full name, date of birth, gender, phone, address, PAN, GSTIN
  (business), bank details, and the uploaded documents — each against its
  purpose.
- **Withdrawal must be as easy as giving consent (s.6(4)).** This is
  implemented as a **single button in the portal** (`POST /api/partner/withdraw`),
  deliberately *not* a "contact support" instruction — a support-only path
  against a one-tap signup is precisely the asymmetry the provision targets.

### 5.3 Aadhaar — the hard line

Aadhaar is **neither requested nor accepted nor stored**. This is a legal
requirement, not a preference. It does not rest on one clause but on **five
independent primary sources**:

1. **Aadhaar Act 2016, s.8A(4)(b)** (inserted by the Aadhaar and Other Laws
   (Amendment) Act 2019, w.e.f. 23.7.2019), verbatim: *"No offline
   verification-seeking entity shall— … (b) collect, use, or store an Aadhaar
   number or biometric information of any individual for any purpose."* A
   **prohibition**, not a guideline. A private marketing programme verifying a
   partner by looking at their Aadhaar card is an "offline verification-seeking
   entity".
2. **s.57 was omitted entirely** by Act 14 of 2019, s.23 — the consolidated Act
   reads literally *"57. [Omitted.]"*. So there is **no statutory route** for a
   body corporate or individual to use Aadhaar.
3. **Puttaswamy** (26 Sep 2018, 2019 (1) SCC 1) held: *"That portion of Section
   57 of the Aadhaar Act which enables body corporate and individual to seek
   authentication is held to be unconstitutional"* — reasoning that
   authentication under *"any contract to this effect"* is *"clearly
   impermissible as a contractual provision is not backed by a law."*
   **A commercial contract cannot supply a lawful basis.**
4. **s.4(4)**: authentication is permitted only to an entity UIDAI is satisfied
   is authorised. This programme is not one and performs **no authentication at
   all**. Reinforced by the **Aadhaar Good Governance Rules 2020**, which
   require a **government sponsor**, and by **PMLA s.11A**, which permits direct
   authentication only to a banking company.
5. **s.29(3)–(4)**: identity information may not be used beyond the purpose
   disclosed in writing, and **no Aadhaar number, demographic information or
   photograph** may be published, displayed or posted publicly — so no Aadhaar
   image may appear in any dashboard or QR flow. **s.30** additionally deems
   electronically stored biometric information to be "sensitive personal data"
   under the IT Act 2000. **s.8(3)** requires the individual to be told the
   **alternatives** to submitting identity information.

**Penalties — and note the personal exposure:**

| Provision | Exposure |
|---|---|
| **s.33A** (inserted 2019) | Civil penalty up to **₹1 crore per contravention**, plus up to **₹10 lakh per day** for a continuing failure |
| **s.38** (unauthorised CIDR access), raised by the 2019 Act | **10 years'** imprisonment, minimum **₹10 lakh** fine; clause (g) covers sharing, using or displaying information in contravention of s.29 |
| **s.42** (general penalty), raised | 3 years |
| **s.43 — offences by companies** | **Directors and officers are personally liable**: every person *"in charge of, and was responsible to, the company for the conduct of the business … shall be deemed to be guilty of the offence"* (with a due-diligence defence) |

**That personal exposure is the reason this control is structural rather than a
policy note.** It is not "the company might be fined" — it is individual
criminal liability with a due-diligence defence, and a written policy that the
system does not enforce is weak evidence of due diligence.

**Note that "visual verification only" is itself constrained.** Viewing a card
without recording the number is permitted, but *capturing* the number — which
includes photographing or scanning the card — is barred. **Do not ask partners
to show Aadhaar at all.**

**How the code enforces it structurally:**

- The `partner_documents.doc_type` CHECK constraint contains **no `aadhaar`
  value**, so an Aadhaar scan cannot be recorded even if a future UI bug
  offered it.
- There is **no `aadhaar_number` column** anywhere — only an optional 4-digit
  mask the partner may volunteer, and storing it requires the consent flag
  (enforced by a CHECK constraint).
- The upload route rejects any `docType` matching `/aadhaar/i` with an
  explanatory message offering the accepted alternatives.
- **No UI displays Aadhaar data** anywhere.

### 5.4 Retention — the counter-intuitive rule

Two obligations pull in **opposite** directions and **both apply**:

| Obligation | Source |
|---|---|
| **Erase** personal data once the purpose is served or consent is withdrawn | DPDP Act 2023 **s.8(7)** |
| **Retain for a minimum of one year** (personal data, traffic data and logs) — the Rules' own illustration says this holds *"even if [the data principal] deletes her account"* | DPDP Rules 2025 **r.8(3)** |

**A naive "delete everything on request" implementation breaches r.8(3).**
Deletion must be **purpose-scoped, not blanket**. This is implemented as a
`earliest_purge_at` column (defaulted to one year from creation) plus a CHECK
constraint asserting `purge_after >= earliest_purge_at`, so **it is
structurally impossible to schedule a purge before the floor**. Withdrawal and
rejection therefore stop processing immediately but schedule deletion at the
later of 90 days and the statutory floor.

Also note **Rule 8(2)**: you must warn the Data Principal **at least 48 hours
before** the erasure deadline. Add this to the purge job when it is built.

The Third Schedule's three-year retention for large platforms applies to
e-commerce entities with ≥2 crore registered users in India. **Unless Soulful
Bhakti crosses that threshold it does not apply** — do not build to those
periods as if they were yours.

### 5.5 Data minimisation

- Only fields needed to (a) identify the partner legally and (b) pay them later
  are collected.
- **Age is never stored** — only date of birth, with a CHECK constraint
  enforcing 18+ (a minor cannot contract). Age is derived for display.
- **Bank account number is not stored** — only the last 4 digits.
- IP addresses are stored only as **salted hashes**, so abuse can be correlated
  without retaining the address.
- **Recommended, and worth doing**: where a business can be verified by a
  government lookup instead of by storing its documents, prefer the lookup.
  **Udyam registration is free, self-declaration based, requires no document
  upload, and the certificate carries a dynamic QR with a public verification
  endpoint** (`udyamregistration.gov.in`). That satisfies verification while
  serving the s.6(1) minimisation duty.

  **But be precise about what Udyam proves**: it evidences **MSME
  classification**, and it is **voluntary — it is not a licence to do business
  and not proof of legal existence**. Likewise a **GST certificate (FORM GST
  REG-06) proves GST registration, not incorporation.** If you need to prove an
  entity legally exists, the incorporation/registration document is the one
  that does it. Do not accept Udyam or GST as a substitute for existence.

### 5.5.1 Where the accepted document list comes from

**UIDAI publishes the authoritative list of accepted supporting documents**
(PoI / PoA / DoB, Lists I–IV). For adults it includes: Passport, Ration/PDS
card, Voter ID, Driving Licence, Service Photo ID card, Pensioner ID,
CGHS/ECHS/ESIC card, MGNREGA Job Card, Domicile Certificate, ST/SC/OBC
Certificate, birth certificate, and electricity bill not older than 3 months.

Two consequences for this build:

1. **The non-Aadhaar route offered to partners is aligned with a government
   list**, not invented — which is what makes it a credible "alternative" for
   the purposes of Aadhaar Act s.8(3).
2. **The identity/address documents accepted here are drawn from that menu**
   (PAN, Passport, Voter ID, Driving Licence for identity; address proof for
   residence). This is the defensible basis for the form's document types.

> **Company-law documents remain LOW confidence.** `mca.gov.in` returned 403 to
> every attempt, so the Certificate of Incorporation / CIN, Shop & Establishment
> licence, and partnership deed / LLP deed evidence could **not** be verified
> against a primary source. They are accepted here because they are the
> conventional evidence of entity existence and authorised signatory, but treat
> the exact acceptance rules as something for counsel to confirm rather than as
> verified law.

### 5.6 Security safeguards (DPDP Rules r.6)

Rule 6(1)(a) requires safeguards of the *character* described — encryption is
listed among illustrative measures using the words "such as". So:

- **[MANDATORY]** to have security measures of that character.
- **[NOT MANDATORY]** encryption as a *named technology* — there is no
  statutory "you must encrypt KYC" rule. Encryption is one clean way to
  discharge the broader obligation, and this implementation does it anyway
  (§6.3) because the engineering case stands on its own.
- Rule 6 also requires **visibility on access via logs/monitoring/review** —
  which is what the append-only `partner_audit_log` provides — and **retention
  of logs and personal data for one year**.

### 5.7 Retention, deletion and crypto-shredding

Deleting an object from storage is **not** by itself a provable erasure:
Supabase supports object versions, and backups/snapshots may retain copies.
Application-level encryption solves this properly.

Every document is encrypted with a **unique per-document Data Encryption Key
(DEK)**, and each DEK is wrapped by the **Key Encryption Key (KEK)** held
outside the database. Destroying the KEK material for a scope makes that
ciphertext permanently unreadable regardless of any surviving copy.

This matters concretely for the Aadhaar incident in §4.3: an accidentally
uploaded Aadhaar scan is **unreadable ciphertext to anyone without the KEK**,
and can be crypto-shredded rather than merely deleted.

### 5.8 Tax (GST / TDS) — current "track-first" phase

The programme currently **records** commission; it does not pay out.

**The credit trigger (this is the part that matters).**

- **TDS s.194H** (commission/brokerage) is triggered at the earlier of **credit
  to the payee's account** or **actual payment** — it is *not* payment-only.
- Merely accruing an internal tracking figure does **not** by itself constitute
  credit to the payee's account.
- **Therefore**: the moment you recognise a commission as an **ascertained sum
  due** to a partner — an invoice raised, a payable credited, a settled balance
  they can see and you are obliged to pay — **the s.194H obligation attaches
  even with zero cash movement.** "No payout yet" does not mean "no compliance
  yet."
- **A trap worth knowing**: the Explanation to s.194H deems credit to *any*
  account, "called by any other name", to be credit to the payee. Re-labelling
  a ledger as "commission payable — suspense" or "held pending reconciliation"
  does **not** avoid TDS if in substance it is a credit for the payee's
  benefit.

**⚠️ The rate is genuinely contested — do not rely on a number.**

| Item | Status |
|---|---|
| **Threshold ₹20,000/financial year** (raised from ₹15,000 by Finance Act 2025 s.63, effective 1 April 2025) | **Agreed by both research streams.** Verbatim amendment text obtained. |
| **Rate** | **UNRESOLVED — 5% vs 2%.** One research stream found 2% in a practitioner rate chart; the other found **5%** with verbatim Finance Act 2025 text and structural corroboration (194H is deliberately absent from Part II of the First Schedule, so the section's own rate applies). The 2% figure is the rate for **insurance commission under s.194D** — a different section — so 2% may well be a secondary-source error. **`incometaxindia.gov.in` returned HTTP 403 to every attempt, so neither figure could be confirmed against the statute.** The statutory phrase "at the rate of five per cent" was surfaced only via a search snippet. |

**Treat the rate as LOW confidence. Get it confirmed by a CA before any payout.**

**The control that matters regardless of the rate.** Under **s.206AA**, a
partner who does not provide a PAN attracts withholding at the higher of twice
the rate, **20%**, or the applicable rate. So a partner without PAN costs **20%
instead of ~5%** — a 4× difference that dwarfs the 5%-vs-2% question. That is
why PAN is mandatory in this form and format-validated on entry. **Collecting
and validating PAN is the highest-value tax control in this build.**

**GST — reverse charge does not appear to apply (HIGH confidence).**

The CBIC/GST Council RCM list is a **closed, enumerated** list. Parsed in full
it returns **zero occurrences of "commission"** and **zero of "business
auxiliary"**; the only individual-provider entries are **advocate** and
**director**. Corroborated by **Notification 09/2024-CT(R)**, which *inserts* a
new entry after serial 5AA — proving the list grows by insertion, i.e. it is
closed.

> **Paying an unregistered individual partner a referral commission does not
> attract RCM.**

Also verified from primary sources: the GST registration threshold is
**₹20 lakh** (₹10 lakh for special-category states) under **CGST Act s.22(1)**;
commission is a "supply" under **s.7(1)(a)**; and the residual rate is **18%**.
So for a partner below the threshold there is **no GST obligation on either
side**, while **TDS applies once the ₹20,000 annual threshold is crossed**.

**Note on the payment flow.** At ₹20,000 per partner per year the TDS exposure
is real but small. What matters far more is **not booking a payable you have not
done the TDS arithmetic on** — because the trigger is the credit, not the
transfer.

### 5.9 Google Play policy

- The QR uses the **Play Install Referrer API**, whose documented purpose is
  install attribution. This is a supported use.
- **Google makes you liable for your partners.** The App Promotion policy
  states verbatim: *"It is your responsibility to ensure that any ad networks,
  **affiliates**, or ads associated with your app comply with these policies."*
  Your QR partners **are "affiliates" in Google's own words** — their conduct
  is your compliance exposure. This is why the portal requires the partner to
  accept the disclosure and honest-promotion declaration (§5.10), and why the
  runbook's promotion guidelines are not optional.
- **Incentivised installs are not banned outright; incentivised reviews are.**
  Practical rule: **never gate any part of the coupon on the user leaving a
  rating or review.**
- **The real payments risk**: a coupon that unlocks **digital content** while
  routing payment **outside Play Billing** violates the Payments policy.
  Physical goods and services are outside Play Billing and lower risk. Safe
  designs are a **price reduction inside the Play Billing flow**, or a
  zero-price grant. **Do not route a digital-goods discount to an external web
  checkout via the QR code.** The current coupon is attribution-only and does
  not change price, which keeps it clear of this risk.
- **Keep the affiliate function secondary to genuine app functionality** — the
  Spam policy targets apps "whose primary purpose is to drive affiliate
  traffic."
- **Server-side install attribution is mandatory in spirit**: fabricating or
  inflating install attributions to earn commissions is Google Ad Fraud
  territory. The existing pipeline attributes from verified webhooks and
  install-referrer, never from client-reported installs.
- **If you share install/user data with partners for attribution, that sharing
  must be disclosed** in your privacy policy and the Play Data safety section.
- Play also requires **in-app account deletion *and* an external web deletion
  route**; temporary deactivation does not qualify. The partner portal's
  withdrawal path (§5.2) addresses the partner side.

### 5.10 Consumer protection and affiliate disclosure

**Affiliate disclosure is already legally mandatory** — CCPA Guidelines 2022,
**paragraph 14**: where a partner's material connection to the brand would not
be reasonably expected by the audience, it *"shall be fully disclosed."*
This is **not** merely good practice.

It is implemented as a **required declaration** in the portal, recorded in the
audit log via `POST /api/partner/disclosure`, and it must also be reflected in
the partner kit. Confirm the exact wording with counsel.

**What must be disclosed to a consumer receiving a coupon:**

- **Who is offering it** — the brand or the partner (this also mirrors Google
  DDA §7.1, which requires clear communication of who a promotion comes from).
- **The partner's material connection**, where the audience would not expect it.
- **Expiry and conditions** on the coupon itself.
- Avoid the dark patterns that map onto coupons: **disguised advertisement,
  false urgency, forced action, drip pricing**.

From **1 January 2027**, the E-Commerce (Amendment) Rules 2026 add
sponsored-listing disclosure, a **30-day "prior price"** rule that defeats
inflated reference prices, and a dark-pattern self-audit.

> **Open question worth counsel time:** whether Soulful Bhakti is an
> **"e-commerce entity"** at all. That characterisation determines whether the
> E-Commerce Rules disclosure duties apply to you directly.

---

## 6. Security model

### 6.1 Trust boundaries

| Boundary | Enforcement |
|---|---|
| Public portal | 256-bit bearer token; only its **SHA-256 hash** is stored. Every RPC resolves the row **from the hash**, and the portal never sends a partner id, so it **cannot address another partner's row**. |
| Database | **No anon/authenticated RLS policy exists** on any partner table. Even a leaked anon key reads nothing. |
| Storage | Bucket is **private with no storage policy**; all bytes are brokered by the service-role server. |
| Admin | Reuses the existing `requireAdmin` (Clerk `@soulfulbhakti.com` domain or ADMIN_TOKEN session). |
| Documents | Encrypted at the application layer **before** upload; admins get proxied bytes, never a public or signed URL. |

### 6.2 Why documents are proxied rather than served via signed URLs

Three documented Supabase behaviours make signed URLs the wrong tool here:

1. **Signed URLs are not revocable.** They are signed with a key separate from
   the project JWT signing key, so *rotating your JWT secret does not
   invalidate them*; the only documented revocation path is contacting support.
   A leaked URL is a bearer credential for its full lifetime.
2. **Response headers on a signed URL are set by Supabase's CDN**, not by this
   app — so the OWASP-prescribed download headers cannot be enforced on that
   path.
3. **Proxying creates an auditable chokepoint.** Every document open is written
   to an append-only log with the reviewer's identity, timestamp and result.

The cost is bandwidth through the app server. For KYC documents, opened rarely
and individually, that is the right trade.

### 6.3 Document handling

- **Allow-list only**: PDF, JPEG, PNG. Validated by **magic bytes**, with the
  client's declared type as a hint that must *agree*.
- **Filename attacks rejected**: NTFS alternate data streams (any `:`), NUL
  bytes and control characters, path traversal, hidden-file prefixes, >255
  chars. The **server generates the object name**, so traversal is structurally
  impossible rather than merely filtered.
- **5 MB** cap enforced by the parser (`multer`), not just at the storage tier.
- Stored as `application/octet-stream` — the object is ciphertext, so declaring
  a real type would be both wrong and a needless hint.
- Served with `Content-Disposition: attachment`, `X-Content-Type-Options:
  nosniff`, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`.
- **SHA-256 integrity check** on every read: if the bytes do not match what was
  submitted, the document is refused and the mismatch is logged.
- **No public malware-scanning service is used.** Uploading a partner's PAN to a
  third-party scanner would itself be a PII disclosure. If scanning is added,
  use a self-hosted engine asynchronously with a `pending_scan` state.

### 6.4 Tokens

| Token | Lifetime | Storage | Entropy |
|---|---|---|---|
| Portal session | indefinite (partner-held) | SHA-256 hash only | 256 bits |
| Email verification | 24 hours, single-use | SHA-256 hash only | 256 bits |

- A **standard hash function is sufficient** for 256-bit tokens — OWASP ASVS
  5.0.0 req 6.5.2 permits it above 112 bits of entropy; bcrypt/Argon2 are only
  required below that.
- Verification consumption is a **single atomic `UPDATE ... WHERE ...
  RETURNING`**, closing the TOCTOU race a naive SELECT-then-UPDATE leaves open
  (ASVS 6.5.1: usable exactly once).
- Issuing a new verification token **invalidates the previous one**, so only the
  newest emailed link works.

### 6.5 Abuse resistance

- **Registration is not a user-enumeration oracle** (ASVS 6.3.8). The response
  is identical whether or not the address is already registered; for a duplicate
  the *existing* partner is emailed a notice instead of issuing a token.
- Rate limits on registration, verification, resend, upload and submit. Note
  `ipv6Subnet` is left at the library default of `/56`: Indian mobile ISPs
  commonly delegate large IPv6 prefixes, so a per-address limit alone is
  trivially bypassed.
- **`MemoryStore` caveat**: these limits reset on restart and multiply across
  instances. They are a coarse abuse floor; the authoritative limits are the
  per-partner document cap (15) and the per-account resend window (5/hour),
  both enforced in Postgres.
- The audit log is **append-only** — a trigger makes UPDATE and DELETE fail.

---

## 7. Schema reference

### `partners`
One row per application. Key points: `portal_token_hash` (unique),
`email_verify_token_hash`, `status`, `affiliate_id` (set on approval),
`purge_after`, and **`earliest_purge_at`** — the DPDP Rules r.8(3) one-year
minimum retention floor, defaulted at creation.

Statuses: `draft` → `pending_verification` → `submitted` → `under_review` →
(`needs_info` ⇄) → `approved` | `rejected` | `withdrawn`

Key CHECK constraints: 18+ (`partners_adult_check`), PAN format, GSTIN format,
Aadhaar last-4 digits only **and** only with consent, business must declare an
entity type, consent flags required for any non-draft status, and
**`partners_purge_floor_check`** which makes it impossible to schedule a purge
before the statutory retention floor.

### `partner_documents`
Metadata only; the bytes live in the private bucket. Stores the declared **and**
sniffed MIME type (a mismatch is a spoofing signal the reviewer can see), the
SHA-256 of the plaintext, and the encryption envelope fields (`enc_iv`,
`enc_tag`, `dek_wrapped`, `dek_iv`, `dek_tag`).

### `partner_audit_log`
Append-only. `actor_type` (`partner` | `admin` | `system`), `action`,
`from_status`/`to_status`, non-sensitive `detail` JSON, `ip_hash`,
`user_agent`. **No raw PII, no document content and no tokens are ever written
here.**

### `partner_email_events`
Verification / resend / verified events; backs the per-account resend window.

---

## 8. Tests

### 8.1 Running the full pipeline verification

```powershell
# From the repo root. Brings up a throwaway PostgreSQL, applies the real
# migrations, and runs every test layer against it.
.\scripts\verify-partner-pipeline.ps1
```

Requires PostgreSQL binaries (auto-detected from scoop or `C:\Program Files`).
The instance is disposable and lives under `_pgtest/`; it is never used by
production.

### 8.2 Individual layers

```bash
cd server
npm run test:partner           # crypto + structural + HTTP-vs-stub
npm run test:partner-crypto    # 31 unit tests
npm run test:partner-verify    # structural checks on both HTML pages
npm run test:partner-flow      # 37 HTTP integration tests
```

### 8.3 What each layer covers

| Layer | Count | Proves |
|---|---|---|
| Real SQL behaviour (`partner_db.test.sql`) | **131 assertions** | The SQL functions, CHECK constraints, SECURITY DEFINER posture and grants behave as authored — **against a genuine PostgreSQL server** |
| HTTP end-to-end vs **real** PostgreSQL (`partner-real-db.test.mjs`) | **29 tests** | The whole pipeline works through the real Express server and real database, including encryption round-trips |
| HTTP integration vs stub (`partner-flow.test.mjs`) | **37 tests** | Route logic, validation and trust boundaries in isolation |
| Crypto + file validation (`partner_crypto.test.mjs`) | **31 tests** | Encryption round-trip, tamper detection, fail-closed KEK, upload attack rejection |
| Structural (`partner-verify.cjs`) | — | Page wiring, ID uniqueness, no token leakage, no external resources |
| Pre-existing admin tests | **25 tests** | No regression in the existing admin panel |

### 8.4 The assertions that matter most

- **A valid PAN upload lands in storage as real ciphertext** — verified by
  reading the bytes back out of PostgreSQL and asserting they are not the
  original PDF.
- **Opening a document decrypts it byte-for-byte** — the served bytes are
  compared against the original upload, proving the full envelope-encryption
  round trip through a real database.
- **The issued referrer code works with `bind_affiliate_referral`**, and the
  **issued coupon works with `validate_coupon` / `redeem_coupon`** — i.e. the
  RPCs the **shipped Android app already calls**. This is the compatibility
  proof that no app change is needed; if it fails, the program is broken for
  real users.
- **A client cannot set `status` or `affiliate_id`** through the draft endpoint,
  confirmed against the real database.
- **An under-18 applicant and a malformed PAN are rejected by real CHECK
  constraints** reached through the real HTTP path.
- **Aadhaar cannot be recorded as a document type** even when a request tries.
- **Approving twice returns the same referrer code and coupon** — no duplicate
  QR codes, verified by counting rows in the real database.
- **Withdrawal works for a partner who never consented** (see §8.5).
- **The append-only trigger blocks UPDATE and DELETE** on the audit log.
- **`anon` cannot execute `partner_approve`, `partner_set_verification_token`
  or `credit_affiliate_commission`** — verified via `has_function_privilege`.

### 8.5 Two real bugs found by testing against a real database

Both were **invisible to the stub-based suite** and would have shipped. They are
recorded here because the lesson generalises: a stub mirrors the author's
assumptions, and the assumptions are what is wrong.

**Bug 1 — `partner_submit` crashed on every incomplete submission.**
The plpgsql statement `v_missing := v_missing || 'consent'` is ambiguous: the
parser can read `||` as string concatenation on an untyped literal, and fails at
runtime with *"Array value must start with { or dimension information"*. This
broke the **single most common path** — a partner who clicks Apply before
finishing the form, which is exactly when the missing-fields list is built. Now
uses `array_append()`, which is unambiguous.
*Guarded by:* `submit is refused without consent` / `the missing consent is
reported`.

**Bug 2 — withdrawal was impossible for a partner who had not consented.**
`partners_consent_check` required consent for every status except `draft`. But
`withdrawn` is a *non-draft* status, so a partner who withdrew **before**
accepting the terms got a 500. That inverts DPDP Act 2023 s.6(4) — you would
have to consent in order to revoke. `withdrawn` is now exempt, and an
`alter table ... drop constraint / add constraint` block makes the fix apply to
databases created by the earlier revision.
*Guarded by:* `a partner who never consented CAN still withdraw`, plus
`a submitted application STILL requires consent` to prove the constraint was not
weakened for the states that matter.

### 8.6 Why the real-database layer exists

The stub-based suite mirrors the SQL's *observable* semantics, which means it
can only ever confirm that the routes call the database the way the tests assume
they should. It cannot prove:

- that a plpgsql function runs at all (Bug 1),
- that a CHECK constraint's `status IN (...)` list is right (Bug 2),
- that `SETOF` vs `TABLE` return shapes reach the application correctly,
- that grants and `SECURITY DEFINER` behave as authored,
- that encrypted bytes survive a real round trip.

All five of those produced real findings. **Run this layer before any
production deploy.**

> The adapter (`test/real-supabase-adapter.mjs`) is a test fixture and is never
> imported by production code. It emulates PostgREST over the `pg` driver and
> reproduces supabase-js's **return-shape rules** — a scalar-returning function
> yields the bare value while a `SETOF`/`TABLE` function yields an array. That
> distinction is load-bearing: getting it wrong silently corrupts `get_secret`
> and therefore the admin token and the document-encryption key.

---

## 9. Launch checklist

**Infrastructure**
- [ ] Migration 033 applied; verification queries at the end all pass
- [ ] `partner-kyc` bucket exists and is **private**
- [ ] `partner_kek` generated and **backed up outside Supabase**
- [ ] Email provider configured and `mail_from` set
- [ ] SPF, DKIM and DMARC published; a test verification email arrives in the inbox
- [ ] Startup log shows `email=…, encryption=ready`

**Legal / policy**
- [ ] `/partner/terms` and `/partner/privacy` written and published
- [ ] Privacy notice is **itemised** (each data element + its specific purpose), per DPDP Rule 3 — not a generic paragraph
- [ ] Withdrawal is as easy as signup (it is a single portal button — verify it works end to end)
- [ ] Written CA opinion on s.194H / s.206AA / GST-RCM **before any payout**
- [ ] **CA to resolve the s.194H rate: 5% or 2% — the research is genuinely split and neither could be confirmed against the statute.** The ₹20,000 threshold is agreed.
- [ ] Confirm the partner-facing consequence: no PAN means **20%** withholding, not ~5% (s.206AA)
- [ ] Counsel review of the Aadhaar position and the DPDP consent wording; the Aadhaar control now rests on five independent primary sources
- [ ] Confirm the exact acceptance rules for company-law documents (MCA was unreachable; LOW confidence)
- [ ] Partner promotion guidelines issued, covering the **disclosure obligation** and the ban on incentivised reviews
- [ ] Confirm the coupon does **not** route digital-goods payment outside Play Billing
- [ ] Counsel: **is Soulful Bhakti an "e-commerce entity" at all?** This determines whether the E-Commerce Rules disclosure duties apply to you directly — worth counsel time before building to them

**Operational**
- [ ] `partner_admin_alert_email` set so new applications are noticed
- [ ] Reviewer access restricted to people authorised to see identity documents
- [ ] Documented process for handling an accidentally uploaded Aadhaar scan (do not approve; request PAN; crypto-shred the file)
- [ ] Purge job built, respecting `earliest_purge_at` and warning the partner **≥48 hours** before erasure (DPDP Rule 8(2))
- [ ] Breach runbook: **72 hours** to the DPDP Board; **6 hours** to CERT-In; both may apply to one incident
- [ ] CERT-In: ICT logs retained **180 days within India**; NTP synced to NIC/NPL
- [ ] DPDP programme tracked against the **~mid-May 2027** commencement of rules 3, 5–16

**Verification**
- [ ] `.\scripts\verify-partner-pipeline.ps1` reports **ALL PIPELINE STEPS PASSED**
- [ ] Migration 033 applies cleanly to a database **and re-applies cleanly** (idempotent)
- [ ] One real application taken end-to-end: register → verify → upload → apply → approve
- [ ] The issued QR resolves to the Play listing with the correct `utm_source`
- [ ] The issued coupon validates through the app **and** the referrer code binds
      through `bind_affiliate_referral` (the compatibility proof for "no app changes")
