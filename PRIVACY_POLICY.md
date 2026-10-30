**Privacy Policy — Soulful Bhakti**

This policy describes what the Soulful Bhakti Android app and its supporting
services collect, why, and how you can control it. It replaces the earlier
policy inherited from the upstream open-source project this app is built on,
which described different software and different data practices.

*Last updated: 2026-10-30*

---

**Summary**

- Product analytics is **opt-in and off by default**. Nothing is collected for
  analytics until you turn it on in *Settings → Privacy → Share analytics*, and
  you can turn it off again at any time.
- We do not sell your data and we do not use it for advertising. Like almost
  every Android app, the app can read your device's **advertising identifier**,
  but only while you have analytics switched on and only for measurement and
  diagnostics — never to target ads at you and never for personalized
  advertising. See *Advertising identifier* below.
- Signing in is optional for free listening. If you never sign in, we do not
  have your name or email address at all.
- This summary is a convenience only; the rest of this policy is what applies.

---

**Information we collect**

**1. Account information (only if you sign in).** Sign-in uses Google via Clerk.
We receive a user identifier, and the email address and display name associated
with the Google account you choose. We use this to keep your playlists, likes
and listening history attached to you across devices, and to identify your
subscription. Signing in is optional unless you buy a plan.

**2. Product analytics (opt-in only).** If — and only if — you enable
*Settings → Privacy → Share analytics*, the app sends usage data to two
analytics providers:

- **PostHog** (PostHog, Inc.), through PostHog's EU or US ingestion endpoint;
- **Google Analytics for Firebase** (Google LLC), through Firebase/Google
  Analytics.

This includes: which screens you open, app lifecycle events (app opened,
backgrounded, installed, updated), app version, device model and operating
system, and errors the app handles itself. If you are signed in, these events are
linked to your account identifier so we can tell a real usage pattern from a
broken one. We do not send your email address, name, phone number, search text,
or the audio you listen to. Enabling this is your choice, and turning it off stops
collection immediately for both providers and clears the analytics identifier
stored on your device.

**Advertising identifier.** While analytics is on, Google Analytics for Firebase
reads your device's advertising identifier (the Android Advertising ID) and uses
it for measurement and diagnostics only — for example, to count installs and to
attribute them to a partner's QR code. We do **not** use it to target advertising
at you, we do **not** use it for personalized advertising (the app turns
personalized-ads signals off), we do **not** connect it to your name or email
address, and we do **not** sell it. It is read only while analytics is on: turn
that switch off and the app stops reading it. The app itself serves no ads and
contains no advertising SDK.

**3. Crash and diagnostic reports.** Crash reports are sent to **Google Firebase
Crashlytics** so we can find and fix crashes. They contain a stack trace, the app
version, and device/OS information. They do not contain your listening history or
your account email.

**4. Push notifications.** If you allow notifications, **OneSignal** stores a
device push token so notifications can be delivered. If you are signed in, the
token is associated with your account identifier. You can decline the permission
or turn notifications off in Android settings at any time.

**5. Purchases and subscriptions.** If you buy a plan, **Superwall** and Google
Play process the purchase and report your subscription status to the app. Payment
details are handled by Google Play; we never receive your card details.

**6. Referral attribution.** If you installed the app by scanning a partner's QR
code, the referral code from the Play Install Referrer is stored on your device
and, once you sign in, associated with your account so the partner can be
credited.

**7. Partner and creator applications.** If you apply to the partner programme,
the information you submit (including identity and payment details required by
law) is used to review the application, meet tax and payment obligations, and pay
commissions.

**Information we do not collect**

- We do not collect or store the audio you listen to.
- We do not collect your contacts, photos, calendar, or SMS.
- We do not use the advertising identifier to target ads at you, we do not use it
  for personalized advertising, and the app contains no advertising SDK. It is
  read only for measurement, and only while analytics is on (see above).
- We do not sell personal data to anyone.

**Permissions the app asks for, and why**

| Permission | Why |
| --- | --- |
| Internet, network state | Streaming audio; optional sign-in and sync |
| Notifications | Optional push notifications |
| Foreground service / media playback | Continue playing with the screen off |
| Vibrate | Playback and notification feedback |
| Modify system settings | Only when you choose "Set as ringtone"; a special permission you grant in Android settings |
| Storage / media access | Save tracks for offline playback, when you ask for it |

**Legal basis and your consent**

Where India's Digital Personal Data Protection Act, 2023 applies, we process
personal data on the basis of your consent, which you give by using the relevant
feature and which you may withdraw at any time — for analytics, with the switch
in *Settings → Privacy*; for notifications, in Android settings; for your account
and its data, by deleting your account in the app. Withdrawing consent stops
future processing; it does not affect processing already carried out.

**Who processes data on our behalf**

| Provider | Purpose | Their policy |
| --- | --- | --- |
| PostHog, Inc. | Product analytics (opt-in) | https://posthog.com/privacy |
| Google (Analytics for Firebase) | Product analytics and measurement, including the advertising identifier, only while analytics is on (opt-in) | https://firebase.google.com/support/privacy Â· https://policies.google.com/privacy |
| Google (Firebase Crashlytics) | Crash reporting | https://firebase.google.com/support/privacy |
| Google Play Services | Distribution, purchases, install referrer | https://policies.google.com/privacy |
| Clerk | Sign-in and account identity | https://clerk.com/legal/privacy |
| OneSignal | Push notification delivery | https://onesignal.com/privacy_policy |
| Superwall | Subscription/paywall management | https://superwall.com/privacy |
| Supabase / Cloudflare R2 | Backend database and audio delivery | https://supabase.com/privacy · https://www.cloudflare.com/privacypolicy/ |

These providers process data only to provide their service to us. Some are
located outside India; using the app involves transferring the data described
above to those locations.

**Retention**

Analytics events are retained in PostHog according to the retention period
configured for the project, and in Google Analytics according to the retention
configured for the Firebase project. Crash reports are retained by Firebase
Crashlytics according to its retention settings. Account data (playlists, likes, history) is
retained while your account exists and is deleted when you delete your account in
the app.

**Your choices and rights**

- **Analytics:** *Settings → Privacy → Share analytics* — off until you enable it,
  and effective immediately when you turn it off.
- **Notifications:** Android system settings, or by declining the permission.
- **Account and data deletion:** available in the app (profile → delete account).
  This deletes your account and your local data, and clears the third-party
  identities associated with it.
- **Access, correction or questions:** contact us using the address below.

**Security**

Data is encrypted in transit (HTTPS). We apply least-privilege access to backend
systems and keep secrets in a managed secret store. No method of transmission or
storage is perfectly secure, and we cannot promise absolute security.

**Children**

The app is not directed to children under 13, and we do not knowingly collect
personal data from them. If you believe a child has provided us with personal
data, contact us and we will delete it.

**Changes to this policy**

We will post any change on this page and update the date above. Material changes
will also be noted in the app's release notes.

**Contact**

Questions about this policy or your data: **krtirtho@gmail.com**
