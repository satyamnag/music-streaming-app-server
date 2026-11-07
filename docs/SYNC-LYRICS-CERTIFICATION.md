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

## Written track: Ramuniki Jai (2026-11-07)

`2fff9edc-611a-4d35-8cac-829f4ac5fb85` — 259 s. The owner re-segmented the Telugu to
**49 cues, all sung, with no `{{Music}}` banners**, and cleared both English columns. Rendered
with `sync-variants.yml` run `42333795925`, which writes **only** `synced_lyrics_en` and
`synced_lyrics_en_tr`.

The timeline runs `19.707 → 252.925`; the intro (0 → 19.707), the outro (252.925 → 259) and the
interludes between stanzas are gaps rather than banners, by the owner's segmentation.

| check | result |
| --- | --- |
| cues | **49 / 49 / 49**, identical start+end at every index |
| Telugu column | **unchanged — sha256 identical before and after** |
| English columns | were empty → 49 sung cues each, 21/21 plain lines covered |
| music mask | 0 banners in all three columns |
| Telugu script in either English column | **0** |
| empty cues | **0** |
| every English line | a verbatim `plain_lyrics_en` / `plain_lyrics_en_tr` line, none invented |
| stored vs the run's render | **byte-identical** |

No sub-line splitting was needed: all 49 cues are exact plain lines, so each cue takes the
same-index line of its plain column.

### Two things in the plain columns, reported not changed

* `plain_lyrics_en` row 20 ends with an authoring directive inside the sung line:
  `Hail to the divine essence that transforms one's destiny! {Repeat Pallavi}`. That string is
  now in two synced cues (`135.638` and `138.191`) and renders as **literal text**, because the
  apps treat a line as a divider only when the whole line is braces.
* The Anupallavi couplet is reversed in English: the line under `భారతదేశమును భద్రముగ కాచెడి,`
  reads `To the young Sri Rama,`, which translates the *next* Telugu line. It reads correctly as
  one English sentence across the pair, but a listener reading both columns stacked sees the
  following line's translation highlighted.

### Timing note carried over from the Telugu column

Four cues are too short for their text: cue 22 is 1.36 s for 24 Telugu characters
(22.1 chars/s), cue 23 is 1.20 s (24.2), cue 24 is 2.36 s (12.7), cue 36 is 1.68 s (16.7).
The English columns mirror those times exactly, so they are equally unreadable there.
Reported, not changed — the Telugu timeline is the owner's.

## Written track: Ramudu Vachadu Baala (2026-11-06)

`07f2934c-77f7-45d7-aa77-53ce15c7bbb3` — 234 s, **44 cues: 35 sung + 9 `{{Music}}`**,
contiguous `0.000 → 234.000`, 20 plain-lyric lines (19 distinct — `బాలరాముడు, భక్తవరదుడు,` is
rows 28 and 30, and both rows carry the same English).

### Where the music regions came from

The owner supplied an SRT and the WAV master. Before trusting any pipeline timing the WAV was
compared with the opus the app serves: **identical duration (233.600 s both), envelope
correlation 0.9995 at zero lag** — the same recording, so pipeline timings transfer.

Regions came from `sync-from-srt.yml` run `42169317314` (validate-only), windowed on the
supplied cues: WhisperX alignment, an independent Whisper large-v3 cross-check, then
reconcile. 0 unplaced lines, 0 weak lines. That produced nine instrumental stretches —
including two the reconcile pass had absorbed into neighbouring lines because each fell under
its 3.0 s music-gap threshold after snapping (83.113 and 218.702, both restored).

Three boundaries were corrected against the evidence rather than taken from the pipeline:

| region | pipeline said | written | why |
| --- | --- | --- | --- |
| outro | starts 226.000 | **229.068** | the aligner compressed a 15-character line into 0.92 s (16.3 chars/s — impossible for singing). The supplied 229.068 gives 3.7 chars/s, and the audio drops from RMS 0.173 (the loudest window in the track) to 0.0999 at 229.2 |
| short fill | ends 212.263 | **211.780** | the ASR has a word onset inside that span (`రాముడు`, p=0.98) which begins the next line |
| interlude | ends 155.580 | **154.866** | the supplied cue starts 0.71 s early — ordinary grid tolerance, not swallowed music |

One lyric start was moved: `న్యాయ పోరాటము విజయము కాగా,` sat behind 8.54 s of interlude, so it
went `104.600 → 113.140` (aligner and ASR both place that line at 113.14–116.40).

### The gap-free version, and the four banners that covered singing

The owner then closed every remaining gap by hand and asked for that version to be fixed and
written. Four of those closures had pushed a `{{Music}}` banner into the first sung word, so
those four music ends were pulled back to the measured voice onset with the following lyric
start moved to match — gap-free, with no banner covering singing:

| music cue | was | now | next line start |
| --- | --- | --- | --- |
| 1 | 16.356 | **15.840** | 15.840 |
| 10 | 65.346 | **64.360** | 64.360 |
| 32 | 190.850 | **189.780** | 189.780 |
| 38 | 212.313 | **211.780** | 211.780 |

