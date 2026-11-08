# Razorpay subscriptions for Soulful Bhakti (Android)

Status: **Pathway A implemented** (backend + app entitlement). Pathways B/C are
design-only. See §0.1 for the shipped files.
Last verified against official docs: see [Sources](#13-sources)
Owner decision required: only for Pathway B (§3.2), if it is ever wanted.

---

## 0. TL;DR

Your app is a **Flutter Android app distributed on Google Play**, with a **digital
subscription** (₹120/month, ₹1,200/year) that unlocks premium tracks. Google Play's
payments policy says a music subscription sold *inside* a Play-installed app must use
Google Play Billing — **unless** you are enrolled in one of Google's alternative-billing
programs. India has one, and it is open to all developers, but it comes with obligations
(enrolment, PCI DSS, code integration, 24-hour transaction reporting to Google, and a
reduced-by-4% Google service fee).

So there are exactly **three legal shapes** for adding Razorpay, and they are not
interchangeable:

| # | Shape | Razorpay runs | Play-compliant | Effort |
|---|-------|---------------|----------------|--------|
| **A** | Razorpay checkout **on your website**, app unlocks from server entitlement | Outside the app | Yes — nothing to enrol in | ~1 week |
| **B** | Razorpay **inside** the Play app, next to Play Billing (India alternative-billing program) | In-app, user chooses | Yes, **after** Play Console enrolment + API integration | 3–5 weeks |
| **C** | Razorpay in a **non-Play build** (direct APK / other stores) | In-app, no Play involvement | Yes — Play policy doesn't apply | 1–2 weeks + distribution |

Anything else (Razorpay checkout in your Play app for the same premium music, with no
enrolment) is a policy violation that risks app removal. That shape is not offered here.

**Recommendation:** build the Razorpay rail once (backend + entitlement, §6–§8), ship
it through **Pathway A** first because it is compliant today and costs one week, then
decide on **Pathway B** only if in-app Razorpay is a hard requirement (§3.6).

---

## 0.1 What is implemented (Pathway A)

The web rail is built and tested. The Android app contains **no Razorpay UI, no
new permission and no new dependency** — it only honours a subscription bought
outside the app, which is what keeps the Play listing compliant.

**Server**

| File | What it does |
|---|---|
| `server/migrations/038_razorpay_subscriptions.sql` | `razorpay_subscriptions`, `razorpay_webhook_events`, and `subscription_entitlement(text)` — the single entitlement rule |
| `server/razorpay.mjs` | Razorpay client (plans, subscriptions, cancel), payment-signature and webhook-signature verification, and the testable `createWebhookHandler` |
| `server/server.js` | secrets/config, `initRazorpay()`, and the routes below |
| `server/test/razorpay.test.mjs` | 48 unit tests (signatures, plans, client, webhook contract) |
| `server/test/razorpay-webhook.e2e.mjs` | 19 end-to-end tests booting the real Express app against the stub Supabase |

Routes:

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/razorpay/webhook` | HMAC | lifecycle sync; deduped by `x-razorpay-event-id` |
| POST | `/api/razorpay/subscription` | Clerk bearer | create/reuse a subscription for the caller |
| POST | `/api/razorpay/verify` | Clerk bearer | verify Checkout's signature, then re-read from the API |
| GET | `/api/razorpay/entitlement` | Clerk bearer | the only thing the app calls |
| POST | `/api/razorpay/cancel` | Clerk bearer | cancel the caller's live subscription |
| POST | `/api/admin/razorpay/link` | admin session | create a subscription for a user and return Razorpay's hosted `short_url` |

**App**

| File | What it does |
|---|---|
| `lib/services/clerk/clerk_session_token.dart` | `clerkSessionToken()` — short-lived Clerk JWT for API calls |
| `lib/services/entitlement/entitlement_service.dart` | `EntitlementSignal` (sync gate mirror), pure `entitlementIsActive` / `entitlementFromJson`, and the debounced refresh |
| `lib/modules/monetization/premium_access.dart` | `isPremiumUser = signedIn && (Play/Superwall \|\| Razorpay)` |
| `lib/provider/auth/clerk_auth_provider.dart` | refresh on every resolved sign-in; reset on sign-out |
| `lib/main.dart` | configures the service; refreshes on app resume |
| `android/.../ClerkBridge.kt` | new `getToken` method (`Session.fetchToken()`) |
| `test/modules/monetization/entitlement_signal_test.dart` | 15 unit tests for the gate rule and response parsing |

**Selling a subscription today (no app change, no Play risk)**

`POST /api/admin/razorpay/link` with `{ "user_id": "user_…", "plan": "monthly" }`
returns `{ subscription_id, short_url }`. Send the `short_url` to the customer
(WhatsApp/email); they authorise the mandate on Razorpay's hosted page, the
webhook grants access, and the app unlocks on the next sign-in or resume.

**Configuration required before it does anything**

1. Apply `server/migrations/038_razorpay_subscriptions.sql` in Supabase.
2. Create the two plans in Razorpay and set `RAZORPAY_PLAN_MONTHLY` /
   `RAZORPAY_PLAN_YEARLY` on Render.
3. Set `RAZORPAY_KEY_ID`; store `razorpay_key_secret` and
   `razorpay_webhook_secret` in Supabase Vault (env fallback supported).
4. Add the webhook `https://<host>/api/razorpay/webhook` in the Razorpay
   dashboard for `subscription.*` + `payment.failed`, with that secret.
5. Put `API_BASE_URL=https://<host>` in the app's release `.env`, then rebuild —
   `env.g.dart` is generated, so the value only reaches the APK on the next
   `build_runner`/CI build.

Until step 5, the app behaves exactly as before (Play-only), by design: an
unconfigured build must not fail, it must simply have no web rail.

**Verify**

```
cd server && node test/razorpay.test.mjs
cd server && node test/partner-stub-register.mjs test/razorpay-webhook.e2e.mjs
cd server && node test/partner-stub-register.mjs test/partner-flow.test.mjs   # no regression
cd .. && flutter test test/modules/monetization/
```

---

## 1. What the repository actually does today (code-verified)

| Fact | Where |
|------|-------|
| Flutter app, `applicationId com.soulfulbhakti.app`, `minSdk 26`, `targetSdk/compileSdk 36`, flavours `stable`/`dev`/`nightly` | `android/app/build.gradle` |
| Google Play Billing **8.0.0** already declared (pinned for Superwall) | `android/app/build.gradle:174` |
| Auth is **Clerk** via a native bridge; `ClerkAuthSignal` is the synchronous mirror | `lib/modules/monetization/premium_access.dart:80`, `ClerkBridge.kt` |
| Monetisation is **Superwall**: paywalls + entitlements + purchases | `lib/services/superwall_service.dart` |
| Plans documented in code as ₹120/month and ₹1,200/year, sold through a Superwall placement | `lib/modules/monetization/superwall_gate.dart:14-17` (comment; confirm live prices in the Superwall dashboard) |
| Premium = `signedIn && superwall.subscriptionStatus.isActive` | `lib/modules/monetization/premium_access.dart:51-52` |
| Paid content is gated client-side only (`isTrackLocked`, `gateTrackPlay`, `gateAlbumPlay`, `promptForPaidPlan`) | `lib/modules/monetization/premium_access.dart` |
| Backend: Express on Render, Supabase Postgres, service-role key | `server/server.js`, `render.yaml` |
| Existing webhook pattern to copy: raw body **before** `express.json()`, HMAC verify, replay window | `server/server.js:328-420` |
| Server already verifies Clerk bearer tokens (`verifyClerkRequest`) | `server/server.js:1243-1255` |
| No Razorpay code, keys, tables or endpoints anywhere | grep of repo |

Consequence: **there is no server-side entitlement today.** `GET /stream/:id` hands back
a public CDN URL without checking anything (`server/server.js:598-633`), and the paid
gate is UI + client-side state. Adding Razorpay therefore also means adding the
entitlement source of truth that should have existed anyway — which is the single most
valuable part of this work, whichever pathway you choose.

---

## 2. The policy gate (this is what decides the architecture)

Verified directly from Google's pages; quotes are from those pages.

1. **Play Billing is mandatory for this product.**
   > "Google Play's billing system is required for developers offering in-app purchases
   > of digital goods and services distributed on Google Play."
   >
   > Purchases that require it explicitly include: "Subscription services (such as
   > fitness, game, dating, education, **music**, video, or other content subscription
   > services)" and "App functionality or content (such as an ad-free version of an app
   > or new features not available in the free version)".
   — *Understanding Google Play's Payments policy*

