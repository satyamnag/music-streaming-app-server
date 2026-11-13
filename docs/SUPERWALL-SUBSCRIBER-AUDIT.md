# Superwall subscriber audit — 2026-11-13

Read-only audit of the Superwall project against the Android app
(`com.soulfulbhakti.app`), using the read-only API key stored at
`superwall/api-key` (see `SECRETS-AWS.md`).

Scope: project `Soulful Bhakti` **28422**, application **52776** (android),
organization **26125**. All figures are production (`environment=PRODUCTION`);
sandbox returned 0 transactions.

---

## Headline

**5 Play transactions from 3 distinct Clerk users — and 0 active subscribers.**

Every one of the three has a Google Play purchase recorded (real `GPA.` order ids,
Aug–Nov 2026), yet Superwall holds **no subscription record and no entitlement**
for any of them. In the app's terms (`isPremiumUser = signedIn && (Superwall
status || web entitlement)`) all three are **free**.

## The transactions

| # | Clerk user id | Purchased | Product | Play order id | Country |
|---|---|---|---|---|---|
| 1 | `user_3HyLFqjagXaEZLBuw3dmV2S8Bqu` | 2026-11-12 00:37 | `soulful_yearly:soulful-yearly:sw-auto` | `GPA.3384-7318-4817-82653` | IN |
| 2 | `user_3HoaHfzD3Xl1S1vToCUfjM6vAil` | 2026-08-15 22:54 | `soulful_yearly:soulful-yearly:sw-auto` | `GPA.3338-7903-6237-20416` | US |
| 3 | `user_3HoaHfzD3Xl1S1vToCUfjM6vAil` | 2026-08-21 12:14 | `soulful_yearly:soulful-yearly:sw-auto` | `GPA.3317-1028-0025-72726` | US |
| 4 | `user_3HiWGknEcN962l7QdxvMJmwWb2B` | 2026-08-20 00:37 | **`soulful_monthly:soulfulmonthly:sw-auto`** | `GPA.3390-6539-3485-25083` | IN |
| 5 | `user_3HiWGknEcN962l7QdxvMJmwWb2B` | 2026-08-21 12:00 | `soulful_yearly:soulful-yearly:sw-auto` | `GPA.3393-5333-7751-71823` | IN |

## Per-user state (live, from the API)

| User | `subscription_status` | `has_active_subscription` | entitlements | subscriptions (v3) | total spend |
|---|---|---|---|---|---|
| `user_3HyLFqjagXaEZLBuw3dmV2S8Bqu` | `none` | false | none | 0 | 0 |
| `user_3HoaHfzD3Xl1S1vToCUfjM6vAil` | `none` | false | none | 0 | 0 |
| `user_3HiWGknEcN962l7QdxvMJmwWb2B` | `none` | false | none | 0 | 0 |

Every transaction row also carries `price: 0`.

## Catalog state

- Superwall defines **exactly one product**: `soulful_yearly:soulful-yearly:sw-auto`
  (id `668797`, `play_store`, ₹120) → mapped to entitlement **`pro`** ✓.
- The **monthly product** referenced by transaction #4
  (`soulful_monthly:soulfulmonthly:sw-auto`) **does not exist** in the catalog, so
  that purchase could never have granted access even with perfect verification.

## What this means

1. The app is behaving correctly for these three: Superwall says no subscription,
   so the gate stays closed and the profile card says Free. The bug is upstream of
   the app.
2. Two distinct defects are visible:
   - **Play → Superwall verification never completed** for any of the five
     purchases (no subscription records at all, `price: 0`), which usually means
     the Play **RTDN (Pub/Sub)** and/or the service-account link in
     Superwall → Integrations → Google Play is not working;
   - the **monthly product is not registered**, so a monthly buyer can never be
     activated.
3. One buyer is on a **US** account in a ₹-priced app and all events show
   `price: 0` — worth confirming in Play Console that the orders were actually
   charged rather than being licence-tester/test purchases.

## Next steps (in order)

1. **Play Console → Order management** for the five `GPA.` ids: `Charged` /
   `Cancelled` / `Refunded`. That single check separates "integration broken"
   from "nothing was ever captured".
2. **Superwall → Integrations → Google Play**: service account connected, RTDN
   Pub/Sub topic bound, and a test purchase creating a subscription record.
3. **Superwall → Products**: add the monthly product and map it to `pro`.
4. **Remediate the three users** once 1–3 are understood: grant `pro` manually in
   Superwall (Users → profile → `+` → Grant Entitlement) or issue a web/Razorpay
   subscription. They paid; they should not have to buy twice.

## Reproducing this audit

```bash
KEY=$(aws secretsmanager get-secret-value --profile famerelay --region ap-south-1 \
  --secret-id superwall/api-key --query SecretString --output text)

# every purchase event (event_type=all is required; the default view is empty)
curl -s -H "Authorization: Bearer $KEY" \
 "https://api.superwall.com/v2/projects/28422/applications/52776/recent-transactions?environment=PRODUCTION&from=2024-01-01&to=2026-12-31&event_type=all"

# the paid/free answer per user
curl -s -H "Authorization: Bearer $KEY" \
 "https://api.superwall.com/v2/users/user_xxx/subscription-summary?application_id=52776"
```
