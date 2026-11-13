# Analytics consent — first-run disclosure

Status: implemented, built (`43411155844`) and installed. Answers the question
"can analytics be on by default?" with **no**, and implements the compliant
alternative.

---

## 1. Why default-on was rejected

Play's User Data policy (Prominent Disclosure & Consent,
<https://support.google.com/googleplay/android-developer/answer/10144311>) requires:

| Requirement (quoted) | What default-on would do |
|---|---|
| "Obtain clear, affirmative user consent before collecting any personal or sensitive data" | collect first, never ask |
| consent "must be granted by the user **before** your app can begin to collect" | collection starts at first launch |
| disclosure "must be displayed in the normal usage of the app and not require the user to navigate into a menu or settings" | the only control was Settings → Privacy |
| "must not interpret navigation away … as consent" | no disclosure at all |

Plus two app-specific facts:

- **Advertising ID**: the manifest declares `AD_ID` and Play Console's answer is
  "Yes" (GA4 reads it for measurement), so AAID rules apply — consent required
  where the law requires it.
- **Law**: India **DPDP 2023 §6** and EU/UK **GDPR** (Recital 32; *Planet49*) both
  invalidate pre-ticked consent. Play separately requires compliance with
  applicable law.

So the default stays **OFF**; what was missing was the disclosure.

## 2. What was built

`lib/modules/analytics/analytics_consent.dart`

- `AnalyticsConsentDialog` — the disclosure. Wording follows Play's recommended
  format and names the facts a listener cannot guess: the event types, that
  events carry their **account ID**, that **GA4 may read the advertising ID**,
  that the data is **never sold**, and the way to withdraw (**Settings →
  Privacy**).
- `AnalyticsConsent` — `grant()`, `decline()`, `markDecided()`,
  `promptIfNeeded(context)`.

| Policy requirement | Implementation |
|---|---|
| shown in normal usage, not in a menu | asked from the **Home** screen, post-frame, once |
| affirmative action | "Allow analytics" / "Not now" only |
| navigation away is not consent | `barrierDismissible: false` + `PopScope(canPop: false)` |
| before any collection | PostHog starts only on consent (`initialize` returns early); GA4 starts with `setAnalyticsCollectionEnabled(false)` |
| are they asked again after declining? | no — `analyticsConsentDecided` records the answer |

`KVStoreService.analyticsConsentDecided` exists because "never asked" and "asked
and declined" must be different states: only the first shows the dialog.

`decline()` writes `false` explicitly, so a grant stored by an older build cannot
outlive a deliberate decline, and GA4 is told the same thing.

Answering the Settings toggle also marks the question answered, so a listener who
decides there is never shown the dialog.

## 3. What is still collected without consent

Crash reports (Firebase Crashlytics), which are a security/stability purpose and
are disclosed in Data safety — not product analytics. Everything PostHog/GA4 sends
waits for the dialog.

## 4. Verification

- `test/analytics_consent_prompt_test.dart` (9 tests) pins the policy invariants:
  asked from Home, only when undecided, not dismissible by outside tap or back, an
  explicit decline, the disclosure naming the account ID / advertising ID /
  no-sale / withdrawal path, and both actions reporting correctly.
- 38 tests pass across the consent, wiring, profile, sections and geometry suites;
  `flutter analyze` clean.
- On device: a fresh install (or the next launch of an install that has never
  answered) shows the dialog on Home; "Not now" leaves analytics off; "Allow
  analytics" starts collection immediately.

## 5. Before publishing

- Keep the Data safety answers consistent with the disclosure (usage analytics and
  diagnostics: collected only when the user consents — the Data safety form has no
  "only with consent" toggle, so the declaration stays "collected" and the privacy
  policy states the consent gate).
- Add one line to the privacy policy: analytics is off until the user allows it,
  and can be switched off in Settings → Privacy. The disclosure text already says
  this in-app.