2. **No steering inside the app.**
   > "Within an app, developers may not lead users to a payment method other than Google
   > Play's billing system unless Section 3, 8, or 9 of Payments policy applies. This
   > includes directly linking to a webpage that could lead to an alternate payment
   > method or using language that encourages a user to purchase the digital item
   > outside of the app."
   — same page

   Practically: your Play build may **not** contain a "Subscribe on our website" button,
   link, or nudge for the premium music subscription. Account-management surfaces
   (sign-in, "restore/manage subscription") are fine.

3. **India has a legal exception — alternative billing alongside Play billing.**
   > "In response to recent regulatory developments in India, we are now offering all
   > developers the ability to offer an alternative billing system alongside Google
   > Play's for their mobile and tablet users in India. If a user pays through an
   > alternative billing system, the Google Play service fee will be reduced by 4%."
   — *Changes to Google Play's billing requirements for developers serving users in India*

   Obligations listed there, in order:
   - enrol the app on the Play Console **Alternative billing** page
     (*Manage account → Play apps settings → Monetization settings → Alternative billing*);
   - certify **PCI DSS** compliance and give users a way to report fraudulent transactions;
   - integrate Google's **alternative billing APIs** (client + backend);
   - upload payment-method logos and a **subscription management URL**;
   - **report every authorised transaction from Indian users within 24 hours** through
     the Play Developer API;
   - pay the Google service fee (reduced by 4%) on those transactions.

4. **Web sales are untouched by Play policy.** You may sell outside the app, and the app
   may honour that purchase (sign-in based). What is forbidden is *steering within the
   app* (point 2).

So: **A and C are compliant with zero Play paperwork; B is compliant but is a project.**

---

## 3. Pathway matrix

### 3.1 Pathway A — Razorpay on the web, entitlement consumed by the app

**Who pays:** users who reach your website (marketing, WhatsApp/Instagram, web app).
**In-app:** no Razorpay UI at all. The Play build keeps Superwall + Play Billing exactly
as it is today. It additionally asks your server "is this Clerk user premium?" and
unlocks paid tracks if the answer is yes.

- Compliance: clean. No enrolment, no reporting to Google, no Play review risk.
- Money: no Google cut on web subscriptions; Razorpay's contracted MDR only.
- UX cost: a Play user who wants to pay with UPI cannot do it inside the app. They can
  still subscribe on the web (if they find the website) and the app will unlock.
- Code: server endpoints + webhook + entitlement table + one Dart service + one line in
  `PremiumAccess`. No new Flutter dependency, no Kotlin, no AAB change.
- Effort: **~4–6 working days**, including tests.

This is the fastest way to have Razorpay actually processing subscriptions.

### 3.2 Pathway B — Razorpay inside the Play app (India alternative billing)

**Who pays:** users inside the Play app; they are shown Google's choice screen: *Google
Play* or *Soulful Bhakti (UPI/cards via Razorpay)*.

What it requires:

1. **Play Console enrolment** for the India program (per app, per market) + PCI DSS
   attestation + fraud-reporting contact + subscription-management URL.
2. **A `BillingClient` you own**, configured with
   `enableUserChoiceBilling(UserChoiceBillingListener)` and `launchBillingFlow()`. Google
   renders the choice screen. If the user picks Play, the purchase continues through
   Play inside that client; if they pick your rail, your listener receives
   `UserChoiceDetails` (`externalTransactionToken` + `products`) and you launch Razorpay.
3. **Backend reporting to Google within 24 h**:
   `POST /androidpublisher/v3/applications/{packageName}/externalTransactions?externalTransactionId=…`
   with the token for the first transaction, and new IDs for renewals.
4. A decision about **Superwall**, which today owns the purchase and the entitlement.
   Superwall's Flutter SDK lets you take that over with a `PurchaseController`
   (`purchaseFromGooglePlay(productId, basePlanId, offerId)`, `restorePurchases()`,
   then `Superwall.setSubscriptionStatus(...)`), so the paywall can keep rendering while
   *you* route the purchase. That is the seam to use — but it means the entitlement path
   changes for Play purchases too, and must be re-tested end to end.

