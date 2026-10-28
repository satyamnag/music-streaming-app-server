# Synced Lyrics: fixed-centre singing line

Status: implemented. Version: versionCode 100.

## There are TWO sync surfaces, and the reference is the second one

The app renders synced lyrics in two places, and the reference screenshot - with
its `Lyrics` title, `Plain | Sync` control and `తె` language chip - is the second:

| Surface | Widget | Reached from |
| --- | --- | --- |
| Full lyrics page | `lib/pages/lyrics/synced_lyrics.dart` (`SyncedLyrics`) | the `/lyrics` route |
| Player lyrics page | `lib/pages/player/lyrics.dart` (`_SingleSyncView`) | player -> **Lyrics** button |

Found by opening the screen on the device, not by reading the code: the first
implementation pass covered only the full lyrics page, and the player screen -
the one a listener actually presses **Lyrics** for - still had its old
behaviour. Both now use the same rule and the same highlight.

## What was asked

Refer to the supplied Sync Lyrics reference screen and update ours so that:

1. the line currently being sung sits at **a fixed position in the centre of the
   screen**, and
2. the previous and next lines **move upward** as the track plays.

## What the two screens did before

**Full lyrics page** (`SyncedLyrics`) auto-scrolled, but not to a fixed point:

- `itemBuilder` called `scrollToIndex(..., preferPosition: AutoScrollPosition.middle)`
  **for the active line, during build**, i.e. a side effect inside a build method,
  re-running on every rebuild of that line;
- `scroll_to_index` resolves that target from its **estimated row height**
  (`suggestedRowHeight` is not configured here), so the rendered position is
  approximate - and this list is the worst case for an estimate, because every
  line has a different height: one line of Telugu, two lines, one line plus four
  translation sub-lines, a `♪ Music ♪` banner, or a blank stanza break;
- the **first** line could never reach the middle at all: the only spacer was
  half a screen added to the *last* item, so the top of the list was pinned to
  the top of the view;
- the active line is drawn larger than its neighbours (30 vs 24), so any
  alignment computed before that growth had been laid out was a few pixels off.

**Player lyrics page** (`_SingleSyncView`) was further off:

- it positioned the current line by **scroll fraction** -
  `animateTo(position.maxScrollExtent * currentIndex / length)` - so the line
  landed wherever that fraction fell, essentially never the centre, and drifted
  further the more line heights differed (banners, wrapped Telugu, the blank rows
  rendered for empty variants);
- its only padding was 8dp, so neither the first nor the last line could ever
  reach the middle;
- the highlight was a card with a maroon left bar and a 1.06 scale, not the
  reference's capsule.

## What it does now

**`lib/modules/lyrics/lyrics_auto_center.dart`** - one rule, in one place:

```
Scrollable.ensureVisible(lineContext, alignment: 0.5, duration: 420ms, curve: easeInOutCubic)
```

`alignment: 0.5` is Flutter's own definition of "centre": the documentation for
the offset it resolves (`RenderAbstractViewport.getOffsetToReveal`) states *"If
alignment is 0.5, the child must be positioned as close to the center of the
viewport as possible."* It is computed from the item's **measured** geometry, so
variable line heights and the active line's growth are handled exactly.

