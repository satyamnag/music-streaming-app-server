# Identifying a paid user — and whether a Google Play payer really has access

Scope: the Android app (`com.soulfulbhakti.app`), its Clerk identities, and the
two payment rails. Everything below is verified against this repository and
against the vendors' own documentation; nothing is assumed.

Status: investigation complete. Per-user verdicts for Google Play **cannot** be
produced from our systems — see §2 — so §3.1 is the check that decides it.

---

## 1. The rule the app actually uses (code-verified)

Premium is a single boolean, computed in one place:

```dart
// lib/modules/monetization/premium_access.dart:65-67
static bool isPremiumUser(dynamic ref) =>
    isSignedIn(ref) &&
    (_subscriptionStatus.isActive || EntitlementSignal.isActive);
```

| Rail | Where the truth lives | What the app reads | Evidence |
|---|---|---|---|
| **Google Play** (bought inside the app) | Superwall → Google Play | `SubscriptionStatus.isActive`, mirrored from the SDK stream at startup | `premium_access.dart:45,208-212`, wired in `lib/main.dart:266-269`; SDK call `lib/services/superwall_service.dart:79-83` |
| **Razorpay** (bought outside the app, web / payment link) | our Postgres `razorpay_subscriptions` | `GET /api/razorpay/entitlement` → `EntitlementSignal`, 30-minute freshness | `lib/services/entitlement/entitlement_service.dart:84-179,297`; `server/migrations/038_razorpay_subscriptions.sql:86-113` |

Two properties of that rule matter for the question asked:

1. **Identity is the Clerk user id.** Superwall is told the Clerk id on every
   resolved sign-in (`lib/provider/auth/clerk_auth_provider.dart:184` →
   `superwall_service.dart:79`), and the SDK is configured with
   `passIdentifiersToPlayStore = true` (`superwall_service.dart:72`), so the Play
   purchase carries that same id as `obfuscatedExternalAccountId`.
2. **A missing answer is "free".** If the SDK is unconfigured, throws, or has no
   status, `isActive` is false and the gate refuses (`superwall_service.dart`
   `registerPlacement` deliberately does **not** grant on failure).

A Play subscriber's product ids are fixed in code: `soulful_monthly` and
`soulful_yearly` (`lib/modules/auth/profile_plan_status.dart:31-32`).

---

## 2. Why our own database cannot answer this for the two Play payers

This is the central finding, and it is the reason a direct "yes/no" was not
produced from Postgres.

| Fact | Evidence |
|---|---|
| The Superwall webhook **only credits commissions**; it stores no entitlement, no subscription row, no raw event | `server/server.js:358-420` (verify) → `:455-540` (`handleSuperwallEvent`) |
| Only production `PLAY_STORE`/`STRIPE` purchases, non-trial, positive price pass — everything else is dropped silently | `server/server.js:462-472` |
| `commissions` exists only for buyers who were **referred or coupon-attributed**; a normal buyer leaves no row at all | `server/migrations/003_referrals.sql:83-95`, credit RPCs at `:237-282` |
| The only table written from a purchase is `razorpay_subscriptions`, and it is written **only** from Razorpay entities | `server/server.js:627` `persistRazorpaySubscription`, call sites `:675,738,900,947,975` |
| There is **no** Google Play Developer API / `androidpublisher` code anywhere in this repo — no server-side Play verification exists | `git grep androidpublisher` → no matches |

