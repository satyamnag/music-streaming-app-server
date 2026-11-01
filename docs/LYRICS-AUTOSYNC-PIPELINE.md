# Admin Auto-Sync: plain Telugu lyrics → sync SRT

How the admin portal turns an author's **plain Telugu** column into timed
**sync lyrics**, what it deliberately refuses to do, and where every safety gate
lives.

Code: `server/server.js` (`POST /api/admin/tracks/:id/auto-sync`),
`server/libs/autoSyncLyrics.mjs`, `server/libs/openaiLyricSecondOpinion.mjs`.
Tests: `server/test/auto-sync-*.test.mjs`, `server/test/openai-second-opinion.test.mjs`.

---

## 1. Request path

| Step | Where | Notes |
|---|---|---|
| Admin presses **Propose timings from audio** | `server/admin.html` → `runAutoSync(false)` | writes nothing |
| Admin presses **Propose & Save** | `runAutoSync(true)` | gated write, see §5 |
| Endpoint | `server.js` `POST /api/admin/tracks/:id/auto-sync` | admin session required |

Refusals before any work happens:

- **409** — the track already has timed lyrics (`parseTimedLyrics`). Verified work is
  never overwritten; `force: true` re-runs it as a *suggestion* only.
- **400** — no `plain_lyrics` (nothing to align against) or no `storage_path`.
- **503** — no Deepgram key configured.

## 2. Audio and transcription

1. `HEAD` then `GET` the track's object from R2. Whole object buffered because the
   Deepgram pre-recorded API is a single POST; capped at **40 MB** so one request
   cannot exhaust the container. SHA-256 of the bytes is recorded on the audit row,
   which is the only way to prove later which audio produced a timing.
2. Deepgram `POST /v1/listen` with `model=nova-3`, `language=te`,
   `smart_format=false`, `punctuate=false`, `utterances=false`, `diarize=false`.
   Formatting is off on purpose: it rewrites words, which only adds noise when the
   job is to match the author's own text.
3. Result: word-level `{word, start, end, confidence}` plus `metadata.duration`.

**The Listen API re-transcribes; it does not align a known script.** There is no
forced-alignment parameter. Everything below is therefore *our* matching of a
transcript against the author's text.

## 3. Deterministic alignment (`alignLyrics`)

- Lines are split and classified: `lyric`, `{Section}`, `{{Music}}`, empty.
  **Any** single-brace label is a heading — `{Pallavi}`, `{Charanam 5}`, `{Intro}`,
  `{any_text}` — not a fixed list. The regex is identical to the one the web and
  Android renderers use, so the apps and the timeline can never disagree.
- Words are normalised (NFC, lowercase, punctuation stripped, **combining marks
  kept**) and compared by akshara-bigram Dice similarity ≥ **0.5**.
- A weighted DP (MATCH `+26`, MISMATCH `−18`, gaps `0`) assigns each transcript word
  to at most one lyric line, globally, in order.
- A line's span is the min/max of its own matched words.
- Per-line confidence = `min(coverage, mean ASR confidence, plausibility)` where
  plausibility penalises impossible durations and substantial monotonicity
  inversions.

**Gate:** `alignment.ok` requires match rate ≥ **0.7**, every line placed, and the
**worst** line ≥ **0.55** (`DEFAULT_CONFIDENCE_FLOOR`).

## 4. Cue building (`buildSyncCues` / `renderCuesForVariant`)

Produces the actual SRT timeline:

- **Headings never become cues.** They stay in the plain column (the apps draw them
  as ornament dividers) and are absent from the SRT.
- **`{{Music}}` for everything the voice does not cover** — leading intro,
  interludes, outro — where the gap is ≥ **3 s**. A held note is not an interlude,
  hence the threshold. Both apps already render `{{Music}}` as the "♪ Music ♪" banner.
- **Repeated lines get one cue per sung occurrence.** A run of transcript words that
  was not claimed by any placed line is compared against each placed line
  (mean similarity ≥ **0.6**, ≥ **50 %** of the line's words); if it matches, that
  line is emitted again at the run's measured time. Unrelated speech cannot be
  promoted this way.
- Every cue **ends where the next begins**, so the highlight holds through a held
  note instead of blinking off.
- Times are emitted verbatim as `HH:MM:SS,mmm` — never rounded, never re-derived.

All five language columns are rendered from **one** timeline built from the Telugu
alignment, so a Telugu-only banner can never shift a translation column.

## 5. Write safety

Opt-in with `write: true`. Four independent conditions must all hold:

1. `alignment.ok` — every line cleared the bar.
2. The track has **no existing** timed lyrics, re-read from the DB (not the request).
3. Every lyric line is **byte-identical** to the author's plain line.
4. Every rendered SRT passes the same validator the admin UI uses.

Then: update → **read-back verify** → on any mismatch the previous values are
restored automatically. The pre-write snapshot is stored on the audit row
(`lyric_auto_sync_runs.previous_srt`, migration 037) and
`POST /api/admin/tracks/:id/auto-sync/rollback/:runId` restores it once.

`enhance: true` selects the enhanced timeline (Music banners + repeats). Without it
the legacy line-only proposal is produced and written — byte-identical to the old
behaviour, so an older admin page keeps working.

## 6. Optional OpenAI second opinion

`server/libs/openaiLyricSecondOpinion.mjs`. **Default OFF**: needs
`OPENAI_SECOND_OPINION=1` *and* a key.

- Groups word timings into sung segments (split on gaps > 2.5 s).
- Asks a model — Strict Structured Outputs (`json_schema`, `strict`, temperature 0)
  — **which measured segment sings which line**, `-1` for none.
- Positions **only lines the aligner left unplaced**, using the segment's own
  measured start/end. It is never asked for a timestamp and cannot create one.
- Assisted lines are capped at confidence **0.5**, below the 0.55 floor, so an
  assist can never turn a refused alignment into an automatic write.
- Fail-closed: no key, flag off, timeout (45 s), refusal, HTTP error, malformed
  JSON or an out-of-range index all leave the deterministic result untouched.

**It does not improve millisecond accuracy.** The model never hears the audio; every
second it returns was already measured from the OPUS by Deepgram. What it improves
is *placement* — lines whose sung form is respelled (`వెలగేటి` sung as `వెలిగేటి`) or
split across beats, which the akshara matcher cannot place.

Privacy/cost: with the flag on, a run sends that track's Telugu lyrics and
transcript text to OpenAI, and adds a per-track API cost on top of Deepgram.

## 7. What the admin sees

The report prints lines placed, match rate, lowest confidence, words heard, and —
when the option was used — Music banners, repeated-line cues and total cues. Flagged
lines show **`words n/m`** so "nothing heard" is only claimed when the count really
is zero. Each line carries a server-computed `flagged` flag using the same floor
that gates the write, so the list and the headline count cannot disagree.

## 8. Enabling flags (all default off)

| Variable | Effect |
|---|---|
| `DEEPGRAM_API_KEY` / Vault `deepgram_api_key` | required for Auto-Sync at all |
| `OPENAI_SECOND_OPINION=1` | turns the lyric second opinion on |
| `AWS_SECRETS_ENABLED=1` | secrets from AWS Secrets Manager (see `SECRETS-AWS.md`) |
