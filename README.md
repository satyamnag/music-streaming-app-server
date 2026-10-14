<div align="center">

# Soulful Bhakti

**Devotional music streaming for Android — and the server that powers it.**

Listen to bhajans, kirtans and devotional tracks with synced lyrics, offline
playback and a curated catalogue. Stream free, or subscribe for premium tracks.

</div>

---

## About this repository

This repository holds **two separate things** that share one Supabase database:

| Path | What it is |
|---|---|
| `lib/`, `android/`, `assets/` | The **Soulful Bhakti Android app** (Flutter) |
| `server/` | The **backend**: the admin panel, the REST API, and the Partner Program server |

They are deployed independently — the app ships to Google Play, while `server/`
runs on Render and serves the admin interface at `admin.soulfulbhakti.com`.

---

## The Android app

A Flutter application for devotional music listening.

### Features

- 🎵 **Curated devotional catalogue** — bhajans, kirtans and devotional tracks
- 🕒 **Synced lyrics** — time-aligned lyrics, with plain-text fallback
- 🎤 **Karaoke tracks** — for select songs
- 📥 **Offline playback** — keep music available without a connection
- 🎧 **Background audio** — playback continues with the screen off
- ❤️ **Likes and playlists** — save what you love, organised your way
- 🔔 **Ringtones** — set a track as your ringtone
- 📊 **Listening insights** — your own listening stats
- ✋ **No telemetry** — no diagnostics or user data collection

### Installing the app

The app is distributed through **Google Play**:

<a href="https://play.google.com/store/apps/details?id=com.soulfulbhakti.app">
  <img alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="80">
</a>

---

## The server (`server/`)

A Node.js/Express service that provides:

- **The admin panel** — track, album, playlist and catalogue management, served at `/admin`
- **The REST API** — the catalog and streaming endpoints
- **The Partner Program** — partner registration, KYC review, and issue of partner QR codes and discount coupons, served at `/partner`

### Running it locally

```bash
cd server
npm install
cp .env.example .env    # then fill in the values
npm start
```

It requires `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` to start. Other
credentials — R2 keys, the admin token, webhook secrets — are read from
Supabase Vault at startup, with environment variables as a fallback.

### Tests

```bash
cd server
npm run test:partner           # the Partner Program suite
npm run test:partner-flow      # end-to-end API tests against a stub
.\scripts\verify-partner-pipeline.ps1   # full pipeline verification (from repo root)
```

The pipeline verification brings up a disposable PostgreSQL instance, applies
the real migrations, and runs every test layer against it — including the
failure modes that only appear against a genuine database.

### Partner Program

The Partner Program lets a partner apply to promote the app and receive a QR
code and discount coupon in return. The full workflow, deployment steps, and
compliance position are documented in
[`docs/partner-program/README.md`](docs/partner-program/README.md).

---

## Building the Android app from source

```bash
flutter pub get
flutter build apk --release      # or: flutter build appbundle --release
```

Release builds require the compile-time environment (Supabase URL and keys,
R2 CDN base URL). See [`docs/RELEASE-SIGNING.md`](docs/RELEASE-SIGNING.md) and
[`CONTRIBUTION.md`](CONTRIBUTION.md).

---

## License

This project is licensed under the [BSD-4-Clause](LICENSE) License.

---

<details>
  <summary>
    <h3><code>[Click to show]</code> Services, dependencies &amp; credits</h3>
  </summary>

### Services

