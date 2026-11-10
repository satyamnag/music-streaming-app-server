# Lyrics Sync Studio (admin): real-time Telugu lyric timing → SRT

Status: implemented. Lives in `server/admin.html` (the admin SPA served at
`/admin` and at the admin domain root).

## What it is

A full-screen tool inside the existing admin panel that answers one question
quickly: **where exactly does each Telugu lyric line start?**

The audio (or a local video/audio reference file) plays; the admin presses **S**
at the moment each line begins; the next line is selected automatically; when
the last line is stamped they press **Save to track**. The result is written to
the track's `synced_lyrics` column as SubRip — the format the catalogue already
uses (50 of 79 rows) and the one the Flutter parser reads first.

Three entry points, all in `admin.html`:

| Entry point | Where |
| --- | --- |
| `🎬 Sync Studio` | Tracks toolbar (opens with a track picker) |
| Waveform icon | Each row of the tracks table (opens that track) |
| `🎬 Open Sync Studio` | The Lyrics pane header of the track editor |

## The workflow the tool is built around

```
Load track → lyrics arrive (saved SRT, else plain lyrics, else paste)
Space → play  ·  S → stamp the selected line, selection advances
S … S … S → down the list, one press per sung line
Save → PUT synced_lyrics → re-read the row and compare
```

Ends are **derived**, not typed: a cue's end is the next cue's start minus the
configured gap (default 0.15 s). One stamp therefore fixes two boundaries and
overlapping cues are impossible by construction. A hand-set end (the
`End = playhead` button) pins that one line and is tagged `pinned` in the table;
`Re-derive all ends` unpins everything.

### Why the rows stay in lyric order

A bhajan returns to the pallavi, so time order and lyric order are not the same
thing — and re-sorting the table under the cursor while stamping would move the
row the admin is about to stamp. Rows therefore stay in lyric order, and any
change that breaks "each cue must move forward" is reported in **Timeline
Health** and in the status bar instead of silently reordering the work.
`Sort by time` is an explicit action.

## Keyboard

| Key | Action |
| --- | --- |
| `Space` | Play / pause |
| `S` | Stamp the selected line's start, advance |
| `E` | Set the selected line's end (pins it) |
| `↑` / `↓` | Previous / next line |
| `←` / `→` | Seek 1 s (Shift: 5 s) |
| `[` / `]` | Nudge 0.1 s (Shift: 0.5 s) |
| `Enter` | Jump to the selected line and play |
| `Ctrl`/`⌘` + `S` | Save to the track |
| `Esc` | Close (asks first if there are unsaved changes) |

Shortcuts are ignored while typing in a field, and `Space`/`Enter` are left to a
focused button or link so the studio's own controls stay keyboard-operable.

## What is written, exactly

* One column: `synced_lyrics` (Telugu). The translation/transliteration columns
  are untouched — they share this timeline and are built by the existing
  "Copy timings from Telugu" / step-2 / step-3 flows.
* One request shape: `PUT /api/admin/tracks/:id` with `{ "synced_lyrics": "…" }`.
* Generated SRT, always `HH:MM:SS,mmm --> HH:MM:SS,mmm` with a blank line
  between cues — byte-identical in shape to what `sync-from-srt` and Auto-Sync
  produce, so every downstream consumer sees one format.

## Safety properties

1. **No new write path.** Save uses the existing audited route, so
   `requireAdmin` (ADMIN_TOKEN session or an `@soulfulbhakti.com` Clerk session),
   the transliteration-column retry and the R2 cleanup all still apply. The
   studio adds no endpoint, no SQL and no key of its own.
2. **Validated before it is sent.** The generated document is checked with the
   page's own `isValidSrt` (the same guard the manual editor uses); an invalid
   document is never transmitted.
3. **Verified after it is stored.** The row is re-read and compared. A 200
   response alone is not treated as success — a mismatch reports
   "the row read back different text" instead of a false "saved".