- Money: on a Razorpay-paid transaction you pay **11 % to Google + Razorpay's MDR**
  (Google's own example: a 15 % service fee becomes 11 %). Versus 15 % for Play Billing,
  the saving is therefore `4 % − Razorpay MDR` per transaction — roughly 2 points if your
  card MDR is ~2 %, more on UPI. It is a real saving, but not "2 % instead of 15 %".
- Effort: **3–5 weeks** (native bridge, enrolment review, Google reporting, Play test
  track, regression of the existing Superwall flows).
- Risk: enrolment approval timing and the Superwall swap are the two real ones.

> Important: `enableUserChoiceBilling` is a Play Billing Library API (Play Billing ≥ 5.2;
> you already ship 8.0.0). Superwall takes over purchases by default and its Flutter API
> exposes no user-choice hook — the only supported seam is a custom `PurchaseController`
> — so Pathway B cannot be done purely from Dart and needs a Kotlin bridge.

### 3.3 Pathway C — Razorpay in a non-Play build

Distribute an APK/AAB outside Play (your site, Amazon, Samsung, OEM stores, enterprise).
Play policy does not apply there, so Razorpay can fully replace Play Billing in that
build.

- Compliance: clean, no Google involvement.
- Money: Razorpay MDR only.
- Cost: you lose Play discovery/updates, and you now run two builds with different
  purchase paths and different entitlement sources.
- Effort: **~1–2 weeks** of code, plus distribution and update mechanics.

Best used as a *deliberate* channel (e.g. a "Soulful Bhakti Direct" download), not as a
way to avoid Play fees on the Play listing.

### 3.4 Pathway D — Razorpay for non-digital purchases (only if you have them)

If you sell something that is **not** digital content — temple/puja services, physical
prasad, event passes, or donations where 100 % goes to the creator and nothing unlocks
digital content — Play Billing is not required and Razorpay is legal inside the Play app
today. Your `.env` carries `HIDE_DONATIONS`, so check whether such a surface exists. If
it does, this is the cheapest in-app Razorpay win available, and it shares the same
backend rail as A/B/C.

### 3.5 Pathway E — Razorpay-only in the Play app, no enrolment (**do not do this**)

This is the shape most tutorials show. It is a Play policy violation for this product
and is the most common cause of removal for Indian subscription apps. It is listed here
only so it is explicitly ruled out.

### 3.6 Decision table

| | A (web) | B (Play choice) | C (non-Play) |
|---|---|---|---|
| Play-compliant | ✅ no paperwork | ✅ after enrolment | ✅ n/a |
| Time to first live payment | ~1 week | 3–5 weeks | 1–2 weeks |
| Google fee | none | 11 % (from 15 %) | none |
| UPI inside Play app | ❌ | ✅ | ✅ (other build) |
| Touches existing Play purchase flow | no | **yes** (Superwall swap) | no |
| Play review risk | none | low, but new program | none |
| Best for | revenue now | in-app UPI/cards | direct channel |

**If the goal is "Razorpay subscriptions working, 100 %, this month" → A.**
**If the goal is "users must be able to pay with UPI inside the Play app" → B, and the
backend built for A is reused unchanged.**

---

## 4. Recommended sequence

1. **Phase 0 — Razorpay account (no code).** Plans, subscriptions settings, checkout
   settings, webhook, live keys. Checklist in §11.
2. **Phase 1 — backend rail.** Tables, endpoints, webhook, verification. Works for
   A, B and C. (§6–§8)
3. **Phase 2 — app entitlement.** Server-verified premium flag ORed with Superwall;
   gate unchanged. One new service, one edit in `PremiumAccess`. (§8.3)
4. **Phase 3 — Pathway A go-live.** Web checkout + entitlement. Measure.
5. **Phase 4 — optional Pathway B** only after Phase 3 is stable, with a Play test track
   and the Superwall `PurchaseController` swap.

---

## 5. How Razorpay Subscriptions actually works (verified mechanics)

### 5.1 Objects

- **Plan** — reusable template: amount, currency, period (`daily|weekly|monthly|yearly`),
  interval. Created in Dashboard or `POST /v1/plans`. Store the `plan_id`s in env.
- **Subscription** — `plan_id` + `total_count` (number of billing cycles, max 10 years)
  + optional `start_at`, `quantity`, `addons`, `notes`. Created **server-side**:
  `POST /v1/subscriptions`. The response `id` (`sub_…`) is what Checkout needs.
- **Authentication transaction** — the customer authorises the mandate at Checkout.
  Subscription payments are auto-captured; do not capture manually.
- **Invoices** — one per billing cycle, auto-charged, `invoice.paid` fires.

What the customer is actually charged for the authorisation depends on the start date and
whether you set an upfront amount:

| start date | upfront amount | auth amount |
|---|---|---|
| immediate | – | plan amount |
| future | – | ₹5 (auto-refunded) |
| immediate | ✔ | upfront + plan amount |
| future | ✔ | upfront amount |

### 5.2 Client flow

1. App asks your backend to create a subscription for the signed-in user.
2. Backend returns `{ subscription_id, key_id }` (never the key secret).
3. App opens Razorpay Checkout with `subscription_id` (Flutter plugin option key is
   exactly `subscription_id`; do **not** also pass `amount`).
4. On success Checkout returns `razorpay_payment_id`, `razorpay_subscription_id`,
   `razorpay_signature`.
5. App posts those to your backend. Backend verifies the signature — using the
   **`subscription_id` it stored**, not the one the client sent (Razorpay's own
   instruction) — then fetches the subscription from Razorpay and activates entitlement.
6. Webhooks keep the state correct forever after; the client is never trusted.

### 5.3 Signature (payment)

```
generated_signature = HMAC_SHA256(razorpay_payment_id + "|" + subscription_id, key_secret)  // hex
valid               = timingSafeEqual(generated_signature, razorpay_signature)
```

### 5.4 Webhooks

Subscribe (Dashboard → Account & Settings → Webhooks) with a **webhook secret**, and
validate `X-Razorpay-Signature` = `HMAC_SHA256(raw_body, webhook_secret)`.
Never parse-then-restringify the body when validating.

Events that matter: `subscription.authenticated`, `subscription.activated`,
`subscription.charged`, `subscription.pending`, `subscription.halted`,
`subscription.cancelled`, `subscription.paused`, `subscription.resumed`,
`subscription.completed`, `subscription.updated`, plus `payment.failed` and
`refund.processed` if you refund.

Guarantees you must design for:
- **Duplicates are expected** → dedupe on the `x-razorpay-event-id` header (unique per
  event). Store it with a unique index and ignore repeats.
- **Order is not guaranteed** → derive state from the payload's own
  `current_start`/`current_end`/`status`, never from arrival order.

### 5.5 States → entitlement mapping

| Razorpay state | Meaning | Give premium? |
|---|---|---|
| `created` | not authorised yet | no |
| `authenticated` | mandate authorised, first charge pending | **yes** |
| `active` | billing cycle running | **yes** |
| `pending` | a charge failed, Razorpay is retrying | yes for a grace window (§6.4) |
| `halted` | retries exhausted | until `current_end` (usually already past) |
| `paused` | paused by you/customer | no |
| `cancelled` | cancelled; cannot restart | until `current_end`, then no |
| `expired` | never authorised in time | no |
| `completed` | all cycles done | no |

### 5.6 Payment methods and limits

Cards (Visa/Mastercard/RuPay), **UPI Autopay**, and eMandate (eNACH). Verified limits:
**cards and UPI support recurring payments up to ₹15,000**; higher values fail for
domestic cards. Your ₹120/₹1,200 plans sit comfortably inside that.

Enable each method in **Dashboard → Subscriptions → Settings** (Card / UPI / eMandate);
eMandate is on by default.

### 5.7 Lifecycle actions (cancel / pause / update)

- Cancel: `POST /v1/subscriptions/:id/cancel` (irreversible).
- Pause/resume: `POST /v1/subscriptions/:id/pause|resume`.
- Update plan/quantity/start: `PATCH /v1/subscriptions/:id`.
- Cancel from the app must go through **your** server (key secret stays server-side).

---

## 6. Architecture (rail-independent)

```
Flutter app                     Node (Render)                     Razorpay
-----------                     -------------                     --------
Clerk session token ──────────▶ verifyClerkRequest()
POST /api/razorpay/subscription ────────────────────────────────▶ POST /v1/subscriptions
                                ◀──────────────────────────────── { id: sub_… }
◀── { subscription_id, key_id }
razorpay_flutter Checkout (subscription_id)
◀── payment_id, subscription_id, signature
POST /api/razorpay/verify ─────▶ HMAC verify + GET /v1/subscriptions
                                └─▶ Supabase: razorpay_subscriptions
GET /api/razorpay/entitlement ◀─ computed from table          webhook ──▶ POST /api/razorpay/webhook
                                                                         (HMAC, dedupe, upsert)
```

**Rules baked in:**
- key secret and webhook secret only ever on the server (env/vault — the server already
  has a vault + AWS Secrets Manager path, `server/server.js:260-302`);
- the app never decides entitlement: it reads a server answer;
- the DB is the single source of truth for Razorpay-paid users, so A, B and C share it.

### 6.1 Tables

`razorpay_subscriptions` — one row per subscription, keyed by `subscription_id`.
`razorpay_webhook_events` — dedupe log keyed by `event_id`.
A view/function `subscription_entitlement(user_id)` — the only thing the app reads.

`user_id` is **TEXT** (Clerk user id, e.g. `user_2ab…`), not `uuid`: every existing
user-scoped table in this repo keys off the Clerk id passed explicitly to RPCs
(`server/migrations/003_referrals.sql`, `lib/provider/server/routes/supabase_data.dart`).

### 6.2 Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/razorpay/subscription` | Clerk bearer | create subscription, return `subscription_id` + `key_id` |
| POST | `/api/razorpay/verify` | Clerk bearer | verify checkout signature, activate entitlement |
| GET | `/api/razorpay/entitlement` | Clerk bearer | `{ active, plan, current_end, source }` |
| POST | `/api/razorpay/cancel` | Clerk bearer | cancel the caller's subscription |
| POST | `/api/razorpay/webhook` | HMAC | lifecycle sync (**raw body, mounted before `express.json()`**) |

### 6.3 Why `verify` is still needed when webhooks exist

Webhooks can arrive seconds late, or not at all during a Razorpay incident. `verify`
gives the user instant unlock after payment; the webhook is the durable truth. Both
converge on the same upsert, so a duplicate is harmless.

### 6.4 Grace policy (business decision, default below)

| Status | Access |
|---|---|
| `authenticated`, `active` | yes, open-ended |
| `pending` (failed renewal, Razorpay retrying) | until `current_end` + **72 h** |
| `cancelled`, `halted` | until `current_end` (they paid for that period) |
| `created`, `paused`, `expired`, `completed` | no |

Make the 72 h a single constant so it can be tuned without a release, and keep the SQL
function in §7 in step with this table — it is the only place the rule is enforced.

---

## 7. Implementation — database

`server/migrations/038_razorpay_subscriptions.sql`:

```sql
-- Razorpay subscription state. Service-role writes only; the app reads through the
-- /api/razorpay/entitlement endpoint (Clerk-verified), never directly.
create table if not exists public.razorpay_subscriptions (
  subscription_id   text primary key,              -- sub_XXXXXXXX
  user_id           text not null,                 -- Clerk user id
  plan_id           text not null,                 -- plan_XXXXXXXX
  plan_slug         text not null,                 -- 'monthly' | 'yearly'
  status            text not null,                 -- created|authenticated|active|pending|halted|cancelled|paused|expired|completed
  quantity          integer not null default 1,
  total_count       integer,
  paid_count        integer not null default 0,
  current_start     timestamptz,
  current_end       timestamptz,
  short_url         text,
  last_event_id     text,
  raw               jsonb not null default '{}'::jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists razorpay_subscriptions_user_idx
  on public.razorpay_subscriptions (user_id);

-- Webhook idempotency: Razorpay retries and can deliver duplicates.
create table if not exists public.razorpay_webhook_events (
  event_id    text primary key,                    -- x-razorpay-event-id
  event_type  text not null,
  received_at timestamptz not null default now()
);

alter table public.razorpay_subscriptions   enable row level security;
alter table public.razorpay_webhook_events  enable row level security;
-- No policies on purpose: only the service role (server) may touch these tables.
-- The app has no direct path to them; it calls /api/razorpay/entitlement.

-- Single entitlement answer for a user. Most recent subscription wins.
create or replace function public.subscription_entitlement(p_user_id text)
returns table (active boolean, plan_slug text, current_end timestamptz, status text)
language sql
stable
security definer
set search_path = public
as $$
  with latest as (
    select *
    from public.razorpay_subscriptions
    where user_id = p_user_id
    order by created_at desc
    limit 1
  )
  select
    case
      when latest.status in ('authenticated', 'active') then true
      when latest.status = 'pending'
        then coalesce(latest.current_end, now()) + interval '72 hours' > now()
      when latest.status in ('cancelled', 'halted')
        then coalesce(latest.current_end, now()) > now()
      else false
    end as active,
    latest.plan_slug,
    latest.current_end,
    latest.status
  from latest;
$$;

revoke all on function public.subscription_entitlement(text) from public, anon, authenticated;
-- Called only by the server (service role). The grant is explicit because the
-- REVOKE above also removes PUBLIC's default EXECUTE, which service_role inherits.
grant execute on function public.subscription_entitlement(text) to service_role;
```

---

## 8. Implementation — server and app

### 8.0 One prerequisite the repo does not have yet: a Clerk token for API calls

The app talks to Supabase directly today; it has no authenticated call to the Render
server. `ClerkBridge.kt` exposes only `setPublishableKey`, `getState`,
`signInWithGoogle`, `signOut`, `deleteAccount` — **no token getter** — while
`server.js` authenticates with `Authorization: Bearer <clerk session token>`
(`verifyClerkRequest`, `server/server.js:1243`). So before any `/api/razorpay/*`
endpoint can be called you need one small native addition:

```kotlin
// ClerkBridge.kt — inside the existing when (call.method) block
"getToken" -> {
    scope.launch {
        // Verified present in com.clerk:clerk-android-api:1.0.39 (the version pinned
        // in android/app/build.gradle): SessionKt.getToken(Session, GetTokenOptions?)
        // is the Kotlin extension, backed by SessionTokenFetcher/SessionTokensCache.
        val token = Clerk.session?.getToken()
        mainHandler.post { result.success(token) }
    }
}
```

and a Dart wrapper:

```dart
Future<String?> clerkSessionToken() =>
    _methodChannel.invokeMethod<String>('getToken');
```

Alternative if you would rather not touch the native bridge: put the same endpoints in a
Supabase Edge Function and authenticate with the Clerk JWT there. Functionally
equivalent; more moving parts because the webhook still needs the service role.

### 8.1 Razorpay client (no new dependency)

Node 18+ has global `fetch`; the Render runtime already uses modern Node
(`server/package.json` has no Razorpay SDK and does not need one).

`server/razorpay.js`:

```js
import crypto from 'node:crypto'

const API = 'https://api.razorpay.com/v1'

export function createRazorpay({ keyId, keySecret, webhookSecret, plans }) {
  const auth = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')

  async function call(path, { method = 'GET', body } = {}) {
    const res = await fetch(`${API}${path}`, {
      method,
      headers: { Authorization: auth, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    })
    const json = await res.json().catch(() => ({}))
    if (!res.ok) {
      const err = new Error(json?.error?.description || `razorpay ${res.status}`)
      err.status = res.status
      err.razorpay = json
      throw err
    }
    return json
  }

  // HMAC-SHA256(hex) of `${paymentId}|${subscriptionId}` with the KEY SECRET.
  function verifyPaymentSignature({ paymentId, subscriptionId, signature }) {
    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${paymentId}|${subscriptionId}`)
      .digest('hex')
    return safeEqual(expected, String(signature || ''))
  }

  // HMAC-SHA256(hex) of the RAW body with the WEBHOOK secret.
  function verifyWebhookSignature(rawBody, signature) {
    const expected = crypto
      .createHmac('sha256', webhookSecret)
      .update(rawBody)              // Buffer — never a re-stringified object
      .digest('hex')
    return safeEqual(expected, String(signature || ''))
  }

  return {
    call,
    verifyPaymentSignature,
    verifyWebhookSignature,
    createSubscription: ({ planId, userId, totalCount, notes }) =>
      call('/subscriptions', {
        method: 'POST',
        body: {
          plan_id: planId,
          total_count: totalCount,
          quantity: 1,
          customer_notify: 1,
          notes: { user_id: userId, ...notes },
        },
      }),
    getSubscription: (id) => call(`/subscriptions/${id}`),
    cancelSubscription: (id) => call(`/subscriptions/${id}/cancel`, { method: 'POST' }),
    planIdFor: (slug) => plans[slug] || null,
  }
}

