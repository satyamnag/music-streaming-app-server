# Release Signing — AAB / APK (authoritative note)

> Last updated: 2026-09-25. This is the source of truth for how a locally built
> release **AAB** (and APK) must be signed for the Soulful Bhakti app.

## The upload key + certificate (use THESE for AAB building)

| Item | Location |
| --- | --- |
| Upload key store (private key, .jks) | `C:\Users\SATYAM NAG\Documents\keystores\soulfulbhakti-upload.jks` (2252 B, created 2026-09-20) |
| Upload certificate (public, PEM) | `C:\Users\SATYAM NAG\Documents\keystores\upload_certificate.pem` (1278 B) |

Certificate facts (read from the PEM — public data):
- Subject / Issuer: `CN=Soulful Bhakti, O=Soulful Bhakti, L=Hyderabad, S=Telangana, C=IN`
- Validity: `2026-09-20` → `2054-02-05` (long-lived upload certificate, as required by Play App Signing)
- SHA-1 thumbprint: `46A8A1529EC7F5051DD34B4013D2B53DC6F5F4A5`

## Wiring into the build

`android/app/build.gradle` signs every variant (release, debug, `nightly`, `dev`) with
`signingConfigs.release`, loaded from `android/key.properties`
(`storeFile` / `storePassword` / `keyAlias` / `keyPassword`).

- ❗ `android/key.properties` on this machine still points `storeFile` at the OLD, missing
  keystore `C:\Users\SATYAM NAG\Documents\keystores\sunao_kotlin.jks` (file does not exist).
- ✅ The keystore that actually exists and pairs with `upload_certificate.pem` is
  **`soulfulbhakti-upload.jks`**.
- **Before building a release AAB locally:** update `android/key.properties` so
  `storeFile=C:\\Users\\SATYAM NAG\\Documents\\keystores\\soulfulbhakti-upload.jks`
  and set `storePassword` / `keyPassword` / `keyAlias` to the credentials of THAT keystore.
  (These are secret values owned by the developer; the agent must never read or print them.)

## CI (GitHub Actions, `android-release.yml`) — unchanged

CI decodes the release keystore from the `KEYSTORE` secret into
`android/app/upload-keystore.jks` and writes `key.properties` from the `KEY_PROPERTIES` secret.
The authoritative "as-built" key in CI is therefore `upload-keystore.jks`.

## Rules for builds in this project

0. **ALWAYS prefer GitHub Actions for APK/AAB builds** (user directive, 2026-09-25): local
   Android builds on this machine are slow (multi-ABI Rust/Cargokit compile + Gradle; first run
   can take 30–60 min) and need the MSVC toolchain. The fast, correct path is the existing
   `android-release.yml` workflow (Ubuntu, caches, no local toolchain) — trigger it in the repo's
   Actions tab (workflow_dispatch). It needs these repo secrets configured: `KEYSTORE`
   (base64 of the upload keystore), `KEY_PROPERTIES` (contents of key.properties),
   `DOTENV_RELEASE` (the .env used at compile time). Only fall back to a local build when CI is
   unavailable AND the machine has the MSVC C++ toolchain installed.

1. AAB (Play) or release APK → sign with the upload key pair above (or the CI secret pair).
   Do NOT sign with `sunao_kotlin.jks` (stale/absent) and do NOT ship the debug keystore.
2. The certificate uploaded to Google Play Console must be `upload_certificate.pem`.
3. Never print, commit, or echo any keystore password or private key material anywhere
   (logs, reports, commits, chat).
4. If asked to build an AAB: verify `key.properties` points at `soulfulbhakti-upload.jks`
   first, run `flutter build appbundle --release`, and confirm the output at
   `build/app/outputs/bundle/release/app-release.aab`.