4. **Server-side enforcement (new).** `PUT`/`POST /api/admin/tracks` now reject a
   non-empty `synced_lyrics*` value that is not SRT (`syncedLyricsRejection` in
   `server.js`). The page-level guard was only a UI hint; a request that skipped
   the page could previously store text the app cannot parse, which removes a
   song's synced lyrics rather than degrading gracefully. `null` still means
   "leave alone", `''` still means "clear".
5. **Nothing happens by accident.** Imports, drafts and exports are local.
   Overwriting a track that already has sync lyrics requires a confirmation.
   Closing with unsaved timings asks first.
6. **Escaping.** Every admin-entered string reaches the DOM through `escHtml`,
   so a pasted `<img onerror=…>` renders as text (covered by a browser test).
7. **Crash safety.** A debounced localStorage draft (max 8 tracks, ~400 KB each,
   quota-safe, pruned) survives a closed tab; the pending write is cancelled on a
   successful save so a saved track never re-offers a stale draft.
8. **Pane consistency.** If the Lyrics pane is open on this track's Telugu sync
   column when the studio saves, its textarea is refreshed — otherwise the next
   "Save" there would write the pre-studio text back.

## Workspace layout: the graph and the timeline never hide each other

Both panels are halves of one workspace, so the column is a **three-way split**
rather than "fixed panels and whatever is left":

| Panel | Rule | Why |
| --- | --- | --- |
| Now-playing / transport | `auto` | fixed content |
| Preview (artwork / video + live lyric) | `flex: 1 1 210px`, **110–320 px** | the only decorative panel, so it absorbs the shortfall first |
| Voice graph | `clamp(154px, 23vh, 300px)` canvas, resizable by its grip | a two-lane strip needs real height; a squashed waveform cannot show high from low |
| Timeline editor | `flex: 2 1 280px`, **never below 210 px** | the working surface; this floor is what stops it collapsing |
| Footer (Save / Export) | own grid row, spanning both columns | never scrolls away |

Measured with the layout harness (preview / voice-graph strip / timeline card):

| Viewport | Preview | Voice graph | Timeline | Column scrolls? |
| --- | --- | --- | --- | --- |
| 1920×1080 | 209 | 248 | 279 | no |
| 1536×1024 | 191 | 236 | 255 | no |
| 1440×900 | 140 | 207 | 210 | no |
| 1366×768 | 100 | 131 | 210 | no |
| 1280×720 | 88 | 128 | 210 | yes, by design |
| 1093×614 (narrow branch) | 140 | 128 | 340 | no |

The graph's height comes out of the preview, exactly as the split rule intends:
at 1440×900 the preview is 140 px where it used to be 210, and the timeline sits
at its own 210 px floor either way. The live lyric is still legible there, and
`Preview` in the top bar trades it away entirely when the admin wants the strip
maximised.

**Short viewports** (`max-height: 820px`) shrink the preview first (to 88 px) and
tighten the transport, so the graph and timeline keep their heights instead of
the timeline disappearing. On a 768-high laptop the strip is 131 px, which still
separates the notes; two one-click ways to get more are the **grip** under the
graph and the **Preview** toggle.

**`Preview` toggle** (top bar, remembered in `localStorage`): hides the preview
entirely, which at 1366×768 takes the timeline from 210 px to about 400 px. That
is the "give me the whole screen" switch. Note that a graph height the admin
pinned with the grip is remembered and overrides the responsive default.


**Settings drawer floats.** It is absolutely positioned under the measured top
bar, so opening it takes *zero* height from the workspace — previously it pushed
the timeline out of view, which is one of the ways the editor could vanish.

**Narrow viewports** (`max-width: 1180px`, which is also where a 1366-wide laptop
lands at 125 % zoom) switch to one column that scrolls as a whole, with the footer
pinned by `position: sticky; bottom: 0` and `scroll-padding-bottom: 72px` so the
"follow the singing line" scroll never parks a row behind it. The graph and the
timeline keep real heights there too.

## Voice graph

A two-lane strip between the stage and the timeline. It answers the two
questions a stamping pass actually asks, from what is **seen** rather than
remembered:

