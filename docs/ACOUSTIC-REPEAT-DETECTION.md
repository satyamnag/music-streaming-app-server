# Acoustic Repeat Detection

## Why this exists

Deepgram's `/v1/listen` **re-transcribes**; it does not align a known script to
audio. When a line is sung a second time more quietly, with a different timbre,
or under instrumental masking, Deepgram may not emit those words at all. In that
case no transcript-based path can timestamp the second occurrence.

The track `మల్లె మాలలు` is the concrete failure: its opening four lines are sung
**twice**, but the sync SRT holds them once, because the second singing was not
heard as words.

This module recovers those occurrences from the **audio's acoustic structure**
rather than from transcription. It detects vocal onsets and repeated stanzas
directly from the energy envelope, so a repetition is timestamps-able even where
ASR produced no words.

## Method (signal-processing foundation)

1. **Demux** the track to mono PCM (via ffmpeg) at a fixed sample rate.
2. **Short-time energy envelope** — frame the samples, take root-mean-square,
   normalise to peak. This is the standard vocal-activity proxy; the sung phrase
   is where energy rises and sustains.
3. **Onset detection** — the envelope crossing a hysteresis threshold (enter
   above `onset_high`, exit below `onset_low`) with a minimum re-trigger gap, so
   a held note / breath is not split into two onsets.
4. **Stanza self-similarity** — an onset sequence is sliced at phrase-length
   gaps; a repeated stanza is where two non-overlapping onset patterns match
   above a similarity floor. Each match yields a measured `[start, end]` for the
   *second* (and subsequent) occurrence, independent of any word.
5. **Error bounds** — each onset carries a measured uncertainty derived from the
   envelope's slope at crossing; no timestamp is reported as exact.

This is standard voice-activity detection + onset detection; no ML is required
and the result is deterministic (same audio → same segments).

## Timestamp authority (hybrid)

For a repeat line:
- **Acoustic onset** supplies the occurrence's `start` and `end` (it is the only
  source that exists when Deepgram had no words there).
- **Deepgram word times** (when present) refine the boundary *within* the
  acoustic span.
- The reported timestamp is never more precise than the measured error bound.

`{{Music}}` gaps and `{Section}` headings are untouched by this module.

## Safety contract

- **Read-only by default.** The detector emits a JSON report; it writes nothing.
- A write path, if enabled, is gated by the *same* rule as the rebuild tool:
  a track is replaced only when the new timeline has **strictly more sung cues**
  (recovered repeats) OR repairs a structural timing defect — never otherwise.
- Every write is preceded by a backup (`lyrics-backup.json`) and is restorable
  via `--restore`.
- Compute runs on **GitHub Actions** only (never the web dyno), dry-run-first,
  with `::add-mask::` on every AWS-resolved secret (the repo is public).

## Files

- `server/tools/acoustic-repeat-detect.py` — the detector (Python, Actions).
- `server/libs/autoSyncLyrics.mjs` — ingests acoustic segments and merges
  onset-timed repeats (hybrid with Deepgram words).
- `server/tools/lyrics-rebuild.mjs` / `lyrics-audit.mjs` — orchestrators.
- `.github/workflows/repeat-detect.yml` — the Actions entry point.

## Honest limit

Structural correctness (no missing repeats, monotonic/non-overlapping/in-range,
sane durations) is machine-verifiable and is guaranteed. **Millisecond-exact
timestamps have no ground truth on sung audio** — they are estimates with
reported error bounds, never asserted as "100% perfect".
