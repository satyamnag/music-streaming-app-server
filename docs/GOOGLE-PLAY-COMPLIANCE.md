# Google Play compliance rule + full-app audit

Status: audit performed 2026-11-08 against the repository at commit `00267c51`
Scope: the whole Android app (`Soulful Bhakti Android App & Admin`), not just payments
Verdict: **NOT 100% safe yet.** Payments are clean. P1 is now *partly* remediated
(the extractor initialisation and every piracy string are gone); the three YouTube
libraries are still declared, so the AAB still carries extraction code (§3 P1 status).

---

## 0. The rule (binding for every future change)

**Nothing in the Soulful Bhakti Android app may be implemented, kept, or shipped in
a way that violates Google Play policy, Google's published recommendations, or
Google's technical documentation.**

This applies to every change — features, copy, permissions, dependencies, SDKs,
backend behaviour that the app relies on, and release configuration. Concretely:

1. **Payments.** No digital good or service sold inside the Play-distributed app may
   use anything but Google Play Billing, unless the app is enrolled in an eligible
   Google programme (e.g. the India alternative-billing programme). No link, button,
   QR, copy, or nudge inside the app may lead a user to an external payment method.
   Selling outside the app and honouring that purchase is allowed; steering inside the
   app is not.
2. **Permissions.** No permission is added without a user-visible feature that needs
   it, a Play Console declaration where required, and a matching Data safety answer.
   Special permissions (`WRITE_SETTINGS`, all-files access, package visibility) are
   avoided unless the product genuinely depends on them.
3. **Data.** Every SDK that collects or transmits data appears in the privacy policy
   and the Data safety form, collection is consent-gated where required, and account
   deletion is available in-app and linked in Play Console.
4. **Intellectual property.** No feature, dependency, or string may facilitate access
   to content the app is not licensed to distribute, or circumvent a third party's
   terms (YouTube included).
5. **Documentation-first.** Before any platform-adjacent change, the relevant Google
   policy page and its technical documentation are read and cited in the PR/commit —
   never implemented from memory.
6. **Verification.** A change is not "done" until the behaviour has been observed on a
   Play-installed build, not just a sideloaded APK or an emulator.

If a request conflicts with this rule, the conflict is raised before implementation
rather than resolved silently in code.

---

## 1. Method

Repository-wide scan, evidence recorded by `file:line`:

- Android manifest, Gradle config, ProGuard/R8 state.
- Every declared dependency in `pubspec.yaml` (media sources, analytics, auth, push).
- Runtime wiring in `lib/main.dart`, root widgets, and providers — i.e. what actually
  executes on an Android build, not just what is imported.
- User-visible copy in `lib/l10n/*.arb` (the strings that ship inside the APK).
- The payments surface (Play Billing + Superwall + the new Razorpay web rail).

---

## 2. Verdict

**Payments: compliant** within what the code can prove (§4). The Razorpay rail sells
only outside the app, the Play build contains no steering, and Play Billing remains the
in-app path. The residual payment risk is Google's *classification* judgement, not
conduct — see the separate note in `docs/RAZORPAY-SUBSCRIPTIONS.md`.

**The app as a whole: not 100% safe.** Two findings are inherited from the Spotube
fork and have nothing to do with subscriptions:

| # | Severity | Finding |
|---|---|---|
| P1 | **Blocker** | YouTube extraction machinery is initialised on Android, and the shipped strings say "I know I'm pirating Music" |
| P2 | **High** | `WRITE_SETTINGS`, app-wide cleartext HTTP, and advertising-ID declarations that must stay truthful |

---

## 3. Findings

### P1 — YouTube extractor + piracy copy (Play Intellectual Property policy; YouTube ToS)

Evidence:

- `lib/main.dart` — `NewPipeExtractor.init()` runs on **Android** at startup
  (`if (kIsAndroid || kIsDesktop)`), i.e. the YouTube extractor is initialised in the
  shipped Play build.
