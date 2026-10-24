# PostHog analytics — integration notes

Product analytics for the Soulful Bhakti Android app, replacing Firebase
Analytics. PostHog was chosen over keeping Firebase Analytics because collection
can be gated on an explicit, revocable user decision — Firebase Analytics was
initialised unconditionally in `main.dart` with no consent path at all.

- SDK: [`posthog_flutter`](https://pub.dev/packages/posthog_flutter) `^5.56.2`
  (official docs: <https://posthog.com/docs/libraries/flutter>)
- Wrapper: `lib/services/analytics/posthog_service.dart`
- Consent UI: *Settings → Privacy → Share analytics*
- Consent storage: `analyticsConsent` in SharedPreferences
  (`lib/services/kv_store/kv_store.dart`)

## Two gates, both closed by default

Nothing is sent unless **both** are true:

| Gate | Where it comes from | Default |
| --- | --- | --- |
| Configured | `POSTHOG_API_KEY` in the build's `.env` | empty → SDK never set up |
| Consented | *Settings → Privacy* toggle, stored in SharedPreferences | OFF |

Before consent the SDK is **never set up** — not merely opted out. No anonymous
distinct id is created, no lifecycle event is queued, no request is made. That is
why `PostHogService.initialize` returns early rather than calling `setup()` with
`config.optOut = true`: "never started" is a stronger and more provable promise
than "installed but idle".

## Activating it

1. **Create the PostHog project** and copy its project token (`phc_…`). It is a
   public client-side ingest token, the same one that ships inside every copy of
   the app — it is not a secret in the sense an API key is, but it is still not
   committed to the repo.
2. **Local builds:** add to `.env` (untracked):

   ```
   POSTHOG_API_KEY=phc_xxxxxxxxxxxxxxxx
   POSTHOG_HOST=https://us.i.posthog.com
   ```

   `POSTHOG_HOST` may be omitted; it defaults to the US host. Use
   `https://eu.i.posthog.com` for a project in the EU region.
3. **Release builds:** the release workflow builds `.env` from AWS Secrets
   Manager (`ap-south-1`), so create the secrets `posthog/api-key` and — for an
   EU project — `posthog/host`. Until they exist the release job prints a
   warning and ships with analytics inert; it does not fail.
4. Once the secrets are provisioned, add `POSTHOG_API_KEY` to the required-keys
   check in `.github/workflows/android-release.yml` so a missing token fails the
   build instead of shipping silently.

## Deliberately NOT enabled

Every one of these is an SDK default that this app turns **off**, with the reason
recorded next to it in `_ensureSetup`:

| Setting | SDK default | Here | Why |
| --- | --- | --- | --- |
| `sessionReplay` | `false` | `false` | Replay records the screen. It needs its own explicit consent, not a ride-along on the analytics toggle. |
| `surveys` | `true` | `false` | Surveys cannot render without `PosthogObserver`, which is not installed. |
| `preloadFeatureFlags` | `true` | `false` | No feature flags are evaluated, so the startup `/flags` request would be collection with no reader. |
| `capturePushNotificationSubscriptions` | `true` | `false` | Push goes through OneSignal. Registering an FCM token with PostHog too would send a second device identifier to a second vendor. |
| `capturePushNotificationOpened` | `true` | `false` | Notification-opened attribution belongs to OneSignal here. The iOS cold-start prewarm is opted out separately with `com.posthog.posthog.CAPTURE_PUSH_NOTIFICATION_OPENED` in `Info.plist`, because that path runs before Dart and cannot see the consent flag. |
| `enableWindowsAndLinux` | `true` | `false` | Mobile-only, matching the previous Firebase scope. Desktop capture is experimental in the SDK. |
| `rageClickConfig.enabled` | `true` | `false` | Autocaptured rage clicks are not wanted. |
| error tracking | all `false` | all `false` | Crashlytics owns crash reporting. Enabling both would double-report every crash to two vendors. |

Session replay, surveys, logs and error tracking are therefore available for a
future change but are not part of this one.

## What is captured, and what is not

Captured, once the user opts in:

- Application lifecycle events (opened, backgrounded, installed, updated) —
  native, automatic.
- `$identify` / `$set` when a user signs in, carrying the **Clerk user id only**.
- Anything the app explicitly sends through `PostHogService.capture` /
  `.screen` / `.captureException`. **No feature-level events are instrumented
  yet** — that is product work, and each event should be reviewed for PII before
  it is added.

Not captured: email, name, username, phone, address, search text, playback
history, the audio itself.

### PII redaction and its limit

`PostHogService.redact` runs as a `beforeSend` callback and strips identifying
property keys (exact keys such as `email`, `phone`, `password`, `aadhaar`,
`gstin`, plus the fragments `email`, `phone`, `password`, `secret`, `aadhaar`,
`gstin` anywhere in a key). `name` is matched as a **whole key only**, so
`screen_name`, `track_name`, `artist_name` and `playlist_name` survive.

The SDK documents, and this wrapper cannot work around, the fact that
`beforeSend` **only sees events captured from Dart** (`capture`, `screen`,
`captureException`). Native events — lifecycle, the `$set` from `identify`,
feature flags, replay, surveys — never pass through it. Redaction is the second
line of defence; the first is not passing PII in the first place, which is why
`identify()` sends a user id and nothing else.

## Verifying

```bash
fvm flutter test test/services/posthog_service_test.dart
```

The suite fakes `PosthogFlutterPlatformInterface`, so it proves the exact calls
the SDK would receive — setup, opt-in/out, identify, capture — without a device,
a token or a network. It covers: no collection before consent, the overridden
SDK defaults, identity hygiene (no person properties), redaction, and that a
throwing SDK never propagates into the app.

On a device, with a token configured: open *Settings → Privacy*, turn the toggle
on, and watch for `Application Opened` in PostHog's activity view. Turn it off
and confirm events stop.

### Verifying the live pipeline in CI (no device needed)

Collection is opt-in, so a fresh install sends nothing and PostHog's "Verify
installation" stays waiting until somebody opts in on a real device.
`PostHogService.verifyOptInIfRequested()` closes that gap for CI by granting
consent itself. It is reachable only when **both** of these hold:

1. the binary was compiled with `--dart-define=POSTHOG_VERIFY_OPTIN=true`, and
2. the binary is a **debug** build.

A compile-time constant cannot be switched on at runtime by remote config, by a
stored preference, or by a tampered device; the debug gate means a release binary
refuses even if the define were added to a release pipeline by mistake. In every
shipping build the call returns `false` and changes nothing. It grants consent
through the same `setConsent()` the Settings toggle uses, so what it persists and
what it applies are identical to a user tapping the switch.

Dispatch the emulator workflow with the project token and the flag:

```bash
gh workflow run "Android Emulator Debug (logcat)" \
  -R satyamnag/music-streaming-app-server \
  -f posthog_api_key=phc_REPLACE_ME \
  -f posthog_host=https://us.i.posthog.com \
  -f verify_analytics_optin=true
```

Expected in PostHog within a couple of minutes: `Application Opened` (captured
natively the moment the SDK is set up) plus `analytics_verification_optin`, which
`lib/main.dart` emits purely so the verification run is identifiable in the event
list.

The token is a public client-side ingest token — the same string ships inside
every APK — so passing it as a dispatch input reveals nothing that is not already
in the artifact. It is never committed, and the workflow prints `.env` key names
only, never values.

> A release build (`--release`) is not a valid way to run this: the debug gate
> refuses, by design. To see events from a release build, add the token to the
> build environment and opt in on the device.

## Compliance follow-ups (outside this repo)

Adding any analytics vendor changes what the app collects, so these must match:

1. **Play Console → Data safety**: declare *App activity → Other actions*
   (analytics) and *Device or other IDs*, marked as **optional** and
   **user-controlled** (collection only after opt-in), with data encrypted in
   transit.
2. **Hosted privacy policy**: must name PostHog as a processor, describe the
   opt-in, and link to <https://posthog.com/privacy>. `PRIVACY_POLICY.md` in this
   repo was updated to describe the behaviour, but the version users see is the
   one hosted at the URL in the Play listing.
3. **DPDP Act 2023 (India)**: opt-in consent with an easy withdrawal path is the
   model implemented here. Confirm the notice wording and the retention position
   with counsel; PostHog's retention is configured per project in PostHog, not in
   this repo.

## Rolling back

Everything is contained in one service plus four call sites. To remove PostHog:
delete `lib/services/analytics/posthog_service.dart`, the `posthog_flutter`
dependency, the `POSTHOG_*` fields in `lib/collections/env.dart`, the
`SettingsPrivacySection` (and its l10n keys), the `PostHogService` calls in
`lib/main.dart` and `lib/provider/auth/clerk_auth_provider.dart`, the PostHog
`<meta-data>` in `AndroidManifest.xml`, and the two `com.posthog.posthog.*` keys
in `ios/Runner/Info.plist`. No database migration or stored-data change is
involved: consent is a single boolean in SharedPreferences.

## A note on the PostHog wizard

`npx @posthog/wizard@latest` was evaluated first. The wizard supports Flutter
(`src/services/frameworks/flutter/` in the wizard repo), but published builds
only expose its interactive TUI — `--ci` is rejected outside development builds,
and the headless path needs a personal API key (`phx_…`) plus a gateway token and
a browser OAuth login. It cannot be driven non-interactively, and it sends source
files to Anthropic/OpenAI through PostHog's gateway, so this integration was
written directly against the official docs and the SDK source instead.

Once a project token exists, `npx @posthog/wizard@latest audit` can be run in a
real terminal as an independent review of this setup.
