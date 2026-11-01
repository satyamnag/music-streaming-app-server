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
# Official APIs used (verified against ctc-forced-aligner README):
#   load_audio, load_alignment_model, generate_emissions, preprocess_text,
#   get_alignments, get_spans, postprocess_results
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
    dtype=torch.float32,
    model_name=args.model,
)

audio_waveform = load_audio(audio_url, model.dtype, model.device)

# --- Align the KNOWN text -------------------------------------------------
# Only lyric lines are located; {Pallavi} / {{Music}} carry no voice.
lines = [l.strip() for l in plain.splitlines() if l.strip()]
markup = re = __import__("re")
lyric_lines = [l for l in lines if not re.match(r"^\{[^{}]*\}$", l)]
text = " ".join(lyric_lines)

emissions, stride = generate_emissions(model, audio_waveform, batch_size=4)

# Native Telugu script: the telugu wav2vec2 tokenizer is char-based over Devanagari-like
# script, so no romanization is needed and the words stay readable and mappable.
tokens_starred, text_starred = preprocess_text(text, romanize=False, language="tel")
segments, scores, blank_token = get_alignments(emissions, tokens_starred, tokenizer)
spans = get_spans(tokens_starred, segments, blank_token)
word_timestamps = postprocess_results(text_starred, spans, stride, scores)

# --- Reconstruct per-LINE timing -----------------------------------------
# word_timestamps is a list of {text, start, end, score}. Words flow in the same
# order as `lyric_lines`, so a line's span is the first word's start to the last
# word's end. Repeats are handled naturally: each occurrence is its own word run.
report_lines = []
i = 0
for li, line in enumerate(lyric_lines):
    n_words = len(line.split())
    run = word_timestamps[i:i + n_words] if i < len(word_timestamps) else []
    i += n_words
    if not run:
        report_lines.append({"line_index": li, "text": line, "start": None, "end": None, "score": 0.0})
        continue
    start = run[0]["start"]
    end = run[-1]["end"]
    score = sum((w.get("score") or 0.0) for w in run) / max(1, len(run))
    report_lines.append({
        "line_index": li,
        "text": line,
        "start": round(start, 3),
        "end": round(end, 3),
        "score": round(score, 4),
        "words": len(run),
    })

report = {
    "track_id": track.get("id"),
    "title": track.get("title"),
    "model": args.model,
    "device": args.device,
    "audio_duration_s": track.get("duration"),
    "lyric_lines": len(lyric_lines),
    "lines_timed": sum(1 for l in report_lines if l["start"] is not None),
    "lines_untimed": sum(1 for l in report_lines if l["start"] is None),
    "lines": report_lines,
}

with open(args.out, "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

print(json.dumps({k: v for k, v in report.items() if k != "lines"}, ensure_ascii=False, indent=2))
for l in report_lines:
    t = " - " if l["start"] is None else f"{l['start']:7.2f} -> {l['end']:7.2f}"
    print(f"  {t}  (score {l['score']})  {l['text']}")
print("\nDRY RUN - nothing was written to the database.")