- `lib/main.dart` — `YtDlp.instance.setBinaryLocation(...)` is wired for desktop, and
  `YoutubeClientEngine.ytDlp` is a selectable engine (`lib/hooks/configurators/use_check_yt_dlp_installed.dart`,
  called from `lib/pages/root/root_app.dart`), with `yt_dlp_dart` and
  `youtube_explode_dart` declared in `pubspec.yaml`.
- `lib/l10n/app_en.arb:222-226` — user-facing copy that ships inside the APK:
  - `download_warning`: *"If you download all Tracks at bulk you're clearly pirating
    Music…"*
  - `download_agreement_1`: *"I know I'm pirating Music. I'm bad"*
  - `download_ip_ban_warning`: *"…your IP can get blocked on YouTube…"*

Why this is a policy problem: Google Play's Intellectual Property policy prohibits
apps that facilitate unauthorised access to copyrighted content, and downloading or
extracting YouTube streams violates YouTube's Terms of Service. The fact that the
default playback path now uses your own catalogue (`lib/services/sourced_track/direct_supabase.dart`)
does not neutralise it: the extractor still initialises, the dependencies still ship,
and the consent copy still exists in the binary where a reviewer or an automated scan
can find it. **A single screenshot of "I know I'm pirating Music" is enough to fail a
review.**

Remediation (must ship before the next Play release):

1. Remove `NewPipeExtractor.init()` from the Android path.
2. Drop `yt_dlp_dart`, `youtube_explode_dart`, and the `flutter_new_pipe_extractor`
   dependency, or confine them to a non-Play build via a compile-time guard **and**
   verify they are absent from the AAB.
3. Delete the download/piracy keys from every `lib/l10n/app_*.arb` and the
   `YouTubeEngineNotInstalledDialog` path; then grep the built AAB for `pirat`,
   `YouTube`, `yt-dlp`, `newpipe` to prove they are gone.
4. Re-run the scan after the change — absence of the widget is not absence of the
   string.

**P1 remediation status (2026-11-08, this commit):**

| Step | State |
|---|---|
| 1. `NewPipeExtractor.init()` removed from `lib/main.dart` | **done** — no extractor is initialised in the Android build |
| 3. Piracy / YouTube-IP-ban strings | **done** — 5 keys × 30 locales (150 lines) deleted; `flutter gen-l10n` regenerated; `grep -i pirating lib/l10n` and `lib/l10n/generated` both return 0 |
| 2. Remove `yt_dlp_dart`, `youtube_explode_dart`, `flutter_new_pipe_extractor` | **NOT done** — see below |
| 4. Prove absence in the built AAB | **not possible here** (no Android build on this machine) |

Why step 2 is not done in the same change: `MetadataPlugin.create()` takes a
`YouTubeEngine`, and the `YouTubeEngine` interface itself is typed with
`youtube_explode_dart`'s `Video` / `StreamManifest`. The engine provider is read by
~60 files (`provider/metadata_plugin/**`, `services/sourced_track/sourced_track.dart`,
`provider/server/routes/playback.dart`, `splash_gate`, settings). Deleting the packages
therefore means changing the metadata-plugin API, and that cannot be done blind: it must
be a build-and-device-verified change, not a text edit.

**Consequence, stated plainly:** the two things a reviewer can *see and act on* — a live
extractor initialisation and copy that admits piracy — are gone. The libraries are still
in the dependency tree, so this app is **not yet** certifiable as 100% safe. The next
change must be the package removal above, verified by grepping the built AAB for
`newpipe`, `yt-dlp`, `youtube_explode` and re-running the §6 checklist on a Play-installed
build.

### P2 — permission and transport hygiene