// Length-independent-safe comparison; timingSafeEqual throws on length mismatch.
function safeEqual(a, b) {
  const x = Buffer.from(String(a))
  const y = Buffer.from(String(b))
  if (x.length !== y.length) return false
  try { return crypto.timingSafeEqual(x, y) } catch { return false }
}
```

### 8.2 Endpoints (add to `server/server.js`)

Mount the webhook **with the other raw-body routes, before `app.use(express.json())`**
at line 501 — same reason the Superwall webhook is there (`server/server.js:325-356`).

```js
// --- Razorpay: webhook (raw body BEFORE express.json()) ---
app.post(
  '/api/razorpay/webhook',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const sig = req.headers['x-razorpay-signature']
    const eventId = req.headers['x-razorpay-event-id']
    if (!razorpay) return res.status(503).json({ error: 'razorpay not configured' })
    if (!sig || !eventId || !Buffer.isBuffer(req.body)) {
      return res.status(400).json({ error: 'missing signature, event id or raw body' })
    }
    if (!razorpay.verifyWebhookSignature(req.body, sig)) {
      return res.status(400).json({ error: 'signature verification failed' })
    }

    let event
    try { event = JSON.parse(req.body.toString('utf8')) } catch { return res.status(400).end() }

    // Idempotency: the same event id must be processed once.
    const { error: dupErr } = await supabase
      .from('razorpay_webhook_events')
      .insert({ event_id: eventId, event_type: event.event || 'unknown' })
    if (dupErr) {
      if (dupErr.code === '23505') return res.json({ status: 'duplicate' })
      console.error('[razorpay] event log failed:', dupErr.message)
      return res.status(500).end()   // let Razorpay retry
    }

    try {
      await applyRazorpayEvent(event)
      res.json({ status: 'ok' })
    } catch (err) {
      console.error('[razorpay] apply failed:', err)
      // Remove the idempotency row so the retry is not swallowed.
      await supabase.from('razorpay_webhook_events').delete().eq('event_id', eventId)
      res.status(500).end()
    }
  }
)

