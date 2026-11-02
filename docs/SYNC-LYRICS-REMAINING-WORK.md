# Sync lyrics — what still remains, and who can fix it

Generated from a read-only catalogue verification on 2026-11-02.
**Plain lyrics are the source of truth and are never modified by any tooling.**

## Current state

| | |
| --- | --- |
| tracks in catalogue | 79 |
| fully valid (every line timed, shared timeline, coverage 0 → duration) | **51** |
| with problems | **28** |
| sung lyric cues in the database | 2479 |
| plain-lyric lines still untimed | 127 |

The pipeline, the write gate and the safety properties are unchanged. The items
below are the remainder, grouped by **what would actually fix them**. A track can
appear in more than one group (for example Madvacharya Nutha is both an
audio/lyrics mismatch and a translation problem), so the group sizes do not add
up to 28.

## Group A — sung text does not match the plain lyrics (3)

The transcription is confident (mean confidence 0.93–0.95) but *no* plain-lyric
line matches it well anywhere in the track, so no timing can exist.

| track | untimed / total | best fit anywhere |
| --- | --- | --- |
| Kanaka Durga Teru | 13 / 16 | **0.44** |
| Chintaamani Ganapathi | 19 / 20 | **0.50** |
| Madvacharya Nutha | (126 words outside every cue) | **0.40** |

Example — Kanaka Durga Teru, what the audio actually says:
`సంతింలింది సంతింలింది కదిలింది నేడు కనక దుర్గతేరు ఇది లాగి చూడు బ్రదుక…`

**This needs a human:** either the plain lyrics are a different rendition of the
song, or they use a different transliteration. No algorithm can time text that
is not what is being sung.

## Group B — translations are not line-parallel (11)

`renderCuesForVariant` maps translation line *i* to Telugu line *i*. When the
counts differ the shared timeline cannot be built, so the track is skipped
entirely — even where its Telugu segmentation is excellent.

| track | telugu vs translation |
| --- | --- |
| Ganesh Gayatri Mantra | 19 vs 14 (`en`) |
| Intitho Raamuni Poolaata | 21 vs 28 (`en`) |
| Kalyaanamu Loka Kalyaanamu | 30 vs 34 (`en`) |
| Haaratulettare Sreeraamuniki | 29 vs 23 (`en`) |
| Raama Raamaa Yanare | 21 vs 20 (`en`) |
| Bhadradri Ramayya Nidra Levayya | 29 vs 28 (`en`) |
| Ravi Vamsha Sudhaambhudi Soma | 22 vs 24 (`en_tr`) |
| Sukha Madhuvu Kadalilo | `en_tr` has 1 empty sung line |
| Madvacharya Nutha | `en_tr` not line-parallel |
| Raavayya Maa Intiki | `en_tr` not line-parallel |
| Vandanam Sreeraama! Inakula Soma | `en_tr` not line-parallel |

**This needs a content edit to the translation columns only** (never the Telugu
plain lyrics). Once the counts match, these tracks sync automatically on the next
gated run.

## Group C — correct data, blocked by a deliberately conservative gate (5)

The write gate rejects a track when 2+ cues score under 0.5 against the
transcription. On mantra-style tracks whisper merges words so heavily that the
transcription distorts systematically and the metric under-reports.

Verified by inspection on **Om Vigneshwaraya Namah**: all 36 occurrences carry the
correct plain-lyric line at the correct time, and **34 of 36** consumed *fewer*
tokens than the line has words (heavy merging), e.g.

```
TEXT  గం గం గం గం మహాగణపతయే నమః.
SUNG  గంగం గంగం మాగణ పతెయేనమా        (18.9-24.4s, score 0.670)
```

Same pattern: `Chintaamani Ganapathi`, `Kausalya Suta Raama`, `Om Vigneshwaraya
Namah`, `Raavayya Maa Intiki`, `Ravi Vamsha Sudhaambhudi Soma`, `Vandanam
Sreeraama! Inakula Soma`.

**Deliberately not bypassed.** Relaxing the gate, or adding an override, would
remove a safety net that currently prevents wrong cues from reaching the app.
Unblocking these needs a per-cue human review first — not a threshold change.

## Group D — individual untimed lines that are lyric variants (13 of 13 classified)

Each was classified by locating its best acoustic match and asking which cue
already covers it. All 13 fall into two kinds, neither fixable without editing
plain lyrics:

- **Variant / duplicate line** — the plain lyrics list two forms of the same
  verse line and the recording sings one, e.g. `శుభంకర శ్రీ గణనాధా` alongside the
  sung `సర్వ శుభంకర, గణ నాధా!`; `జై శ్రీరామ!` and `జయ జయ జయ జయ జై శ్రీరామ్!`
  both matching the same chant.
- **Transcription ambiguity** — two lyric lines claim the same tokens with
  comparable scores (e.g. `సిరిదాయి శ్రీరామచంద్రునికి జై!` at 0.839 vs the cue
  already placed there). Only one can be cued; the greedy walk picks the higher
  score.

Affected: Andala Hamsapai (4), Daiva Darshanam (1), Gajamukha Ganapati (1),
Gajaraja Vandana (1), Gam Gananatha! (2), Gangadhara Suta (1), Kaladu kalatalu
Teerchu (1), Mangala Ganapati (2), Ramuni Mandiram (2), Ramuniki Jai (1),
Ravamma Mahalakshmi (1), Shiva Shankara Vinutha (2), Sharanamayya Neeku (19 —
only 8 cues exist for 20 lines because the transcription produced ~8 words/min).

## What will not help

- **WhisperX / forced alignment** — evaluated and rejected, see
  `docs/FORCED-ALIGNMENT-EVALUATION.md`. On sung Telugu the CTC model is
  confident on only 5 of 36 lines and biases every start ~0.6 s late.
- **Lowering thresholds** — that converts "untimed" into "wrongly timed", which
  is worse for the user than an honest gap.

## Security follow-up (unrelated to sync, still open)

The Deepgram API key was exposed in a public Actions log earlier in this project.
Deepgram is no longer part of the pipeline. The key should be **rotated and the
old one deleted** in the Deepgram console — this requires account access and has
not been done by tooling.
