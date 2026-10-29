# Verification evidence — splash, deity banner, ten-track pages, player

Recorded from the reported phone: **Xiaomi 2302EPCC4I, Android 13 (SDK 33),
720x1600 px at density 320 (2x)**, with the release APK built by CI on this
commit series (`gh-artifacts-v110/app-stable-release.apk`,
versionCode 109, applicationId `com.soulfulbhakti.app`).

Tooling: `adb` only — install, `input tap/swipe`, `exec-out screencap`,
`dumpsys media_session`, `logcat`.

## 1. Launch splash — matches the reference exactly

Reference (`recommended icon ui uncropped.jpeg`): black screen, complete
circular medallion, **203 px = 101.5 dp**, centred.

Measured on the device from the captured launch frames:

| frame | artwork | centre | size |
| --- | --- | --- | --- |
| 00–06 (splash held) | 203 x 204 px | (359, 800) | **101.5 dp** |
| 07+ (app drawn) | full screen | — | — |

The screen is pure black outside the medallion, the ring is complete, and the
status-bar icons are light (readable on black). Screenshot:
`_v110_splash.png`.

Before the fix the shipped build (v96) drew a full-bleed icon
(`drawable-*/android12splash.png` at 100% of its canvas) on a transparent splash
background that resolved to the light theme's white — the cropped white screen in
the report.

Also verified inside the built APK (`aapt2 dump resources`): the v31 LaunchTheme
carries `android:windowBackground=@drawable/launch_background`,
`windowSplashScreenBackground=#ff000000`,
`windowSplashScreenAnimatedIcon=@drawable/android12splash`,
`windowSplashScreenIconBackgroundColor=#ff000000`, and every density bucket of
`android12splash` is 35.1 % artwork with transparent corners.

## 2. Deity screen — banner sits properly at the top

`_v110_deity_banner.png` (Krishna). The banner now starts directly under the
status bar and its full height is visible; the ringed badge, the title and the
song-count divider sit inside it with room instead of being crammed against the
top edge (which is what happened when the app's opaque status-bar colour covered
the banner's first 32 dp).

## 3. Ten tracks, then "see more"

- Deity screen (Durga, 13 songs): `_v110_deity_10_tracks.png` — exactly ten cards
  and a "Load more" row. Tapping it revealed the remaining three.
- Top Trending screen (the same page component backs Albums, Newest Arrivals and
  every language screen): `_v110_top_trending_seeall.png` — exactly ten cards and
  "Load more".

## 4. Album screens use the Top Trending card UI

`_v110_album_cards.png` and `_v110_album_cards_header.png` (Durga Vaibhavam,
Govinda Lahari). The tracks are the shared cover cards — cover, two-line title,
bottom-right play control — instead of the old table of rows: the
"# / Title / Album / Duration" header and the select-all checkbox are gone, while
the search, sort and overflow controls stay.

## 5. Player — mini player is always there

Verified in this order on the device:

1. Tap a card's play control → the track starts and the mini player appears with
   the right cover, title, duration and admin colours.
2. `dumpsys media_session` reports `state=3` (PLAYING) with the position advancing
   (~10 s of position per 10 s of wall clock, 155 s buffered) — audio is running,
   not stalled.
3. Tap **pause** on the mini player → `state=2` (PAUSED) and **the mini player
   stays on screen** with the play glyph: `_v110_miniplayer_paused.png`.
4. Tap the mini player → the full-screen player opens.
5. Press back → the full-screen player closes and **the mini player is back at its
   position**: `_v110_miniplayer_after_fullplayer.png`. (This is the sequence that
   previously left the app with no player at all: the visibility rule compared the
   navigation bar height to a stale literal `50` instead of
   `kNavigationBarHeight` = 64.)
6. Tap another track's play control → the new track loads into the mini player and
   plays.

## 6. Sign-in gate behaves as designed

With a signed-out session, tapping a play control shows the "Sign in with your
Google account to get started" dialog (`_v110_signin_gate.png`) rather than
failing silently; after signing in, the same tap starts playback. The gate also
waits for an unresolved auth state instead of treating "not resolved yet" as
signed out.

## Not covered by this device pass

- The Recently Played **screen** (reachable from its row's arrow only once the
  history has more than five tracks; this session had four). It renders the same
  `TrackGridSection` the album screen uses, which was verified above, and the
  ten-track rule is pinned by `test/ten_track_first_page_test.dart`.
- Playback on other OEM skins (Samsung/OnePlus/…) — the splash sizing reasoning
  covers the documented 240 dp and 288 dp icon boxes, and the pre-Android-12 path
  draws the same 101 dp bitmap at its intrinsic size.
