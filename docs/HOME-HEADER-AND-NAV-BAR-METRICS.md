# Home header + bottom bar: measured metrics, not guesses

Status: fixed and covered by tests. Two reported layout defects on the Home
screen:

1. the search icon sat too far from the bell at the top right;
2. the bar labels (`Home` / `Library` / `My Bhakti` / `Profile`) sat flush
   against the bottom edge of the screen.

Both were geometry errors, so both were **measured** before and after the change
with widget tests that render the real widgets — no eyeballed constants.

---

## 1. Header: search ↔ bell spacing

### What was wrong

`lib/pages/home/home.dart` laid the two actions out as
`IconButton(search) → Gap(10) → NotificationBell`. Each `IconButton.ghost` is a
**36dp box** around a 20dp glyph (8dp of padding per side — measured, not
assumed), so the visible distance between the glyphs was
`8 + 10 + 8 = 26dp`.

The bell is followed by `Gap(10)` to the screen edge, and its own 8dp padding
means the bell's glyph sits `10 + 8 = 18dp` from the edge.

So the two gaps that should look identical were **26dp vs 18dp** — which is
exactly the "search is far away from the bell" the owner saw.

### What changed

`lib/pages/home/home.dart:413` — a **2dp** gap between the two actions:

`8 + 2 + 8 = 18dp` between the glyphs, `10 + 8 = 18dp` from the bell's glyph to
the edge. The pair now reads as one deliberate group with an even rhythm.

Measured after the change (360dp-wide viewport):

| Measurement | Before | After |
|---|---|---|
| glyph → glyph | 26dp | **18dp** |
| bell glyph → screen edge | 18dp | 18dp |
| button hit area | 36dp | 36dp (unchanged, non-overlapping) |

### Why not a 48dp tap target here

Material recommends 48×48dp touch targets. Two adjacent 48dp boxes around 20dp
glyphs put the glyphs 28dp apart and cannot be made even against an 18dp edge
inset without pushing them *further* apart than the owner's complaint. Raising
the target size is therefore a deliberate trade-off, recorded here:

- 36dp is the app's existing header standard (unchanged by this fix);
- it clears the WCAG 2.2 AA target-size floor (24dp) and the two areas do not
  overlap, so neither tap is ambiguous;
- `test/bottom_nav_geometry_test.dart` asserts both properties, so a future
  change cannot silently shrink or overlap them.

## 2. Bottom bar: labels no longer touch the bottom edge

### What was wrong

`kNavigationBarHeight` was **64**, but the bar's own content is taller. Measured
with the app's exact configuration (`labelType: all`, `labelPosition: bottom`,
`labelSize: small`, `ButtonStyle.fixed(density: icon)`, the app's theme):

```
Divider            1.0 dp
NavigationBar     74.0 dp   (8 top padding + 58 item + 8 bottom padding)
                 ─────────
content           75.0 dp   vs  container 64.0 dp   → 11 dp clipped
```

The container was 11dp shorter than its content, so the `NavigationBar`'s own
15dp bottom padding was cut to ~4dp — the labels ended up flush with the bottom
edge. The overflow was invisible because the bar wraps its content in a
`SingleChildScrollView`.

### What changed

`lib/modules/root/spotube_navigation_bar.dart:35` — `kNavigationBarHeight = 76`
(the measured 75 plus 1dp of rounding slack). After the change each label keeps
its designed clearance:

| Measurement | Before | After |
|---|---|---|
| content height | 75dp | 75dp |
| container height | 64dp | **76dp** |
| label bottom → bar bottom | ~4dp (clipped) | **15dp** |
| icon top → bar top | 17dp | 17dp |

The icon/label/colour/tap behaviour is untouched; only the bar's height and the
resulting clearance changed.

Two supporting changes:

- `physics: NeverScrollableScrollPhysics()` on that scroll view (`:148`). It
  exists only so the bar can clip while it animates away behind the full player;
  without the override the *bar itself could be dragged*, which is not a
  navigation gesture anyone wants.
- The player's slide maths reads the same constant
  (`lib/modules/player/player_overlay.dart`, `kNavigationBarHeight * invertedPosition`)
  and the mini player's visibility check compares against it
  (`lib/modules/player/player.dart`), so raising the constant keeps the three in
  step — nothing else needed editing.

## 3. Android 15/16 edge-to-edge: already handled, and not double-counted

`android/app/build.gradle:66` sets `targetSdkVersion 36`. From Android 15 (API
35) apps are drawn edge-to-edge and must apply the system-bar insets themselves;
API 36 removes the opt-out. Google's guidance is to consume the window insets
rather than draw under the navigation bar
(<https://developer.android.com/develop/ui/views/layout/edge-to-edge>).

This app already does that once, and correctly:
`lib/pages/root/root_app.dart:55-59` wraps the root `Scaffold` in
`MediaQuery.removeViewInsets(removeBottom: true)` + `SafeArea(top: false)`, so
the whole footer stack (mini player + navigation bar) stops above the system
navigation bar. **No inset was added to the bar in this fix** — adding one would
have created a second gap above the gesture bar.

That is also why the defect was internal to the bar: the bar was already resting
on the system bar correctly; what touched the edge was the *label* against the
bar's own bottom edge.

## 4. Tests

`test/bottom_nav_geometry_test.dart` renders the real `NavigationBar` and the
real header action cluster:

- content height ≤ `kNavigationBarHeight` (fails if the constant is ever too
  small again — the exact bug);
- every one of the four labels keeps ≥ 12dp above the bar's bottom edge;
- the label still sits below its icon;
- header: glyph-to-glyph distance equals the glyph-to-edge inset, and both are
  18dp;
- header: the hit area stays ≥ 36dp and ≥ the 24dp WCAG floor;
- source guard: `home.dart` must keep the 2dp gap between search and the bell.

`test/miniplayer_visibility_test.dart` pins `kNavigationBarHeight` (now 76) so
the bar's height and the player's slide maths cannot drift apart silently.

Re-measure at any time with:

```bash
flutter test test/bottom_nav_geometry_test.dart test/miniplayer_visibility_test.dart
```

## 5. Verification on a device

1. Home screen: the search and bell glyphs are evenly spaced and the pair sits
   evenly inset from the right edge.
2. Bottom bar: labels have visible air above the bar's bottom edge, and nothing
   is clipped at any of the four tabs.
3. Open the full-screen player, then close it — the mini player must come back
   immediately (the bar height is part of that rule).
