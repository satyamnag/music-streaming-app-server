# SyncAlong evaluation for sync lyrics — and what the language model adds

**Status:** evaluated and not adopted as the timing source. The shipped timeline is
unchanged and was not touched.
**Nothing was written to the database.** Evaluated 2026-11-02 on *Gopala Baala*
(`9f2a7923-142f-49e5-bd3b-bff886b8d7a5`, 454 s, 20 lyric lines).

Requested: use [syncalong](https://syncalong.readthedocs.io/en/stable/) to build the
track's three sync-lyric SRTs, with the OpenAI model, and make them 100% correct.

## Why SyncAlong was worth testing (unlike aeneas)

| Fact | Source |
| --- | --- |
| Whisper word timestamps + a **Needleman–Wunsch style dynamic-programming** aligner that maps the known lyrics onto the transcript. No TTS step, no language list. | https://syncalong.readthedocs.io/en/stable/how-it-works/ |
| **"Each lyric line takes the timestamp of its earliest matched word"** — one timestamp per lyric *line*. | same page, step 4 |
| Unmatched lines are **interpolated / extrapolated**: "gives a rough estimate rather than leaving gaps" and "every non-blank line comes out timed". | same page, step 4 |
| Alignment is **"strictly order-preserving"**: "Lyric word 5 can't match a transcript word that comes before word 4's match." | same page, step 3 |
| Output is **LRC** — a start time per line. MIT licence. | home page |
| `align_lyrics_to_transcript(lyric_lines, transcript, *, threshold=55.0) -> list[tuple[LyricLine, float \| None]]` | https://syncalong.readthedocs.io/en/stable/reference/align/ |

Point 4 is the decisive one and it is structural, not a quality issue: an
order-preserving aligner consumes each lyric word **at most once**, so a refrain that
the lyrics list once and the singer sings **eight times** can be timed to exactly one
of those eight. Every other occurrence has no cue, and the interpolation step then
invents timings for anything left over.

Unlike aeneas it *can* handle Telugu (no TTS voice involved), so this was tested for
real.

## What was run

`.github/workflows/syncalong-poc.yml`, read-only, syncalong **2.0.1**, MIT:

1. **Injected (headline measurement)** — syncalong's aligner fed the *best transcript
   that exists* for this track: the committed large-v3 word stream (131 words).
   This is syncalong at its strongest, so the result is not limited by using a
   weaker Whisper model.
   `align_lyrics_to_transcript()` returned 20 pairs, **20/20 matched** (nothing
   needed interpolation).
2. **CLI end-to-end** — the tool's own path,
   `syncalong lyrics.txt track.audio --model tiny`, exit 0, 20 cues, 3m14s CPU.

## Measured against the shipped timeline

Same coverage / suspect tests used for certification. Because LRC carries only a
start time, cue *i* is scored as `[t_i, t_{i+1})` — exactly how a player renders it.

| | syncalong (best transcript) | shipped pipeline |
| --- | --- | --- |
| cues | **20** | **36 sung** (+14 music) |
| cues containing no sung words | 0 | 0 |
| **suspect cues** | **4** | **0** |
| mean anchored-onset coverage | **0.6540** | **0.9341** |
| refrain occurrences represented | **1 of 8** | 8 of 8 |

Line-by-line, syncalong vs the first occurrence we ship:

```
L 0  syncalong  55.92s   ours  20.82s   +35.10   pallavi
L 1  syncalong  58.85s   ours  22.22s   +36.63   paapaalu maavi...
L 2  syncalong  61.78s   ours  54.52s    +7.26   kopala kadali...
L 3  syncalong 128.78s   ours  59.00s   +69.78   opika naavai...
L 4  syncalong 183.08s   ours 180.84s    +2.24   chesaanu naadu...
...
L12  syncalong 322.36s   ours 322.36s     0.00   ahamane agnilo...
L15  syncalong 339.72s   ours 339.72s     0.00   mohana krishnaa...
L18  syncalong 405.82s   ours 405.82s     0.00   kari raaja varada...
```

**This is a genuinely useful finding in both directions.** For the lines that occur
once — every charanam line — syncalong's timing is *identical* to ours (delta 0.00
on 8 of them, ≤ 2.5 s on the rest), which independently corroborates the shipped
timings. For the four lines that repeat (pallavi, its second line, the anupallavi
pair) it is wrong by **+7 s to +70 s**, because it can only represent one occurrence.

The end-to-end CLI run with the `tiny` model was worse still — it gave three
different lines the **same** timestamp `[01:05.34]`, the signature of an aligner that
could not match and fell back to interpolation.

## What the language model adds — again a real, retained improvement

`gpt-4o-mini` (official `/v1/responses`, strict JSON schema, via
`server/libs/openaiLyricSecondOpinion.mjs`) was asked, for every lyric line, **which
of the 36 measured cue spans sings it** — it may only choose among spans we supply,
never invent timing.

| | model-chosen span contains the timestamp |
| --- | --- |
| **shipped timeline** | **20 / 20 (100%)** |
| syncalong | 16 / 20 (80%) |

All four misses are exactly the repeated lines above. The model is therefore kept as
an **independent verifier** of the shipped artifact (recorded in
`docs/SYNC-LYRICS-CERTIFICATION.md`), never as a timing source.

## Decision

1. **Do not adopt syncalong as the timing source.** It is a correct, well-built
   implementation of a *monotone* aligner, and that model of the problem cannot
   represent a repeated refrain — 1 cue where the recording has 8, and it then
   invents timings for whatever does not match.
2. **Keep the deterministic greedy segmenter**, which is the one design in this
   evaluation that emits *one cue per sung occurrence*, all on measured word
   boundaries, with nothing interpolated.
3. **Keep the language model as a verifier.** It is the only independent check that
   scored the shipped artifact 20/20.

## Note on the three-column requirement

syncalong emits a single LRC for the lyric language only; the other two columns can
only be derived by rendering the same timeline (as the pipeline does). That is
already handled by `renderCuesForVariant`, so it was not a blocker — the blocker is
the one-timestamp-per-line model above.

## Reproduce

```bash
gh workflow run syncalong-poc.yml -f ids=9f2a7923-142f-49e5-bd3b-bff886b8d7a5
# artifacts: syncalong-injected (aligner + LRC), syncalong-cli (end-to-end LRC)
```

Read-only: neither job writes to the database.