// Upsert the subscription row from a Razorpay subscription entity (webhook or API).
async function persistRazorpaySubscription(entity, planSlugHint) {
  // Webhook payloads do not always carry `notes`, so fall back to the user id we
  // already stored for this subscription rather than dropping the update.
  let userId = entity.notes?.user_id || null
  if (!userId) {
    const { data } = await supabase
      .from('razorpay_subscriptions')
      .select('user_id')
      .eq('subscription_id', entity.id)
      .maybeSingle()
    userId = data?.user_id || null
  }
  if (!userId) return  // never write an unattributable row

  const row = {
    subscription_id: entity.id,
    user_id: userId,
    plan_id: entity.plan_id,
    plan_slug: planSlugHint || planSlugFor(entity.plan_id),
    status: entity.status,
    quantity: entity.quantity ?? 1,
    total_count: entity.total_count ?? null,
    paid_count: entity.paid_count ?? 0,
    current_start: entity.current_start ? new Date(entity.current_start * 1000).toISOString() : null,
    current_end: entity.current_end ? new Date(entity.current_end * 1000).toISOString() : null,
    short_url: entity.short_url || null,
    raw: entity,
    updated_at: new Date().toISOString(),
  }
  const { error } = await supabase
    .from('razorpay_subscriptions')
    .upsert(row, { onConflict: 'subscription_id' })
  if (error) throw new Error(error.message)
}

async function applyRazorpayEvent(event) {
  const entity = event?.payload?.subscription?.entity
  if (!entity) return   // payment.* events are covered by the subscription entity
  await persistRazorpaySubscription(entity)
}
```

Authenticated endpoints (registered after `express.json()`, next to the referral routes):

```js
function requireClerkUser(req, res, next) {
  verifyClerkRequest(req)
    .then((claims) => {
      if (!claims?.sub) return res.status(401).json({ error: 'unauthorized' })
      req.clerkUserId = claims.sub
      next()
    })
    .catch(() => res.status(401).json({ error: 'unauthorized' }))
}

