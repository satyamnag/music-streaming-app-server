# Forced alignment / WhisperX — evaluation and decision

**Status:** rejected for now (decision recorded 2026-11-02)
**Scope:** the sync-lyrics pipeline in `server/tools/` and `server/libs/autoSyncLyrics.mjs`
**Nothing was written to the database as part of this evaluation.**

## Question

Would replacing the current whisper-word pipeline with WhisperX + wav2vec2 forced
alignment make the synced lyrics 100% accurate?

## What was verified in the official sources first

| Fact | Source |
| --- | --- |
| WhisperX = faster-whisper + wav2vec2 forced alignment + VAD + diarization. The only component we do not already have is the alignment step. | https://github.com/m-bain/whisperX |
| Telugu is in `DEFAULT_ALIGN_MODELS_HF`: `"te": "anuragshas/wav2vec2-large-xlsr-53-telugu"` | https://github.com/m-bain/whisperX/blob/main/whisperx/alignment.py |
| `align()` is per given segment: it can only refine timings inside a segment we already produced. It cannot discover which line is sung where. | same file |
| Documented limitations: characters absent from the model dictionary get no timing; "language specific wav2vec2 model is needed". | whisperx README → Limitations |
| `torchaudio.functional.forced_align(log_probs, targets, input_lengths, target_lengths, blank)` → `(alignment, scores)`; batch size must be 1; `T >= L + repeats`. | https://docs.pytorch.org/audio/stable/generated/torchaudio.functional.forced_align.html |
| Model `vocab_size=66`, `pad_token_id=65`; published `vocab.json` has exactly 66 entries (0..65, `|`=30, `[UNK]`=64, `[PAD]`=65). | https://huggingface.co/anuragshas/wav2vec2-large-xlsr-53-telugu/raw/main/config.json and `/vocab.json` |

### The old blocker is solved

A previous attempt with `ctc-forced-aligner` aborted on `get_vocab()=68` vs
`vocab_size=66`. Cause: `tokenizer.get_vocab()` appends the added tokens `<s>`
and `</s>` at ids 66/67, which are **not** output columns. Filtering the map to
`id < vocab_size` resolves it; the PoC confirms
`vocab_size=66, alignable chars=66, blank=65`.

## Evidence (read-only PoC, GitHub Actions, CPU)

`server/tools/forced_align_poc.py` + `.github/workflows/forced-align-poc.yml`,
run on *Gopala Baala* (454 s, 36 sung cues). Each cue's exact plain-lyric line was
force-aligned inside the inter-cue window (±1.0 s).

| Metric | Result |
| --- | --- |
| lines aligned | 36 / 36 |
| mean alignment probability | median **0.185** (p10 0.063, p90 0.527) |
| cues with p >= 0.5 | **5 / 36** |
| cues with p < 0.1 | 7 / 36 |
| high-confidence cues: \|Δend\| | **0.02 s** — current ends are already correct |
| high-confidence cues: \|Δstart\| | **0.64 s**, 3 of 5 pushed later by > 0.5 s |
| boundaries saturated at the ±1.0 s window edge | 3 |

Representative rows (current → aligned, p):

```
 20.82- 22.22 ->  19.82- 22.92  p=0.000   pallavi (whisper merged the line into one token)
127.38-131.64 -> 126.40-131.12  p=0.095   opika naavai okasaari raavaa
217.94- 220.74 -> 216.94- 220.76 p=0.021  pallavi repeat
400.40-405.82 -> 401.18-405.82  p=0.835   korkela yadusulo kuulemu devaa
```

## Decision

**Do not adopt WhisperX or forced alignment as the timing source.** Keep the
deterministic `whisper-segment-sync.mjs` pipeline.

Reasons, in order of weight:

1. **Confidence is too low on sung Telugu.** A speech-trained CTC model reaches
   only p >= 0.5 on 5 of 36 lines. Forced alignment always returns *a* path, so
   low-p output looks like a result but is not evidence.
2. **The systematic start bias would be a regression.** Where the model *is*
   confident it wants to move every line start ~0.6 s later, while line ends
   already agree to 0.02 s. Applying that would visibly delay all lyrics.
3. **It solves nothing we actually still need.** The residual defects are (a)
   plain-lyric variants/duplicates that the recording sings once, (b) lines whose
   sung text differs from the plain lyrics, and (c) repetition discovery — which
   alignment explicitly cannot do (it is per given segment).
4. **Maintenance liability.** `torchaudio.functional.forced_align` is deprecated
   and announced for removal; torchaudio is in maintenance mode.

## Consequences

- The current pipeline stays the single source of timing; all existing gates
  (structure, shared timeline, strict cue gain, cue/audio agreement) remain in
  force and unchanged.
- `forced_align_poc.py` is kept as a reproducible experiment. It is read-only and
  must not be wired into the write path.
- WhisperX adds no capability over the faster-whisper large-v3 word stream we
  already generate on Modal.

## When to revisit

Only with an acoustic model trained on **sung** Telugu (or a fine-tune on this
catalogue), and only behind a confidence gate (accept an aligned boundary solely
when p >= 0.5), validated against the video-derived offsets already established
(Kavalini Eleti +10.41 s, Gopala Baala +8.84 s). Until then, alignment is not a
timing source.