| Lane | Shows | Why it is there |
| --- | --- | --- |
| Top | **Voice-note piano roll** — one rounded block per sung note, a note-name ruler on the left, a bright contour through the notes | Amplitude says nothing about pitch. "That line comes in on the low note" was simply not visible before; an octave jump used to be indistinguishable from a loud vowel |
| Bottom | Waveform (peak envelope) + vocal-energy guide + **note-onset ruler** | Where a phrase physically begins |

Both lanes share one canvas, so a cue boundary is a single vertical line the eye
can follow from "how high is the voice" straight down to "where the word starts".
That is what makes one pass fast: the melody tells you *which* line is being
sung, the onset tells you *exactly* where it starts.

| Element | Meaning |
| --- | --- |
| Cyan blocks | One sung note at its pitch; the block's height is the note's height |
| White contour | The melody, drawn through the note centres and broken across rests |
| Note-name ruler (left) | `C4`, `G4` … — a bright line at every C, a fainter one at every G |
| Grey-blue columns | Peak envelope (min/max per pixel column, extreme-preserving when zoomed out) |
| Warm band along the bottom | Vocal-energy guide: buckets whose RMS is a meaningful fraction of the loudest one |
| Amber ticks | Detected note onsets (sample-accurate; see below) |
| Gold vertical lines | Every cue start; the selected cue's window is shaded blue |
| Red line + dot | The playhead, on the same clock as the audio; the white dot rides the pitch of the sounding note |
| Note chip in the header | The note being sung **right now** — `A3 · 220 Hz`, or `— rest` |
| Hover label | The time under the cursor, plus the note there |

The vertical scale covers the sung range: the 2nd..98th percentile of voiced
frames, rounded outward to whole semitones, with a twelve-semitone floor (a
narrow melody is not blown up into a cliff) and a thirty-semitone ceiling (one
shouted outlier cannot flatten everything else). Both edges carry half a block
of padding, so the highest and lowest notes are never clipped.

**Controls.** `−` / `+` zoom around the playhead, `Fit` shows the whole track,
`Focus cue` frames the selected line, `Hide` collapses the strip. `Snap` (on by
default) makes a click land on the nearest note onset instead of the exact
pixel. `Notes` hides the melody lane, leaving the waveform. The **grip** under
the strip drags it taller or shorter (arrow keys when focused, `Home` to reset);
the height, the Snap state and the Notes state are remembered per browser.
Clicking the graph seeks; dragging scrubs; clicking within 7 px of a cue
boundary selects that line and jumps to it. The canvas is focusable, and
`Home`/`End` jump to the start/end of the analysed track.

### How the notes are found

The same bytes the player uses are fetched, decoded **once** in the tab through
an `OfflineAudioContext` at **11025 Hz** (the graph needs resolution in time, not
audio bandwidth — decoding 15 minutes of stereo at 44.1 kHz would hold hundreds
of MB of `Float32`), then reduced twice, both times from that one decode:

1. **6000 buckets** of min/max + RMS + a "carries voice" flag, cached per URL
   (3 entries), for the waveform and the energy guide.
2. **A YIN pitch tracker** (de Cheveigné & Kawahara, *JASA* 111:1917–1930,
   2002) over the mono mixdown: difference function, cumulative-mean normalised
   difference, absolute threshold, parabolic interpolation. 40 ms hop,
   640-sample window (~58 ms), 64 Hz–1 kHz.

The pitch pass runs in **~9 ms cooperative slices** (`setTimeout` between
slices), so the transport, the playhead and the keyboard stay responsive and a
track change simply invalidates the job. Frames are grouped into notes (a split
needs two frames more than 0.75 semitones from the running mean, so vibrato
stays one note). The RMS envelope also yields the **onset index**: a coarse
pass finds each rise, then a fine pass walks the raw samples backwards from a
peak-|x| envelope, which is what makes an onset accurate to milliseconds rather
than to a 40 ms frame.

Every constant above is **measured**, not chosen by eye — the harness and the
accuracy table are in "Verification performed".