app.post('/api/razorpay/subscription', requireClerkUser, async (req, res) => {
  try {
    if (!razorpay) return res.status(503).json({ error: 'razorpay not configured' })
    const slug = String(req.body?.plan || '').toLowerCase()
    const planId = razorpay.planIdFor(slug)
    if (!planId) return res.status(400).json({ error: 'unknown plan' })

    // One live subscription per user: reuse an unfinished one instead of stacking.
    // (`limit(1)` + array read, not maybeSingle(): more than one historical row is
    // normal, and maybeSingle() throws on multiple matches.)
    const { data: existingRows } = await supabase
      .from('razorpay_subscriptions')
      .select('subscription_id, status, plan_slug')
      .eq('user_id', req.clerkUserId)
      .in('status', ['created', 'authenticated', 'active'])
      .order('created_at', { ascending: false })
      .limit(1)
    const existing = existingRows?.[0]
    if (existing?.status === 'created' && existing.plan_slug === slug) {
      return res.json({ subscription_id: existing.subscription_id, key_id: razorpay.keyId, reused: true })
    }
    if (existing) return res.status(409).json({ error: 'already subscribed' })

    const sub = await razorpay.createSubscription({
      planId,
      userId: req.clerkUserId,
      totalCount: slug === 'yearly' ? 10 : 120,   // ≤10 years
    })
    await persistRazorpaySubscription({ ...sub, status: 'created', notes: { user_id: req.clerkUserId } }, slug)
    res.json({ subscription_id: sub.id, key_id: razorpay.keyId })
  } catch (err) {
    console.error('[razorpay] create failed:', err.message)
    res.status(502).json({ error: 'could not start subscription' })
  }
})

app.post('/api/razorpay/verify', requireClerkUser, async (req, res) => {
  try {
    const { razorpay_payment_id, razorpay_subscription_id, razorpay_signature } = req.body || {}
    if (!razorpay_payment_id || !razorpay_subscription_id || !razorpay_signature) {
      return res.status(400).json({ error: 'missing fields' })
    }

    // Use OUR stored id, not the client's: Razorpay's own instruction for this check.
    const { data: row } = await supabase
      .from('razorpay_subscriptions')
      .select('subscription_id, user_id')
      .eq('subscription_id', razorpay_subscription_id)
      .maybeSingle()
    if (!row || row.user_id !== req.clerkUserId) {
      return res.status(404).json({ error: 'subscription not found' })
    }

    const ok = razorpay.verifyPaymentSignature({
      paymentId: razorpay_payment_id,
      subscriptionId: row.subscription_id,
      signature: razorpay_signature,
    })
    if (!ok) return res.status(400).json({ error: 'invalid signature' })

    // Signature proves the payload; the API call proves the current state.
    const entity = await razorpay.getSubscription(row.subscription_id)
    await persistRazorpaySubscription(entity)

    // Answer from the same function the entitlement endpoint uses, so the rule
    // lives in exactly one place.
    const { data: entRows } = await supabase.rpc('subscription_entitlement', {
      p_user_id: req.clerkUserId,
    })
    const ent = Array.isArray(entRows) ? entRows[0] : entRows
    res.json({ active: Boolean(ent?.active), status: entity.status })
  } catch (err) {
    console.error('[razorpay] verify failed:', err.message)
    res.status(502).json({ error: 'verification failed' })
  }
})

app.get('/api/razorpay/entitlement', requireClerkUser, async (req, res) => {
  const { data, error } = await supabase.rpc('subscription_entitlement', { p_user_id: req.clerkUserId })
  if (error) return res.status(500).json({ error: error.message })
  const row = Array.isArray(data) ? data[0] : data
  res.json({
    active: Boolean(row?.active),
    plan: row?.plan_slug || null,
    current_end: row?.current_end || null,
    status: row?.status || 'none',
    source: 'razorpay',
  })
})

app.post('/api/razorpay/cancel', requireClerkUser, async (req, res) => {
  try {
    const { data: rows } = await supabase
      .from('razorpay_subscriptions')
      .select('subscription_id')
      .eq('user_id', req.clerkUserId)
      .in('status', ['authenticated', 'active', 'pending'])
      .order('created_at', { ascending: false })
      .limit(1)
    const row = rows?.[0]
    if (!row) return res.status(404).json({ error: 'no active subscription' })
    const entity = await razorpay.cancelSubscription(row.subscription_id)
    await persistRazorpaySubscription(entity)
    res.json({ status: entity.status })
  } catch (err) {
    console.error('[razorpay] cancel failed:', err.message)
    res.status(502).json({ error: 'cancel failed' })
  }
})
```

Config (env / vault, following the existing `VAULT_SECRET_KEYS` pattern at
`server/server.js:210-220`):

```
RAZORPAY_KEY_ID=rzp_live_…
RAZORPAY_KEY_SECRET=…
RAZORPAY_WEBHOOK_SECRET=…
RAZORPAY_PLAN_MONTHLY=plan_…
RAZORPAY_PLAN_YEARLY=plan_…
```

Wiring notes for the snippet above: `razorpay` is a module-level instance built in
`start()` from those secrets (null when unset, so every route fails 503 instead of
throwing), exactly like `clerkClient` at `server/server.js:1212-1228`;
`planSlugFor(planId)` is a two-line reverse lookup over the same env map; `supabase` is
the existing service-role client.

### 8.3 Flutter — payment + entitlement

`pubspec.yaml`: `razorpay_flutter: ^1.4.7` (Dart `>=2.12 <4.0`, Flutter `>=2.0`;
project is Dart `>=3.0`, Flutter `>=3.29` — compatible). Android side: plugin
`com.razorpay.razorpay_flutter`, `minSdk 19` (project is 26), pulls
`com.razorpay:checkout:1.6.+`; add the documented ProGuard keeps if you ever enable
minification.

`lib/services/razorpay/razorpay_subscription_service.dart`:

```dart
import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Client for the Razorpay rail. The server owns plan ids, keys and entitlement;
/// this class only opens Checkout and reports what Checkout returned.
class RazorpaySubscriptionService {
  RazorpaySubscriptionService(this._http, this._tokenProvider);

  /// Your app's existing API client (add `API_BASE_URL` to `.env`/`Env` for the
  /// Render host) with two helpers: postJson(path, body, {token}) and
  /// getJson(path, {token}).
  final EntitlementHttpClient _http;
  final Future<String?> Function() _tokenProvider;

  Razorpay? _razorpay;
  Completer<PaymentSuccessResponse>? _pending;

  void init() {
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
  }

  void dispose() => _razorpay?.clear();

