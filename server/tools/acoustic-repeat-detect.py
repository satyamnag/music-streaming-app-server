#!/usr/bin/env python3
"""
Acoustic repeat detection for the Soulful Bhakti sync-lyrics pipeline.

Recovers sung-line occurrences that Deepgram's /v1/listen did NOT transcribe, by
reading the audio's vocal-energy structure instead of transcription words.

    track audio  ->  ffmpeg -> mono PCM  ->  energy envelope  ->  voice onsets
        ->  stanza self-similarity  ->  repeat segments (JSON)

This script is READ-ONLY: it writes a single JSON report and never touches the
database. It is run on GitHub Actions (compute-heavy), never the web dyno.

Determinism: same audio -> same output. No randomness, no ML.

Usage:
    python acoustic-repeat-detect.py --audio FILE [--json OUT] [--min-repeat-gap S]
        [--onset-high X] [--onset-low X] [--min-hold S] [--similarity F]

Output JSON shape:
    {
      "audio": "...",
      "sample_rate": 16000,
      "duration": 123.45,
      "onsets": [{"start":1.2, "end":2.0, "error":0.05, "energy":0.8}, ...],
      "repeats": [
        {"a": {"start":..,"end":..,"error":..}, "b": {...}, "similarity":0.81}
      ]
    }
"""

import argparse
import json
import subprocess
import sys
from array import array


# ---------------------------------------------------------------------------
# PCM decode (ffmpeg to mono, float-normalised s16)
# ---------------------------------------------------------------------------
def decode_audio(path):
    """Demux any ffmpeg-supported container to 16 kHz mono s16 samples."""
    cmd = [
        "ffmpeg", "-v", "error", "-i", path,
        "-ac", "1", "-ar", "16000", "-f", "s16le", "-",
    ]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if proc.returncode != 0:
        raise RuntimeError("ffmpeg failed: " + proc.stderr.decode("utf-8", "replace")[:300])
    raw = proc.stdout
    samples = array("h")
    samples.frombytes(raw)
    return [s / 32768.0 for s in samples]


# ---------------------------------------------------------------------------
# Energy envelope (short-time RMS, peak-normalised)
# ---------------------------------------------------------------------------
def energy_envelope(samples, sr, frame=0.025, hop=0.010):
    fl = int(sr * frame)
    hp = int(sr * hop)
    if fl <= 0 or hp <= 0:
        raise RuntimeError("bad frame/hop for sample rate")
    env = []
    i = 0
    n = len(samples)
    while i + fl <= n:
        seg = samples[i:i + fl]
        rms = (sum(s * s for s in seg) / fl) ** 0.5
        env.append(rms)
        i += hp
    if not env:
        return [], fl, hp
    peak = max(env) or 1.0
    return [e / peak for e in env], fl, hp


# ---------------------------------------------------------------------------
# Onset detection (hysteresis on the envelope)
# ---------------------------------------------------------------------------
def detect_onsets(env, sr, hop, onset_high=0.18, onset_low=0.08, min_hold=0.30, min_gap=0.12):
    """Return sorted list of {start,end,error,energy} with hysteresis + re-trigger gap."""
    hop_s = hop / sr
    onsets = []
    active_start = None
    prev_end = None
    for idx, e in enumerate(env):
        t = idx * hop_s
        if active_start is None:
            if e >= onset_high:
                active_start = t
                # slope-based error: time since envelope crossed the low threshold
        else:
            if e <= onset_low:
                end = t
                dur = end - active_start
                if dur >= min_hold:
                    if prev_end is None or active_start - prev_end >= min_gap:
                        peak_env = max(env[int(active_start / hop_s): idx + 1]) if idx >= int(active_start / hop_s) else e
                        onsets.append({
                            "start": round(active_start, 3),
                            "end": round(end, 3),
                            # conservative: frame hop is the floor of boundary error
                            "error": round(hop_s, 3),
                            "energy": round(peak_env, 4),
                        })
                        prev_end = end
                active_start = None
    # trailing active span (voice to end of file)
    if active_start is not None:
        t = (len(env) - 1) * hop_s
        dur = t - active_start
        if dur >= min_hold:
            onsets.append({
                "start": round(active_start, 3),
                "end": round(t, 3),
                "error": round(hop_s, 3),
                "energy": round(max(env[int(active_start / hop_s):]), 4),
            })
    return onsets


