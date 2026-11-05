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
| Voice graph | fixed `clamp(64px, 8.5vh, 104px)` canvas | a squashed waveform is useless; it keeps a readable height |
| Timeline editor | `flex: 2 1 280px`, **never below 210 px** | the working surface; this floor is what stops it collapsing |
| Footer (Save / Export) | own grid row, spanning both columns | never scrolls away |

Measured with the layout harness (canvas height / timeline card height):

| Viewport | Preview | Graph | Timeline | Column scrolls? |
| --- | --- | --- | --- | --- |
| 1920×1080 | 265 | 84 | 389 | no |
| 1536×1024 | 248 | 79 | 355 | no |
| 1440×900 | 210 | 69 | 280 | no |
| 1366×768 | 126 | 64 | 252 | no |
| 1280×720 | 110 | 64 | 220 | no |
| 1093×614 (narrow branch) | 140 | 64 | 381 | yes, by design |

**Short viewports** (`max-height: 820px`) shrink the preview first (to 88 px) and
tighten the transport, so the graph and timeline keep their heights instead of
the timeline disappearing.

**`Preview` toggle** (top bar, remembered in `localStorage`): hides the preview
entirely, which at 1366×768 takes the timeline from 252 px to **400 px**. That is
the "give me the whole screen" switch.

**Settings drawer floats.** It is absolutely positioned under the measured top
bar, so opening it takes *zero* height from the workspace — previously it pushed
the timeline out of view, which is one of the ways the editor could vanish.

**Narrow viewports** (`max-width: 1180px`, which is also where a 1366-wide laptop
lands at 125 % zoom) switch to one column that scrolls as a whole, with the footer
pinned by `position: sticky; bottom: 0` and `scroll-padding-bottom: 72px` so the
"follow the singing line" scroll never parks a row behind it. The graph and the
timeline keep real heights there too.

## Voice graph

A 96 px strip between the stage and the timeline shows the whole track's
amplitude, the regions that carry voice, and every cue boundary — so a stamp can
be placed from what is **seen**, not only what is remembered. Stamping by ear
drifts on sustained notes; an onset is visible.

| Element | Meaning |
| --- | --- |
| Grey-blue columns | Peak envelope (min/max per pixel column, extreme-preserving when zoomed out) |
| Warm band along the bottom | Vocal-energy guide: buckets whose RMS is a meaningful fraction of the loudest one |
| Gold vertical lines | Every cue start; the selected cue's window is shaded blue |
| Red line + dot | The playhead, on the same clock as the audio |
| Hover label | The time under the cursor |

**Controls.** `−` / `+` zoom around the playhead, `Fit` shows the whole track,
`Focus cue` frames the selected line (its window ± 60 %), `Hide` collapses the
strip. Clicking the graph seeks; dragging scrubs; clicking within 7 px of a cue
boundary selects that line and jumps to it. The canvas is focusable, and
`Home`/`End` jump to the start/end of the analysed track.

**How it is built.** The same bytes the player uses are fetched, decoded **once**
in the tab through an `OfflineAudioContext` at **11025 Hz** (peaks need
resolution in time, not audio bandwidth — decoding 15 minutes of stereo at
44.1 kHz would hold hundreds of MB of `Float32` for a 96 px strip), then reduced
to 6000 buckets of min/max + RMS and cached per URL (3 entries, ~72 KB each).
The static layer is rendered once into an offscreen canvas and blitted per frame,
so following the playhead costs one `drawImage`.

**Honest limits.** The energy band is an *aid*, not voice detection: it is a
simple adaptive threshold (10 % of the loudest bucket, one-bucket dropouts
closed) and it is labelled "guide" in the code for that reason. Nothing in the
validation, export or save path reads it — the timings come from the admin's
stamps alone.

**Failure is never fatal.** An unsupported codec, a file over 160 MB, or a
browser without `OfflineAudioContext` degrades to a message plus a `Retry`
button. The clock, stamping, export and Save keep working, because the graph is
an aid and never a dependency. A decode superseded by another track is aborted
and never reported as an error.

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

* `node --check` on `server.js` and on the extracted studio script; balanced
  markup; no duplicate element ids.
* **60/60 browser checks** in headless Edge over CDP against a stubbed admin API
  serving a real 60 s WAV (with a loud/quiet envelope so the energy guide has
  something real to find), run four times consecutively with zero failures:
  entry points wired, track/lyrics load, media metadata, **voice graph decoded,
  canvas sized, drawn, described, energy band rendered, cue count, click-to-seek
  landing on the right time, playhead pixel at the seek point, selected-cue
  shading (and no shading elsewhere), zoom / Fit / Focus cue / Hide-Show, and a
  decode failure that still allows stamping and saving, then a cached track
  returning instantly**, stamping (derived ends, tail), nudge, shift-all, exact
  exported SRT, save → PUT body → stored row, refusal of a backward cue,
  keyboard `S`, close and reopen from the saved column, LRC detection, and inert
  markup. Zero page exceptions, zero console errors.
* **55/55 layout checks** in headless Edge, measuring real geometry at
  1920×1080, 1536×1024, 1440×900, 1366×768, 1280×720 and four narrow viewports
  (1180×820, 1093×614, 1024×768, 900×700): the graph is on screen and ≥ 40 px,
  the timeline is on screen and ≥ 190 px, both sit fully above the pinned footer,
  the graph is directly above the table, the table scrolls its rows internally
  rather than the page, the Save button is inside the viewport, hiding the
  preview grows the timeline (252 → 400 px at 1366×768) while keeping the graph,
  the toggle reports its state, the canvas re-measures after the change, and the
  Settings drawer takes no height from the workspace and is anchored under the
  top bar.
* **17/17 checks** against the validator functions *extracted from the shipped
  `server.js`*: valid SRT (including CRLF and a `{{Music}}` cue) accepted; LRC,
  textless cues, missing timings and noise rejected; `null`/`''`/absent handled.
* The repository's own suites, unmodified: `admin-static-verify` ,
  `admin-filters.test` (25/25), `admin-filters.e2e` (24/24),
  `auto-sync-admin-ui` (15/15), `auto-sync-lyrics` (44/44),
  `auto-sync-cues` (35/35), `auto-sync-endpoint` (20/20),
  `aws-secrets` (8/8), `openai-second-opinion` (15/15),
  `missing_column_error`, `featured_payload` — all passing.

## Deliberately not done

* No automatic alignment or transcription inside the studio. Proposals from
  Auto-Sync / Build-from-SRT still arrive through their own panels; the studio is
  the human pass that finishing timing needs.
* No wave-render thumbnail: the timeline table plus the live preview is what the
  stamping loop reads, and a waveform canvas would add a decode dependency for
  no gain in accuracy.
* Translation columns are not edited here (see above).

## Changed since the first version

* **Voice graph** added (see above). The earlier note that a waveform "would add
  a decode dependency for no gain in accuracy" was wrong for this workflow: an
  onset is easier to place against a visible edge than against memory, which is
  exactly what slows a hand-timed pass down.
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
