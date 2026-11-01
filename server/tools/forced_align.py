# ============================================================================
# Forced alignment of known Telugu lyrics to audio - DRY RUN, NEVER WRITES.
#
# Why this exists: free ASR (Deepgram nova-3) re-transcribes and drops quiet or
# repeated lines. Forced alignment does the opposite - it takes the lyric text
# the author already wrote and LOCATES each line in the audio, so a line that is
# repeated is found every time it occurs, and a quiet line the ASR skipped is
# still found.
#
# This script is a DRY RUN by design. It outputs, per track, the predicted line
# times and scores to a JSON report. It makes no database call whatsoever.
#
# Official APIs used (verified against the INSTALLED package's __init__.py,
# MahmoudAshraf97/ctc-forced-aligner v0.3.0, NOT the README):
#   load_audio, load_alignment_model, generate_emissions, preprocess_text,
#   get_alignments, get_spans, postprocess_results
#
# IMPORTANT install note: this API is published ONLY as the git source
#   pip install git+https://github.com/MahmoudAshraf97/ctc-forced-aligner.git
# PyPI's `ctc-forced-aligner` (v1.0.2) is a DIFFERENT package (Deskpai fork)
# with the AlignmentTorch/generate_srt API and no permissive Telugu model; it
# does NOT export load_alignment_model and makes this script fail immediately.
#
# Model chosen for commercial use: jonatasgrosman/wav2vec2-large-xlsr-53-telugu
# (Apache-2.0). The library's DEFAULT model is CC-BY-NC and is deliberately NOT
# used here.
#
# Env: TRACK_ID, R2_BASE_URL, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
# Usage: python server/tools/forced_align.py [--track <id>] [--out out.json]
# ============================================================================

import argparse, json, os, sys, urllib.parse

def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(2)

# --- CLI ---------------------------------------------------------------
ap = argparse.ArgumentParser()
ap.add_argument("--track", default=os.environ.get("TRACK_ID"))
ap.add_argument("--out", default="forced-align.json")
ap.add_argument("--model", default="jonatasgrosman/wav2vec2-large-xlsr-53-telugu")
ap.add_argument("--device", default="cpu")
args = ap.parse_args()

SUPA = (os.environ.get("SUPABASE_URL") or "").rstrip("/")
KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or ""
CDN = (os.environ.get("R2_BASE_URL") or "").rstrip("/")
if not SUPA or not KEY: fail("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY required")
if not CDN: fail("R2_BASE_URL required")
if not args.track: fail("--track is required")

# --- Fetch the track ----------------------------------------------------
fields = "id,title,duration,storage_path,plain_lyrics,plain_lyrics_en,plain_lyrics_en_tr"
resp = __import__("urllib.request").request.urlopen(
    __import__("urllib.request").request.Request(
        f"{SUPA}/rest/v1/tracks?id=eq.{urllib.parse.quote(args.track)}&select={fields}",
        headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"},
    )
)
rows = json.load(resp)
if not rows:
    fail(f"track {args.track} not found")
track = rows[0]

plain = (track.get("plain_lyrics") or "").strip()
if not plain:
    fail("track has no plain_lyrics")

audio_url = f"{CDN}/{urllib.parse.quote(str(track.get('storage_path') or '').lstrip('/'))}"
print(f"track: {track.get('title')}  duration={track.get('duration')}s")
print(f"audio: {audio_url}")

# --- Load the model (first run downloads ~1.3GB; cached afterwards) -------
print("loading alignment model (first run downloads the checkpoint)...")
import torch
from ctc_forced_aligner import (
    load_audio,
    load_alignment_model,
    generate_emissions,
    preprocess_text,
    get_alignments,
    get_spans,
    postprocess_results,
)

model, tokenizer = load_alignment_model(
    args.device,
    args.model,
    dtype=torch.float32,
)

audio_waveform = load_audio(audio_url, model.dtype, model.device)

# --- Align the KNOWN text -------------------------------------------------
# Only lyric lines are located; {Pallavi} / {{Music}} carry no voice.
lines = [l.strip() for l in plain.splitlines() if l.strip()]
markup = re = __import__("re")
lyric_lines = [l for l in lines if not re.match(r"^\{[^{}]*\}$", l)]
text = " ".join(lyric_lines)

emissions, stride = generate_emissions(model, audio_waveform, batch_size=4)

