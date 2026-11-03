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
# An ASR transcript can MISS whole passages (measured: 145 words for 41 sung lines), so
# "no ASR words in the aligned span" is not proof of misplacement. Forced alignment is
# locally accurate; a relocation of more than this is not credible evidence and is
# refused. The genuine corrections on Peru Teliyakunna were 5.3 s and 7.7 s.
MAX_MOVE_SECONDS = 20.0

# --- head repair ----------------------------------------------------------------
# A monotone whole-track alignment has no state for an instrumental break: every
# script character has to be emitted somewhere, so the line that follows a long
# unscripted passage can have its FIRST character dragged back into that passage.
# Measured on Darshanamu Neeyara: the boundary between the refrain line and the next
# line was placed at 170.88 s, while the independent ASR heard the next line's words
# only from 183.30 s and the aligner's own singing evidence was 0.00 for 179-183 s -
# a 12.4 s error, and the only head in that track that far unsupported.
#
# Both signals are required, because neither alone is proof: the ASR misses words in
# singing, and a slow line can legitimately hold for 20 s (that track really does,
# after every refrain). A head is repaired only when it is wordless for at least
# HEAD_GAP_MIN seconds AND the cue's character rate is too slow to have been sung in
# one pass. The new start is the first ASR word minus the track's OWN measured offset
# between a cue start and its first word, so no absolute constant is invented.
HEAD_GAP_MIN = 4.0        # seconds of wordless head before a late start is believed
HEAD_RATE_MAX = 2.0       # characters/second; below this the span cannot be one pass
HEAD_MOVE_MIN = 2.0       # smallest repair worth making
ASSOC_TOL = 1.5           # seconds of tolerance when tying an ASR word to a cue


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

    # MONOTONE CURSOR. A relocation must start at or after the previous line's end,
    # otherwise two low-coverage lines can both pick the same best-matching ASR window
    # and the rebuilt timeline overlaps (measured: lines 37, 38 and 40 all jumped onto
    # 245.18-249.62, which the validator then correctly refused). The cursor only moves
    # forward, so moves cascade in order instead of colliding.
    cursor = 0.0
    moves = []
    for i, s in enumerate(stats):
        if s["in_span"] >= LOW_COVERAGE:
            cursor = max(cursor, s["cue"]["end"])
            continue
        lo = max(cursor, next((p["cue"]["end"] for p in reversed(stats[:i])
                               if p["in_span"] >= LOW_COVERAGE), 0.0))
        hi = next((n["cue"]["start"] for n in stats[i + 1:] if n["in_span"] >= LOW_COVERAGE), args.duration)
        if hi - lo < 0.2:
            cursor = max(cursor, s["cue"]["end"])
            continue
        cand = [w for w in words if w["start"] >= lo - 0.05 and w["end"] <= hi + 0.05]
        if not cand:
            cursor = max(cursor, s["cue"]["end"])
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
        if (bs is not None and sc >= GOOD_COVERAGE and sc > s["in_span"] + MIN_GAIN
                and abs(bs - s["cue"]["start"]) <= MAX_MOVE_SECONDS):
            moves.append({"index": i, "text": s["cue"]["text"], "from": [s["cue"]["start"], s["cue"]["end"]],
                          "to": [bs, be], "in_span": s["in_span"], "best": sc, "window": [lo, hi]})
            s["cue"]["start"], s["cue"]["end"] = bs, be
            cursor = max(cursor, be)
        else:
            cursor = max(cursor, s["cue"]["end"])

    for m in moves:
        print(f"  MOVED line {m['index'] + 1}: {m['from'][0]:.2f}-{m['from'][1]:.2f} -> "
              f"{m['to'][0]:.2f}-{m['to'][1]:.2f}  (in-span {m['in_span']:.2f} -> {m['to'] and m['best']:.2f})")
    if not moves:
        print("  no line needed moving")

    # ---- head repair (see HEAD_GAP_MIN / HEAD_RATE_MAX above) -------------------
    def assoc(c):
        return [w for w in words
                if c["start"] - ASSOC_TOL <= w["start"] < c["end"] + ASSOC_TOL]

    # The track's own offset between a cue start and its first ASR word, measured only
    # on heads that are already tight. No absolute constant is invented.
    offs = []
    for s in stats:
        w = assoc(s["cue"])
        if not w:
            continue
        d = w[0]["start"] - s["cue"]["start"]
        if 0.0 <= d <= HEAD_GAP_MIN:
            offs.append(d)
    offs.sort()
    offset = offs[len(offs) // 2] if offs else 0.0
    print(f"  head offset measured on {len(offs)} tight heads: {offset:.2f}s")

    repairs = []
    for i, s in enumerate(stats):
        c = s["cue"]
        w = assoc(c)
        if not w:
            continue
        gap = w[0]["start"] - c["start"]
        chars = len(c["text"].replace(" ", ""))
        rate = chars / max(1e-6, c["end"] - c["start"])
        if gap < HEAD_GAP_MIN or rate >= HEAD_RATE_MAX:
            continue
        new_start = round(w[0]["start"] - offset, 3)
        if new_start - c["start"] < HEAD_MOVE_MIN or new_start >= c["end"] - 1.0:
            continue
        if new_start - c["start"] > MAX_MOVE_SECONDS:
            continue
        prev = stats[i - 1]["cue"] if i else None
        if prev is not None and new_start <= prev["start"] + 0.5:
            continue
        repairs.append({"index": i, "text": c["text"], "from": [c["start"], c["end"]],
                        "to": [new_start, c["end"]], "head_gap": gap, "rate": rate,
                        "first_word": w[0]["start"]})
        # The previous cue holds through the passage instead of a new {{Music}} banner:
        # the supplied structure is preserved (only the boundary moves).
        if prev is not None and prev["end"] < new_start:
            prev["end"] = new_start
        c["start"] = new_start
    for r in repairs:
        print(f"  REPAIRED head line {r['index'] + 1}: {r['from'][0]:.2f}-{r['from'][1]:.2f} -> "
              f"{r['to'][0]:.2f}-{r['to'][1]:.2f}  (wordless head {r['head_gap']:.2f}s, "
              f"rate {r['rate']:.2f} c/s, first word {r['first_word']:.2f}s)")
    if not repairs:
        print("  no head needed repairing")

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
        json.dump({"duration": args.duration, "cues": len(timeline), "moved": moves,
                   "head_offset": offset, "head_repairs": repairs, "timeline": timeline},
                  open(args.report, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(f"wrote {args.report}")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