So: for a Google Play purchase, **the only authoritative record is Superwall's**
(and Google's). Our Postgres answers the Razorpay rail only.

One consequence worth stating plainly: `premium_access.dart` is the *only*
place the Play grant is decided, and `/stream/:id` returns a public CDN URL with
no premium (or even auth) check (`server/server.js`, `/stream/:id` route). The
paid boundary is a **UI gate**, not an enforced entitlement. That is how the app
behaves today, by design of the current code, and it is why "does this user have
access?" is a question about their device state, not about a server row.

---

## 3. The checks, in order of authority

### 3.1 Superwall — authoritative for Google Play

Run the read-only checker in this repo (GETs only; the key is never printed):

```bash
SUPERWALL_API_KEY=... node server/tools/check-paid-user.mjs \
  user_3HyLFqjagXaEZLBuw3dmV2S8Bqu  <second user id>
```

It prints, per user, exactly the fields the app's gate is built on:
`subscription_status`, `has_active_subscription`, `active_product_ids`,
`primary_store`, `expiration_date`, `next_renewal_date`, active entitlements, and
whether Superwall has ever seen the id at all. Exit codes: `0` all answered,
`1` at least one unknown, `2` configuration problem.

Under the hood (Superwall API v2, <https://api.superwall.com/docs>):

| Purpose | Endpoint |
|---|---|
| Find the Android `application_id` | `GET /v2/projects` → `data[].applications[]` (match `bundle_id = com.soulfulbhakti.app`) |
| **The verdict** | `GET /v2/users/{app_user_id}/subscription-summary?application_id=…` |
| Entitlements (informational — the app does not read these) | `GET /v2/users/{app_user_id}/active-entitlements?application_id=…` |
| Confirm an id is known / search | `POST /v2/users/query` (`search_term` is a substring match on `app_user_id`) |
| **Enumerate Play payers** (to find the unknown second user) | `GET /v2/projects/{id}/applications/{application_id}/recent-transactions?environment=PRODUCTION&from=…&to=…&event_type=initial_purchase` |

Subscription state as Superwall reports it: `subscription_status` is one of
`active`, `trial`, `expired`, `cancelled`, `none`.

No dashboard needed. Without an API key, the dashboard equivalent is:
**Users** → search the Clerk id → open the profile → **Overview** shows App User
ID, Total Spent and last seen; **Entitlements** shows active entitlements and
their expiry; the **Subscriptions Events** filter lists the purchase, renewal and
cancellation events. (Documented: <https://superwall.com/docs/dashboard/overview-users>,
<https://superwall.com/docs/dashboard/subscription-management>.)

How to read the answer:

| Superwall says | The app grants |
|---|---|
| `has_active_subscription: true` (`subscription_status` is `active` or `trial`) | paid tracks play; crown badge hidden; profile card names the plan |
| `404` for that app_user_id | **not paid on this identity** — the purchase was made under a different Clerk user or a different Superwall id |
| `cancelled`/`expired` with no active period | not paid; the app shows the paywall |
| Active but the user says they are blocked | device/build problem, not entitlement — see §5.4 |

### 3.2 Google Play Console — the money, not the identity

Monetise → **Order management** (search an order id) or **Financial reports**
(a sales report for a date range) shows the subscription product, the order id
and the purchase state. Play Console does **not** show the Clerk id; the
`obfuscatedExternalAccountId` is only returned by the Developer API
(`purchases.subscriptionsv2.get`), which this project does not use. Use Play
Console to confirm *that* money was taken, and Superwall to confirm *which
person* holds it.

### 3.3 In the app — fastest for support

1. Profile → **YOUR SUBSCRIPTION** card. A Play subscriber shows
   `Monthly Plan` / `Yearly Plan` and `Started … · valid until …`
   (`lib/modules/auth/profile_plan_status.dart:173-197`).
2. Tap a paid track (golden crown, top-right). It plays → entitled. Paywall
   appears → not entitled.

Both surfaces read the same gate, so they agree with each other. They do **not**
say "Free plan" to a Play subscriber on a build at or after the entitlement
fixes (Nov 11); older builds could, which is a support-script caveat (§5.4).

### 3.4 Postgres — authoritative for Razorpay/web only

Read-only, safe to run in the Supabase SQL editor:

```sql
-- The single entitlement answer the app trusts for the web rail.
select * from subscription_entitlement('user_3HyLFqjagXaEZLBuw3dmV2S8Bqu');

-- Every web subscriber, newest first (sanity check of the whole rail).
select user_id, plan_slug, status, current_start, current_end, paid_count, updated_at
from razorpay_subscriptions
order by created_at desc;

-- Was this user ever recorded as a referred/affiliate Play buyer?
-- (Absence proves nothing: non-referred buyers leave no row.)
select referred_user_id, product_id, plan_price, rate_percent, created_at
from commissions
where referred_user_id = 'user_3HyLFqjagXaEZLBuw3dmV2S8Bqu';
```

Entitlement rule, for reading the output (`038_razorpay_subscriptions.sql:86-113`):

| Status | Access |
|---|---|
| `authenticated`, `active` | yes |
| `pending` | yes until `current_end` + 72 h |
| `cancelled`, `halted` | yes until `current_end` |
| `created`, `paused`, `expired`, `completed` | no |

---

## 4. The two users

**`user_3HyLFqjagXaEZLBuw3dmV2S8Bqu`** — verified real in Clerk (read-only
Admin API lookup; provider `oauth_google`):

| Field | Value |
|---|---|
| created | 2026-08-15 23:07:40 UTC |
| last sign-in | 2026-11-12 00:34:25 UTC |
| last active | 2026-11-11 07:41:08 UTC |
| external account | Google OAuth (no email/OTP identity attached) |

Our systems add two more facts: the user has **no referral code** and **zero
referral/commission activity** (`GET /api/referrals/{id}/summary` → all zeros),
and `user_profiles.id` is a `uuid` column, so this Clerk id has no profile row
(the endpoint answers HTTP 500 `invalid input syntax for type uuid`).

**Play verdict: not decidable from our side.** It requires the Superwall call in
§3.1 — one command, read-only.

**The second user: unknown so far.** There is no place in this repository or in
our database that lists Play purchasers, so it must be enumerated from
Superwall's `recent-transactions` (§3.1) or from Play Console's order list
cross-referenced with Superwall. The web-rail checks (§3.4) will not find them.

---

## 5. Findings and risks

1. **No server-side Play entitlement exists.** Nothing to fix for today's
   question, but it means entitlement cannot be audited, revoked or reported
   from our backend; every Play answer depends on Superwall's availability and
   on the device holding a configured SDK.
2. **Two identities per person is a real failure mode.** A web purchase made
   with email OTP and an app sign-in with Google resolve to *two different Clerk
   users*; the app then correctly answers "free" for the wrong person. This is
   recorded in the project's own commit history (`9ebdf6b0`, `735059e6`) for a
   Razorpay subscriber, and the same shape applies to a Play buyer who switched
   Google accounts. Mitigation: always confirm the purchase's `app_user_id` is
   the id the user signs in with today.
3. **The paywall is UI-only.** `/stream/:id` hands out a public CDN URL with no
   auth or premium check, so a determined client can stream a locked track. A
   paid user's "access" is therefore never enforced server-side; do not treat a
   successful stream as proof of payment.
4. **Builds older than the Nov 11 entitlement fixes** can show `Free plan` to a
   paying user (client-side token/identity races fixed in `92514da1`,
   `9ebdf6b0`, `457981a5`, `ed28cd6e`, `3d56864f`, `c07c3012`). A support answer
   of "the card says Free" is only meaningful on a current build.
5. **`Soulful Bhakti Web App/SUBSCRIPTIONS.md` is wrong** where it says Play
   purchases "both land in the same `razorpay_subscriptions` table". They do
   not — no code path writes a Play purchase there (§2). That sentence should be
   corrected so nobody audits Play revenue against that table.

---

## 6. Safety of what was done

- No write, no mutation, no state change was issued to any system. The commands
  run were: `git grep`/file reads, one Clerk Admin API `GET /v1/users/{id}`, one
  public `GET /api/user-profile` and `GET /api/referrals/{id}/summary` on our own
  API, `GET` probes of Superwall's public API (which returned 401), and reads of
  the published OpenAPI spec.
- The Clerk secret was read from AWS Secrets Manager (`famerelay`,
  `ap-south-1`, `clerk/secret-key`) per the project's credential policy, used
  in-process, and never printed. No key or token is stored in this document or
  in the tool.
- `server/tools/check-paid-user.mjs` is read-only by construction: only `GET`
  plus Superwall's read-only `POST /v2/users/query`; it prints the key nowhere
  and references no mutation endpoint.

---

## 7. To finish the two verdicts

Provide either:

1. a Superwall API key (read scope) exported as `SUPERWALL_API_KEY` — then
   `node server/tools/check-paid-user.mjs <id> [id...]` answers both users in one
   run; or
2. the Superwall **Users** profile for each id (App User ID, `has_active`/
   entitlement state, product ids, expiry), or a `recent-transactions` export
   for the purchase window.

Either route answers the same two facts: whether the id is known to Superwall
at all, and whether it currently holds an active Play subscription.