Banners are stored as the canonical `{{Music}}` (the owner had `{{ Music }}` with spaces), so
the strict `=== MUSIC_LABEL` comparisons in the server tools now count **35 lyric / 9 banners**
for all three columns instead of 44 / 0. Both app renderers treat either spelling identically
(`lib/modules/lyrics/lyrics_markup.dart`, `Soulful Bhakti Web App/libs/lyricsMarkup.ts`).

### How it was written

`write-final-timeline.yml` (added by this work) takes a committed final SRT, renders
`synced_lyrics_en` / `synced_lyrics_en_tr` against **that** timeline with
`render-variant-sync.mjs`, then writes all three columns through `finalize_payload.mjs` in one
PATCH with a backup. It never runs the aligner: the supplied timeline is the input. Run
`42176568701`.

| check | result |
| --- | --- |
| database `synced_lyrics` / `_en` / `_en_tr` | PATCH `204`, read-back **identical** for all three |
| stored Telugu vs the supplied timeline | text **and** timings identical, cue for cue |
| columns | 44 / 44 / 44, identical start+end at every index, identical music mask |
| structure | 0 → 234 s, contiguous, no gap, no overlap, no zero-length cue |
| every plain line cued; every cue an exact plain-lyric line | **yes — 20/20** |
| Telugu script in either variant / empty cues | **0 / 0** |
| variants vs the validated render | **byte-identical** |
| music | 9 cues, longest 20.76 s = 8.9 % (limit 25 %) |
| plain lyric columns | never written (backup holds only the three `synced_*` columns) |

### Re-segmented to 40 cues, and the English columns rebuilt (2026-11-06)

The owner then replaced the Telugu timeline with their own 40-cue version — 34 sung + 6
`{{Music}}`, contiguous `0 → 234.000` — and cleared both English columns. Re-rendered with
`sync-variants.yml` run `42185603891`, which renders from the stored Telugu and writes
**only** `synced_lyrics_en` and `synced_lyrics_en_tr`.

| | |
| --- | --- |
| cues | **40 / 40 / 40**, identical start+end at every index |
| Telugu column | **unchanged — sha256 identical before and after** |
| English columns | were empty → **34 sung cues each**, 20/20 plain lines covered |
| music mask | 6 banners in all three columns |
| Telugu script in either English column | **0** |
| empty cues | **0** |
| every English line | a verbatim `plain_lyrics_en` / `plain_lyrics_en_tr` line, none invented |
| stored vs the run's render | **byte-identical** |

No sub-line splitting was needed: all 34 sung cues are exact plain lines, so each cue takes
the same-index line of its plain column. The three short banners from the earlier pass
(83.113, 209.176, 218.702) are absent from this segmentation, so that instrumental now sits
inside the neighbouring lyric cues instead of being its own banner.

The earlier note about `బాలరాముడు, భక్తవరదుడు,` at 198.830–200.664 being 1.83 s no longer
applies: this timeline gives that line 4.23 s (191.000–195.080 and 199.230–203.456).

## Certified track: Ramya Guna Dhama (2026-11-04)

`c74a0c00-7fe8-4317-9d1b-4c0dff8da750` — 284 s, **36 supplied cues**, 20 distinct
plain-lyric lines, **42 cues / 36 sung / 6 music**. Written by run `41758326739`.

Built from the owner's SRT (`server/tools/inputs/Ramya-Guna-Dhama.source.srt`) with
windowed alignment (`segments_from` = the same file).

### Audio

The supplied master and the opus the app serves are the same recording: both
284.080 s, envelope correlation **0.9989** at zero lag, per-second profile 0.9999.

### Alignment

| | |
| --- | --- |
| lines placed | **36 / 36** — 32 windowed + 4 in a regional group, 0 unplaced |
| per-line posterior | median **0.699**, p10 0.573, min 0.318 |
| occurrences vs the supplied SRT | **identical** — refrain pair 8× each, charanam 3's first two lines 2× each, the rest once |
| independent ASR in-span coverage | mean **0.812**, median 0.929 |
| supplied grid deviation | median **−0.66 s**, p10 −1.03 s, largest 1.33 s |

Two supplied cues cannot hold their own text — cue 22 is 1.118 s for 20 characters
and cue 23 is 1.435 s for 24 — so the regional-group pass took them together with
their neighbours (group `[21, 22, 23]`, plus `[24]`), and no line was dropped.

The interludes became six `{{Music}}` cues, the longest 31.40 s (11.1 %):

```
{{Music}}   0.00 -  31.40   ( 31.4s)   intro
{{Music}}  79.40 -  91.27   ( 11.9s)
{{Music}} 126.24 - 139.40   ( 13.2s)
{{Music}} 173.48 - 184.38   ( 10.9s)
{{Music}} 220.44 - 232.65   ( 12.2s)
{{Music}} 279.53 - 284.00   (  4.5s)   outro
```

Music cues carry mean singing evidence 0.085 against 0.130 for the sung cues.

### One finding the owner should look at: a duplicated stanza

Cues 21–24 of the supplied SRT are the *same two lines* twice:

