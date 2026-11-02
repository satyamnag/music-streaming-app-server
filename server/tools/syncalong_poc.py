#!/usr/bin/env python3
"""PROOF OF CONCEPT - read-only. Runs syncalong's aligner on one track.

Two modes, because they answer different questions:

  injected (default)
      Feed syncalong the BEST transcript that exists for this track: the committed
      large-v3 word stream in whisper-words.json. This is syncalong at its
      strongest, so the measurement is not limited by a weaker Whisper model.
      Uses `align_lyrics_to_transcript()` exactly as documented.

  cli
      The tool's own end-to-end path (`syncalong song.txt song.mp3`), which runs
      its own Whisper. Wiring check, not the quality benchmark.

Nothing is written to the database.

Official sources:
  https://syncalong.readthedocs.io/en/stable/            (MIT, Whisper + DP aligner, LRC out)
  https://syncalong.readthedocs.io/en/stable/how-it-works/
      "Each lyric line takes the timestamp of its earliest matched word" and
      unmatched lines are INTERPOLATED / EXTRAPOLATED => one timestamp per lyric
      line, invented timings where nothing matched.
  https://syncalong.readthedocs.io/en/stable/reference/align/
      align_lyrics_to_transcript(lyric_lines, transcript, *, threshold=55.0)
  https://syncalong.readthedocs.io/en/stable/reference/transcribe/
      WordTimestamp(word, raw, start, end)
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
MARKER = re.compile(r"^\s*\{.*\}\s*$")


def http_get(url, headers=None, timeout=180):
    h = {"User-Agent": UA, "Accept": "*/*"}
    if headers:
        h.update(headers)
    with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=timeout) as r:
        return r.read()


def lrc_time(sec):
    """[mm:ss.xx] as documented for syncalong's LRC output."""
    total = max(0.0, float(sec))
    minutes = int(total // 60)
    rest = total - minutes * 60
    return f"[{minutes:02d}:{rest:05.2f}]"


def render_lrc(lines, stamps):
    out = []
    for text, ts in zip(lines, stamps):
        out.append(f"{lrc_time(ts) if ts is not None else '[00:00.00]'} {text}")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--mode", default="injected", choices=["injected", "cli", "both"])
    ap.add_argument("--model", default="tiny", help="whisper model for --mode cli")
    ap.add_argument("--out-dir", default="syncalong-out")
    args = ap.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    supa = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_ANON_KEY"]
    row = json.loads(http_get(
        f"{supa}/rest/v1/tracks?id=eq.{args.id}&select=title,plain_lyrics,duration",
        {"apikey": key, "Authorization": "Bearer " + key, "Accept": "application/json"},
    ))[0]
    tracks = json.load(open("track-list.json", encoding="utf-8"))
    url = next(t["url"] for t in tracks if t["id"] == args.id)

    lines = [l.strip() for l in row["plain_lyrics"].splitlines() if l.strip() and not MARKER.match(l)]
    print(f"track: {row['title']}  duration {row['duration']}s")
    print(f"lyric lines: {len(lines)}")

    summary = {"title": row["title"], "lyric_lines": len(lines), "runs": []}

    if args.mode in ("injected", "both"):
        import syncalong  # noqa: F401  (import check)
        from syncalong.lyrics import parse_lyrics
        from syncalong.transcribe import WordTimestamp
        from syncalong.align import align_lyrics_to_transcript

        print(f"syncalong version: {getattr(syncalong, '__version__', 'unknown')}")

        wrec = json.load(open("whisper-words.json", encoding="utf-8"))
        track = next(w for w in wrec if w["id"] == args.id)
        transcript = [
            WordTimestamp(word=str(w["word"]).strip(), raw=str(w["word"]).strip(),
                          start=float(w["start"]), end=float(w["end"]))
            for w in track["words"]
        ]
        print(f"injected transcript: {len(transcript)} words (committed large-v3 stream)")

        lyric_lines = parse_lyrics("\n".join(lines))
        print(f"syncalong parsed {len(lyric_lines)} lyric line(s)")

        pairs = align_lyrics_to_transcript(lyric_lines, transcript)
        print(f"align returned {len(pairs)} pair(s)")
        stamps = [ts for _line, ts in pairs]
        matched = sum(1 for s in stamps if s is not None)
        print(f"lines with a matched word: {matched}/{len(stamps)}  (the rest are interpolated)")

        lrc = render_lrc(lines, stamps)
        path = os.path.join(args.out_dir, "syncalong-injected.lrc")
        open(path, "w", encoding="utf-8").write(lrc)
        json.dump({"lines": lines, "timestamps": stamps},
                  open(os.path.join(args.out_dir, "syncalong-injected.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
        print("\n--- LRC (first 8) ---")
        print("\n".join(lrc.splitlines()[:8]))
        summary["runs"].append({"mode": "injected", "words": len(transcript),
                                "lines": len(pairs), "matched": matched, "lrc": path})

    if args.mode in ("cli", "both"):
        audio = os.path.join(args.out_dir, "track.audio")
        open(audio, "wb").write(http_get(url))
        txt = os.path.join(args.out_dir, "lyrics.txt")
        open(txt, "w", encoding="utf-8").write("\n".join(lines) + "\n")
        cmd = [sys.executable, "-m", "syncalong", txt, audio, "--model", args.model]
        print("\n$ " + " ".join(cmd), flush=True)
        p = subprocess.run(cmd, capture_output=True, text=True)
        print(f"--- cli: exit {p.returncode}")
        if p.stderr.strip():
            print("STDERR:", p.stderr.strip()[:3000])
        out = os.path.join(args.out_dir, "syncalong-cli.lrc")
        if p.returncode == 0 and p.stdout.strip():
            open(out, "w", encoding="utf-8").write(p.stdout)
            print("\n".join(p.stdout.splitlines()[:8]))
            summary["runs"].append({"mode": "cli", "model": args.model, "exit": 0,
                                    "cues": p.stdout.count("]"), "lrc": out})
        else:
            print(p.stdout[:2000])
            summary["runs"].append({"mode": "cli", "model": args.model, "exit": p.returncode})

    json.dump(summary, open(os.path.join(args.out_dir, "syncalong-summary.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("\nwrote syncalong-summary.json")


if __name__ == "__main__":
    sys.exit(main())