  void _onSuccess(PaymentSuccessResponse r) { _pending?.complete(r); _pending = null; }
  void _onError(PaymentFailureResponse r) {
    // Razorpay.PAYMENT_CANCELLED == 2: the user closed Checkout. That is a
    // "declined", not a failure worth an alert — callers treat both the same.
    if (!(_pending?.isCompleted ?? true)) {
      _pending!.completeError(RazorpayCheckoutException(r.code ?? -1, r.message ?? ''));
    }
    _pending = null;
  }

  /// Returns true when the server confirmed the subscription is live.
  Future<bool> subscribe(String plan /* 'monthly' | 'yearly' */) async {
    final token = await _tokenProvider();
    if (token == null) throw StateError('sign-in required');

    final session = await _http.postJson(
      '/api/razorpay/subscription',
      {'plan': plan},
      token: token,
    );
    final subscriptionId = session['subscription_id'] as String;
    final keyId = session['key_id'] as String;

    final completer = Completer<PaymentSuccessResponse>();
    _pending = completer;
    _razorpay!.open({
      'key': keyId,
      'subscription_id': subscriptionId,   // amount comes from the plan; do not send amount
      'name': 'Soulful Bhakti',
      'description': plan == 'yearly' ? 'Premium — Yearly' : 'Premium — Monthly',
      'theme': {'color': '#8B5E3C'},
      'retry': {'enabled': true, 'max_count': 3},
    });

    final result = await completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () => throw TimeoutException('checkout did not finish'),
    );

    final verified = await _http.postJson('/api/razorpay/verify', {
      'razorpay_payment_id': result.paymentId,
      // 1.4.7 exposes paymentId / orderId / signature / data (all nullable).
      // A subscription has no order id, so read the subscription id from the raw
      // payload and fall back to the id we created server-side.
      'razorpay_subscription_id':
          (result.data?['razorpay_subscription_id'] as String?) ?? subscriptionId,
      'razorpay_signature': result.signature,
    }, token: token);

    return verified['active'] == true;
  }
}

class RazorpayCheckoutException implements Exception {
  RazorpayCheckoutException(this.code, this.message);
  final int code;
  final String message;
  bool get isUserCancelled => code == Razorpay.PAYMENT_CANCELLED;
  @override
  String toString() => 'RazorpayCheckoutException($code): $message';
}
```

> Verified against `razorpay_flutter 1.4.7` (package archive inspected): the plugin
> forwards the whole options map to `CheckoutActivity` as `OPTIONS`, so `subscription_id`
> reaches the native SDK; `PaymentSuccessResponse` carries `paymentId`, `orderId`
> (from `razorpay_order_id`), `signature`, and the raw `data` map — which is where
> `razorpay_subscription_id` appears. Error code `2` is `Razorpay.PAYMENT_CANCELLED`.

Entitlement mirror, following the existing `ClerkAuthSignal` pattern:

```dart
/// Synchronous, always-safe mirror of the server's entitlement answer.
class RazorpayEntitlementSignal {
  static bool active = false;
  static DateTime? checkedAt;

  static bool get isActive =>
      active && (checkedAt == null ||
          DateTime.now().difference(checkedAt!) < const Duration(minutes: 15));
}

/// Called at launch, on sign-in, on returning from Checkout, and on resume.
Future<void> refreshRazorpayEntitlement() async {
  try {
    final json = await api.getJson('/api/razorpay/entitlement', token: await sessionToken());
    RazorpayEntitlementSignal.active = json['active'] == true;
    RazorpayEntitlementSignal.checkedAt = DateTime.now();
  } catch (_) {
    // Fail closed for NEW unlocks; keep the last known value until it expires.
  }
}
```

The one gate edit (`lib/modules/monetization/premium_access.dart:51`):

```dart
static bool isPremiumUser(dynamic ref) =>
    isSignedIn(ref) &&
    (_subscriptionStatus.isActive || RazorpayEntitlementSignal.isActive);
