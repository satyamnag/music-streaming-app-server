#!/usr/bin/env python3
"""Transcribe one track to the word format whisper-segment-sync.mjs parses.

Used for tracks that are NOT in the committed whisper-words.json snapshot. Produces
`words.txt` lines of:  <start> -> <end>   <word>  (p=<prob>)

Official references: faster-whisper README (WhisperModel / transcribe kwargs,
word_timestamps, beam_size, condition_on_previous_text).
  https://github.com/SYSTRAN/faster-whisper
"""
import argparse
import json
import os
import urllib.request

MODEL = "large-v3"
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"


def http_get(url, headers=None, timeout=600):
    h = {"User-Agent": UA, "Accept": "*/*"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--track", required=True)
    ap.add_argument("--out-dir", default="audio-out")
    ap.add_argument("--beam", type=int, default=5)
    ap.add_argument("--compute-type", default="int8",
                    help="ctranslate2 compute type: int8 (fast) or float32 (more accurate)")
    ap.add_argument("--separate-vocals", action="store_true",
                    help="isolate vocals with Demucs before transcribing (needs demucs installed)")
    args = ap.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    supa = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_ANON_KEY"]
    r2 = os.environ["R2_BASE_URL"].rstrip("/")
    row = json.loads(http_get(
        f"{supa}/rest/v1/tracks?id=eq.{args.track}&select=id,title,duration,storage_path,plain_lyrics,plain_lyrics_en,plain_lyrics_en_tr",
        {"apikey": key, "Authorization": "Bearer " + key, "Accept": "application/json"},
    ))[0]
    if not row.get("storage_path"):
        raise SystemExit("track has no audio file")
    url = f"{r2}/" + "/".join(urllib.parse.quote(p) for p in row["storage_path"].split("/"))
    print(f"track: {row['title']}  duration {row['duration']}s")
    print(f"audio: {url}")

    audio = os.path.join(args.out_dir, "track.audio")
    open(audio, "wb").write(http_get(url))
    print(f"audio bytes: {os.path.getsize(audio)}")

    from faster_whisper import WhisperModel
    target = audio
    if args.separate_vocals:
        # Dense sung passages are where whisper drops words, because music masks the
        # vocal. Demucs gives it a cleaner signal. Optional: fails loudly if missing.
        import subprocess
        import shutil
        print("separating vocals with demucs...")
        subprocess.run([shutil.which("demucs") or "demucs", "--two-stems", "vocals",
                        "-n", "htdemucs", "-o", args.out_dir, audio], check=True)
        cand = os.path.join(args.out_dir, "htdemucs", os.path.splitext(os.path.basename(audio))[0], "vocals.wav")
        if not os.path.exists(cand):
            cand = os.path.join(args.out_dir, "htdemucs", "track", "vocals.wav")
        if not os.path.exists(cand):
            raise SystemExit("demucs produced no vocals stem at " + cand)
        target = cand
        print(f"vocals stem: {target}")

    model = WhisperModel(MODEL, device="cpu", compute_type=args.compute_type)
    segments, info = model.transcribe(
        target,
        language="te",
        word_timestamps=True,
        beam_size=args.beam,
        condition_on_previous_text=False,
        vad_filter=False,
    )
    lines = []
    for seg in segments:
        for w in (seg.words or []):
            text = str(w.word).strip()
            if not text:
                continue
            lines.append(f"{float(w.start):.2f} -> {float(w.end):.2f}   {text}  (p={float(getattr(w, 'probability', 0) or 0):.3f})")

    open(os.path.join(args.out_dir, "words.txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    open(os.path.join(args.out_dir, "plain.txt"), "w", encoding="utf-8").write(row["plain_lyrics"] or "")
    json.dump({"track": row["id"], "title": row["title"], "duration": row["duration"],
               "words": len(lines), "language": info.language},
              open(os.path.join(args.out_dir, "job.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    span = (float(lines[0].split(" -> ")[0]), float(lines[-1].split(" -> ")[1].split("   ")[0])) if lines else (0, 0)
    print(f"words: {len(lines)}   language {info.language}   span {span[0]:.1f}s -> {span[1]:.1f}s")
    print(f"wrote {args.out_dir}/words.txt and plain.txt")


if __name__ == "__main__":
    import urllib.parse  # noqa: F401  (used above)
    main()
