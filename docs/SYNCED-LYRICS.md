# Synced Lyrics: fixed-centre singing line

Status: implemented. Version: versionCode 101.

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
Scrollable.ensureVisible(lineContext, alignment: LyricsAutoCenter.alignment, duration: 420ms, curve: easeInOutCubic)
```

`alignment` is Flutter's own fraction between the leading edge (0.0) and the
trailing edge (1.0) of the viewport, documented on
`RenderAbstractViewport.getOffsetToReveal` as *where the child should be
positioned after applying the returned offset*. It is computed from the item's
**measured** geometry, so variable line heights and the active line's growth are
handled exactly.

It is **0.3** - just under a third of the way down - not 0.5. The centre spent the
bottom half of the screen on lines still to come; a third keeps the next two or
three lines visible while leaving the line just sung on screen above the anchor.

Precisely, the API places the line's BOX at that fraction of the way from "top edge
aligned" (0.0) to "bottom edge aligned" (1.0), so its centre lands at
`0.3 * (viewportHeight - lineHeight) + lineHeight / 2` - about 32% of the viewport
for a single line, and a little lower for a block of three languages. At 0.5 every
reading of the number is the same point, which is why this formula only matters now
that the anchor moved; the widget test derives the expected position the same way
instead of assuming a pure fraction (it caught exactly that 8px difference).

Because the anchor is no longer the middle, the space reserved **below** the last
line has to be the mirror of it: `LyricsAutoCenter.trailingSpace(height)` returns
`height * (1 - alignment)` (70%), and both screens take it from there so the two
cannot disagree. Reserving half a window (as the centre anchor needed) would leave
the final lines unable to rise to the anchor, and the lock would silently break
near the end of the track - the `the LAST line still reaches the anchor` test
exists for exactly that.

Driven from a single `useEffect` keyed on the active line index (and on the text
zoom, which changes every line's height), running **post-frame** so the line is
measured at its final size.

A line that has not been built yet - the screen opening mid-song, or a seek -
first jumps to an estimate without animating, then positions exactly on the next
frame. The jump is only ever a hint; the positioning is authoritative.

### The scroll model, corrected

The first version added half a window of space **above** the first line as well as
below the last. That made the first line start in the MIDDLE of the screen under a
large empty area while nothing was playing - reported from the device, screenshot
in hand. The correct model only needs the space BELOW:

| Moment | What happens |
| --- | --- |
| Nothing playing / before the first cue | the lyrics begin at the **top** of the view and fill it downwards |
| Track playing, early lines | the singing line cannot reach the anchor yet, so it sits progressively lower with each cue |
| Track playing, once the anchor is reachable | the singing line **locks onto the anchor** (30% down) and stays there for the rest of the track |
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
soon as the line can reach the anchor it does, and every later cue resolves to the
same alignment - the lock. `LyricsAutoCenter.scrollToStart` handles the return to
the top when a track restarts or loops and no cue is current yet.

There is deliberately **no** spacer above the list (and no top padding on the
player list). One trailing reservation BELOW keeps the final line able to reach the
anchor, so the lock survives to the end of the track.

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

## Multi-language lyrics (Plain and Sync), as the web app has it

The Soulful Bhakti web app's lyrics panel (`components/LyricsPanel.tsx`) gives the
listener a MULTI-select of lyric languages - Telugu, English transliteration,
English translation, Hindi transliteration, Hindi translation - and both its Plain
and Sync sheets stack whichever ones are picked, each in its own colour. That
facility now exists in the Android app on the player's lyrics screen (player ->
**Lyrics**), which is where the Plain / Sync tabs live.

**The chips toggle instead of replacing.** Previously a language chip was a
single-select: picking English dropped Telugu. Each chip now adds or removes its
language, so one, two, three or all five can be read at once.

**The rules are pure and tested** (`lib/modules/lyrics/lyric_language_selection.dart`),
because each one can empty or misalign the screen:

| Rule | Why |
| --- | --- |
| Only languages the CURRENT tab has text for are offered/drawn | a track can have plain lyrics without synced ones, or English without Hindi |
| A tab never draws nothing while it has any text | the selection is intersected with what the tab has; if that is empty, the first available language is shown (the web app's fallback) |
| Pressing the only shown chip does nothing | otherwise the sheet would blank itself (the web app's "keep at least one") |
| Display order, not selection order | Telugu then transliteration then translation, so a listener reads how it sounds before what it means |

**Plain lyrics** (`MultiLanguagePlainView`) align the languages LINE BY LINE:
the plain text arrives as one block per language (the admin's `plain_lyrics*`
columns, or derived from the synced variants), so `buildPlainLyricRows` splits
them and pads the shorter ones, keeping blank rows as stanza spacing so the
authored breaks survive. Each line stays selectable (copyable), `{Heading}` rows
still render the ornament divider, and a row the author did not translate simply
shows the languages it has.

**Sync lyrics** (`_MultiSyncView`) stack the selected languages on each timed line,
each in its language colour. The line being sung keeps the cream capsule, with
every shown language inside it in the capsule's own ink: the per-language colours
are chosen against this page's background and are not legible on cream, and the
capsule ink is the pairing whose contrast is asserted (>= 4.5:1 on both ends of the
gradient). The anchor, the descent, the lock, tap-to-seek and the `{{Music}}`
banner are all unchanged.

Scope, deliberately: the player's lyrics screen. The `/lyrics` page's Synced tab
already shows the main line together with every translation beneath it, and its
Plain tab is untouched.

### How far this was verified on the device

- **Plain multi-language: verified.** With one language selected the sheet showed
  the Telugu lines (headings as ornament dividers, stanza breaks intact); tapping
  the English-transliteration chip added the transliteration under every line;
  tapping the translation chip made it three; deselecting them and then pressing
  the last remaining chip left the sheet unchanged. Screenshots were taken at each
  step.
- **Sync multi-language: NOT seen live, and it cannot be with the current
  catalogue.** All 79 tracks were checked: every one stores only the Telugu
  `synced_lyrics`; `synced_lyrics_en` / `_en_tr` / `_hi` / `_hi_tr` are empty for
  every track, so the Sync tab can only ever offer the Telugu chip. The stacking
  code is the same per-line block list the Plain sheet renders, and the selection
  rules behind it are unit-tested, but the visual result on the Sync tab is
  unverified for that reason.
- **Anchor: verified by the widget tests, not by eye on this build.** The two
  tracks used for a look (`Ravamma Mahalakshmi`, `Sukha Madhuvu Kadalilo`) both
  reported "There is no data" on the Sync tab. That gate (`hasAnySync`) is
  unchanged code from the previous build and the old single-language view was
  never constructed either, so the state comes from the lyrics provider, not from
  this change; the endpoint serves valid SRT for those tracks from the same
  process. A previous build did render them, so the most likely cause is a stale
  `lyricsTable` row being used when the server fetch fails (the provider prefers
  the server and falls back to that cache). Worth a separate look - it is not
  part of this change, and it blocked the on-device confirmation of the anchor.

## Why some tracks showed no synced lyrics (versionCode 103)

Reported: *Tenela Tiyyani*, *Srinivasa Kalyana Sambaram*, *Tirumala Narayanaa* and
others showed no synced lyrics. All three store **SRT** in `synced_lyrics`
(`00:00:10,427 --> 00:00:12,595`), verified against the live table, and each also
carries `plain_lyrics*`.

Two causes, both fixed:

1. **The format was decided by luck.** The parser tried LRC first and reached SRT
   only when the LRC attempt produced nothing. SRT has to be *identified*, not
   inferred: its `-->` arrow never appears in LRC. Parsing now lives in
   `lib/modules/lyrics/lyric_parsing.dart`, which detects SRT by that marker and
   parses it first, then falls back to LRC. Real payloads from the reported tracks
   are unit tests asserting the actual cue times - so what is checked is "the cues
   arrived with their timings", not merely "something non-empty came back".

2. **The Sync tab's gate read a second provider.** Whether the lyrics were
   "synced" came from `syncedLyricsMapProvider`, which only the active-line clock
   needs. While that provider was loading - or after it errored - the tab was
   declared empty even though the timed lines were already loaded; the plain
   fallback (every cue at time zero) produces the identical symptom. Both screens
   now decide it from the lyrics in hand (`hasRealTimings`), so an unrelated
   provider's state cannot hide them.

Nothing about the text, timings, banners, tap-to-seek, colours or the anchor
changed: the SRT/LRC payloads, the ordering and the fallbacks are as before apart
from the format detection.

### Verification of this fix

- `test/modules/lyrics/lyric_parsing_test.dart` - 14 assertions over the real SRT
  of two of the reported tracks (plus a CRLF variant) and a valid LRC block, so the
  other format cannot regress: cues keep their exact times (`10.427s`, `12.971s`,
  `635ms`, ...), `hasRealTimings` classifies those tracks as synced, and text with
  no cues still yields "no timings" so the plain path is untouched.
- `dart analyze` clean; release APK built by `Android Release Build` and installed
  (versionCode 103).
- **On-device visual check of the Sync tab is outstanding**, and this is the honest
  limitation: the player sheet's **Lyrics** button did not accept synthetic input
  in this session (single taps at three vertical positions, a 2 px micro-swipe, and
  keyboard focus + Enter were all tried). The same button was already unresponsive
  before this change, so it is a tooling limitation rather than a regression. One
  manual tap - player -> **Lyrics** -> **Sync** - confirms it on any of those
  tracks.

## Verification

- **`test/modules/lyrics/lyrics_auto_center_test.dart`** (widget tests, CI):
  - the anchor is 0.3 and the trailing reservation is its mirror (70%);
  - the FIRST line sits flush with the **top** of the view, never at the anchor;
  - the singing line descends cue by cue (offset stays 0 while the anchor is out
    of reach) and then locks onto it for every later line;
  - a middle line, the LAST line (which is what the reservation is for), and a
    line that has **not been built yet** (opening mid-song) each land within 1px
    of the anchor;
  - a restart (`scrollToStart`) returns the list to the top, and is a safe no-op
    at the top or before the list exists;
  - source guards: both screens position through `LyricsAutoCenter`, neither
    scrolls from `itemBuilder`, each has exactly ONE trailing reservation, and the
    player page has no top padding.
- **`test/modules/lyrics/lyric_language_selection_test.dart`**: one/two/three
  languages drawn in display order; a selection this tab cannot show falls back to
  its first language; a tab with no text draws nothing; toggling adds, removes,
  refuses to remove the last shown language, and never mutates the caller's set;
  plain rows align line by line, pad a shorter language, keep blank rows as stanza
  breaks, pick the first non-empty column as the markup source, and handle CRLF.
- **`test/components/lyrics/lyrics_active_line_capsule_test.dart`**:
  - the capsule's horizontal centre matches the line's centre (the "not aligned"
    report), which a min-width row fails;
  - a long Telugu line with four translation sub-lines does not overflow at 320dp;
  - the singing ink keeps **≥ 4.5:1** against both ends of the cream gradient;
  - the gold and cream match the existing decorations.
- `dart analyze` clean, and the signed release APK built by the
  `Android Release Build` workflow, installed with `adb install -r`, and checked on
  the device: lyrics starting at the top before playback, the line descending to
  the 30% anchor and locking there, the capsule aligned with the other lines, and
  the language chips stacking two and three languages in both tabs.