```

That is the whole app-side change for Pathway A: no new paywall, no new screen.

### 8.4 Pathway B only — Play choice + Razorpay

Only after A is stable. Shape:

1. `Superwall.configure(apiKey, purchaseController: _controller, options: ...)` — the
   SDK already supports this (`superwallkit_flutter 2.4.9`,
   `PurchaseController.purchaseFromGooglePlay(productId, basePlanId, offerId)`).
2. `purchaseFromGooglePlay` asks the native bridge to run a `BillingClient` built with
   `.enableUserChoiceBilling { details -> … }` + `launchBillingFlow(productDetails,
   offerToken)`.
3. If the user picks Google Play, Play completes the purchase inside that client; you
   verify server-side, write entitlement, then
   `Superwall.setSubscriptionStatus(SubscriptionStatus.active)`.
4. If the user picks Razorpay, the listener hands you
   `details.externalTransactionToken`; call Razorpay Checkout, then on success POST the
   token + amount to your server, which reports it to Google:
   `POST /androidpublisher/v3/applications/com.soulfulbhakti.app/externalTransactions?externalTransactionId=…`
   (initial transaction uses the token; renewals use new ids) **within 24 hours**.
5. Add the subscription-management URL and payment-method logo in Play Console.

Non-negotiables for B: Play Billing ≥ 5.2 (you have 8.0.0), the token must be persisted
before the Razorpay flow starts, and the 24-hour reporting job needs monitoring.

---

## 9. Test matrix (do these in test mode first)

| # | Scenario | Expected evidence |
|---|---|---|
| 1 | Create subscription (monthly) server-side | `sub_…` in Razorpay test dashboard, row `status=created` |
| 2 | Authorise with test card `4718 6091 0820 4366` | `razorpay_payment_id` + signature returned; row `authenticated`/`active` |
| 3 | Forged signature | `/verify` → 400, no entitlement change |
| 4 | Replayed webhook (same `x-razorpay-event-id`) | second call → `{status:'duplicate'}`, one row |
| 5 | Webhook with bad HMAC | 400, nothing written |
| 6 | Renewal via Dashboard "Charge this now" | `subscription.charged`, `current_end` advanced |
| 7 | Failed renewal → `pending` → `halted` | premium kept ≤72 h, then revoked |
| 8 | Cancel | `cancelled`; premium until `current_end`, then revoked |
| 9 | Expired (unauthenticated past `start_at`) | no premium |
| 10 | Paid track as Razorpay subscriber | plays; as free user | paywall |
| 11 | Signed-out user | 401 from every `/api/razorpay/*` |
| 12 | Cross-user attack: verify someone else's `sub_…` | 404 (ownership check) |
| 13 | Airplane mode after payment | last-known entitlement holds, no crash |
| 14 | Razorpay sandbox → live key swap | same flows with real ₹1 test |

Then the Play-specific ones for B: choice screen renders only in India; Play choice
purchases still unlock; Razorpay choice purchase reported to Google within 24 h
(visible in Play Console → financial reports); 5 %-ish of Play users on a test track.

---

## 10. What "100 % successfully" means here

It is achievable, but only as a **defined** bar — not as a promise about Play review.
Acceptance criteria I would hold this to:

1. A user can pay ₹120 by card and by UPI Autopay in test mode, and is premium within
   10 seconds of Checkout closing, verified by `GET /api/razorpay/entitlement`.
2. Every webhook event is signature-verified, deduped, and idempotent under replay.
3. Entitlement is revoked exactly once, at the right moment, for halt/cancel/expire/refund.
4. No secret exists in the app bundle (`strings`/unzip check of the release AAB).
5. Forged signature, cross-user access, and unsigned webhooks all fail closed.
6. The paid gate behaves identically for Play-paid and Razorpay-paid users.
7. The release AAB still passes the repo's existing gates
   (`flutter analyze`, tests, the release workflow's permission audit).

For Pathway B add: Google's transaction report for a test purchase appears in Play
Console, and Play's choice screen is shown only to Indian users.

---

## 11. Go-live checklist

**Razorpay**
- [ ] Business KYC complete; subscriptions product enabled on the account.
- [ ] Two plans created (monthly 12000 paise / yearly 120000 paise, INR) and their
      `plan_id`s stored in env — never created per-request.
- [ ] Subscriptions → Settings: Card, UPI, eMandate enabled as intended.
- [ ] Flash Checkout enabled (otherwise Checkout fails for subscription ids).
- [ ] Webhook URL `https://<render-host>/api/razorpay/webhook` with the six
      `subscription.*` events + `payment.failed`; secret stored server-side.
- [ ] Live key id/secret in the vault; test keys only on dev/nightly flavours.
- [ ] Settlement account and refund policy confirmed.

**App**
- [ ] `razorpay_flutter` added; `flutter pub get`; release build green.
- [ ] ClerkBridge `getToken` + Dart wrapper added (§8.0); server returns 401 without a
      valid bearer, verified on device.
- [ ] ProGuard keeps present if `minifyEnabled` is ever turned on.
- [ ] `<queries>` in `AndroidManifest.xml` covers UPI intent resolution (Android 11+
      package visibility) — the plugin needs the UPI apps visible; test on a device with
      GPay/PhonePe installed.
- [ ] Privacy policy + Play Data Safety updated: Razorpay named as the payment processor,
      "financial info" collected/processed by a third party, no card data stored by app.
- [ ] Analytics events: `subscription_checkout_opened`, `subscription_activated`,
      `subscription_failed(code)`.

**Play Console (Pathway B only)**
- [ ] Enrolled on the Alternative billing page for India, per app.
- [ ] PCI DSS attestation + fraud-reporting contact submitted.
- [ ] Payment-method logo (192×20 dp) and subscription-management URL uploaded.
- [ ] 24-hour Google reporting job deployed and alerting.
- [ ] Internal test track validated with Indian test accounts.

---

## 12. Risks and open questions

1. **The one that gets apps removed:** shipping Razorpay in-app without Pathway B
   enrolment. Policy quote in §2. Don't.
2. **Superwall is the current entitlement source.** Pathway A leaves it untouched
   (OR-ed). Pathway B migrates it to a `PurchaseController`, which touches every existing
   subscriber's unlock path — plan a regression pass, not just a new-feature test.
3. **Paid audio is not actually protected server-side today.** `GET /stream/:id` returns
   a public CDN URL with no check. Razorpay work should not be the thing that fixes this,
   but it is the natural moment to add a server-side entitlement check on paid tracks —
   otherwise a Razorpay subscriber and a pirate get the same stream URL.
4. **Pathway B's economics are thinner than they look:** 11 % Google + Razorpay MDR is
   not "2 % instead of 15 %". Model it before committing 4 weeks.
5. **Razorpay account-level eligibility** (subscriptions on UPI Autopay, e-mandate) varies
   by account and MCC; confirm with your Razorpay account manager, not from docs.
6. **Webhook secret rotation** breaks signature validation for in-flight retries — keep
   the old secret during rollover (Razorpay's own note).
7. **Proration/upgrades** (monthly → yearly) are not automatic across rails; either use
   Razorpay's `PATCH /subscriptions/:id` plan change or cancel + resubscribe. Decide.
8. **Google's programme names and fees move.** The current docs already show manual
   reporting being sunset in favour of the alternative-billing APIs, and a newer
   "Billing Choice" programme in the Play docs navigation. Before committing to Pathway
   B, re-read the India programme page and your Play Console's Alternative billing screen —
   the enrolment categories and fee wording are the two things that change.

---

## 13. Sources

All fetched and read on 2026-11-08 from the official documentation (snapshots kept in
`D:\Soulful Bhakti\_razorpay_docs\`).

Google Play
- Payments policy: https://support.google.com/googleplay/android-developer/answer/10281818
- India alternative billing program: https://support.google.com/googleplay/android-developer/answer/13306652
- Understanding alternative billing options: https://support.google.com/googleplay/android-developer/answer/13821247
- Enrolling your app in alternative billing: https://support.google.com/googleplay/android-developer/answer/14245100
- Alternative billing APIs (client): https://developer.android.com/google/play/billing/alternative
- In-app integration with user choice: https://developer.android.com/google/play/billing/alternative/alternative-billing-with-user-choice-in-app
- Backend integration / external transactions: https://developer.android.com/google/play/billing/alternative/backend

Razorpay
- Subscriptions overview & lifecycle: https://razorpay.com/docs/payments/subscriptions/
- How subscriptions work: https://razorpay.com/docs/payments/subscriptions/workflow
- Integration guide (subscription + Checkout): https://razorpay.com/docs/payments/subscriptions/integration-guide
- Subscription states: https://razorpay.com/docs/payments/subscriptions/states
- Subscription webhooks: https://razorpay.com/docs/payments/subscriptions/subscribe-to-webhooks
- Webhook signature validation & idempotency: https://razorpay.com/docs/webhooks/validate-test
- Create subscription API: https://razorpay.com/docs/api/payments/subscriptions/create-subscription
- Subscriptions API index (cancel/pause/resume): https://razorpay.com/docs/api/payments/subscriptions
- Subscriptions settings (methods, ₹15,000 card/UPI cap): https://razorpay.com/docs/payments/subscriptions/settings
- Flutter plugin: https://pub.dev/packages/razorpay_flutter (1.4.7) and
  https://github.com/razorpay/razorpay-flutter

Local (code-verified): `android/app/build.gradle`, `lib/modules/monetization/premium_access.dart`,
`lib/modules/monetization/superwall_gate.dart`, `lib/services/superwall_service.dart`,
`server/server.js`, `server/supabase-schema.sql`, `pubspec.yaml`.