**Honest limits.** The tracker is **monophonic**: over a loud drone or a busy
interlude it follows whichever voice dominates, and it reports that note
honestly rather than inventing two. A track with no pitched content reports
"no sung notes found" and falls back to the waveform alone. The energy band and
the notes are *aids*; nothing in the validation, export or save path reads them,
because the timings come from the admin's stamps alone.

**Failure is never fatal.** An unsupported codec, a file over 160 MB, or a
browser without `OfflineAudioContext` degrades to a message plus a `Retry`
button. The pitch pass failing or finding nothing leaves the waveform and the
energy guide exactly as they were. The clock, stamping, export and Save keep
working, because the graph is an aid and never a dependency. A decode superseded
by another track is aborted and never reported as an error.


## Media

* Default: the track's own audio via the public `/stream/:id/file` (Range
  supporting), falling back to `/api/admin/audio/file` for karaoke.
* `Load Media`: any local audio/video file is played as the timing reference.
  It is never uploaded — the file is read in the browser as an object URL, so a
  video song can be timed against its own picture.
* A `<video>` element is used for both, so there is exactly one clock; when the
  file has no video track (`videoWidth === 0`) it is hidden and the cover art
  becomes the stage backdrop.

## Verification performed

Both harnesses live in `server/tools/` and are rerunnable:

```
node server/tools/_voice_notes.test.mjs           # tracker accuracy + speed
node server/tools/_voice_notes.test.mjs --tune    # + how the constants were swept
node server/tools/_voice_notes.browser.mjs        # headless Edge, pixels + layout
```

`_voice_notes.test.mjs` **extracts** the tracker's functions and constants out of
`server/admin.html` and evaluates them in a sandbox — a test that runs its own
copy of an algorithm proves nothing about the code that ships. It also asserts
that the constants still equal the documented set, so the table below cannot
silently stop being true.

### Voice-note tracker (45/45, synthetic ground truth)

| Property | Result |
| --- | --- |
| Steady harmonically rich tones, C2 (65.4 Hz) → A5 (880 Hz) | ≤ 2.4 cents error on every tone, no octave errors |
| Weak fundamental (harmonics louder than f0 — a soft chest voice) | ≤ 2.2 cents on 155 / 233 / 349 / 523 Hz |
| Vibrato 1.2–3 % at 4.5–6 Hz | median within 25 cents and held as **one** note |
| Glide 200 → 400 Hz | start and end within 45 cents, several notes |
| Silence | 0 voiced frames |
| White noise | 0 % of frames voiced |
| Known melody D3 → C5 → G3 | three notes, correctly named, ordered and timed (±60 ms) |
| Onset precision, abrupt sung onsets | mean \|error\| **0.9 ms** on 0.500 s and 1.800 s |
| Onset precision, 120 ms swell | lands inside the swell (0.44 s for a 0.40–0.52 s swell) |
| Melody over a steady drone | follows the louder voice (the documented monophonic limit) |
| Speed | 211 µs/frame → a 60 s track in ~320 ms, a 5-minute track in ~1.6 s of *background* slices |

The onset-refinement constants (`envMs`/`frac`/correction) were chosen by
sweeping them over 88 ground-truth onsets — 8 pitches × 5 deliberately
non-aligned lead offsets × 2 levels, plus soft swells — and taking the set with
the smallest mean error, not by eyeballing the graph. `--tune` reruns that sweep.

### Browser (61/61 in headless Edge over CDP, against a stubbed admin API)

Runs the real page and a real 4.6 s WAV whose melody is D3 → C5 → G3, then reads
the canvas pixels back — because "the note is drawn high" is a claim about
pixels, not about code.

* Boots, loads the track, opens the studio, decodes the audio, finishes the note
  pass; the header reports the sung range as `notes D3–C5`.
* **The high note is drawn high**: C5's block centre sits at 5 % of the canvas
  height, D3's at 53 %, G3 between them; the blocks are 4–5 CSS px tall (blocks,
  not hairlines); nothing is drawn over the silence; the top note is not clipped.
* The note-name ruler draws at least three note names in a reserved gutter, and
  no note block spills into it.