```
21  సర్వప్రాణుల యెడల సమభావ ధామా,     23  సర్వప్రాణుల యెడల సమభావ ధామా,   (identical)
22  సర్వసమర్థ, సౌశీల్య రామా,          24  సర్వసమర్థ, సౌశీల్య రామా,        (identical)
```

The independent ASR transcribes that stretch completely and finds the stanza **once**:

```
184.38-185.78 సర్వ   185.78-186.74 ప్రాణుల  186.74-187.38 ఏడల
187.38-189.52 సమభావ 189.52-190.74 ధామా
190.74-192.22 సర్వ  192.22-193.22 సమర్థ    193.22-195.40 సవ్షిల్య  195.40-196.78 రామా
196.78-197.78 ధైర్య 197.78-199.20 స్వభావ   199.20-201.04 క్రోధ ...
```

Lines 21 and 22 occupy 184.38 → 196.78 and the next word is line 25's first word, so
there is no room for a second pass. The pipeline never drops a supplied line, so
cues 23 and 24 are kept and share that span (0.96 s and 3.65 s respectively) — which
is why one cue in the middle of that stanza is short. If those two rows are indeed
duplicates, deleting them from the supplied SRT and re-running gives 34 sung cues
with every line at a natural length.

### Verification

| check | result |
| --- | --- |
| database `synced_lyrics` / `_en` / `_en_tr` | PATCH `204`, read-back **identical** for all three |
| stored Telugu vs the run artifact | **byte-identical** |
| columns | 42 / 42 / 42, identical start+end at every index, identical music mask |
| structure | 0 → 284 s, contiguous, no gap/overlap, no zero-length, no duplicate start |
| every plain line cued; every cue an exact plain-lyric line | **yes — 20/20** |
| repetitions | every line with exactly its supplied occurrence count |
| music | 6 cues, longest 31.40 s = 11.1 % (limit 25 %) |
| per-line posterior | median 0.699, p10 0.573, min 0.318 |
| genuine misplacement suspects | **0 of 36** |
| plain lyrics | never written |

### Variants re-rendered after the owner re-segmented the Telugu (2026-11-04)

The owner then edited `synced_lyrics` by hand, splitting every plain line into two cues
(73 cues over the same 20 plain lines, music banners written as `{{♪ Music ♪}}`). The
English columns still held the old 42-cue timeline, so they were re-rendered from the
stored Telugu with `sync-variants.yml` (run `41780206742`), which writes **only**
`synced_lyrics_en` and `synced_lyrics_en_tr`.

`render-variant-sync.mjs` gained what that structure needs:

* a cue that is a **prefix or suffix of a plain line** is mapped to that line and the
  variant line is split at the matching point — at the punctuation mark nearest the same
  relative position when the Telugu split is at punctuation, otherwise at the word
  boundary nearest it, nudged left when it would end on a dangling function word;
* any `{{...}}` cue is a music banner and is mirrored **verbatim**, so all three columns
  carry the same text for a music row;
* a **hard guard** refuses the write if any cue in a variant column still contains
  Telugu script, or if a sub-line cue cannot be split. That fallback is how Telugu used
  to leak into the English columns; it can no longer ship.

| | |
| --- | --- |
| cues | **73 / 73 / 73**, identical start+end at every index |
| Telugu column | **unchanged — sha256 identical before and after** |
| English columns | 42 cues → **73**, 20/20 plain lines covered |
| Telugu script in either variant | **0 cues** |
| empty cues / music-mask mismatches | **0 / 0** |
| stored variants vs the run artifacts | **byte-identical** |

Spot checks of the splits (each piece taken from the plain column, nothing invented):

```
సర్వప్రాణుల యెడల      Sarva Praanula Yedala        Abode of equanimity
సమభావ ధామా,           Samabhaava Dhaamaa,          towards all living beings,
సర్వసమర్థ,             Sarvasamartha,               All-powerful Rama
సౌశీల్య రామా,          Sausheelya Raamaa,           of noble character,
అందరిలో మంచిని         Andarilo Manchini            One who sees
కాంచగల సోమా,           Kaanchagala Somaa,           in everyone,
```

## Certified track: Pattabhi Raamuni (2026-11-03)

`50320a38-84ed-4da5-afe2-95dab5ab2b61` — 292 s, **41 supplied cues**, 20 distinct
plain-lyric lines, **47 cues / 41 sung / 6 music**. Written by run `41664755012`.

This is the track that proved the whole-track alignment cannot be trusted on every
recording, and the first one rebuilt through **windowed** alignment
(`segments_from` = the supplied SRT).

### Is the WAV master the same audio as the opus the app serves?

Measured (16 kHz mono, what the model receives):

| | `(S) SB29 …V04.wav` | R2 opus |
| --- | --- | --- |
| duration | 292.800 s | **292.800 s** |
| best envelope lag | — | **0.00 s** |
| envelope correlation | — | **0.9993** |
| per-second profile correlation | — | **0.9999** |

Same recording, sample aligned. The opus is what the app serves, so that is what the
pipeline aligns against.

### Why this track needed windowed alignment