| Item | Evidence | Assessment |
|---|---|---|
| `WRITE_SETTINGS` | `android/app/src/main/AndroidManifest.xml:13` | Special permission. Justified only by the ringtone feature; Play treats it as sensitive. Keep only if the ringtone setter is user-initiated and prominent; be ready to answer a Play permissions declaration. |
| `usesCleartextTraffic="true"` | same manifest:46 | App-wide plaintext HTTP. Exists for the local media server. Violates Google's transport-security recommendation and exposes user data. Replace with a network security config scoped to `localhost`/`127.0.0.1`. |
| `AD_ID` | manifest:29 | Truthful only if the Play Console advertising-ID declaration says Yes **and** the Data safety form declares it. `docs/PLAY_DATA_SAFETY.md` claims they match; that claim needs re-verification in the Console, not just in the repo. |
| `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE*` | manifest:5-8 | Standard for a music player with push and a media foreground service. Declared correctly, with `foregroundServiceType="mediaPlayback"` (manifest:128). |

### P3 — cannot be verified from this repository

These are Console facts, not code facts. Nobody can call the app "100% safe" until a
human with Play Console access checks them:

1. Subscription products `soulful_monthly` / `soulful_yearly` exist, active, priced —
   and Superwall maps those exact IDs.
2. Payments profile verified (PAN, bank, GST).
3. Data safety form matches the real SDK set: Firebase Analytics, Crashlytics, PostHog,
   OneSignal, Clerk, Superwall, Razorpay (web only).
4. Account deletion: in-app exists (`ClerkBridge.deleteAccount` + profile action); the
   **web URL required by Play Console** must also be live.
5. Content rating questionnaire and target-audience answers are current.
6. Copyright: you hold or licence the rights to every track distributed in the app.

### Licensing note (not Play policy)

`LICENSE` is BSD-4-Clause with the copyright line replaced by "Copyright (c) 2026
Sangeet". If this codebase derives from Spotube (BSD-4-Clause), the original copyright
notice must be retained in source and binary distributions. Play does not police this,
but a rights holder can. Worth a legal review alongside the P1 fix.

---

## 4. Verified clean (payments and platform)

- No alternate payment method inside the app: no Razorpay SDK, no UPI deep link, no
  checkout copy in UI strings (`lib/l10n/app_en.arb` has no purchase/website/UPI text).
- Paid tracks are gated fail-closed: `PremiumAccess.isPremiumUser` requires a signed-in
  user plus an active Play/Superwall or server-verified Razorpay entitlement; a missing
  configuration shows an error, never free premium.
- No `MANAGE_EXTERNAL_STORAGE`, no broad storage permissions, no `QUERY_ALL_PACKAGES`
  (only an `https` VIEW query).
- No advertising SDK (the `gh-artifacts-ads-*` folders are build experiments; no ad
  dependency is declared).
- `targetSdk 36`, Play Billing `8.0.0` — meet the current Play requirements.
- Foreground media service and its type are declared; media-button receiver is standard.

---

## 5. Remediation order

1. **P1 before anything else.** It is the one finding that can cost the listing, it is
   unrelated to subscriptions, and it is a deletion job, not a rewrite.
2. **P2 transport**: scope cleartext to loopback via `network_security_config.xml`.
3. **P2 permission**: decide whether the ringtone setter justifies `WRITE_SETTINGS`;
   if it does, document it for a Play declaration.
4. **P3**: run the six Console checks with screenshots as evidence.
5. Re-run this audit after each change; the rule in §0 holds for every future commit.

---

## 6. Definition of compliant (re-run whenever the app changes)

- [ ] No `pirat`, `yt-dlp`, `newpipe`, `youtube_explode` strings or libs in the built AAB
- [ ] No external-payment link/copy inside the app (`grep` UI strings and routes)
- [ ] Play Billing products live and purchasable on an internal-testing install
- [ ] Data safety form = actual SDK set; privacy policy names Razorpay for web payments
- [ ] Account deletion works in-app and its Console URL resolves
- [ ] Manifest permissions unchanged without a matching declaration
- [ ] `flutter analyze` clean for every touched file; tests green
- [ ] Every platform decision cites an official Google page or doc in the commit

---

## 7. Credential sourcing — AWS Secrets Manager only

