# Sync lyrics — single-track certification

Purpose: prove, on one track, that the whole pipeline produces a **correct** result
and that the database holds exactly it. This is the acceptance test to re-run after
any change to `whisper-segment-sync.mjs` or `sync-all-tracks.mjs`.

Read-only apart from the write it certifies. Exits non-zero on any finding.

```bash
cd server/tools
SUPABASE_ANON_KEY=... node sync-all-tracks.mjs --ids <id> [--refine]   # stage 0: pipeline output
SUPABASE_ANON_KEY=... node _certify.mjs "Gopala Baala"                  # stages 1-6
SUPABASE_ANON_KEY=... node _determinism.mjs <id> "Gopala Baala"        # determinism + DB equality
```

## Certified track: Gopala Baala

`9f2a7923-142f-49e5-bd3b-bff886b8d7a5` — 454 s, 131 measured words, 20 plain-lyric
lines, 36 sung cues, 14 music banners. Written by run `41480808351`.

**All 21 checks pass, exit code 0.**

| # | Check | Result |
| --- | --- | --- |
| 1-3 | database `synced_lyrics` / `_en` / `_en_tr` byte-identical to the pipeline output | PASS |
| 4 | timeline starts at 0 | PASS (0) |
| 5 | timeline ends exactly at the track duration | PASS (454 vs 454) |
| 6 | no gap and no overlap anywhere | PASS (0) |
| 7 | no zero-length cue | PASS |
| 8 | no duplicate cue start | PASS |
| 9 | no blank cue text | PASS |
| 10 | identical cue count across the three languages | PASS (50 / 50 / 50) |
| 11 | identical start/end at every index | PASS (0 mismatches) |
| 12 | identical music-mask at every index | PASS (0 mismatches) |
| 13 | every Telugu cue is an EXACT plain-lyric line | PASS (0 unknown) |
| 14 | every plain-lyric line is cued at least once | PASS (20/20) |
| 15 | plain lyrics unchanged by the pipeline | PASS |
| 16 | every sung cue has both translations at the same index | PASS (0 empty) |
| 17 | no cue is suspect (empty span / other line fits better / unexplained) | PASS (0 of 36) |
| 18 | every lyric cue contains measured words | PASS |
| 19 | no gross cue/audio mismatch | PASS (worst 0.70) |
| 20 | fewer than 2 weak cues | PASS (0 under 0.50) |
| 21 | no music banner hides a lyric line | PASS (0 of 14) |

Artifact hashes, byte-identical across two independent runs:

```
te.srt     99f1728eb0efd358835c4174b60c473bf3128b633c246e252e006d4374c4270c   4342 bytes
en.srt     4c87da4099377cc33800e9342d3c11ec767f970cd5211000c26d63773dcae0b3   3304 bytes
en_tr.srt  ba1387dbda985fa1fe1367e8ddeca4c09abc46540aaa980bd739aaf13bdbc842   2968 bytes
```

Determinism: run twice → identical SHA-256. Database value → identical SHA-256 to
the pipeline artifact. The pipeline is deterministic and the write path is faithful.

## What this certification caught (and fixed)

The stored timeline had one cue boundary 1.18 s early:

```
cue #47  తిరువేంకటేశా! తప్పించ రావా?   411.92 - 417.88   ->  411.92 - 419.06
cue #48  గోపాల బాల గోవింద నామా,       417.88 - 434.70   ->  419.06 - 434.70
```

Measured words at the boundary:

```
తిరువేం @411.92   కటేషా @413.32   తత్పించరావా @414.56   మామ్ @417.88   వోపాల @419.06
```

`417.88` is the token `మామ్`, which is **not** part of `గోపాల బాల గోవింద నామా`;
`గోపాల` is only sung from `419.06`. So the stored cue displayed the refrain 1.18 s
before it was sung.

The cue count was unchanged (36 → 36), so the strict-gain comparator said `keep` and
the improvement could never be written. `--refine` (workflow input `refine`) now
permits exactly this rewrite when, on measured evidence:

- all existing hard checks pass,
- the sung-cue count is unchanged,
- the suspect-cue count does not increase,
- mean **anchored-onset** coverage improves by more than 0.005.

Gopala Baala: onset coverage `0.9279 -> 0.9341`, suspect `0 -> 0`.

## Refinement batch APPLIED 2026-11-02 (run `41525877006`)

A catalogue dry run with `refine=true` identified these tracks as having an optimal
cue **count** but stale **boundaries**. All were rewritten through the gated
workflow (`write=true`, `refine=true`, explicit id list — no other row was touched):
**9 written, 0 errors.**

| track | cues | onset coverage | suspect |
| --- | --- | --- | --- |
| Chintalu Maakela | 29 | 0.7672 → 0.7963 | 4 → 3 |
| Gan Gan Ganapati | 33 | 0.8992 → 0.9093 | 0 → 0 |
| Ganapati Namo Namami | 36 | 0.8892 → 0.8955 | 0 → 0 |
| Madhava Mukundha | 31 | 0.8370 → 0.8472 | 3 → 2 |
| Mangala Ganapati | 29 | 0.8112 → 0.8282 | 0 → 0 |
| Maya Kadali | 33 | 0.8632 → 0.8847 | 2 → 1 |
| Ramuni Keerthi | 34 | 0.9103 → 0.9230 | 1 → 0 |
| Shiva Shankara Vinutha | 30 | 0.7196 → 0.7252 | 1 → 0 |
| Veyi Naamaala | 34 | 0.8991 → 0.9041 | 0 → 0 |

Veyi Naamaala sits exactly at the +0.005 threshold; it cleared the gate on the
unrounded values and is non-regressive on every other axis.

### Verification of the batch

| check | result |
| --- | --- |
| written / errors | **9 / 0** |
| per-track audit (structure, shared timeline, exact plain-lyric text, agreement) | **9 of 9 pass** on every structural axis |
| pre-write backup captured | 9 tracks, exactly `synced_lyrics`, `_en`, `_en_tr` — **no plain-lyric column** |
| plain lyrics unchanged across all 79 tracks | **YES** |
| lyric line lost by the rewrite | **0** — the cued-line set is identical before/after in all 9 |
| post-condition: re-running the same refine pass | **`would_write` 0** (64 keep, 15 blocked, 0 errors) |
| Gopala Baala from the earlier certification | column hashes still `99f1728e…` / `4c87da40…` / `ba1387db…` |

The 4 untimed lines inside this batch are **pre-existing content issues**, unchanged
by the rewrite:

- Mangala Ganapati — `మధుర భక్తితో షోడశ పూజలు,` and `విధిగ పూజలో చేసేమయ్యా..`
- Shiva Shankara Vinutha — `శివశంకర వినుత శ్రీరామ.` (short-form duplicate of the
  sung pallavi) and `రాగం: సింధుభైరవి` (a **metadata line** — "Ragam:
  Sindhubhairavi" — not a sung lyric at all)

## Notes

- `--refine` is **off by default**; without it the run behaves exactly as before.
- Certification checks 1-3 are the ones that only pass immediately after a write.
  A later unrelated edit to the pipeline will make them fail by design, which is
  the signal to re-run the track.
- Certification does not and cannot prove millisecond-exactness against ground
  truth; it proves structure, shared timeline, text fidelity, and that every cue
  is explained by the audio it covers.
