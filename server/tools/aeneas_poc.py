#!/usr/bin/env python3
"""PROOF OF CONCEPT - read-only. Runs aeneas against one track and writes its SRT.

aeneas aligns a MONOTONE text sequence to the whole audio: fragment i must come
after fragment i-1, and every fragment gets a contiguous slice of the track. Our
songs repeat the refrain many times while the plain lyrics list each line once, so
the prediction is that aeneas can only produce ONE cue per lyric line.

This script exists to measure that instead of asserting it. It writes nothing to
the database.

Official sources:
  https://github.com/readbeyond/aeneas  (v1.7.3, 2017; Python 2.7 / 3.5+;
      requires ffmpeg + eSpeak; "Confirmed working on 38 languages" - Telugu is
      NOT among them; Limitations: "Audio is assumed to be spoken: not suitable
      for song captioning")
  https://pypi.org/simple/aeneas/  (source tarballs only, no wheels)
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


def run(cmd, label):
    print("\n$ " + " ".join(cmd), flush=True)
    p = subprocess.run(cmd, capture_output=True, text=True)
    print(f"--- {label}: exit {p.returncode}")
    if p.stdout.strip():
        print(p.stdout.strip()[:4000])
    if p.stderr.strip():
        print("STDERR:", p.stderr.strip()[:4000])
    return p.returncode, p.stdout + p.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--out-dir", default="aeneas-out")
    ap.add_argument("--languages", default="te,eng")
    args = ap.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    supa = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_ANON_KEY"]
    row = json.loads(http_get(
        f"{supa}/rest/v1/tracks?id=eq.{args.id}&select=title,plain_lyrics,duration,synced_lyrics",
        {"apikey": key, "Authorization": "Bearer " + key, "Accept": "application/json"},
    ))[0]

    tracks = json.load(open("track-list.json", encoding="utf-8"))
    url = next(t["url"] for t in tracks if t["id"] == args.id)

    # aeneas `plain` text = one fragment per non-empty line; strip our {Section} markers
    fragments = [l.strip() for l in row["plain_lyrics"].splitlines() if l.strip() and not MARKER.match(l)]
    text_path = os.path.join(args.out_dir, "fragments.txt")
    with open(text_path, "w", encoding="utf-8") as f:
        f.write("\n".join(fragments) + "\n")
    print(f"track: {row['title']}  duration {row['duration']}s")
    print(f"fragments written: {len(fragments)} (aeneas will emit at most one cue per fragment)")

    audio_path = os.path.join(args.out_dir, "track.audio")
    with open(audio_path, "wb") as f:
        f.write(http_get(url))
    print(f"audio: {os.path.getsize(audio_path)} bytes")

    run([sys.executable, "-m", "aeneas.diagnostics"], "diagnostics")

    summary = {"fragments": len(fragments), "attempts": []}
    for lang in args.languages.split(","):
        lang = lang.strip()
        out = os.path.join(args.out_dir, f"aeneas-{lang}.srt")
        cfg = f"task_language={lang}|os_task_file_format=srt|is_text_type=plain"
        code, log = run([sys.executable, "-m", "aeneas.tools.execute_task",
                         audio_path, text_path, cfg, out], f"execute_task {lang}")
        produced = os.path.exists(out) and os.path.getsize(out) > 0
        cues = 0
        if produced:
            body = open(out, encoding="utf-8").read()
            cues = len(re.findall(r"-->\s", body))
            print(f"--- {lang}: produced SRT with {cues} cue(s), {os.path.getsize(out)} bytes")
        summary["attempts"].append({"language": lang, "exit": code, "srt": produced, "cues": cues,
                                    "log_tail": log[-1200:]})
    with open(os.path.join(args.out_dir, "aeneas-summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1)
    print("\nwrote aeneas-summary.json")


if __name__ == "__main__":
    sys.exit(main())
