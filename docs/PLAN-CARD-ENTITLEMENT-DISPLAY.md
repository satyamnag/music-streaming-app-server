# Why a Google Play subscriber saw "Free plan", and the fix

Status: fixed. Reported with a screenshot: `impastorrajeshkumar@gmail.com`, paid
through Google Play, **locked tracks played** — and the profile card still said
`Free plan / Upgrade to Pro`.

That combination is the whole diagnosis: the gate that decides playback said
"paid" while the card that displays the plan said "free". Two surfaces, two
different sources.

---

## 1. The two sources (code-verified)

| Surface | What it read | Where |
|---|---|---|
| Playback gate (correct) | `SubscriptionStatus.isActive` — Superwall's status, derived from the user's **active entitlements** | `lib/modules/monetization/premium_access.dart:65-67`, fed by `subscribeToStatus()` (`:208-212`, wired in `lib/main.dart:269`) |
| Profile card (wrong) | `CustomerInfo.subscriptions` — the **local transaction list** — looking for `isActive && !isRevoked` | old `lib/modules/auth/profile_plan_status.dart:99-106` |

Those are not the same list. From the SDK's own model
(`superwallkit_flutter 2.4.9`, `lib/src/public/CustomerInfo.dart`):

- `CustomerInfo.entitlements` — `Entitlement.isActive` is documented as *"whether
  there is any active, non-revoked transaction for this entitlement"*, with
  `latestProductId`, `startsAt`, `expiresAt`, `willRenew`;
- `CustomerInfo.subscriptions` — the `SubscriptionTransaction` records **this
  device/account has locally seen**.

A purchase that was validated server-side rather than created on this install —
restored after a reinstall, renewed in the background, or attached to an existing
Superwall identity — yields an **active entitlement with no local
`SubscriptionTransaction`**. The gate says premium (tracks play); the card found
an empty list and fell through to `Free plan`.

Superwall's own documentation agrees that `subscriptionStatus` is the state to
read: *"A Stream that emits the user's current subscription status"* and the
convenience `isActive` (<https://superwall.com/docs/flutter/sdk-reference/subscriptionStatus>),
with entitlements being what grants access
(<https://superwall.com/docs/dashboard/subscription-management>: *"the platform
reconciles those events into user entitlements that power … access gates"*).

## 2. The fix

The card no longer re-derives the plan. It asks the same question the gate asks.

`lib/modules/auth/profile_plan_status.dart` now contains a pure decision
function, `planCardView` (`:89`), with this precedence — richest detail first,
access last, so the two surfaces can never disagree:

1. an active `SubscriptionTransaction` → plan name from its `productId`, dates
   from `purchaseDate` / `expirationDate` / `willRenew` (unchanged behaviour);
2. an active `Entitlement` → plan name from `latestProductId`, dates from
   `startsAt` / `expiresAt` / `willRenew` (**the case that was missing**);
3. Superwall's `subscriptionStatus` via
   `PremiumAccess.isPlaySubscriptionActive` (`premium_access.dart:79`) — the
   gate's exact field, so "premium but no detail yet" still shows a paid plan;
4. the server-verified Razorpay/web answer (`EntitlementSignal`), as before.

`Free plan` is therefore shown **only when every source says free**. The widget
also subscribes to `subscriptionStatus` now, so the card repaints when Superwall
changes its verdict instead of freezing the value it read at mount.

The card still shows the spinner instead of "Free plan" while the first answer
for the user is outstanding, and a confirmed subscriber never sees the spinner —
`isChecking` is `!isPremium && (loading || webPending)`.

### Alternatives considered and rejected

| Option | Why not |
|---|---|
| Read only `subscriptionStatus` | Fixes the contradiction but throws away the plan name, start date and expiry the card is specified to show |
| Call `restorePurchases()` from the card | A restore is a user-initiated Play action; doing it silently on a profile render would hammer the Play API and can trigger the purchase dialog. Superwall already restores automatically |
| Show "Premium" whenever tracks play | Display would still be wrong about *which* plan and when it ends; the owner would lose the expiry information |

## 3. Tests

`test/profile_plan_status_test.dart` (12 cases) pins the rule, including the
exact reported shape:

- **active entitlement + empty `subscriptions` → premium, "Yearly Plan"** (the
  regression test for this report);
- gate active with **no** `CustomerInfo` at all → premium, "Premium Plan";
- inactive entitlement → free;
- an active local transaction still wins and names the plan from its product id;
- revoked transaction ignored; lifetime entitlement says "Lifetime access";
- web-only access still shows the web plan and end date, and never overrides a
  Play product name;
- free only when nothing is active and nothing is pending; pending → "checking".

## 4. Google Play compliance

Nothing in this change touches the payment rails:

- The **only** in-app purchase path is still Google Play Billing through
  Superwall. No Razorpay UI, link, button or wording was added — Play's Payments
  policy forbids steering users to an external payment method for this digital
  subscription (`docs/RAZORPAY-SUBSCRIPTIONS.md` §2).
- The card displays **status only**. "Upgrade to Pro" was already the paywall
  entry point and is hidden as soon as the user is premium (that is the bug being
  fixed: it was shown to a paying user).
- Play Billing requires accurate account state; showing a paid subscriber their
  real plan and expiry is the compliant direction, not a risk.
- Recommendation (not implemented here, needs product sign-off): add a
  "Manage subscription" row that opens
  `https://play.google.com/store/account/subscriptions`, which Play expects apps
  with subscriptions to offer. Account-management surfaces are permitted inside
  a Play app.

## 5. Verifying on a device

1. Sign in as the affected account on a build that contains this change.
2. Profile → **YOUR SUBSCRIPTION** must show the paid plan (name, dates) and **no
   "Upgrade to Pro"** button.
3. Tap a crowned paid track — it must play (that path was already correct).
4. Then force a free account (second device) and confirm it still shows
   `Free plan` + the upgrade button, so the fix did not widen access.

Note: this also closes the gap flagged in `docs/PAID-USER-VERIFICATION.md` §5.4 —
"the card says Free" was a real display defect for Play subscribers, not evidence
that their entitlement was missing.
