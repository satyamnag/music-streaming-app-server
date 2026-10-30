# Play Console — Data safety answer sheet

Written against the Android app tree at commit `760a437c` (branch
`fix/drop-leftover-firebase-analytics`), on 2026-10-25; **updated 2026-10-30** when
the owner decided to DECLARE the advertising ID instead of avoiding it (see
section A.1).
Play Console path: **Policy and program → App content → Data safety**.

Every row below is answered from the shipped code, and each one names the evidence. Where an answer
could not be settled from an official source, it is listed in *Open items* instead of being guessed.

## Read this first — two rules that decide most of the answers

Straight from Google's own Data safety documentation:

- **"Collect" means transmitting data from your app off a user's device**, and it
  **"includes user data transmitted off device from your app by libraries and/or SDKs used in your
  app, irrespective of whether data is transmitted to you or a third-party server."**
  So every third-party SDK below (Clerk, Supabase, Crashlytics, PostHog, OneSignal, Superwall)
  collects *on our behalf*, and pseudonymous data **"must be disclosed."**
  <https://support.google.com/googleplay/android-developer/answer/10787469>
- **"Shared" does not include a service provider.** Transferring data to a provider that processes
  it on our instructions is *collected, not shared*; it becomes *shared* only when the SDK builds
  advertising profiles across its customers, which none of ours does. Same source.

Consequence: nothing in this app is declared as **shared**. The form still asks about sharing, so
the answer to "Is this data shared?" is **No** for every row.

## A. Data types to declare

| # | Console category | Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What produces it |
| - | ---------------- | --------- | --------- | ------ | --------- | -------------------- | -------- | ---------------- |
| 1 | Personal info | **Name** | Yes | No | No | Optional | App functionality; Account management | Clerk sign-in; Superwall `setUserAttributes({name})` |
| 2 | Personal info | **Email address** | Yes | No | No | Optional | App functionality; Account management | Clerk sign-in; OneSignal `addEmail`; Superwall `setUserAttributes({email})` |
| 3 | Personal info | **User IDs** | Yes | No | No | Optional | App functionality; Account management; Analytics | Clerk user id; PostHog `identify` (only when opted in); OneSignal `login`; Superwall `identify`; Supabase `bind_affiliate_referral` |
| 4 | Financial info | **Purchase history** | Yes | No | No | Optional | App functionality | Google Play Billing + Superwall entitlement state |
| 5 | App activity | **App interactions** | Yes | No | No | Optional | Analytics | PostHog app-lifecycle and screen events, only while the opt-in is on; the anonymous play counter |
| 6 | App info and performance | **Crash logs** | Yes | No | No | Required | App functionality | Firebase Crashlytics |
| 7 | App info and performance | **Diagnostics** | Yes | No | No | Required | App functionality | Firebase Crashlytics (device metadata, app state) |
| 8a | Device or other IDs | **Device or other IDs** | Yes | No | No | Required | App functionality; Analytics | Crashlytics installation id (Firebase installations SDK, no opt-out); PostHog distinct id (opt-in); OneSignal subscription id (push permission); Play Install Referrer code |
| 8b | Device or other IDs | **Advertising ID** | Yes | No | No | Optional (the Settings → Privacy switch turns it off) | Analytics; Measurement/attribution | Google Analytics for Firebase, only while analytics is on — see A.1 |

Evidence, file by file:

| Row | Evidence |
| --- | -------- |
| 1, 2, 3 | `lib/provider/auth/clerk_auth_provider.dart:145-161` — `sw.identify(userId)`, `sw.setUserAttributes({email, username, name})`, `os.login(userId)`, `os.setEmail(email)`. PostHog deliberately receives the user id only (`identify()` doc comment, `lib/services/analytics/posthog_service.dart:217-222`). |
| 4 | Subscriptions go through Google Play Billing with Superwall as the paywall layer; no card field exists anywhere in the app. |
| 5 | `lib/services/analytics/posthog_service.dart` — the config block at lines 36-62 lists what is captured and what is deliberately switched off (session replay, surveys, rage clicks, feature-flag preloading, push attribution). Play counts: `sb.rpc('record_play', params: {'track_id': trackId})` at `lib/provider/server/routes/supabase_data.dart:297` sends a track id and nothing else. |
| 6, 7 | `lib/main.dart:105-122` — `recordFlutterFatalError` / `recordError(fatal: true)`. Crashlytics has **no** user id attached: there is no `setUserIdentifier` call in the repo. |
| 8 | Crashlytics depends on the Firebase installations SDK (Firebase's own data-disclosure guide says to "account for the end-user data collected automatically by that SDK"); PostHog distinct id; OneSignal subscription id; `lib/services/install_referrer/referrer_service.dart:87-94` posts the referrer code with `user_id`. |

**Optional vs required.** Sign-in is optional, so rows 1-5 are optional. Rows 6-8 are **required**:
crash reporting and the identifiers it carries are collected with no in-app opt-out. Google's rule is
that a type may be declared optional only if **all** users can opt out, so a partially opt-in data
type is still declared *required*.

### A.1 The advertising ID: now DECLARED (Console answer: Yes)

**Status change, 2026-10-30.** The app used to avoid the identifier: the leftover
`firebase-analytics` Gradle dependency was removed, the `AD_ID` permission fell
out of the merged manifest, and this sheet said "do not declare it".

The owner has chosen to declare it instead, so that the Console declaration is
answered **Yes** and the release is not blocked on it. That means the app now has
to carry a component that genuinely uses the identifier, and it does:

| what | where | why |
| --- | --- | --- |
| `com.google.firebase:firebase-analytics` | `android/app/build.gradle` | Google's Android docs state GA4 collects the Advertising ID by default — they document `google_analytics_adid_collection_enabled=false` to switch that off, which only makes sense because it is on |
| `com.google.android.gms.permission.AD_ID` (explicit) | `android/app/src/main/AndroidManifest.xml` | Play blocks a release whose declaration says Yes while the artifact lacks the permission, so it must not be possible for a dependency change to remove it silently |
| `firebase_analytics_collection_enabled=false` | same manifest | Google's documented "get end-user consent before collecting data" switch. Collection stays off until the listener turns analytics on |
| `google_analytics_default_allow_ad_personalization_signals=false` | same manifest | the identifier is used for measurement only — never personalized advertising, which is what the privacy policy and the Play Ads policy promise |
| `FirebaseAnalyticsService.applyConsent` | `lib/services/analytics/firebase_analytics_service.dart`, called from `main.dart` and the Settings → Privacy toggle | applies that switch to GA4 (`setAnalyticsCollectionEnabled`) |

Sources, both official and both read before the change:
<https://firebase.google.com/docs/analytics/android/configure-data-collection> ·
<https://developer.android.com/about/versions/13/behavior-changes-13>

**What the declaration obliges, and how each obligation is met.** The Play Ads
policy requires the identifier to be used *only* for "advertising and user
analytics", forbids connecting it to personally-identifiable information or
associating it with a persistent identifier for analytics, and requires its
collection to be disclosed in a legally adequate privacy notification
(<https://support.google.com/googleplay/android-developer/answer/9857753>):

| Obligation | How this app meets it |
| --- | --- |
| Only advertising/user-analytics use | GA4 measurement and attribution only; `google_analytics_default_allow_ad_personalization_signals=false` keeps it out of personalized advertising; the app serves no ads |
| Not connected to PII | no `setUserId`, no email/name on any GA4 call; the app passes nothing to GA4 beyond the SDK's own automatic events |
| Not associated with a persistent identifier *for analytics* | the analytics identifiers that do exist (PostHog distinct id, Crashlytics installation id) belong to separate vendors and are not linked to the advertising ID |
| Disclosed to users | `PRIVACY_POLICY.md` — summary bullet, the analytics section's "Advertising identifier" paragraph, the processor table — and the Settings → Privacy subtitle now names GA4 and the identifier |
| Consent | collection is off by default (manifest flag) and on only after the opt-in switch; turning it off stops GA4 collection immediately |

**Runtime evidence (Realme RMX2027, Android 11, release APK).** GA4's own log
confirms the manifest switch reaches the SDK:

```text
I FA : App measurement disabled via the manifest
I FA : App measurement initialized, version: 192007
```

That line is the SDK reporting `firebase_analytics_collection_enabled=false` — the
app is running, GA4 is present, and no measurement happens until the listener
opts in.
**Tripwires.** `test/analytics_consent_wiring_test.dart` drives the REAL Settings
switch and asserts GA4 receives `setAnalyticsCollectionEnabled(true)` on opt-in and
`false` on opt-out (through the seam in `FirebaseAnalyticsService`), and
`test/play_advertising_id_test.dart` asserts the permission, the
two manifest flags, the Gradle/pubspec artifacts, both consent call sites and the
policy disclosure — and it fails if anyone re-adds
`google_analytics_adid_collection_enabled=false` (which would make the Console's
"Yes" untrue). The release workflow's permission audit now treats a MISSING
`AD_ID` as an error rather than a pass.

**Historical evidence, kept for context.** Before the removal, the merged
manifest carried the permission and the blame report named the source:

```text
com.google.android.gms.permission.AD_ID          <- com.google.android.gms:play-services-measurement(-api):23.2.0
android.permission.ACCESS_ADSERVICES_ATTRIBUTION <- com.google.android.gms:play-services-measurement-api:23.2.0
android.permission.ACCESS_ADSERVICES_AD_ID       <- com.google.android.gms:play-services-measurement-api:23.2.0
```

Run <https://github.com/satyamnag/music-streaming-app-server/actions/runs/40189466351>
carried all three; run
<https://github.com/satyamnag/music-streaming-app-server/actions/runs/40193002183>
carried none after the removal. Both `ACCESS_ADSERVICES_*` permissions come back
with GA4 and need no separate declaration: Play has no Privacy Sandbox
declaration, only the Advertising ID one (see section E).

**Console answers that go with this** (App content → Advertising ID):

- "Does your app use advertising ID?" → **Yes**
- "Is the advertising ID used for advertising?" → **No** (analytics/measurement
  only; this is what the manifest flag enforces)
- Advertise/promote your app with the identifier, or use it to build user
  profiles → **No**

And in Data safety, row 8 changes: `Device or other IDs` now includes the
**advertising ID**, is still **collected**, still **not shared**, and its purpose
gains **Analytics** alongside App functionality; it becomes **optional**, because
every listener can switch analytics off and with it the identifier.
## B. Data types deliberately NOT declared

| Not declared | Why |
| ------------ | --- |
| Location (approximate, precise) | No location permission and no location API anywhere. |
| Financial info → User payment info | Google Play Billing holds the card data; the app never sees it. |
| Health and fitness, Messages, Photos and videos, Audio files, Files and docs, Calendar, Contacts | No such permission, and no code path that reads or transmits them. |
| Web browsing history | Nothing is collected. |
| App activity → In-app search history | Search runs against our own catalog on the device; queries are not transmitted. |
| App activity → Installed apps | The app checks whether the optional external YouTube engine is installed (`lib/hooks/configurators/use_check_yt_dlp_installed.dart`), but that result stays on the device and is never sent anywhere. |
| App activity → Other user-generated content | Playlists, likes and history live in the on-device database; they are never uploaded. |
| Device or other IDs → Advertising ID | **Now declared** — see A.1. It was previously absent from the manifest and therefore not declared. |

## C. Security practices

| Question | Answer | Basis |
| -------- | ------ | ----- |
| Is all user data encrypted in transit? | **Yes** | Every off-device endpoint the app talks to is HTTPS: Supabase, Clerk, PostHog, OneSignal, Superwall, Crashlytics, and the Cloudflare R2 audio streams. |
| Do you provide a way to request data deletion? | **Yes** | In-app: Profile → "Delete account" (`lib/modules/auth/profile_dialog.dart:75-101` → `ClerkAuthProvider.deleteAccount`). Web: <https://www.soulfulbhakti.com/account-deletion>. |
| Committed to the Play Families policy? | No — leave unticked | The Service is not directed at children under 13. |
| Independent security review? | No — not performed | Optional paid review. |

Two notes on the encryption answer, because it is all-or-nothing and covers every SDK:

- `android:usesCleartextTraffic="true"` is set app-wide
  (`android/app/src/main/AndroidManifest.xml:30`). The app runs its own playback proxy on
  `127.0.0.1` and streams from `http://127.0.0.1:<port>/stream/...`, which Android 9+ would
  otherwise block. That traffic never leaves the device, and the LAN path used when driving another
  of the user's own devices carries playback commands only — no user data is transmitted to us over
  cleartext. Worth tightening to a network security config that allows cleartext for loopback only;
  that is a hardening task, not a Data safety answer change.
- The web app is **not** covered by this sheet. If the Data safety form covers the web app too, its
  analytics need their own answers.

## D. Open items before submitting

1. ~~Ship the advertising-ID fix before answering the form.~~ **Superseded on 2026-10-30:** the app
   now DECLARES the identifier (A.1) rather than removing it, so the Console answer is **Yes** and the
   hosted policy must disclose GA4 and the advertising identifier again — the opposite of what web PR
   #1 did. Update the hosted policy before publishing this build.
2. **Deletion must reach the processors.** Google requires that when an account is deleted you
   "delete the user data associated with that app account" and, where service providers process it,
   "request the service provider to do the same." The app currently resets local identity
   (`sw.reset()`, `os.logout()`, `ph.reset()`) on account deletion, which detaches the device but
   does not by itself purge events already held by PostHog, nor the OneSignal user record. Decide the
   retention position for those two before submitting, and mirror it on the deletion page.
3. **Legal review** of the matching privacy-policy wording (web PR #1).
4. **Copy the answers into the Console** — this file is the source, the Console is the submission.
   The Console holds no export of what was submitted, so re-derive it from here if it ever needs to
   change.

## E. What could not be confirmed from official sources

- Google publishes no page describing a separate Play Console **"Advertising ID" declaration**
  question, its answer options, or the enforcement for getting it wrong. What *is* official is the
  mapping above: `AD_ID` in the manifest ⇄ `Device or other IDs` in Data safety.
- There is **no Play Console declaration for Privacy Sandbox / Ads Services** usage at all; only
  "Contains ads" exists, and that is a content declaration, not a privacy one.
- There is **no "linked to the user" question** in Play's form; that is Apple/App Store wording. The
  nearest official concepts are the pseudonymous-data rule (must be disclosed) and the anonymous-data
  exception.
- No vendor (Clerk, Supabase, PostHog, OneSignal, Superwall) publishes a Play data-type mapping, and
  OneSignal, Superwall and PostHog never mention the advertising ID in their documentation in either
  direction. Only Google's own SDKs publish mappings — which is why Crashlytics' rows lean on
  Firebase's disclosure guide
  (<https://firebase.google.com/docs/android/play-data-disclosure>) and the rest lean on what the
  code actually sends.

## Sources

- Data safety data types, definitions, and the collect/share/ephemeral rules —
  <https://support.google.com/googleplay/android-developer/answer/10787469>
- Data deletion requirements —
  <https://support.google.com/googleplay/android-developer/answer/13327111>
- Declaring data use, incl. the `AD_ID` trigger —
  <https://developer.android.com/privacy-and-security/declare-data-use>
- Advertising ID permission, transitive merge, and the Android 13 change —
  <https://developer.android.com/about/versions/13/behavior-changes-13>
- Ads policy, advertising identifier obligations —
  <https://support.google.com/googleplay/android-developer/answer/9857753>
- Analytics for Firebase and the advertising ID —
  <https://support.google.com/analytics/answer/11582702>
- Firebase SDK data disclosure (Crashlytics, Firebase installations SDK) —
  <https://firebase.google.com/docs/android/play-data-disclosure>