The monotone whole-track pass **fails structurally** here: it emitted line 1 at 2.4 s
(before the 29.7 s intro) and packed all 41 cues into 2.4 → 131.5 s, then left
131.5 → 292.0 s as a single banner (55 % of the track). Reproduced twice, on two
different supplied scripts. The cause is the same one documented for the head repair:
a monotone path has no state for an unscripted passage, and on this recording it
found it cheaper to compress the script than to stretch it.

Windowed alignment fixes it, because each line is only ever placed inside its own
neighbourhood:

| | |
| --- | --- |
| lines placed acoustically | **40 / 41** |
| per-line posterior | median **0.743**, p10 0.594, 39 of 41 ≥ 0.5 |
| the one line kept at the supplied time | line 36 (see below) |
| independent ASR in-span coverage | mean **0.810**, median 0.929 |

The repeats were preserved exactly as supplied — **11× the pallavi line, 10× its
partner**, plus the anupallavi pair 2× and every charanam line once or twice — which
is the direct answer to "can WhisperX deal with repetitive lines": it can, because
the repetitions are in the script.

### What the alignment corrected

The supplied grid was consistently **~1.2 s late** (median −1.19 s, p10 −1.50 s,
largest 1.78 s). The four refrain cues the owner reported as missing — around 4:25,
4:35 and 4:40 — are now sung lines rather than one 25.3 s cue or a music banner:

| | before (stored) | after |
| --- | --- | --- |
| cues | 43 (37 sung, 6 music) | **47 (41 sung, 6 music)** |
| pallavi occurrences | 8 | **11** |
| partner-line occurrences | 9 | **10** |
| 4:25 / 4:35 / 4:40 | one 25.3 s cue + banner | **4:24.2 pallavi, 4:35.2 pallavi, 4:40.1 ఇట్టే** |
| longest sung cue | 25.3 s | **8.3 s** |

The instrumental passages — which the supplied cues had swallowed — became six real
`{{Music}}` cues:

```
{{Music}}   0.00 -  29.79   ( 29.8s)   intro
{{Music}}  68.34 -  88.98   ( 20.6s)
{{Music}} 118.34 - 134.06   ( 15.7s)
{{Music}} 173.69 - 190.06   ( 16.4s)
{{Music}} 218.99 - 225.45   (  6.5s)
{{Music}} 288.35 - 292.00   (  3.7s)   outro
```

### The row that cannot carry a timestamp, and the regional group that fixes it

Supplied cue 36 is **19 milliseconds** long (`00:04:20,894 → 00:04:20,913`) for a
24-character line. No placement inside that window can be right, and dropping the line
is not an option, so the first windowed run had to keep the supplied position — the
cue displayed for 1.66 s with posterior 0.000 and was the only line in the track with
no acoustic support at all.

The aligner now detects a cue whose window cannot hold its own text at a singable rate
(`--window-max-rate`, default 8 characters/second) and aligns that line **together with
its immediate neighbours in one regional trellis**: the audio distributes the group
inside the combined region, exactly as the whole-track pass does but scoped to a few
seconds instead of the whole track. Lines that are not crowded keep the per-line path
untouched.

On this track: one crowded cue (line 36) → one regional group over lines 35–37, region
254.95 → 265.96 s (11.0 s for 68 characters = 6.2 characters/second, plausible for the
fast closing refrain). The three lines came out with posteriors 0.581 / **0.480** /
0.446 instead of 0.720 / **0.000** / 0.416, and **no line is left at its supplied time
any more** — 38 windowed + 3 regional, 0 unplaced.

That stretch still cannot be corroborated by the other two signals — the ASR collapses
253.9 → 275.2 into one 21.3 s "సర్వము", and the acoustic onset detector sees one
unbroken 26.6 s energy burst (252.1 → 278.6) with no phrase boundary — so the line
order there rests on the owner's SRT, and every timestamp in it now comes from the
audio.

### Verification

| check | result |
| --- | --- |
| database `synced_lyrics` / `_en` / `_en_tr` | PATCH `204`, read-back **identical** for all three |
| stored Telugu vs the run artifact | **byte-identical** |
| columns | 47 / 47 / 47, identical start+end at every index, identical music mask |
| structure | 0 → 292 s, contiguous, no gap/overlap, no zero-length, no duplicate start |
| every plain line cued; every cue an exact plain-lyric line | **yes — 20/20** |
| repetitions | every line with exactly its supplied occurrence count (11× / 10× / 2× / 2× + 16) |
| music | 6 cues, longest 29.79 s = 10.2 % (limit 25 %) |
| placements | **38 windowed + 3 regional, 0 kept at the supplied time, 0 unplaced** |
| per-line posterior | median 0.743, p10 0.591, **min 0.446** |
| genuine misplacement suspects | **0 of 41** |
| independent ASR agreement | mean in-span coverage 0.807, median 0.929 |
| plain lyrics | never written |

## Certified track: Rama Naamamu Madhuramu (2026-11-03)

