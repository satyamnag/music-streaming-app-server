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
* **40/40 browser checks** in headless Edge over CDP against a stubbed admin API
  serving a real 60 s WAV: entry points wired, track/lyrics load, media
  metadata, stamping (derived ends, tail), nudge, shift-all, exact exported SRT,
  save → PUT body → stored row, refusal of a backward cue, keyboard `S`, close
  and reopen from the saved column, LRC detection, and inert markup. Zero page
  exceptions, zero console errors.
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
