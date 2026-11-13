# Bitmap downsampling + R8 optimization (Play Console advisories)

Status: fixed. Two performance advisories, two unrelated causes — one was in our
own widget code, the other was a release build with shrinking switched off.

Sources:
- <https://developer.android.com/develop/ui/compose/graphics/images/optimization>
- <https://developer.android.com/google/play/vitals/code-optimization>

---

## 1. Bitmap downsampling

**Reported:** `BitmapFactory` without `BitmapFactory.Options` at `B6.i.b` and
`Ae.h.a`.

**Found:** exactly two call sites, both in
`android/app/src/main/kotlin/com/sangeet/app/glance/widgets/TrackDetailsView.kt`
(the home-screen app widget). They decoded:

- the album cover with `BitmapFactory.decodeFile(path)` — **full resolution**, no
  `Options`. Covers are 1024×1024 and up, so that is ~4 MB of ARGB_8888 per
  bitmap, held by a widget that draws it in a **50dp or 100dp** square;
- the fallback icon with `BitmapFactory.decodeResource(...)`, also without
  `Options`.

Two call sites, two report entries — the obfuscated names in the Play report.

**Fix:** a shared helper, `glance/BitmapDecoding.kt`, implementing the two-pass
pattern from the documentation:

```kotlin
// pass 1: bounds only, no allocation
val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
BitmapFactory.decodeFile(path, bounds)
// pass 2: decode at the smallest power-of-two sample that still covers the target
val options = BitmapFactory.Options().apply {
    inSampleSize = calculateInSampleSize(bounds, reqWidthPx, reqHeightPx)
    inPreferredConfig = Bitmap.Config.ARGB_8888
}
BitmapFactory.decodeFile(path, options)
```

`calculateInSampleSize` halves while the result still covers the requested size,
so the bitmap is never upscaled (no blur) and never more than 2× larger than the
widget can show. The widget computes the target from the size it is about to draw
(`50.dp` / `100.dp`) × `displayMetrics.density`, and both decodes go through the
helper — the widget file no longer references `BitmapFactory` at all.

Effect for a 1024px cover drawn at 50dp on a 2.75 density screen (≈138px):
`inSampleSize = 4` → 256px, i.e. **~16× less memory** (4 MB → 256 KB).

## 2. R8 optimization

**Reported:** optimised resource shrinking not enabled; "upgrade AGP to 9.0 or
higher".

**Found:** this module's release build had **no shrinking at all** — no
`minifyEnabled`, no `shrinkResources`, and no `proguardFiles` line — even though
`android/app/proguard-rules.pro` had been maintained for exactly that purpose.

**Fix** (`android/app/build.gradle`, release build type):

```gradle
minifyEnabled true
shrinkResources true
proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
        'proguard-rules.pro'
```

`proguard-android-optimize.txt` (not the legacy default) is what enables the
optimising passes.

Keeps added to `proguard-rules.pro` for the SDKs that resolve their own classes by
name — shrinking one of them would break sign-in, purchases or push at runtime,
which is far more expensive than the few hundred KB they occupy:

```proguard
-keep class com.clerk.** { *; }
-keep class com.superwall.** { *; }
-keep class com.onesignal.** { *; }
-keep class com.posthog.** { *; }
-keep class com.ryanheise.** { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.glance.appwidget.GlanceAppWidgetReceiver { *; }
-keep class com.sangeet.app.** { *; }
```

### About the AGP 9.0 part of the advisory

Not done, deliberately. This project builds with **AGP 8.9.1** and **Flutter
3.35.2**; Flutter's Gradle plugin validates the AGP range it supports, and AGP 9
is outside it (the repo already carries
`android.suppressUnsupportedCompileSdk=36` for the neighbouring constraint).
Moving to AGP 9 would be a Flutter-upgrade project of its own, with a much larger
risk surface than the advisory is worth — the advisory's actionable half
(resource shrinking) is enabled, which is the part that affects the shipped bytes.

## 3. Verification

`test/android_performance_guards_test.dart` (7 tests):

- the helper reads bounds first, sets `inSampleSize`, and pins the config;
- the widget contains no `BitmapFactory` reference (comments stripped first);
- the decode target is derived from the 50/100dp size and the display density;
- the release block enables `minifyEnabled`, `shrinkResources` and the optimising
  proguard file;
- every reflection-heavy SDK, worker and widget receiver is kept.

35 tests pass across the performance, edge-to-edge, layout and plan-card suites.

Runtime check to run on a device after installing a shrunk build (R8 changes what
is in the APK, so this is the one part that needs eyes):

1. sign in with Google (Clerk);
2. open the paywall and reach Google Play (Superwall);
3. notification permission prompt and an inbox open (OneSignal);
4. play a track, then background the app (audio_service);
5. add the home-screen widget and play a track so its cover renders (the bitmap
   path above);
6. open Settings → share a track (file_picker / share paths).

## 4. Rollback

`minifyEnabled`/`shrinkResources` are two lines in `build.gradle`; the bitmap
change is the single widget file plus the new helper.