`2bdf7163-f40a-4c6e-83cb-d5da2c101d76` — 284 s, **48 supplied cues**, 20 distinct
plain-lyric lines (the pallavi pair 9× each, the anupallavi once, charanam 1 2×,
**charanam 2 once**, charanams 3 and 4 2× each), **54 cues / 48 sung / 6 music**.
Written by run `41652558345`.

Built from the owner's SRT (`server/tools/inputs/Rama-Naamamu-Madhuramu.source.srt`)
through `sync-from-srt.yml` with **windowed alignment** (`segments_from` = the same
file), so the pipeline never staged an untimed SRT into `synced_lyrics`: the three
columns held a 30-cue timeline that the new gates would refuse (see below), and they
were replaced in one PATCH with a backup.

### Is the WAV master better input than the opus the app serves?

The owner asked for the 48 kHz master (`(S) SB25 - Raama Naamamu Madhuramu - V05.wav`)
to be used "because WhisperX can go through a wav file better". Measured rather than
assumed — both files decoded to exactly what the model receives (16 kHz mono):

| | master WAV | R2 opus |
| --- | --- | --- |
| duration | 284.520 s | **284.520 s** |
| best envelope lag | — | **0.00 s** |
| envelope correlation after gain normalisation | — | **1.0000** |
| band energy 0–1 kHz / 1–3 kHz / 3–6 kHz / 6–8 kHz | 98.06 / 1.68 / 0.19 / 0.07 % | 98.05 / 1.69 / 0.19 / 0.07 % |

They are the same recording, sample-aligned, and the wav2vec2 aligner resamples to
16 kHz mono, so the opus is not losing anything the CTC model can see. No upload of a
52 MB WAV to the CDN was needed.

### Can forced alignment handle the repeated lines?

Yes, for the same reason as on Darshanamu Neeyara: the repeats are in the **script**.
`align()` walks a known transcript monotonically (`get_trellis` → `backtrack` →
`merge_repeats`), so a line that appears 9× in the script is 9 consecutive runs of its
characters. What an aligner cannot do is invent an occurrence the script omits.

| | |
| --- | --- |
| lines placed | **48 / 48** |
| per-line posterior | median **0.683**, p10 0.453, **min 0.301**; 0 below 0.3 |
| occurrences per line vs the supplied SRT | **identical — 0 differ** |
| the pallavi pair | 9× each at 23.8 / 29.2 / 40.8 / 95.4 / 143.9 / 181.8 / 243.7 / 249.8 / 255.9 and 26.0 / 32.1 / 44.2 / 98.7 / 147.6 / 184.5 / 246.5 / 252.7 / 260.8 |
| lines genuinely better explained elsewhere | **0 of 48** |

### What the alignment corrected

The supplied grid was close but consistently ~0.5 s late: median **−0.53 s**, p10
−0.93 s, p90 −0.16 s, largest 1.81 s.

More important, three supplied cues were 27–34 s long because they lumped a refrain
line together with the instrumental that follows it (cues 8, 18, 34 of the upload).
Windowed alignment places each line where it is actually sung and leaves the
instrumental empty, so those passages became real `{{Music}}` cues:

```
{{Music}}   0.00 -  23.83   ( 23.8s)   intro
{{Music}}  47.07 -  71.26   ( 24.2s)   after "రమ్యము, రమణీయము."
{{Music}} 101.79 - 133.04   ( 31.2s)
{{Music}} 151.00 - 157.64   (  6.6s)
{{Music}} 186.24 - 219.80   ( 33.6s)   longest = 11.8 % of the track
{{Music}} 267.02 - 284.00   ( 17.0s)   outro
```

Music cues carry mean singing evidence `0.078` against `0.162` for the sung cues, so
they sit where the aligner genuinely heard no Telugu.

### The one thing the aligner could not do here

The CTC model **under-covers fast singing**. In the closing refrain six lines came out
0.7–1.0 s long for 13–14 characters (20+ characters/second, physically impossible)
while the independent ASR heard every one of them with p ≥ 0.92 and its words tiled
the whole stretch 243.6 → 267.0 with no gaps — and two `{{Music}}` cues appeared where
words were plainly being sung.