# ---------------------------------------------------------------------------
# Stanza self-similarity: repeated onset patterns -> repeated sung occurrences
# ---------------------------------------------------------------------------
def _onset_signature(onsets, start, end):
    """Relative onset timing (normalised to [0,1]) of onsets within [start,end]."""
    inside = [o for o in onsets if o["start"] >= start - 0.05 and o["end"] <= end + 0.05]
    if not inside:
        return None
    lo = inside[0]["start"]
    hi = inside[-1]["end"]
    span = (hi - lo) or 1e-6
    return [(o["start"] - lo) / span for o in inside], lo, hi


def _sig_similarity(a, b):
    """Mean 1 - |da - db| over the shorter signature, aligned by count."""
    if not a or not b:
        return 0.0
    n = min(len(a), len(b))
    total = 0.0
    for i in range(n):
        total += 1.0 - abs(a[i] - b[i])
    return total / n


def _group_phrases(onsets, phrase_gap=1.2):
    """Cluster onsets into phrases: a phrase ends where silence exceeds phrase_gap."""
    if not onsets:
        return []
    phrases = []
    cur = [onsets[0]]
    for o in onsets[1:]:
        if o["start"] - cur[-1]["end"] <= phrase_gap:
            cur.append(o)
        else:
            phrases.append(cur)
            cur = [o]
    if cur:
        phrases.append(cur)
    return phrases


def _windowed_repeats(onsets, min_words=4, min_repeat_gap=6.0, similarity=0.6, max_span=40.0):
    """
    Windowed self-similarity: slide a window of `min_words` consecutive onsets
    across the track and compare its relative-onset signature against every later
    window of the same size. Recovers repeated stanzas even when they are sung
    back-to-back (no silence separates them), which phrase grouping cannot see.

    Returns {a,b,similarity} pairs; a/b are the window's first/last onset times.
    """
    starts = [o["start"] for o in onsets]
    n = len(onsets)
    if n < min_words:
        return []

    def sig(times):
        span = (times[-1] - times[0]) or 1.0
        return [(t - times[0]) / span for t in times]

    repeats = []
    seen = set()
    for i in range(0, n - min_words + 1):
        wa = starts[i:i + min_words]
        sig_a = sig(wa)
        for j in range(i + min_words, n - min_words + 1):
            if starts[j] - starts[i] < min_repeat_gap:
                continue
            if starts[j + min_words - 1] - starts[i] > max_span:
                continue
            wb = starts[j:j + min_words]
            sim = _sig_similarity(sig_a, sig(wb))
            if sim >= similarity:
                key = (round(starts[i], 2), round(starts[j], 2))
                if key in seen:
                    continue
                seen.add(key)
                repeats.append({
                    "a": {"start": round(starts[i], 3), "end": round(starts[i + min_words - 1], 3)},
                    "b": {"start": round(starts[j], 3), "end": round(starts[j + min_words - 1], 3)},
                    "similarity": round(sim, 4),
                })
    return repeats


