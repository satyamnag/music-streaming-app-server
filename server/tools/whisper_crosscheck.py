#!/usr/bin/env python3
"""Independent cross-check of an aligned SRT against a Whisper transcript.

Forced alignment always returns a path, so a low posterior is the only warning it
gives. This transcribes the same audio with faster-whisper (large-v3, word
timestamps) and asks, per line, two separate questions:

  in_span     how much of the line's text explains the words inside its aligned span
  best        the best such fit anywhere in the track, and where

A line whose `best` is clearly better than its `in_span` fit is mis-placed by the
aligner; the report records where the audio actually puts it. Nothing is guessed and
nothing is interpolated: `best` is always a real word boundary.

  python whisper_crosscheck.py --url <audio> --srt <aligned.srt> --duration 291
"""
import argparse
import json
import os
import re
import subprocess
import tempfile
import urllib.request

MODEL = "large-v3"
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
SRT_TIME = re.compile(r"(\d+):(\d+):(\d+),(\d+) --> (\d+):(\d+):(\d+),(\d+)")
MUSIC = "{{Music}}"


def http_get(url, timeout=300):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=timeout) as r:
        return r.read()


def ffmpeg_exe():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


def parse_srt(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n").strip()
    out = []
    for block in re.split(r"\n\n+", text):
        lines = [l for l in block.split("\n") if l.strip()]
        ti = next((i for i, l in enumerate(lines) if "-->" in l), None)
        if ti is None:
            continue
        m = SRT_TIME.search(lines[ti])
        out.append({
            "start": int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3)) + int(m.group(4)) / 1000,
            "end": int(m.group(5)) * 3600 + int(m.group(6)) * 60 + int(m.group(7)) + int(m.group(8)) / 1000,
            "text": " ".join(lines[ti + 1:]).strip(),
        })
    return out


def norm(s):
    return "".join(ch for ch in str(s) if ch.isalnum() or "\u0c00" <= ch <= "\u0c7f").lower()


def coverage(line, span):
    """Semiglobal character coverage: whole `line` against any substring of `span`."""
    if not line or not span:
        return 0.0
    if line in span:
        return 1.0
    n, m = len(line), len(span)
    prev = list(range(m + 1))
    for i in range(1, n + 1):
        cur = [i] + [0] * m
        ci = line[i - 1]
        for j in range(1, m + 1):
            cur[j] = min(prev[j - 1] + (0 if ci == span[j - 1] else 1), prev[j] + 1, cur[j - 1] + 1)
        prev = cur
    best = min([prev[0]] + prev[1:])
    return max(0.0, 1 - best / n)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--srt", required=True)
    ap.add_argument("--out-dir", default="whisperx-out")
    args = ap.parse_args()

    raw = http_get(args.url)
    tmp = tempfile.mkdtemp()
    src = os.path.join(tmp, "in.audio")
    open(src, "wb").write(raw)

    from faster_whisper import WhisperModel
    model = WhisperModel(MODEL, device="cpu", compute_type="int8")
    segments, info = model.transcribe(src, language="te", word_timestamps=True,
                                      beam_size=1, condition_on_previous_text=False)
    words = []
    for seg in segments:
        for w in (seg.words or []):
            t = norm(w.word)
            if t:
                words.append({"n": t, "start": float(w.start), "end": float(w.end),
                              "word": str(w.word).strip(), "p": float(getattr(w, "probability", 0) or 0)})
    print(f"whisper {MODEL}: {len(words)} words, language {info.language} "
          f"(p={getattr(info, 'language_probability', 0):.2f})")
    if not words:
        raise SystemExit("no words transcribed")

    cues = parse_srt(args.srt)
    report = []
    print(f"\n{'#':>3} {'in-span':>8} {'best':>6} {'best at':>16} {'verdict':<16} text")
    for i, c in enumerate(cues, 1):
        if c["text"].strip() == MUSIC:
            continue
        line = norm(c["text"])
        inside = [w for w in words if w["start"] >= c["start"] - 0.05 and w["start"] < c["end"]]
        in_span = coverage(line, "".join(w["n"] for w in inside))

        # Cheap first: only lines whose own span does not explain them get the
        # expensive whole-track search (one DP per candidate window).
        if in_span >= 0.6:
            best, bs, be = in_span, c["start"], c["end"]
        else:
            k = max(2, round(len(line) / 5))
            best, bs, be = 0.0, None, None
            for a in range(len(words)):
                for ln in range(max(1, k - 3), k + 4):
                    if a + ln > len(words):
                        break
                    s = coverage(line, "".join(w["n"] for w in words[a:a + ln]))
                    if s > best:
                        best, bs, be = s, words[a]["start"], words[a + ln - 1]["end"]
        verdict = "OK"
        if best >= 0.6 and best > in_span + 0.15 and bs is not None and abs(bs - c["start"]) > 1.5:
            verdict = "MISPLACED?"
        report.append({
            "index": i, "text": c["text"], "start": c["start"], "end": c["end"],
            "in_span": round(in_span, 3), "best": round(best, 3),
            "best_start": bs, "best_end": be, "verdict": verdict,
        })
        print(f"{i:>3} {in_span:>8.3f} {best:>6.3f} "
              f"{f'{bs:.2f}-{be:.2f}' if bs is not None else '-':>16} {verdict:<16} {c['text'][:34]}")

    bad = [r for r in report if r["verdict"] != "OK"]
    print(f"\nlines checked: {len(report)}   flagged: {len(bad)}")
    for b in bad:
        print(f"  line {b['index']}: in-span {b['in_span']:.3f} vs best {b['best']:.3f} "
              f"at {b['best_start']:.2f}-{b['best_end']:.2f}  {b['text'][:40]}")

    json.dump({"model": MODEL, "words": len(words), "report": report},
              open(os.path.join(args.out_dir, "whisper-crosscheck.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    json.dump(words, open(os.path.join(args.out_dir, "whisper-words.json"), "w", encoding="utf-8"),
              ensure_ascii=False)
    print("\nwrote whisper-crosscheck.json and whisper-words.json")


if __name__ == "__main__":
    main()