`reconcile_timeline.py` now has a **word-snap** pass: where the best contiguous window
of ASR words explains a line (a) at least 0.75 of its characters, (b) either clearly
better than the cue's own span (+0.15) or about equally well while the cue's own span
explains < 0.95, and (c) at a singable rate (≥ 1 character per ⅛ s), the cue takes
those word boundaries. Order is preserved (a new start is clamped to the previously
accepted end, and a monotone normalisation pulls an earlier cue's end back to the next
cue's start when the two models disagree by a few tens of ms).

On this track that produced 11 snaps, including the whole closing refrain:

```
243.71 - 246.46   రామ నామము మధురము,
246.46 - 249.84   రమ్యము, రమణీయము.
249.84 - 252.66   రామ నామము మధురము,
252.66 - 255.90   రమ్యము, రమణీయము.
255.90 - 260.82   రామ నామము మధురము,
260.82 - 267.02   రమ్యము, రమణీయము.
267.02 - 284.00   {{Music}}
```

### What was there before

The stored 30-cue timeline was structurally broken in exactly the way the new gates
forbid — it is worth recording because it is what the app was serving:

| | before | after |
| --- | --- | --- |
| cues | 30 (23 sung, 7 music) | **54 (48 sung, 6 music)** |
| plain lines with **no cue at all** | **3** (`సామ గానము తోటి పలికిన,`, `విన్న, పల్కిన వీను, జిహ్వకు,`, `పరమాన్నము అది పీయుషం`) | **0** |
| refrain pair occurrences | 1× and 3× (unbalanced) | **9× and 9×** |
| longest sung cue | 16.9 s for a 13-character line | **6.2 s** |
| trailing `{{Music}}` | 30.7 s starting at 253.3 (the closing refrain was silent) | 17.0 s starting at 267.0 |

`finalize_payload.mjs` now refuses a timeline that leaves a plain-lyric line uncued
(and, with `--expect-lyric-cues`, one that drops a supplied occurrence), so this state
can no longer be written for any track.

### Verification

| check | result |
| --- | --- |
| database `synced_lyrics` / `_en` / `_en_tr` | PATCH `204`, read-back **identical** for all three |
| stored Telugu vs the run artifact | **byte-identical** |
| columns | 54 / 54 / 54, identical start+end at every index, identical music mask |
| structure | 0 → 284 s, contiguous, no gap/overlap, no zero-length, no duplicate start |
| every plain line cued; every cue an exact plain-lyric line | **yes — 20/20** |
| repetitions | every line with exactly its supplied occurrence count |
| music | 6 cues, longest 33.56 s = 11.8 % (limit 25 %); evidence 0.078 vs 0.162 sung |
| per-line posterior | median 0.683, min 0.301, 0 weak |
| genuine misplacement suspects | **0 of 48** |
| independent ASR agreement | mean in-span coverage **0.691**, median 0.818 |
| plain lyrics | never written (backup holds only the three `synced_*` columns) |

### Variants re-rendered after the owner re-segmented the Telugu (2026-11-06)

The owner replaced `synced_lyrics` with their own 54-cue grid — 48 sung cues plus the six
interludes as `{{ Music }}` — which moved every cue boundary. The English columns still
held the certified 2026-11-03 timeline: the same cue **count**, different times. They were
therefore re-rendered from the stored Telugu with `sync-variants.yml` (run `42138526081`),
which writes **only** `synced_lyrics_en` and `synced_lyrics_en_tr`.

No sub-line splitting was needed. Every one of the 48 sung cues is an exact plain line, so
each cue took its text from the same-index line of `plain_lyrics_en` / `plain_lyrics_en_tr`,
and the six banners were mirrored verbatim so all three columns carry the same text per row.

| | |
| --- | --- |
| cues | **54 / 54 / 54**, identical start+end at every index |
| Telugu column | **unchanged — sha256 identical before and after** |
| English columns | certified grid → **the owner's grid**, 20/20 plain lines covered |
| Telugu script in either variant | **0 cues** |
| empty cues / music-mask mismatches | **0 / 0** |
| stored variants vs the run artifacts | **byte-identical** |
| plain lyric columns | untouched, 20 / 20 / 20 lines |
| all three columns | span **0.000 → 284.000** |

One consequence of the owner's own spelling, recorded so a later audit is not misled: the
banners are `{{ Music }}` **with spaces**, not the canonical `MUSIC_LABEL = '{{Music}}'`.
Every renderer treats any `{{...}}` as a banner — `lib/modules/lyrics/lyrics_markup.dart`,
`Soulful Bhakti Web App/libs/lyricsMarkup.ts` and `classifyLine()` in
`server/libs/autoSyncLyrics.mjs` — so the apps render it correctly. But the strict
`=== MUSIC_LABEL` comparisons in the server tools (`prepare_srt_job`, `finalize_payload`,
`shift-timeline`, `_certify`, …) count this track as **54 lyric cues / 0 banners** instead
of 48 / 6. Normalising the six rows to `{{Music}}` restores those counts; it changes no
timing and nothing user-visible.

## Certified track: Darshanamu Neeyara (2026-11-03)

`72029c9c-9ed0-43c5-a0c0-f0744a98c61d` — 398 s, **48 supplied cues**, 20 distinct
plain-lyric lines (the pallavi pair 8× each, the two anupallavi lines 2×, charanam 1
2×, **charanam 2 once**, charanams 3 and 4 2× each), **50 cues / 48 sung / 2 music**.
Written by run `41613044079`.

Built from the owner's SRT (`server/tools/inputs/Darshanamu-Neeyara.source.srt`)
through `sync-from-srt.yml` using the new `srt_path` input, so **nothing was staged
into `synced_lyrics` first**. The backup the run wrote proves the columns were
empty before it: `synced_lyrics`, `synced_lyrics_en`, `synced_lyrics_en_tr` all
`0 chars`. `plain_lyrics` / `plain_lyrics_en` / `plain_lyrics_en_tr` were read
only — `finalize_payload.mjs` PATCHes exactly the three `synced_*` columns.

### Can forced alignment handle the repeated lines?

Yes — and precisely because the repeats are already in the **script**. WhisperX's
aligner is not a segmenter: `align()` walks a *known* transcript monotonically
through the audio (`get_trellis` → `backtrack` → `merge_repeats`, see
`whisperx/alignment.py`). A line that appears 8× in the script is simply 8
consecutive runs of its characters, so nothing has to decide "which occurrence is
this". What the aligner *cannot* do is invent an occurrence the script does not
list, or decide that two adjacent occurrences are the same one — those are
segmentation questions, which is why `whisper-segment-sync.mjs` (greedy over ASR
words, one cue per sung occurrence) exists for tracks with no supplied script.

Measured on this track with the 48 cues supplied as one monotone script:

| | |
| --- | --- |
| lines placed | **48 / 48** |
| per-line posterior | median **0.747**, p10 0.673, **min 0.612**; 0 lines below 0.3 |
| occurrences per line vs the supplied SRT | **identical — 0 differ** |
| the pallavi pair | 8× each at 22.4 / 37.0 / 64.9 / 149.0 / 225.1 / 307.9 / 364.8 / 380.1 and 29.5 / 44.0 / 72.4 / 156.1 / 232.0 / 315.1 / 370.9 / 384.3 |
| lines genuinely better explained elsewhere | **0 of 48** |

The 12 cues the cross-check flags as "a better fit exists" are all either a window
that *contains* the cue (2) or **another occurrence of the same line** (10). That is
inherent to a refrain — identical text matches at every occurrence — and it is
harmless because the monotone timeline fixes which occurrence is which.

### What the alignment corrected in the supplied timing

Median deviation **−0.01 s**, p10 −0.49 s, p90 +0.09 s: the supplied grid was nearly
right but not exact. The head and tail became real `{{Music}}` cues (0 → 22.44 s and
394.48 → 398 s), and four lines moved by more than 0.9 s. On every large correction
the independent faster-whisper transcript agrees with the **produced** value, not the
supplied one:

| line | supplied start | produced start | words the ASR actually hears |
| --- | --- | --- | --- |
| 19 `ఓంకార, స్వస్తి, గద, చక్ర భూష` | 183.686 | **182.780** | `ముకార` @183.30, `స్వస్తి` @184.70 |
| 45 `దర్శనము నీయర, దశవతార రామ` | 366.298 | **364.780** | `సెం`…`దిషన` @364.80 |
| 46 `దరి మమ్ము చేర్చర, దశరథ సుత రామ` | 373.218 | **370.940** | `రాము`…`దిమము` @371.16 |
| 48 `దరి మమ్ము చేర్చర, దశరథ సుత రామ` | 387.057 | **384.280** | `కరిమంము` @385.78 |

Largest deviation from the supplied file is now **2.78 s**, and on the three largest
of those the supplied grid is the outlier.

### The one defect the first alignment had, and the rule that fixes it

The first validate-only run put the boundary between lines 18 and 19 at **170.88 s**.
Three independent sources disagreed with it:

- the aligner's own singing evidence `1 − p(blank)` was **0.00 for 179–183 s**,
- the independent ASR heard no word at all between 162.12 s and 183.30 s, then line
  19's second half (`ముకార`, `స్వస్తి`, `గదచ`, `క్రభూషా`) from 183.30 s,
- the owner's SRT had that boundary at 183.686 s.

A whole-track monotone alignment has no state for an instrumental break: every
script character must be emitted somewhere, so line 19's first character was dragged
back into the 21 s interlude and the rest of the line squeezed forward. The cue
therefore displayed its text **12.4 s before it is sung**.

`reconcile_timeline.py` now has a **head-repair** pass. It runs after the ASR
cross-check (so it has independent evidence) and repairs a head only when *both*
hold: the head is wordless for ≥ 4.0 s **and** the cue's character rate is below
2.0 c/s (it cannot have been sung in one pass). Both are required because neither
alone is proof — the ASR misses words in singing, and a slow line can legitimately
hold for 20 s (this track really does, after every refrain, and the owner's file
agrees). The replacement start is the first ASR word minus the track's **own**
measured cue-start-to-first-word offset, so no absolute constant is invented. The
previous cue extends to the new boundary, so the supplied structure (48 lyric cues,
music only at the head and tail) is preserved.

Result: exactly **one repair**, `170.88 → 182.78`.

### Verification

| check | result |
| --- | --- |
| database `synced_lyrics` / `_en` / `_en_tr` | PATCH `204`, read-back **identical** for all three |
| stored Telugu vs the run artifact | **byte-identical** |
| columns | 50 / 50 / 50, identical start+end at every index, identical music mask |
| structure | 0 → 398 s, contiguous, no gap/overlap, no zero-length, no duplicate start |
| every Telugu cue an EXACT plain-lyric line; every plain line cued | **yes — 20/20** |
| repetitions | every line with exactly its supplied occurrence count |
| music | only `0.00–22.44` and `394.48–398.00`; longest 22.44 s = 5.6 % of the track (limit 25 %) |
| `{{Music}}` vs singing evidence | music mean **0.042** vs sung mean **0.102** |
| per-line posterior | median 0.747, min 0.612, 0 weak |
| genuine misplacement suspects | **0 of 48** |
| plain lyrics | never written |

Regression: re-running the patched `reconcile_timeline.py` on **Peru Teliyakunna**'s
stored cross-check artifacts still reports *no head needed repairing*, produces the
same 43 cues and the same two relocations, and the only difference from the stored
column is the 0.5 s shift the owner asked for afterwards.

## Certified track: Ganesh Gayatri Mantra (2026-11-03)

`f64c8a76-2b7e-4e85-8bc6-863b6daf9120` — 309 s, 179 measured words, 15 lyric lines
(9 unique, the mantras repeat), **67 cues / 63 sung**, 4 music banners.

**All 21 checks pass**, and it was genuinely broken before:

| | before | after |
| --- | --- | --- |
| cue counts per column | **48 / 29 / 48** (desynchronised) | **67 / 67 / 67**, identical times |
| ends at track duration | **no** | yes (309 s) |
| untimed lyric lines | 2 | **0** |
| suspect cues | 9 | **0 of 63** |
| music banners hiding a lyric | 16 | **0 of 4** |
| worst cue/audio agreement | 0.00 | **0.72** |

### How it was fixed

The Telugu (source of truth) and the transliteration both had 19 lines; the English
column had **14**, because it merged two lines per stanza. That made the columns
non-parallel, so no aligned three-column timeline could exist.

Owner-approved content fix (`fix_ganesh_en.mjs`, workflow `fix-ganesh-en.yml`):
`plain_lyrics_en` rebuilt as 19 line-parallel lines — **16 lines are the existing
author text moved to the correct index, verbatim**, and **3 are new**:

- `మహోదరాయ ధీమహి` → "We meditate on the One with the great belly."
- `వక్రతుండాయ ధీమహి` → "We meditate on the One with the curved trunk."
- `ఓం తత్పురుషాయ విద్మహే` → "Om, let us meditate on the Supreme Person;"

Guards enforced: `plain_lyrics` and `plain_lyrics_en_tr` had to be byte-identical to
the hashes captured at approval; blank-line positions had to match the Telugu exactly;
`plain_lyrics` was never written. Post-write hashes confirm the Telugu and the
transliteration were untouched. The workflow refuses to run unless the `confirm`
input is `APPLY`, and uploads the before/after backup.

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

## Catalogue-wide certification sweep (2026-11-02)

Every one of the 79 tracks was run through the full check set in one read-only pass
(`_certify_all.mjs`): structure, shared three-column timeline, exact plain-lyric
text, every line timed, zero suspect cues, no banner hiding a lyric, and the
cue/audio agreement gate. The single-track certification above is the same set.

| | |
| --- | --- |
| **tracks passing every check** | **36 / 79** |
| tracks with at least one finding | 43 |
| pending writes the pipeline could still make | **0** |

This is stricter than the write gate — it adds the per-cue suspect test and the
banner test — so it exposes residual quality that the gate never looked at.

### Findings by class

| finding | tracks | fixable by tooling? |
| --- | --- | --- |
| suspect cue(s) — one to three per track | 35 | No: the pipeline's alternative scores no better (`would_write 0`) |
| weak cues | 16 | No — same reason |
| banner hides a lyric | 14 | No — same reason |
| structural: does not end at duration / column cue count differs | **12** | No — **all 12 are `skip` tracks**, blocked on content |
| untimed lines | 27 | No — content (see `SYNC-LYRICS-REMAINING-WORK.md`) |

### The important structural finding

**8 tracks currently have language columns with different cue counts**
(`column cue count differs`), and **9 do not end at their track duration**. Both are
real defects in what the app is serving today, because those rows still hold
timelines written before `coverTimeline` and the shared-timeline fix existed.

They cannot be repaired by rebuilding: each one is a `skip` track whose translation
column is not line-parallel, so the renderer cannot produce three aligned columns.
The repair is the content edit described in `SYNC-LYRICS-REMAINING-WORK.md`.

Affected: Bhadradri Ramayya Nidra, Ganesh Gayatri, Haaratulettare, Intitho Raamuni
Poolaata, Kalyaanamu Loka Kalyaanamu, Raama Raamaa Yanare, Ravi Vamsha
Sudhaambhudi, Sukha Madhuvu Kadalilo, Vandanam Sreeraama, plus Raavayya Maa Intiki,
Kanaka Durga Teru and Madvacharya Nutha (duration only).

### Why no further writes are possible

The pipeline reports `would_write 0` even with `--refine`: for every track it is
allowed to write, its own proposal is not measurably better than what is stored. The
43 findings above sit either on tracks it may not write (content-blocked) or on
tracks where the alternative timeline is not better. Reaching beyond that would mean
either editing plain lyrics or loosening a gate.

## Notes

- `--refine` is **off by default**; without it the run behaves exactly as before.
- Certification checks 1-3 are the ones that only pass immediately after a write.
  A later unrelated edit to the pipeline will make them fail by design, which is
  the signal to re-run the track.
- Certification does not and cannot prove millisecond-exactness against ground
  truth; it proves structure, shared timeline, text fidelity, and that every cue
  is explained by the audio it covers.