1. [Flutter](https://flutter.dev) — Cross-platform UI toolkit for building native applications from a single codebase.
1. [Supabase](https://supabase.com) — Postgres database, authentication and storage.
1. [Cloudflare R2](https://www.cloudflare.com/developer-platform/r2/) — Object storage and CDN for audio delivery.
1. [Clerk](https://clerk.com) — Authentication.
1. [Superwall](https://superwall.com) — Subscription paywall and purchase webhooks.
1. [OneSignal](https://onesignal.com) — Push notifications.
1. [MPV](https://mpv.io) — Media playback engine.
1. [Render](https://render.com) — Hosting for the server and admin panel.
1. [Google Play](https://play.google.com) — Android distribution.

### Dependencies

1. [app_links](https://github.com/llfbandit/app_links) — Android App Links, Deep Links, iOS Universal Links and custom URL schemes for Flutter.
1. [audio_service](https://pub.dev/packages/audio_service) — Play audio in the background while the screen is off.
1. [audio_session](https://github.com/ryanheise/audio_session) — iOS audio session category and Android audio attributes.
1. [auto_route](https://github.com/Milad-Akarie/auto_route_library) — Declarative routing with generated navigation.
1. [bonsoir](https://bonsoir.skyost.eu) — Zeroconf network service discovery.
1. [cached_network_image](https://github.com/Baseflow/flutter_cached_network_image) — Load and cache network images.
1. [connectivity_plus](https://github.com/fluttercommunity/plus_plugins) — Network connectivity state.
1. [device_info_plus](https://github.com/fluttercommunity/plus_plugins) — Device make, model and OS version.
1. [dio](https://github.com/cfug/dio) — HTTP client with interceptors and cancellation.
1. [drift](https://drift.simonbinder.eu/) — Reactive persistence library for SQLite.
1. [encrypt](https://pub.dev/packages/encrypt) — High-level cryptography APIs.
1. [envied](https://github.com/petercinibulk/envied) — Read environment variables into Dart at build time.
1. [file_picker](https://github.com/miguelpruivo/plugins_flutter_file_picker) — Native file explorer integration.
1. [flutter_cache_manager](https://github.com/Baseflow/flutter_cache_manager) — Generic cache manager for Flutter.
1. [flutter_hooks](https://github.com/rrousselGit/flutter_hooks) — React-style hooks for Flutter.
1. [flutter_riverpod](https://riverpod.dev) — Reactive caching and data-binding framework.
1. [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) — Keychain (iOS) and KeyStore (Android) backed secure storage.
1. [flutter_svg](https://pub.dev/packages/flutter_svg) — SVG rendering.
1. [home_widget](https://pub.dev/packages/home_widget) — Home screen widgets for Android and iOS.
1. [http](https://pub.dev/packages/http) — Composable, Future-based HTTP requests.
1. [image_picker](https://pub.dev/packages/image_picker) — Select images from the device library or camera.
1. [intl](https://pub.dev/packages/intl) — Internationalisation, date and number formatting.
1. [just_audio](https://github.com/ryanheise/just_audio) — Feature-rich audio player.
1. [logger](https://pub.dev/packages/logger) — Small, extensible logger.
1. [lrc](https://pub.dev/packages/lrc) — Parse and generate LRC lyrics files.
1. [media_kit](https://github.com/media-kit/media-kit) — Cross-platform audio and video playback.
1. [path_provider](https://pub.dev/packages/path_provider) — Platform-specific file system locations.
1. [permission_handler](https://pub.dev/packages/permission_handler) — Cross-platform permission handling.
1. [shadcn_flutter](https://github.com/sunarya-thito/shadcn_flutter) — Component library for Flutter.
1. [shared_preferences](https://pub.dev/packages/shared_preferences) — Simple key-value persistence.
1. [shelf](https://pub.dev/packages/shelf) — Web server middleware for Dart.
1. [shelf_router](https://pub.dev/packages/shelf_router) — Request routing for shelf.
1. [simple_icons](https://teavelopment.com/) — A large free SVG icon set for Flutter.
1. [skeletonizer](https://github.com/Milad-Akarie/skeletonizer) — Skeleton loading placeholders.
1. [sliding_up_panel](https://github.com/akshathjain/sliding_up_panel) — Draggable sliding panel widget.
1. [sqlite3](https://github.com/simolus3/sqlite3.dart/tree/main/sqlite3) — SQLite bindings via dart:ffi.
1. [timezone](https://pub.dev/packages/timezone) — Time zone database and aware DateTime.
1. [url_launcher](https://pub.dev/packages/url_launcher) — Launch URLs, phone, SMS and email schemes.
1. [uuid](https://pub.dev/packages/uuid) — RFC4122 UUID generation and parsing.
1. [visibility_detector](https://pub.dev/packages/visibility_detector) — Detect widget visibility.
1. [web_socket_channel](https://pub.dev/packages/web_socket_channel) — WebSocket StreamChannel wrappers.
1. [wikipedia_api](https://github.com/KRTirtho/wikipedia_api) — Wikipedia API for Dart and Flutter.

### Build tooling

1. [build_runner](https://pub.dev/packages/build_runner) — Dart code generation.
1. [drift_dev](https://drift.simonbinder.eu/) — Drift code generator.
1. [envied_generator](https://github.com/petercinibulk/envied) — Generator for Envied.
1. [flutter_gen_runner](https://github.com/FlutterGen/flutter_gen) — Type-safe asset, font and colour generation.
1. [flutter_launcher_icons](https://github.com/fluttercommunity/flutter_launcher_icons) — Generate launcher icons.
1. [flutter_lints](https://pub.dev/packages/flutter_lints) — Recommended lints.
1. [freezed](https://pub.dev/packages/freezed) — Code generation for immutable classes.
1. [json_serializable](https://pub.dev/packages/json_serializable) — JSON serialisation code generation.

</details>

<div align="center"><h4>© Soulful Bhakti</h4></div>