**Rule.** Every credential the app's backend uses is read from **AWS Secrets Manager**
(`ap-south-1`), named `<service>/<key>`. No credential is committed, written into a
`.env` that ships anywhere, pasted into a ticket, or kept in a chat.

Resolution order (implemented in `server/server.js` + `server/libs/awsSecrets.mjs`):

```
AWS Secrets Manager  ->  Supabase Vault  ->  process.env  ->  absent = fail closed
```

AWS is applied last and therefore wins for any name it supplies. It stays disabled
unless `AWS_SECRETS_ENABLED=1`, and it needs a least-privilege principal with
`secretsmanager:GetSecretValue` on the specific ARNs only.

| Credential | AWS secret name |
|---|---|
| Deepgram | `deepgram/api-key` |
| OpenAI | `openai/api-key` |
| Razorpay key secret | `razorpay/key-secret` |
| Razorpay webhook secret | `razorpay/webhook-secret` |

The server's **internal** names are unchanged (`deepgram_api_key`,
`razorpay_key_secret`, ...); only the AWS lookup name is translated, by the explicit
map in `libs/awsSecrets.mjs`.

### The mobile app is the exception, and it is not negotiable

A Flutter app **cannot** read Secrets Manager: that would require shipping AWS access
keys inside the APK, which is strictly worse than the problem it solves — anyone who
unzips the app gets your AWS account.

So the app is allowed to carry **publishable / client-side identifiers only**:

| Allowed in the app | Not allowed, ever |
|---|---|
| Clerk publishable key (`pk_live_…`) | Clerk secret key (`sk_live_…`) |
| Supabase anon key | Supabase service-role key |
| Superwall publishable key (`pk_…`) | Superwall secret key (`sk_…`) |
| OneSignal App ID | OneSignal REST key |
| PostHog project token | Razorpay key secret / webhook secret |

`lib/collections/env.dart` is compiled into the binary by `envied` (obfuscated, trivially
reversible). Anything placed there is public.

### Known violation to fix

`SUPERWALL_API_KEY=sk_fec748…` in `.env` is a **secret** key being used where the SDK
expects the publishable `pk_…` key. Two problems at once: Superwall will not initialise
with it, and a secret credential is inside the binary.

Action: rotate the `sk_` key in the Superwall dashboard, put the `pk_…` key in the
release `.env`, and never store a secret there again.

### Verification status (2026-11-09)

| Check | Result |
|---|---|
| Endpoint reachable from this machine | ✅ `secretsmanager.ap-south-1.amazonaws.com` answered (HTTP 404 on a bare POST = endpoint alive) |
| Loader test suite (`server/test/aws-secrets.test.mjs`) | ✅ 8/8 — includes timeout, fail-closed, region, name translation |
| Razorpay name mapping | ✅ `razorpay_key_secret` -> `razorpay/key-secret`, `razorpay_webhook_secret` -> `razorpay/webhook-secret` |
| AWS source enabled today | ❌ **off** — `AWS_SECRETS_ENABLED !== '1'` returns immediately |
| `GetSecretValue` authorises for this account | ⚠️ **not testable here** — no AWS credentials on this machine. Must be proven on Render with the real principal |

To close the last row, run this where the deployment credentials live (Render shell),
and expect each secret to be named and each failure to be an explicit code, never a
silent fallback:

```bash
AWS_SECRETS_ENABLED=1 AWS_REGION=ap-south-1 node -e "
import('./libs/awsSecrets.mjs').then(async (m) => {
  const { SecretsManagerClient, GetSecretValueCommand } = await import('@aws-sdk/client-secrets-manager');
  const r = await m.loadAwsSecrets({
    names: ['razorpay/key-secret','razorpay/webhook-secret'],
    client: new SecretsManagerClient({ region: 'ap-south-1' }),
    GetSecretValueCommand,
  });
  console.log('loaded:', r.loaded, 'failed:', r.failed.map(f => f.name + ':' + f.reason));
});"
```