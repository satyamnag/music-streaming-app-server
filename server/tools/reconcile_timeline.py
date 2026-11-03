#!/usr/bin/env python3
"""Reconcile a WhisperX alignment against an independent ASR transcript.

Forced alignment always returns a path, but it can mis-place a line - measured on
Peru Teliyakunna, the final refrain pair was compressed into a 5.6s interlude while the
singer actually repeats it 10s later (score 0.45 vs 0.88 elsewhere).

This applies ONE conservative rule and nothing else:

  for a line whose aligned span contains almost none of its own words
  (in_span < 0.30), search the ASR words only inside the SEARCH WINDOW bounded by its
  confident neighbours (previous confident line's end .. next confident line's start),
  and move it only if the best window there explains the line clearly better
  (coverage >= 0.80 and > in_span + 0.30).

Bounding by neighbours is what makes it safe: a low-confidence line can never jump
across a confident one, so ordering cannot break and repeated refrains cannot collapse
into each other.

Then the timeline is rebuilt: lines in order, `{{Music}}` wherever text is not sung
(head, gaps >= --music-gap, tail), anchored at 0 and at the duration, contiguous.

  python reconcile_timeline.py --aligned a.srt --words w.json --duration 291 \
      --music-gap 3.0 --out final.srt --report report.json
"""
import argparse
import json
import re
import sys

MUSIC = "{{Music}}"
SRT_TIME = re.compile(r"(\d+):(\d+):(\d+),(\d+) --> (\d+):(\d+):(\d+),(\d+)")
LOW_COVERAGE = 0.30
GOOD_COVERAGE = 0.80
MIN_GAIN = 0.30


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


def fmt(t):
    ms = int(round(max(0.0, t) * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def norm(s):
    return "".join(ch for ch in str(s) if ch.isalnum() or "\u0c00" <= ch <= "\u0c7f").lower()


def coverage(line, span):
    """Semiglobal character coverage: the whole line against any substring of span."""
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
    return max(0.0, 1 - min([prev[0]] + prev[1:]) / n)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--aligned", required=True)
    ap.add_argument("--words", required=True)
    ap.add_argument("--duration", type=float, required=True)
    ap.add_argument("--music-gap", type=float, default=3.0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    cues = parse_srt(args.aligned)
    lyric = [c for c in cues if c["text"].strip() != MUSIC]
    words = json.load(open(args.words, encoding="utf-8"))
    if not lyric:
        sys.exit("no lyric cues in the aligned SRT")
    if not words:
        sys.exit("no ASR words - refusing to reconcile without independent evidence")
    print(f"aligned lyric cues: {len(lyric)}   ASR words: {len(words)}   duration {args.duration}s")

    def in_span(c):
        w = [x for x in words if x["start"] >= c["start"] - 0.05 and x["start"] < c["end"]]
        return coverage(norm(c["text"]), "".join(x["n"] for x in w)), w

    stats = []
    for c in lyric:
        cov, w = in_span(c)
        stats.append({"cue": c, "in_span": cov, "words": len(w)})
    confident = [s for s in stats if s["in_span"] >= LOW_COVERAGE]

    moves = []
    for i, s in enumerate(stats):
        if s["in_span"] >= LOW_COVERAGE:
            continue
        lo = next((p["cue"]["end"] for p in reversed(stats[:i]) if p["in_span"] >= LOW_COVERAGE), 0.0)
        hi = next((n["cue"]["start"] for n in stats[i + 1:] if n["in_span"] >= LOW_COVERAGE), args.duration)
        cand = [w for w in words if w["start"] >= lo - 0.05 and w["end"] <= hi + 0.05]
        if not cand:
            continue
        line = norm(s["cue"]["text"])
        k = max(2, round(len(line) / 5))
        best = (0.0, None, None)
        for a in range(len(cand)):
            for ln in range(max(1, k - 3), k + 4):
                if a + ln > len(cand):
                    break
                sc = coverage(line, "".join(x["n"] for x in cand[a:a + ln]))
                if sc > best[0]:
                    best = (sc, cand[a]["start"], cand[a + ln - 1]["end"])
        sc, bs, be = best
        if bs is not None and sc >= GOOD_COVERAGE and sc > s["in_span"] + MIN_GAIN:
            moves.append({"index": i, "text": s["cue"]["text"], "from": [s["cue"]["start"], s["cue"]["end"]],
                          "to": [bs, be], "in_span": s["in_span"], "best": sc, "window": [lo, hi]})
            s["cue"]["start"], s["cue"]["end"] = bs, be

    for m in moves:
        print(f"  MOVED line {m['index'] + 1}: {m['from'][0]:.2f}-{m['from'][1]:.2f} -> "
              f"{m['to'][0]:.2f}-{m['to'][1]:.2f}  (in-span {m['in_span']:.2f} -> {m['to'] and m['best']:.2f})")
    if not moves:
        print("  no line needed moving")

    lyric.sort(key=lambda c: c["start"])
    timeline = []
    if lyric[0]["start"] > 0.05:
        timeline.append({"kind": "music", "text": MUSIC, "start": 0.0, "end": lyric[0]["start"]})
    for c in lyric:
        prev_end = timeline[-1]["end"] if timeline else 0.0
        if c["start"] - prev_end >= args.music_gap:
            timeline.append({"kind": "music", "text": MUSIC, "start": prev_end, "end": c["start"]})
        timeline.append({"kind": "lyric", "text": c["text"], "start": c["start"], "end": c["end"]})
    last = timeline[-1]["end"]
    if args.duration - last > 0.05:
        timeline.append({"kind": "music", "text": MUSIC, "start": last, "end": args.duration})

    timeline[0]["start"] = 0.0
    timeline[-1]["end"] = float(args.duration)
    for i in range(1, len(timeline)):
        timeline[i]["start"] = timeline[i - 1]["end"]
    bad = [e for e in timeline if e["end"] - e["start"] <= 0.001 or not e["text"].strip()]
    if bad:
        sys.exit(f"{len(bad)} invalid cue(s) after reconciliation")

    srt = "\n".join(f"{i}\n{fmt(e['start'])} --> {fmt(e['end'])}\n{e['text']}\n" for i, e in enumerate(timeline, 1))
    open(args.out, "w", encoding="utf-8").write(srt)

    music = sum(1 for e in timeline if e["kind"] == "music")
    print(f"\ntimeline: {len(timeline)} cues ({len(timeline) - music} sung, {music} music), "
          f"span {timeline[0]['start']:.3f} -> {timeline[-1]['end']:.3f}")
    if args.report:
        json.dump({"duration": args.duration, "cues": len(timeline), "moved": moves, "timeline": timeline},
                  open(args.report, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(f"wrote {args.report}")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
