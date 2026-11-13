# Android 15 edge-to-edge — both Play Console advisories

Status: fixed. Two advisories arrived in sequence, and the second one changed the
answer to the first. This records the final design and why it looks the way it
does.

Sources: <https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge>

---

## 1. The two advisories

**A1 — "Edge-to-edge may not display for all users."**
Apps targeting SDK 35 display edge-to-edge by default; the app should handle
insets, or call `enableEdgeToEdge()` for backward compatibility.

**A2 — "Your app uses deprecated APIs or parameters for edge-to-edge."**
`Window.setStatusBarColor`, `Window.setNavigationBarColor`,
`LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`, reported at five places: two
obfuscated `onCreate`s, Material's datepicker, Flutter's
`PlatformPlugin.setSystemChromeSystemUIOverlayStyle`, and
`androidx.credentials.provider`.

**A1 and A2 conflict.** `enableEdgeToEdge()` — the call A1 asks for — is *built
out of* the APIs A2 reports. Verified in the released AndroidX source
(`androidx/core/view/WindowCompat.java`, core 1.17.0/1.19.1):

```java
public static void enableEdgeToEdge(@NonNull Window window) {
    window.getDecorView();
    setDecorFitsSystemWindows(window, false);
    window.setStatusBarColor(Color.TRANSPARENT);        // ← A2
    window.setNavigationBarColor(Color.TRANSPARENT);    // ← A2
    // API 28–29: LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES   ← A2
}
```

So satisfying A2 means keeping A1's *effect* without the deprecated calls.

## 2. What was actually ours

Three of the five reported sites were this app's code; two are library internals.

| Reported site | Owner | Action |
|---|---|---|
| the Activity's `onCreate` (via `enableEdgeToEdge`) | **ours** | replaced (below) |
| `PlatformPlugin.setSystemChromeSystemUIOverlayStyle` | reached from **our** Dart | stopped passing bar colours |
| `windowLayoutInDisplayCutoutMode=shortEdges` (theme) | **ours** | `always` |
| `com.google.android.material.datepicker…` | library (transitive) | not our code — see §5 |
| `androidx.credentials.provider…` | library (transitive) | not our code — see §5 |

## 3. The fix

### 3.1 The Activity opts in with the one call that is not deprecated

`android/app/src/main/kotlin/com/sangeet/app/MainActivity.kt`, before
`super.onCreate`:

```kotlin
WindowCompat.setDecorFitsSystemWindows(window, false)
```

That is the actual switch that makes the app own the insets — not deprecated, and
not flagged. Deliberately **not** called any more:

- `setStatusBarColor` / `setNavigationBarColor` — no-ops on Android 15+, and the
  window background shows through instead (see 3.3);
- no cutout-mode juggling in code — the theme owns it (see 3.2).

### 3.2 The theme uses the cutout mode Android 15 mandates

All four style files (`values`, `values-night`, `values-v31`,
`values-night-v31`):

```xml
<item name="android:windowLayoutInDisplayCutoutMode">always</item>
```

`SHORT_EDGES`, `NEVER` and `DEFAULT` are all interpreted as `ALWAYS` on Android 15
for non-floating windows, so `always` is both the required value and the
non-deprecated one.

### 3.3 Transparent bars without the colour setters

`NormalTheme` in every variant now sets:

```xml
<item name="android:windowDrawsSystemBarBackgrounds">false</item>
```

With that flag the window draws no bar background at all, so the status and
navigation bars show the app's own background — exactly the look the colour
setters produced — and no deprecated API is involved. Flutter keeps the icons
legible against it (`statusBarIconBrightness` follows the app theme).

### 3.4 Flutter passes no bar colours

`lib/pages/root/root_app.dart` used to send `statusBarColor: backgroundColor`;
that value travels: Dart → engine `PlatformPlugin.setSystemChromeSystemUIOverlayStyle`
→ `Window#setStatusBarColor`. The call now sends **only**
`statusBarIconBrightness`.

### 3.5 Insets are still consumed exactly once

Unchanged from the A1 fix: the root `SafeArea(top: true, bottom: true)` in
`lib/pages/root/root_app.dart` applies both insets, and the per-page `SafeArea`s
become no-ops (a `SafeArea` hands zero padding to its descendants).

## 4. What this does not change

- No new dependency. The `androidx.core:core-ktx:1.17.0` pin stays (it guarantees
  a current `WindowCompat`, and its AAR requires `compileSdk 36`, which this
  module uses).
- No manifest, permission, ABI or audio-service change; MainActivity keeps its
  `AudioServiceActivity` base class.
- Behaviour on Android 14 and below: the system bars show the app background, as
  before. On Android 15+: edge-to-edge is enforced by the platform anyway, and the
  insets are in the same place.

## 5. The two library-owned sites (and why they are not a break)

`com.google.android.material.datepicker…onStart` and
`androidx.credentials.provider…` are pulled in transitively (Material Components
via an SDK's UI, Credential Manager via the auth SDK). They are not this app's
source, and no Flutter plugin in this project declares either directly, so there
is nothing to bump without changing those SDKs.

Google's own page classifies these as **deprecated and disabled**, not removed:

> The following APIs are deprecated and disabled: `R.attr#statusBarColor`,
> `Window#setDecorFitsSystemWindows`, `Window#setNavigationBarColor` (gesture
> navigation), `Window#setStatusBarColor` …

i.e. on Android 15 they are no-ops; nothing regresses at runtime. They disappear
from the report when the SDKs that contain them ship updated versions.

## 6. Verification

`test/android_edge_to_edge_test.dart` (10 tests):

- the Activity calls `setDecorFitsSystemWindows(window, false)` before
  `super.onCreate`;
- the compiled code contains **no** `setStatusBarColor`, `setNavigationBarColor`,
  `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES` or `enableEdgeToEdge` (comments are
  stripped first, because the KDoc names them to explain why they are avoided);
- all four theme files use `always`, never `shortEdges`, and NormalTheme disables
  system-bar backgrounds;
- Flutter passes no `statusBarColor` / `systemNavigationBarColor` but still sets
  the icon brightness;
- the root `SafeArea` still consumes both insets.

29 tests pass across the edge-to-edge, layout and plan-card suites.

On-device: status bar and navigation bar must show the app background (not a grey
scrim), no header under the clock, bottom bar clear of the system buttons, and
audio playback unaffected. The Android 13 phone confirms the pre-15 path; the
15+ path is the platform's own forced behaviour plus the same insets.

## 7. Rollback

Revert `MainActivity.kt`, the four `styles.xml` files, `root_app.dart` and the
test together — they are one unit. Removing only the theme flags would leave the
bars with a system-drawn scrim behind dark icons.
