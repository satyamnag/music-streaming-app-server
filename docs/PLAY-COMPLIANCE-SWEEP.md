# Google Play compliance sweep — Soulful Bhakti Android

Date: 2026-11-13. Scope: the whole app, end to end. Every row states the policy
area, the state, and the evidence used to judge it. "Fixed" rows were changed in
this or a recent batch; the rest were verified as already compliant.

---

## 1. Store / technical requirements

| Area | Requirement | Status | Evidence |
|---|---|---|---|
| Target API level | Play requires a recent `targetSdk` | OK — **36** | `android/app/build.gradle` |
| 64-bit | Must ship 64-bit | OK — `arm64-v8a` + `armeabi-v7a` | release `ndk.abiFilters` |
| App Bundle | New apps ship AAB | OK — CI builds `.aab` (72.5 MB) | run `43369925294` |
| Edge-to-edge (Android 15) | Insets handled | **Fixed** — root `SafeArea` + guarded helper | `docs/ANDROID-EDGE-TO-EDGE.md` |
| Deprecated edge-to-edge APIs | Migrate off | **Fixed** — cutout `always`, helper only < API 35 | same |
| R8 / resource shrinking | Optimise the release build | **Fixed** — `minifyEnabled` + `shrinkResources` + keeps | `docs/ANDROID-PERFORMANCE-R8-AND-BITMAPS.md` |
| Bitmap downsampling | No full-size `BitmapFactory` | **Fixed** — two-pass `inSampleSize` in the widget | same |
| Splash theme | Correct display | **Fixed** — light splash in light mode, dark in dark | `docs/HOME-SHELVES-AND-ARRANGEMENT.md` |

## 2. User data & privacy

| Area | Requirement | Status | Evidence |
|---|---|---|---|
| Privacy policy | Reachable in-app + on the listing | OK — Settings → About → `soulfulbhakti.com/privacy` | `lib/pages/settings/about.dart:109` |
| Account deletion (in-app) | A pathway in normal usage | OK — Profile → **Delete account** (link, 48dp, confirmed) | `docs/ACCOUNT-DELETION-UI.md` |
| Account deletion (web) | A web resource declared in Play Console | OK — `soulfulbhakti.com/account-deletion` (web, mobile and email routes) | `app/(site)/account-deletion/page.tsx` |
| Prominent disclosure & consent | For personal data that is collected | OK by construction — product analytics is **opt-in, default OFF**, so nothing is collected before the user turns it on; the toggle's own subtitle is the disclosure at the point of consent | `posthog_service.dart:28`, `firebase_analytics_service.dart` |
| Analytics consent UX | — | First-run prompt **removed** on product decision: a popup on every fresh install hurt UX, and with collection OFF by default it is not required | revert `3b7ff83c` |
| Data safety accuracy | Declarations match behaviour | OK — AD_ID declared "Yes"; usage analytics + diagnostics declared; the consent gate does not change *what* can be collected | Play Console |
| Advertising ID | `AD_ID` permission only if used, and not for personalisation without consent | OK — used by GA4 for measurement only when analytics is enabled; no ads SDK; manifest comment documents the promise | `AndroidManifest.xml:15-29` |
| Backup | User data backup policy | OK — `allowBackup="false"` | manifest |

## 3. Payments

| Area | Requirement | Status | Evidence |
|---|---|---|---|
| In-app digital goods | Must use Google Play Billing | OK — Superwall → Play Billing is the only in-app rail | `docs/RAZORPAY-SUBSCRIPTIONS.md` §2 |
| External payment | No steering inside the Play app | OK — Razorpay exists only on the web; the Play build carries no link or wording pointing at it | same |

## 4. Permissions (every one, and why)

| Permission | Why | Play-sensitive? |
|---|---|---|
| `INTERNET` | catalogue, audio CDN, auth | no |
| `WAKE_LOCK` | keep playback alive | no |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | the media playback service, with `foregroundServiceType="mediaPlayback"` declared | OK — correct type declared |
| `POST_NOTIFICATIONS` | playback + release notifications | OK — requested at runtime |
| `VIBRATE` | notification feedback | no |
| `WRITE_SETTINGS` | set a downloaded bhajan as ringtone/notification/alarm (explicit user action in Settings) | special permission — used only for that, never silently |
| `AD_ID` | GA4 measurement when analytics is enabled | OK — see §2 |

No location, no contacts, no SMS/call log, no `QUERY_ALL_PACKAGES`, no background
location, no `MANAGE_EXTERNAL_STORAGE`.

**Permissions the libraries add to the merged manifest** (verified by dumping the
built AAB with bundletool, not guessed):

| Permission | Added by | Note |
|---|---|---|
| `com.android.vending.BILLING` | Play Billing / Superwall | required for the subscription |
| `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION` | Firebase/GA4 | measurement only; declared as such |
| `RECEIVE_BOOT_COMPLETED`, `com.google.android.c2dm.permission.RECEIVE` | OneSignal | push + restore after reboot |
| `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_NETWORK_STATE` | bonsoir (mDNS) | the LAN Connect discovery |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | flutter_secure_storage | optional device unlock |
| `BIND_GET_INSTALL_REFERRER_SERVICE` | Play Install Referrer | affiliate QR attribution |
| launcher bag of `*.permission.*BADGE*` / `UPDATE_COUNT` | the notification-badge plugin | launcher-specific badge writes |

None of these is a restricted permission that needs a Play declaration form, and
the merged `<application>` element carries `allowBackup="false"`,
`extractNativeLibs="false"`, no `debuggable` and no
`requestLegacyExternalStorage` — verified in the shipped bundle.

## 5. Changed in this sweep

1. **`requestLegacyExternalStorage` removed** — deprecated and ignored from API 30.
2. **Cleartext traffic documented and reviewed** — the flag stays because the
   loopback session server and the LAN "Connect" feature are plaintext by design;
   every remote endpoint (catalogue API, R2 CDN, Supabase, Clerk, Superwall,
   OneSignal) is HTTPS. Android's network-security-config cannot express "private
   subnets only", so a localhost-only policy would break Connect. The manifest now
   explains this at the flag.

## 6. Component export review

| Component | Exported | Why it must be |
|---|---|---|
| `MainActivity` | yes | launcher, deep links, share-to-app, widget tap |
| `AudioService` | yes | `MediaBrowserService` (notification/headset/car controls) |
| `MediaButtonReceiver` | yes | `MEDIA_BUTTON` |
| `HomePlayerWidgetReceiver` | yes | `APPWIDGET_UPDATE` from the launcher |
| `HomeWidgetBackgroundReceiver` / `…Service` | yes | the home_widget plugin's documented manifest |

Nothing else is exported.

## 7. Not covered here (developer-side, in Play Console)

Content rating questionnaire, the Data safety form itself, the store listing
(screenshots, descriptions), and the Play App Signing enrolment. Those are console
answers, not code.

## 8. Open item worth a decision

The **Data safety** form has no "only with consent" toggle. Analytics stays
declared as collected (it can be), while the app collects nothing until the user
opts in. That is accurate, but the privacy policy should state the opt-in
explicitly — one sentence in `/privacy` is the only outstanding documentation task.
