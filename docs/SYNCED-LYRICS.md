# Synced Lyrics: fixed-centre singing line

Status: implemented. Version: versionCode 98.

## What was asked

Refer to the supplied Sync Lyrics reference screen and update ours so that:

1. the line currently being sung sits at **a fixed position in the centre of the
   screen**, and
2. the previous and next lines **move upward** as the track plays.

## What the screen did before

`SyncedLyrics` already auto-scrolled, but not to a fixed point:

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

**Half a window of empty space** above the first line and below the last, so the
first and last lines can reach the centre too. This replaces the old
half-a-screen pad that was attached to the last item only.

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
  the first, a middle and the last line each land within 1px of the viewport
  centre; four consecutive cues each land on the *same* centre point while the
  scroll offset increases (the text travels up behind a fixed point); a line that
  has not been built yet (opening mid-song) still ends up centred; and a
  source guard fails if the screen stops using the post-frame centring or
  resumes scrolling from `itemBuilder`.
- **`test/components/lyrics/lyrics_active_line_capsule_test.dart`**: a long
  Telugu line with four translation sub-lines does not overflow at 320dp; the
  singing ink keeps **≥ 4.5:1** against both ends of the cream gradient; the gold
  and cream match the existing decorations.
- `dart analyze` clean, built by the `Android Release Build` workflow, installed
  over versionCode 97 with `adb install -r`.