Driven from a single `useEffect` keyed on the active line index (and on the text
zoom, which changes every line's height), running **post-frame** so the line is
measured at its final size.

A line that has not been built yet - the screen opening mid-song, or a seek -
first jumps to an estimate without animating, then centres exactly on the next
frame. The jump is only ever a hint; the centring is authoritative.

### The scroll model, corrected

The first version added half a window of space **above** the first line as well as
below the last. That made the first line start in the MIDDLE of the screen under a
large empty area while nothing was playing - reported from the device, screenshot
in hand. The correct model only needs the space BELOW:

| Moment | What happens |
| --- | --- |
| Nothing playing / before the first cue | the lyrics begin at the **top** of the view and fill it downwards |
| Track playing, early lines | the singing line cannot be centred yet, so it sits progressively lower with each cue |
| Track playing, once centring is possible | the singing line **locks onto the centre** and stays there for the rest of the track |
| Repeat / loop / new play | the list returns to the **top** and the whole descent happens again |

This falls out of Flutter's own arithmetic rather than any special-casing. In the
implementation of `ScrollPosition.ensureVisible` (quoted on its API page) the
resolved offset is clamped:

```dart
target = viewport.getOffsetToReveal(object, alignment, ...).offset;
target = clampDouble(target, minScrollExtent, maxScrollExtent);
```

So while the current line's centre lies above the top of the viewport the target
is negative, clamps to `minScrollExtent` (0), and the list stays at the top; as
soon as the line can be centred it is, and every later cue resolves to the same
alignment - the lock. `LyricsAutoCenter.scrollToStart` handles the return to the
top when a track restarts or loops and no cue is current yet.

There is deliberately **no** spacer above the list (and no top padding on the
player list). One half-window spacer BELOW keeps the final line centreable, so the
lock survives to the end of the track.

### Horizontal alignment of the singing line

The second device report: the highlighted line was not aligned with the others,
which are centred by `textAlign`. The capsule was a min-width `Row`, and a
min-width row dropped into a full-width list item sits against the **left** edge.
It now uses `mainAxisSize: MainAxisSize.max` with `mainAxisAlignment: center`, so
the capsule centres ITSELF in whatever width it is given and cannot be misaligned
by a host again; the pill is still the only flexible child, so a long line wraps
inside the space the ornaments leave and nothing overflows.

**`lib/components/lyrics/lyrics_active_line_capsule.dart`** - the highlight from
the reference screen, built from the palette the lyric decorations already use
rather than a second visual language:

| Element | Value | Shared with |
| --- | --- | --- |
| Capsule fill | `#FDF7E7` → `#F3E6C8` gradient | cream pill of `LyricsOrnamentDivider` (`{Heading}`) |
| Border, ornaments | `#C9A227` hairline gold | gold rules/flourishes of `LyricsOrnamentDivider` |
| Singing line ink | `#520101` | documented deep-maroon primary of the Bhakti scheme |

The ornaments are gold eight-ray sunbursts painted with paths, so they need no
asset and stay crisp at every text-zoom level.

### Deliberate deviations from the reference

- **No full-width gold rules** beside the capsule. In the reference the capsule
  spans almost the whole width, so its rules are short; here the capsule hugs the
  line, and spending ~24dp per side on rules would push a long line onto an extra
  row every time it became current - the text would jump as it was highlighted.
- **The page background is unchanged.** The reference is a light sheet; this page
  is drawn on the album artwork with the tinted surface. Repainting the page
  would be a redesign of the screen, not a lyrics change.
- **Inactive lines are not dimmed**, for the reason already documented in this
  file: their ink is the palette colour that palette_generator guarantees 4.5:1
  for against this backdrop, and dimming it is what previously cost contrast. The
  capsule carries the emphasis instead.

## What was deliberately not touched

Plain Lyrics tab, language variants, `{{Music}}` banners, `{Heading}` dividers,
tap-a-line-to-seek, the delay and text-zoom controls, the mini-player lyrics, and
every provider and backend route. The only colour decision added is the ink
*inside* the capsule, which is a surface this change introduced.

## Verification

- **`test/modules/lyrics/lyrics_auto_center_test.dart`** (widget tests, CI):
  - the FIRST line sits flush with the **top** of the view, never in the middle;
  - the singing line descends cue by cue (offset stays 0 while it cannot be
    centred) and then locks onto the centre for every later line;
  - a middle line, the last line, and a line that has **not been built yet**
    (opening mid-song) each land within 1px of the viewport centre;
  - a restart (`scrollToStart`) returns the list to the top, and is a safe no-op
    at the top or before the list exists;
  - source guards: both screens centre through `LyricsAutoCenter`, neither scrolls
    from `itemBuilder`, the full page has exactly ONE half-window spacer (below the
    list) and the player page has no top padding.
- **`test/components/lyrics/lyrics_active_line_capsule_test.dart`**:
  - the capsule's horizontal centre matches the line's centre (the "not aligned"
    report), which a min-width row fails;
  - a long Telugu line with four translation sub-lines does not overflow at 320dp;
  - the singing ink keeps **≥ 4.5:1** against both ends of the cream gradient;
  - the gold and cream match the existing decorations.
- `dart analyze` clean, and the signed release APK built by the
  `Android Release Build` workflow, installed with `adb install -r`, and checked on
  the device against both reports: lyrics starting at the top before playback, the
  line travelling down to the centre and locking there, and the capsule aligned
  with the other lines.
