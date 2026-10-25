# Play Console — Data safety answer sheet

Written against the Android app tree at commit `760a437c` (branch
`fix/drop-leftover-firebase-analytics`), on 2026-10-25.
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
| 8 | Device or other IDs | **Device or other IDs** — *not* the advertising ID | Yes | No | No | Required | App functionality; Analytics | Crashlytics installation id (Firebase installations SDK, no opt-out); PostHog distinct id (opt-in); OneSignal subscription id (push permission); Play Install Referrer code |

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

### The advertising ID: was collected, cause found, fix verified

Nothing in this repo declared the permission, which is why it was read off the built APK instead of
inferred from the dependency list. The APK did carry it — run
<https://github.com/satyamnag/music-streaming-app-server/actions/runs/40189466351>:

```text
uses-permission: name='android.permission.ACCESS_ADSERVICES_AD_ID'
uses-permission: name='android.permission.ACCESS_ADSERVICES_ATTRIBUTION'
uses-permission: name='com.google.android.gms.permission.AD_ID'
```

The manifest merger's blame report named the source: **Google Analytics for Firebase, still present
as a raw Gradle dependency** after the Dart plugin had already been replaced by PostHog.

```text
com.google.android.gms.permission.AD_ID          <- com.google.android.gms:play-services-measurement(-api):23.2.0
android.permission.ACCESS_ADSERVICES_ATTRIBUTION <- com.google.android.gms:play-services-measurement-api:23.2.0
android.permission.ACCESS_ADSERVICES_AD_ID       <- com.google.android.gms:play-services-measurement-api:23.2.0
```

Those modules enter only through `implementation 'com.google.firebase:firebase-analytics'` in
`android/app/build.gradle`: no other resolved Google POM declares `play-services-measurement`, and
`gradlew :app:dependencyInsight` shows the app module's own declaration as the only path. The line
was wrong twice over — it kept a second analytics vendor running next to PostHog, and it was the only
reason the app could read the advertising ID.

Branch `fix/drop-leftover-firebase-analytics` removes it, and the removal is verified rather than
assumed. Crashlytics is unaffected: `firebase-crashlytics`' own POM depends on `firebase-sessions`,
`firebase-installations` and `firebase-measurement-connector`, none of which pull
`play-services-measurement`.

| | Build carrying the leftover dependency | After the fix |
| --- | --- | --- |
| `aapt2 dump permissions` | AD_ID and both `ACCESS_ADSERVICES_*` present | all three **gone** |
| Audit verdict | `AD_ID is present …` (warning) | `AD_ID is absent: no Advertising ID declaration is required for this build.` |
| Run | [40189466351](https://github.com/satyamnag/music-streaming-app-server/actions/runs/40189466351) | [40193002183](https://github.com/satyamnag/music-streaming-app-server/actions/runs/40193002183) |

Per Android's own behaviour-change note, an app without the permission receives a string of zeroes
instead of the advertising ID
(<https://developer.android.com/about/versions/13/behavior-changes-13>).

**So: do not declare the advertising ID, provided the build you ship contains this fix.** For any
build cut from `main` before it merges, the opposite holds — declare it under `Device or other IDs`,
because Google's declaration guide lists the `AD_ID` permission as a trigger for that type, and
Google documents that Analytics for Firebase collects the advertising ID by default
(<https://developer.android.com/privacy-and-security/declare-data-use> ·
<https://support.google.com/analytics/answer/11582702>). That state also drags in the Play Ads
policy, which requires the identifier to be **"only … used for advertising and user analytics"**,
forbids connecting it to **"personally-identifiable information"** or associating it with a
persistent identifier for analytics, and requires its collection and use to be
**"disclosed to users in a legally adequate privacy notification"**
(<https://support.google.com/googleplay/android-developer/answer/9857753>). Removing the dependency
satisfies all of that by not collecting the identifier at all.

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
| Device or other IDs → Advertising ID | Verified absent from the shipped manifest once the leftover Analytics dependency is removed — see section A. |

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

1. **Ship the advertising-ID fix before answering the form.** It is resolved on branch
   `fix/drop-leftover-firebase-analytics` and verified by run 40193002183. Until it merges, any build
   cut from `main` still collects the advertising ID and must be declared. The hosted-policy PR
   (<https://github.com/satyamnag/music-streaming-web/pull/1>) drops the Firebase Analytics
   disclosure on that same assumption, so it must not be deployed ahead of this fix — if the fix is
   abandoned, that PR has to restore the disclosure instead.
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
