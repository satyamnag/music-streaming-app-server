# Launch splash screen

The splash shown while the Android app starts is the Soulful Bhakti medallion,
centred, on pure black. This document is the contract for it, because it is
drawn by TWO different platform mechanisms (the pre-Android-12 launch window and
the Android 12+ splash screen API) and both have to produce the same picture on
every phone.

The reference UI the owner supplied is a black screen with the full circular
medallion, uncropped, at roughly 101 dp.

## Why it used to be wrong

Two independent defects, both visible in the reported screenshot:

1. **The icon was full-bleed.** `drawable-*/android12splash.png` was the
   medallion filling its whole canvas (100% of the bitmap), so on Android 12+ the
   platform's splash icon mask cut the gold ring off and sliced the temple and
   the "Soulful Bhakti" lettering.
2. **The background was transparent.** `windowSplashScreenBackground` was
   `@android:color/transparent`, which resolves to the *theme's* window
   background — white under `Theme.Light.NoTitleBar`. That is the white screen in
   the screenshot.

## The rules that are implemented now

### Android 12+ (`values-v31`, `values-night-v31`)

Per the official splash screen documentation
(<https://developer.android.com/develop/ui/views/launch/splash-screen#dimensions>):

| icon | canvas | must fit within |
| --- | --- | --- |
| with an icon background | 240 × 240 dp | a **160 dp** circle |
| without an icon background | 288 × 288 dp | a **192 dp** circle |

"Everything outside the circle turns invisible (masked)", and one third of the
foreground is masked. So the artwork may occupy **at most two thirds** of the
canvas, and anything at that boundary is one OEM rounding away from being cut.

The shipped icon therefore draws the medallion at **35% of its canvas**, a
fraction chosen from measurement rather than taste: Android lays a
background-less splash icon out in a **288 dp** box, the reference phone renders
the icon that way (`203 px` medallion on a 2x screen = 101 dp), so
`101 / 288 = 35%` reproduces the reference exactly on it. A device that honours
`windowSplashScreenIconBackgroundColor` and uses the 240 dp box draws the same
art at 84 dp — smaller, never bigger — and both are far inside the 67 % mask.
It is generated (never hand-edited) by:

```
python tool/generate_android12_splash.py          # writes all five densities
python tool/generate_android12_splash.py --check  # reports what would change
```

The theme additionally sets:

- `android:windowSplashScreenBackground` = `#FF000000` (black backdrop);
- `android:windowSplashScreenIconBackgroundColor` = `#FF000000` (the icon
  background circle is invisible against that backdrop);
- `android:windowBackground` = `@drawable/launch_background`, so an OEM skin
  that ignores the `windowSplashScreen*` attributes still paints the same black
  screen with the same centred medallion instead of a white one.

### Android 11 and below (`drawable*`/`launch_background.xml`)

A `layer-list` of a black backdrop plus `<bitmap android:gravity="center"
android:src="@drawable/splash">`. `gravity="center"` draws the bitmap at its
intrinsic size and **does not scale or mask it**, so this path cannot crop the
logo at any density; `splash.png` is 101 dp in every bucket.

### Both paths

They draw the same artwork at the same size, so a device on Android 10 and a
device on Android 15 show the same launch screen.

## Changing it

1. Replace `drawable-xxxhdpi/splash.png` with the new medallion (transparent
   background, artwork touching the canvas edges).
2. Run `python tool/generate_android12_splash.py`.
3. Re-check the ratio: the medallion must stay near 35% of the canvas. Anything
   above 66% is inside the platform's mask and will be cropped on some devices.
4. Install on a real phone and watch the launch (the splash lives for well under
   a second; `adb shell screenrecord` is the reliable way to see it).

The Flutter splash that follows (`lib/modules/splash/splash_screen.dart`) is a
different surface with its own animation and is not covered by this contract.
