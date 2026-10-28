# Paid-track crown badge (replaces the centred lock)

Status: implemented. Version: versionCode 104.

## What was asked

Three requirements, verbatim:

1. **Playback gating matrix** — (a) not signed in + tap play on ANY track (paid
   or free) → Google OAuth sign-in/login popup appears, and after sign-in that
   tapped track starts playing; (b) signed in + free track → plays immediately;
   (c) signed in + paid track → does **not** play at all.
2. **Badge** — replace the lock icon (shown centred over the cover) with a
   **golden Crown icon at the TOP-RIGHT corner** of every paid track's cover.
3. **Album screen** — replace the lock with the golden crown on the paid track
   **rows** under an album screen.

## Gating (requirement 1)

`PremiumAccess` itself was already correct and was **not** modified — its gate
asks for sign-in *before* the premium check, which is the required order. The
bug was in two of its **call sites**.

### The defect found and fixed (`6840df32`)

`lib/components/track_card/home_track_card.dart` and
`lib/components/track_tile/track_tile.dart` only called
`PremiumAccess.gateTrackPlay` **when the track was locked** (paid && !premium):

```dart
if (locked) { await PremiumAccess.gateTrackPlay(...); return; }
action();   // free track: straight to playback, no gate at all
```

So a signed-out tap on a **free** track never reached `requireSignInToPlay`: no
Google sign-in prompt appeared, and the player then refused silently
(`_playbackAllowed` false), so the play button looked dead. That is the opposite
of requirement 1(a).

Both surfaces now call `gateTrackPlay` **unconditionally**. That gate already
asks for sign-in first for every track and only then decides about the paywall,
so on these surfaces:

| Visitor | Track | Result |
| --- | --- | --- |
| signed out | any (free or paid) | Google sign-in prompt, then the gate continues |
| signed in | free | plays immediately, no dialog |
| signed in | paid, not premium | paywall, **no playback** |

`locked` now only decides the crown badge, which is all it should decide. The
album row's duplicated play body was collapsed into the gate's `feature`
callback so the two paths cannot drift apart again.

Note: `HomeTrackCard.onTap` is a *play* gesture on every playback surface (home
rows, search, see-all, recently played, language songs, featured playlists) and a
*navigation* gesture in the two analytics grids. Both gestures are gated now, so
a signed-out visitor is asked to sign in there too; the action still completes
after sign-in. Narrowing that to the play button alone is a one-line change if
that is preferred.

## Badge (requirements 2 & 3): the crown

New file `lib/components/premium/paid_crown_badge.dart` exposes:

- `PaidCrown` — a gold (`#E0A000`) crown painted via `CustomPainter` (same
  painted-glyph approach as `featured_playlist_chips.dart`), with a thin dark
  halo for legibility on light artwork;
- `PaidCrownBadge` — a `Positioned(top/right)` overlay pinning the crown to the
  cover's top-right corner.

Two call sites changed, both driven by the same `locked` flag (`paid &&
!premium`) as before — only the glyph and position changed:

| Surface | File | Before | After |
| --- | --- | --- | --- |
| Track cover | `lib/components/track_card/track_card.dart:560` | `LockedBadge` (centred dark-scrim lock) | `PaidCrownBadge` top-right |
| Album row | `lib/components/track_tile/track_tile.dart` (~270) | `Icon(Icons.lock)` in the play slot | `PaidCrownBadge` top-right over the 40x40 cover |

**Out of scope, left unchanged:** album **covers** still use `LockedBadge`
(`lib/modules/album/album_card.dart:158`) — the requirement only concerns paid
*tracks*, not album covers.

## Verification

- `test/paid_crown_badge_test.dart` rasterises the real crown painter and asserts
  it is not blank, not a solid blob, right-way-up (spike high, band low) and
  in-bounds; it also probes the source to confirm the track cover and album row
  reference the crown (not the lock) and that album covers keep their lock.
- `test/paid_crown_position_test.dart` measures the real `TrackCard` and proves
  the **position**: the crown is flush with the cover's top and right edges
  (minus its 4dp inset), its centre is in the top-right quadrant, the centre
  `LockedBadge` is gone, and a free track draws no crown.
- `playback_login_gate_test.dart` gained two regressions: neither the home card
  nor the album row may gate conditionally again.
- CI, all **green** on the commits that were merged:
  `flutter-verify` 40759105409 + `android-release` 40759113328 (gating fix,
  `6840df32`), and `flutter-verify` 40763328653 (crown position, `f73886f3`).
  The test names were confirmed in the run logs as actually executing.
- APK built by Actions and installed on the device (RMX2027) as versionCode 105
  (upgrade from 104); launch and an album screen verified. Screenshots captured
  for visual confirmation: `_v105_home.png`, `_v105_album.png`.

### What is not machine-verified

Which catalogue rows are `paid` is device data, not code, so this note does not
claim a specific on-device row was seen wearing a crown. The rendering, the
position and the swap are covered by the tests above; the final look should be
confirmed by eye on a paid track and a paid album.