# Native Telugu script: the telugu wav2vec2 tokenizer is char-based over the
# Telugu script, so no romanization is needed and the words stay readable and
# mappable. (v0.3.0 signature: preprocess_text(text, romanize, language,
# split_size="word", star_frequency="segment").)
tokens_starred, text_starred = preprocess_text(text, romanize=False, language="tel")
segments, scores, blank_token = get_alignments(emissions, tokens_starred, tokenizer)
spans = get_spans(tokens_starred, segments, blank_token)
word_timestamps = postprocess_results(text_starred, spans, stride, scores)

# --- Reconstruct per-LINE timing -----------------------------------------
# word_timestamps is a list of {text, start, end, score} in AUDIO order. A line
# that is sung twice yields its words TWICE, interleaved in time order. The
# correct mapping therefore assigns each word to its best-matching lyric line
# (by token overlap) and then groups CONSECUTIVE words assigned to the same line
# into ONE occurrence. Repeats fall out naturally: two separated runs -> two
# timed spans for the same line.
#
# This replaces the previous text-order split, which assumed each line appears
# exactly once and silently merged both occurrences of a repeated line into one.
def text_similarity(a, b):
    """Token-set Dice similarity between two strings."""
    sa = set(a.lower().split())
    sb = set(b.lower().split())
    if not sa or not sb:
        return 0.0
    return (2.0 * len(sa & sb)) / (len(sa) + len(sb))

# Pre-tokenise each lyric line once.
line_tokens = []
for li, line in enumerate(lyric_lines):
    line_tokens.append((li, line, line.lower().split()))

occurrences = []  # one entry per timed occurrence: {line_index, text, start, end, score, words}
for w in word_timestamps:
    wtext = str(w.get("text") or "").strip()
    if not wtext:
        continue
    # Best-matching lyric line for this single word.
    best = max(
        ((text_similarity(wtext, line), li, line) for li, line, _ in line_tokens),
        key=lambda x: x[0],
    )
    occurrences.append({
        "line_index": best[1],
        "text": best[2],
        "start": float(w.get("start") or 0.0),
        "end": float(w.get("end") or 0.0),
        "score": float(w.get("score") or 0.0),
    })

# Group CONSECUTIVE words assigned to the same line into one occurrence, so a
# repeat (a second, later run of the same line) becomes a distinct span.
report_lines = []
i = 0
while i < len(occurrences):
    li = occurrences[i]["line_index"]
    run = [occurrences[i]]
    j = i + 1
    while j < len(occurrences) and occurrences[j]["line_index"] == li:
        run.append(occurrences[j])
        j += 1
    start = run[0]["start"]
    end = run[-1]["end"]
    score = sum(o["score"] for o in run) / max(1, len(run))
    text = lyric_lines[li] if li < len(lyric_lines) else run[0]["text"]
    report_lines.append({
        "line_index": li,
        "occurrence": len([r for r in report_lines if r["line_index"] == li]),
        "text": text,
        "start": round(start, 3),
        "end": round(end, 3),
        "score": round(score, 4),
        "words": len(run),
    })
    i = j

# Sort by start time for a clean timeline, keeping occurrences in audio order.
report_lines.sort(key=lambda l: (l["start"], l["line_index"]))

# Count occurrences per line and report repetition explicitly.
occurrence_count = {}
for l in report_lines:
    occurrence_count[l["line_index"]] = occurrence_count.get(l["line_index"], 0) + 1
repeated_lines = {li: n for li, n in occurrence_count.items() if n >= 2}

report = {
    "track_id": track.get("id"),
    "title": track.get("title"),
    "model": args.model,
    "device": args.device,
    "audio_duration_s": track.get("duration"),
    "lyric_lines": len(lyric_lines),
    "occurrences": len(report_lines),
    "lines_timed": len(set(l["line_index"] for l in report_lines)),
    "repeated_lines": {str(li): n for li, n in repeated_lines.items()},
    "repeat_occurrences": sum(n - 1 for n in repeated_lines.values()),
    "lines": report_lines,
}

with open(args.out, "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

print(json.dumps({k: v for k, v in report.items() if k != "lines"}, ensure_ascii=False, indent=2))
for l in report_lines:
    occ = f"#{l['occurrence']} " if l["occurrence"] else ""
    print(f"  {l['start']:7.2f} -> {l['end']:7.2f}  (score {l['score']})  {occ}{l['text']}")
print("\nDRY RUN - nothing was written to the database.")
