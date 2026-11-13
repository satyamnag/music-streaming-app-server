# Android 15 edge-to-edge — both Play Console advisories

Status: fixed. Two advisories arrived in sequence and the second one changed the
answer to the first; this records the final design, the wrong turn taken in
between, and the evidence.

Sources: <https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge>

---

## 1. The two advisories

**A1 — "Edge-to-edge may not display for all users."** Apps targeting SDK 35 are
edge-to-edge by default; handle the insets, or call `enableEdgeToEdge()` for
backward compatibility.

**A2 — "Your app uses deprecated APIs or parameters for edge-to-edge."**
`Window.setStatusBarColor`, `Window.setNavigationBarColor`,
`LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`, reported at five call sites.

They conflict: **`enableEdgeToEdge()` is built out of the APIs A2 reports**
(verified in the released `androidx/core/view/WindowCompat.java`):

```java
public static void enableEdgeToEdge(@NonNull Window window) {
    window.getDecorView();
    setDecorFitsSystemWindows(window, false);
    window.setStatusBarColor(Color.TRANSPARENT);        // ← A2
    window.setNavigationBarColor(Color.TRANSPARENT);    // ← A2
    // API 28–29: LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES   ← A2
}
```

The resolution is the deprecation's own wording: those APIs are deprecated **in
Android 15 / API 35**. Below 35 they are still the only way to make the system
bars transparent, so they stay — but strictly behind an API-level guard, and never
on 35+ where the platform enforces edge-to-edge and the setters are disabled.

## 2. Who owned the five reported sites

| Reported site | Owner | Resolution |
|---|---|---|
| obfuscated `onCreate`s (the helper, inlined) | **ours** | helper now called only below API 35 |
| `PlatformPlugin.setSystemChromeSystemUIOverlayStyle` | reached from **our** Dart | no bar colour is sent any more |
| `windowLayoutInDisplayCutoutMode=shortEdges` (theme) | **ours** | `always` in all four style files |
| `Material datepicker …onStart` | transitive library | not our code — §5 |
| `androidx.credentials.provider…` | transitive library | not our code — §5 |

## 3. The final code

### 3.1 MainActivity — the helper, version-guarded

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
        WindowCompat.enableEdgeToEdge(window)
    }
    super.onCreate(savedInstanceState)
}
```

- **Below 35:** the helper makes both bars transparent and disables contrast
  enforcement — advisory A1's documented path, and none of what it calls is
  deprecated here.
- **35+:** nothing is called. The platform enforces edge-to-edge and the setters
  are no-ops, so any call would be dead code (`VANILLA_ICE_CREAM` = API 35).

### 3.2 Theme — the cutout mode Android 15 requires

All four style files (`values`, `values-night`, `values-v31`,
`values-night-v31`):

```xml
<item name="android:windowLayoutInDisplayCutoutMode">always</item>
```

`SHORT_EDGES` — the value Play reported — is gone. On Android 15 `SHORT_EDGES`,
`NEVER` and `DEFAULT` are all reinterpreted as `ALWAYS` for non-floating windows,
so `always` is both the mandated value and the non-deprecated one.

### 3.3 Flutter — icon brightness only

`lib/pages/root/root_app.dart` no longer sends `statusBarColor`. That value
travelled Dart → engine `PlatformPlugin.setSystemChromeSystemUIOverlayStyle` →
`Window#setStatusBarColor`, one of the reported sites. The style now sends only
`statusBarIconBrightness`, so the icons stay legible against whatever the bars
show.

### 3.4 Insets are consumed exactly once

`SafeArea(top: true, bottom: true)` at the root; the per-page `SafeArea`s become
no-ops because a `SafeArea` hands zero padding to its descendants.

## 4. The wrong turn (kept here on purpose)

The first attempt removed `enableEdgeToEdge()` altogether and tried to get
transparent bars from the theme
(`android:windowDrawsSystemBarBackgrounds=false` on `NormalTheme`). Measured on the
real device:

- the status bar rendered **pure black with no icon pixels** (rows 0–47 all
  `#000000`, bright-pixel count 0) while the app asked for **dark** icons — an
  invisible status bar;
- the navigation bar went black and opaque.

So the flag was reverted, and the helper came back behind the API guard. The
theme now declares no bar colours at all. This is why the test asserts the flag is
**absent**.

## 5. The two library-owned sites (and why they are not a break)

`com.google.android.material.datepicker…onStart` and
`androidx.credentials.provider…` come in transitively (Material Components via an
SDK's UI, Credential Manager via an auth SDK). No Flutter plugin in this project
declares either directly, so there is nothing to bump from here.

Google's page classifies these as **deprecated and disabled**, not removed:

> The following APIs are deprecated and disabled: `R.attr#statusBarColor`,
> `Window#setDecorFitsSystemWindows`, `Window#setNavigationBarColor` (gesture
> navigation), `Window#setStatusBarColor` …

On Android 15 they are no-ops, so nothing regresses at runtime; they leave the
report when those SDKs ship updated versions.

## 6. Verification

`test/android_edge_to_edge_test.dart` (10 tests):

- the helper is called, and the call sits **inside** an `SDK_INT < VANILLA_ICE_CREAM` guard;
- the app never calls `setStatusBarColor` / `setNavigationBarColor` itself
  (comments are stripped before the check, because the KDoc names them);
- all four theme files use `always`, never `shortEdges`, and carry **no**
  `windowDrawsSystemBarBackgrounds`;
- Flutter sends no bar colour but still sets the icon brightness;
- the root `SafeArea` consumes both insets.

29 tests pass across the edge-to-edge, layout and plan-card suites.

On device (Android 13, `2302EPCC4I`): bars transparent showing the app
background, clock and icons visible, nothing under the status bar, bottom bar
clear of the system buttons.

## 7. Rollback

Revert `MainActivity.kt`, the four `styles.xml` files, `root_app.dart` and the test
together — they are one unit.
