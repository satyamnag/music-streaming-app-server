# Android 15 edge-to-edge (Play Console action item)

Status: fixed and pinned by tests. Triggered by Play Console's advisory:

> **Edge-to-edge may not display for all users.** From Android 15, apps targeting
> SDK 35 will display edge-to-edge by default. Apps targeting SDK 35 should
> handle insets to make sure that their app displays correctly on Android 15 and
> later. … Alternatively, call `enableEdgeToEdge()` for Kotlin or
> `EdgeToEdge.enable()` for Java for backward compatibility.
> — <https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge>

---

## 1. What the app was doing

| Fact | Evidence |
|---|---|
| Targets SDK 36, compiles against 36 | `android/app/build.gradle` (`targetSdkVersion 36`, `compileSdkVersion 36`) |
| The Activity never opted into edge-to-edge | no `enableEdgeToEdge` / `setDecorFitsSystemWindows` anywhere in the repo |
| The window therefore had **two** different models: below Android 15 the system inset the view; from Android 15 the platform forces edge-to-edge and stops insetting it | the behaviour change itself |
| The root only consumed the **bottom** inset, leaving the top to each page | `lib/pages/root/root_app.dart` (`SafeArea(top: false)`) |
| The Activity is a `FlutterActivity`, not a `ComponentActivity` | `MainActivity : AudioServiceActivity()` → `AudioServiceActivity extends FlutterActivity` |

So on Android 14 and below everything looked right, and on Android 15+ the app
entered edge-to-edge by force with the top inset handled only where an individual
page happened to use a `SafeArea`.

## 2. The fix (three parts, all verified)

### 2.1 Opt in with the current, non-deprecated API

`MainActivity.onCreate`, **before** `super.onCreate`:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    WindowCompat.enableEdgeToEdge(window)   // androidx.core.view
    super.onCreate(savedInstanceState)
}
```

Why this API and not the one Play literally names:

- `ComponentActivity.enableEdgeToEdge()` is **deprecated** in current AndroidX;
  its own `@Deprecated` message says *"Use `WindowCompat.enableEdgeToEdge(Window)`"*
  (verified in `androidx-main/activity/.../EdgeToEdge.kt`).
- It is also **not callable** here: it is an extension on `ComponentActivity`, and
  `MainActivity` extends `com.ryanheise.audioservice.AudioServiceActivity`, which
  extends `FlutterActivity` → `android.app.Activity`. Converting the Activity to a
  `ComponentActivity` (audio_service does ship `AudioServiceFragmentActivity`)
  would change lifecycle/plugin behaviour for a window flag — not worth it when an
  equivalent, non-deprecated, window-level API exists.

`WindowCompat.enableEdgeToEdge(window)` is the implementation AndroidX forwards to.
Verified from the released source (`core-1.19.1-sources.jar`,
`androidx/core/view/WindowCompat.java`):

```java
public static void enableEdgeToEdge(@NonNull Window window) {
    Objects.requireNonNull(window);
    window.getDecorView();                 // force decor now, so later setup cannot overwrite
    setDecorFitsSystemWindows(window, false);
    window.setStatusBarColor(Color.TRANSPARENT);
    window.setNavigationBarColor(Color.TRANSPARENT);
    // API 30+: LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS, API 28–29: SHORT_EDGES
    // API 29+: status/navigation bar contrast enforcement off
}
```

Calling it before `super.onCreate` is what makes the "force the decor view first"
note work: Flutter's own window setup runs later and must not undo it.

### 2.2 Pin the dependency that provides it

`android/app/build.gradle`:

```gradle
implementation 'androidx.core:core-ktx:1.17.0'
```

Verified, not guessed:

| Version | Has `WindowCompat.enableEdgeToEdge` | AAR `minCompileSdk` |
|---|---|---|
| 1.16.0 | **no** | – |
| 1.17.0 | **yes** | **36** ✓ (this module compiles against 36) |
| 1.19.1 | yes | **37** ✗ (would need compileSdk 37) |

1.17.0 is therefore the correct pin: the first release with the API, and the
highest one this module's `compileSdk 36` accepts. Declared explicitly so a
transitive dependency can't silently downgrade it.

### 2.3 Consume the top inset at the root

`lib/pages/root/root_app.dart`: `SafeArea(top: false)` → `SafeArea(top: true)`.

With `decorFitsSystemWindows=false` the window spans the whole screen, so the
status bar no longer insets the view — the app must. Doing it once at the root is
what makes it correct for **every** page: a `SafeArea` hands zero padding to its
descendants, so the per-page `SafeArea`s (home, library, profile, …) become
no-ops and the app is inset exactly once, never twice.

The bottom inset was already consumed there (navigation bar + floating footers),
and that is unchanged.

## 3. What does not change

- **Look on Android 14 and below:** identical. The window now extends behind the
  bars, and the root `SafeArea` puts the content back where it was. The status bar
  area keeps the app's background colour (`SystemChrome.setSystemUIOverlayStyle`
  in `root_app.dart` still sets it; on API 35+ that colour is simply ignored and
  the Scaffold background shows instead — the same colour).
- **Look on Android 15+:** unchanged content position, but now explicit rather
  than accidental.
- **Audio service:** untouched — the Activity keeps its `AudioServiceActivity`
  base class.
- **No new permissions, no manifest change, no ABI change.**

## 4. Verification

`test/android_edge_to_edge_test.dart` (5 tests) pins the whole arrangement:

1. `WindowCompat.enableEdgeToEdge(window)` is called and imported;
2. it runs **before** `super.onCreate`;
3. the `AudioServiceActivity` base class is unchanged;
4. `androidx.core:core-ktx:1.17.0` is pinned and the module still compiles against 36;
5. the root `SafeArea` is `top: true` and the bottom inset handling is intact.

Run together with the layout and plan-card suites: **25 tests pass**;
`flutter analyze` is clean.

On-device checklist (needs an Android 15+ phone to be conclusive):
1. status bar does not overlap the header on any tab;
2. the bottom bar still clears the navigation bar / gesture bar;
3. the home wallpaper starts just below the status bar, as before;
4. audio playback and the mini player behave as before.

## 5. Rollback

Revert the three files (`MainActivity.kt`, `app/build.gradle`, `root_app.dart`)
together — the call, the pin and the root inset are one unit; removing only the
inset would put headers under the status bar on Android 15+.