* The live chip reads `C5` at 2.3 s, `D3` at 1.0 s and `—` over the silence.
* **One click lands the cue on the note**: a click 50 ms after the C5 onset
  snaps to 1.804 s; with `Snap` off the same click stays at 1.850 s.
* `Notes` off removes every note block and on brings them back; the grip resizes
  the strip and the canvas re-measures; zoom adds the window to the header and
  `Fit` restores it.
* Regressions intact: stamping writes `00:00.500` / `00:01.800`, `Save` PUTs
  `synced_lyrics`, the generated document is valid SubRip with three cues, and
  the status says *Saved & verified* rather than merely sent.
* Zero page exceptions, zero console errors.

### Layout (24/24 checks at six viewports)

1920×1080, 1536×1024, 1440×900, 1366×768, 1280×720, 1093×614: the voice graph is
≥ 120 px, the timeline ≥ 190 px, `Save` is inside the viewport, and the graph and
the timeline are either both on screen or the whole column scrolls (the
documented narrow/short branch). See the measured table above.


### Repository suites, unmodified

`admin-static-verify` (all three inline script blocks parse; no new duplicate
element ids), `admin-filters.test` (25/25), `admin-filters.e2e` (24/24),
`auto-sync-admin-ui` (15/15), `auto-sync-lyrics` (44/44), `auto-sync-cues`
(35/35), `auto-sync-endpoint` (20/20), `aws-secrets` (8/8),
`openai-second-opinion` (15/15) — 186/186 passing.


## Deliberately not done

* No automatic alignment or transcription inside the studio. Proposals from
  Auto-Sync / Build-from-SRT still arrive through their own panels; the studio is
  the human pass that finishing timing needs.
* **No automatic cue placement from the onsets.** The onset index powers
  click-to-snap and the amber ruler, but the studio never writes a cue the admin
  did not stamp: a detected onset is evidence, not a decision.
* No polyphonic pitch tracking. The YIN pass reports the dominant voice and says
  so; two simultaneous singers would need a source-separation stage that would
  not be worth its cost for a hand-timing tool.
* Translation columns are not edited here (see above).

## Changed since the first version

* **The voice graph got a melody lane.** It used to be a 64–104 px waveform:
  enough to see an onset, useless for the other half of a stamping decision —
  *which* note the line starts on. It is now a two-lane strip with a YIN pitch
  track drawn as a piano roll, a note-name ruler, a live "now singing" note chip,
  a sample-accurate onset ruler used for click-to-snap, a `Snap` toggle, a
  `Notes` toggle, and a drag grip for its height; and it defaults to
  `clamp(154px, 23vh, 300px)` instead of 64 px. The pitch pass runs cooperatively
  so the page never freezes, is strictly additive (a failure leaves the old
  waveform+energy graph exactly as it was), and costs one extra 13 MB mono
  mixdown per cached track, released as soon as the analysis lands.

  onset is easier to place against a visible edge than against memory, which is
  exactly what slows a hand-timed pass down.
* **The graph moved the strip's height out of the preview, not the timeline.**
  Raising the strip to 207–248 px on a large screen costs the preview about
  70 px (it is the decorative panel, so it yields) while the timeline stays on
  its 210 px floor; at 1280×720 the column scrolls rather than hiding either
  panel, which is the same documented branch as before.
* **Switching tracks writes the outgoing draft first.** The timeline is replaced
  wholesale when the track changes, so the pending draft is flushed before the
  switch; returning to that track offers the timings back instead of a blank
  editor.
* **Selecting a line redraws the graph.** The selected cue's window is drawn on
  the graph, so a selection change has to invalidate that layer — without it the
  shading stayed on the previously selected line (caught by the pixel check).
* **The workspace is a split, not a stack.** The timeline used to be the only
  panel that could shrink, so on a short viewport — or with the Settings drawer
  open — it collapsed to nothing while the graph and the preview kept their
  height. The preview now yields first, the timeline has a 210 px floor, the
  drawer floats, and the footer is pinned. See "Workspace layout" above.
* **A missing offline decoder fails fast.** It is detected before the track is
  downloaded, instead of after a full fetch that could never be used.
