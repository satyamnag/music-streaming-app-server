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

## Gating (requirement 1): no code change needed

The playback gate already satisfies all three cells and is unit-guarded by
`test/modules/monetization/playback_login_gate_test.dart`:

- `PremiumAccess.gateTrackPlay` → `requireSignInToPlay` (shows the Clerk Google
  Google OAuth sign-in) runs **before** the premium check, so a signed-out tap
  prompts sign-in first, then plays the tapped track after login.
- Signed-in + free → `requireSignInToPlay` returns immediately true, no blocker.
- Signed-in + paid + not premium → the Superwall paywall is shown and playback
  is refused (server /stream returns 403, direct_supabase refuses, prefetcher
  skips). Strictly no playback.

Nothing in `PremiumAccess` was modified for this change.

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

- New `test/paid_crown_badge_test.dart` rasterises the real crown painter and
  asserts it is not blank, not a solid blob, right-way-up (spike high, band
  low) and in-bounds; it also probes the source to confirm the track cover and
  album row reference the crown (not the lock) and that album covers keep their
  lock.
- CI (`flutter-verify` run 40723412953, `android-release` run 40723428117) both
  **passed** on the `feat/paid-crown-badge` branch.
- APK installed on-device (RMX2027) as versionCode 104; launch verified. The
  home screenshot was captured for visual confirmation:
  `_v104_home.png` in the workspace root.