def detect_repeats(onsets, min_repeat_gap=8.0, similarity=0.6, max_span=40.0, phrase_gap=1.2):
    """
    Find repeated sung stanzas from onset timing alone.

    Two complementary strategies:
      1. PHRASE self-similarity: silence-bounded phrases compared pairwise.
      2. WINDOWED self-similarity: any later window of onsets whose relative
         timing matches an earlier one — catches back-to-back repetitions that
         phrase grouping merges into one long phrase.

    Both produce {a, b, similarity} where a is the earlier occurrence and b the
    later one. Results are deduplicated by (a.start, b.start).
    """
    # Phrase-based matches.
    phrases = _group_phrases(onsets, phrase_gap)
    out = []
    for i in range(len(phrases)):
        pa = phrases[i]
        a_sig = [o["start"] for o in pa]
        if len(a_sig) < 2:
            continue
        a_span = (a_sig[-1] - a_sig[0]) or 1.0
        a_norm = [(t - a_sig[0]) / a_span for t in a_sig]
        for j in range(i + 1, len(phrases)):
            pb = phrases[j]
            b_sig = [o["start"] for o in pb]
            if len(b_sig) < 2:
                continue
            if b_sig[0] - a_sig[0] < min_repeat_gap:
                continue
            if b_sig[-1] - a_sig[0] > max_span:
                continue
            b_span = (b_sig[-1] - b_sig[0]) or 1.0
            b_norm = [(t - b_sig[0]) / b_span for t in b_sig]
            sim = _sig_similarity(a_norm, b_norm)
            if sim >= similarity:
                ae = pa[0].get("error", 0.0)
                be = pb[0].get("error", 0.0)
                err = round(max(ae, be), 3)
                out.append({
                    "a": {"start": round(a_sig[0], 3), "end": round(a_sig[-1], 3), "error": err},
                    "b": {"start": round(b_sig[0], 3), "end": round(b_sig[-1], 3), "error": err},
                    "similarity": round(sim, 4),
                })

    # Windowed matches (back-to-back repetitions).
    for r in _windowed_repeats(onsets, min_repeat_gap=min_repeat_gap, similarity=similarity, max_span=max_span):
        ae = onsets[0].get("error", 0.0)
        r["a"]["error"] = ae
        r["b"]["error"] = ae
        out.append(r)

    # De-duplicate by (a.start, b.start) keeping the higher-similarity entry.
    best = {}
    for r in out:
        key = (r["a"]["start"], r["b"]["start"])
        if key not in best or r["similarity"] > best[key]["similarity"]:
            best[key] = r
    return sorted(best.values(), key=lambda r: (r["a"]["start"], r["b"]["start"]))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main(argv):
    p = argparse.ArgumentParser(description="Acoustic repeat detection (read-only)")
    p.add_argument("--audio", required=True, help="path to the track audio file")
    p.add_argument("--json", default=None, help="write JSON report to this file")
    p.add_argument("--onset-high", type=float, default=0.18, help="envelope threshold to ENTER voice")
    p.add_argument("--onset-low", type=float, default=0.08, help="envelope threshold to EXIT voice")
    p.add_argument("--min-hold", type=float, default=0.35, help="min voice span (s) to count as an onset")
    p.add_argument("--min-repeat-gap", type=float, default=8.0, help="min gap (s) between an occurrence and its repeat")
    p.add_argument("--similarity", type=float, default=0.6, help="phrase signature similarity floor")
    p.add_argument("--max-span", type=float, default=40.0, help="max span (s) covering an occurrence + repeat")
    p.add_argument("--phrase-gap", type=float, default=1.2, help="silence (s) that ends a phrase")
    args = p.parse_args(argv)

    sr = 16000
    samples = decode_audio(args.audio)
    env, fl, hop = energy_envelope(samples, sr)
    if not env:
        report = {"audio": args.audio, "sample_rate": sr, "duration": len(samples) / sr,
                  "onsets": [], "repeats": [], "error": "no audible energy"}
        text = json.dumps(report, ensure_ascii=False, indent=2)
        print(text)
        if args.json:
            with open(args.json, "w", encoding="utf-8") as f:
                f.write(text + "\n")
        return 0

    onsets = detect_onsets(env, sr, hop, args.onset_high, args.onset_low, args.min_hold)
    repeats = detect_repeats(onsets, args.min_repeat_gap, args.similarity, args.max_span, args.phrase_gap)

    report = {
        "audio": args.audio,
        "sample_rate": sr,
        "duration": round(len(samples) / sr, 3),
        "onsets": onsets,
        "repeats": repeats,
    }
    text = json.dumps(report, ensure_ascii=False, indent=2)
    print(text)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

