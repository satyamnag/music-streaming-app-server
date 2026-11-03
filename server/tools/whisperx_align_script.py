#!/usr/bin/env python3
"""Re-time a GIVEN SRT against the real audio with WhisperX forced alignment.

The supplied subtitle lists every sung occurrence (the refrain pair appears 9x), so
the script is already in audio order - which is the one situation a monotone aligner
handles correctly. No ASR is involved: forced alignment needs no transcript, only the
known text and the acoustic model.

What it produces, in the app's structure:
  * one cue per supplied line, carrying the supplied text EXACTLY
  * `{{Music}}` cues covering every region the line text is not aligned into
    (head, interior gaps longer than --music-gap, tail), so the timeline spans
    0 -> duration with no hole and no overlap
  * every boundary is an aligned character boundary from the wav2vec2 CTC model -
    nothing is interpolated

Official sources
  whisperx alignment model table ("te" -> anuragshas/wav2vec2-large-xlsr-53-telugu)
    https://github.com/m-bain/whisperX/blob/main/whisperx/alignment.py
  whisperx aligner (get_trellis / backtrack / merge_repeats), used here at
    whole-track scope instead of per segment
    same file
  model config (vocab_size 66, pad_token_id 65, blank = [PAD])
    https://huggingface.co/anuragshas/wav2vec2-large-xlsr-53-telugu/raw/main/config.json
    https://huggingface.co/anuragshas/wav2vec2-large-xlsr-53-telugu/raw/main/vocab.json

  python whisperx_align_script.py --url <audio> --srt inputs/x.srt --duration 291
"""
import argparse
import json
import os
import re
import subprocess
import tempfile
import urllib.request

import numpy as np
import torch

SAMPLE_RATE = 16000
FRAME_SECONDS = 320 / SAMPLE_RATE        # wav2vec2 conv stride -> 20 ms per frame
MUSIC_LABEL = "{{Music}}"
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
SRT_TIME = re.compile(r"(\d+):(\d+):(\d+),(\d+) --> (\d+):(\d+):(\d+),(\d+)")


def http_get(url, timeout=300):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def ffmpeg_exe():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


def load_audio(url):
    raw = http_get(url)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "in.audio")
        open(src, "wb").write(raw)
        pcm = subprocess.run(
            [ffmpeg_exe(), "-v", "error", "-i", src, "-f", "s16le", "-acodec", "pcm_s16le",
             "-ar", str(SAMPLE_RATE), "-ac", "1", "-"],
            capture_output=True, check=True).stdout
    return np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768.0


def parse_srt(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n").strip()
    cues = []
    for block in re.split(r"\n\n+", text):
        lines = [l for l in block.split("\n") if l.strip()]
        ti = next((i for i, l in enumerate(lines) if "-->" in l), None)
        if ti is None:
            continue
        m = SRT_TIME.search(lines[ti])
        body = " ".join(lines[ti + 1:]).strip()
        cues.append({"start": int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3)) + int(m.group(4)) / 1000,
                     "end": int(m.group(5)) * 3600 + int(m.group(6)) * 60 + int(m.group(7)) + int(m.group(8)) / 1000,
                     "text": body})
    return cues


def emit_time(t):
    ms = int(round(max(0.0, t) * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def emissions_for(model, wav, device, window=30.0, context=1.0):
    """Chunked forward pass -> log_softmax emissions for the whole track.

    A single pass over a 291 s track would need T^2 attention (T ~ 14.5k frames), so
    the audio is processed in windows with context on both sides and only the middle
    is kept.
    """
    if not torch.is_tensor(wav):
        wav = torch.from_numpy(wav)
    total = wav.shape[0] / SAMPLE_RATE
    step = window - 2 * context
    out = []
    t0 = 0.0
    while t0 < total - 1e-6:
        w_start = max(0.0, t0 - context)
        w_end = min(total, t0 + step + context)
        seg = wav[int(w_start * SAMPLE_RATE):int(w_end * SAMPLE_RATE)]
        with torch.inference_mode():
            logits = model(seg.unsqueeze(0).to(device)).logits[0]
        lp = torch.log_softmax(logits, dim=-1).cpu()
        n = lp.shape[0]
        # frames of this window that belong to [t0, t0+step)
        f_lo = int(round((t0 - w_start) / FRAME_SECONDS))
        f_hi = min(n, int(round((min(total, t0 + step) - w_start) / FRAME_SECONDS)))
        if f_hi > f_lo:
            out.append(lp[f_lo:f_hi])
        t0 += step
    return torch.cat(out, dim=0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--srt", required=True)
    ap.add_argument("--duration", type=float, required=True)
    ap.add_argument("--music-gap", type=float, default=3.0,
                    help="gaps at least this long become a {{Music}} cue")
    ap.add_argument("--out-dir", default="whisperx-out")
    args = ap.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    cues_in = parse_srt(args.srt)
    texts = [c["text"] for c in cues_in]
    print(f"supplied cues: {len(cues_in)}  first {cues_in[0]['start']:.3f}s  last end {cues_in[-1]['end']:.3f}s")
    print(f"track duration: {args.duration}s")

    wav = load_audio(args.url)
    audio_seconds = len(wav) / SAMPLE_RATE
    print(f"audio decoded: {audio_seconds:.3f}s")

    from whisperx.alignment import load_align_model, get_trellis, backtrack, merge_repeats

    device = "cpu"
    model, metadata = load_align_model(language_code="te", device=device)
    vocab = metadata["dictionary"]
    blank = None
    for ch, idx in vocab.items():
        if ch.lower() in ("[pad]", "<pad>"):
            blank = idx
    if blank is None:
        blank = model.config.pad_token_id
    print(f"align model: te, {len(vocab)} dictionary entries, blank id {blank}")

    # Build the monotone target sequence and remember which line each char belongs to.
    # `clean` MUST stay index-aligned with `chars`/`owners`: merge_repeats() maps path
    # token indices back into it.
    chars, owners, clean_chars = [], [], []
    for li, text in enumerate(texts):
        for ch in text:
            if ch in (" ", "\t", "\u00a0"):
                continue
            idx = vocab.get(ch.lower())
            if idx is None:
                continue
            chars.append(idx)
            owners.append(li)
            clean_chars.append(ch)
    clean = "".join(clean_chars)
    print(f"alignable characters: {len(chars)} (of {sum(len(t) for t in texts)})")

    emission = emissions_for(model, wav, device)
    print(f"emission frames: {emission.shape[0]}  ({emission.shape[0] / (1 / FRAME_SECONDS):.1f}s)")

    trellis = get_trellis(emission, chars, blank)
    path = backtrack(trellis, emission, chars, blank)
    if path is None:
        raise SystemExit("backtrack failed - the script does not align to this audio")
    segs = merge_repeats(path, clean)
    print(f"aligned character segments: {len(segs)}")

    # line -> frame span (and score)
    span = {}
    score = {}
    for cdx, seg in enumerate(segs):
        li = owners[cdx]
        if li not in span:
            span[li] = [seg.start, seg.end]
            score[li] = [seg.score, 1]
        else:
            span[li][0] = min(span[li][0], seg.start)
            span[li][1] = max(span[li][1], seg.end)
            score[li][0] += seg.score
            score[li][1] += 1

    lines = []
    for li, text in enumerate(texts):
        if li not in span:
            lines.append({"text": text, "start": None, "end": None, "score": 0.0,
                          "supplied": [cues_in[li]["start"], cues_in[li]["end"]]})
            continue
        s, e = span[li]
        lines.append({
            "text": text,
            "start": round(s * FRAME_SECONDS, 3),
            "end": round((e + 1) * FRAME_SECONDS, 3),
            "score": round(score[li][0] / score[li][1], 4),
            "supplied": [cues_in[li]["start"], cues_in[li]["end"]],
        })

    placed = [l for l in lines if l["start"] is not None]
    print(f"\nlines aligned: {len(placed)}/{len(lines)}")
    print(f"{'#':>3} {'new start':>9} {'new end':>9} {'supplied':>9} {'delta':>7} {'score':>6}  text")
    for li, l in enumerate(lines):
        if l["start"] is None:
            print(f"{li + 1:>3} {'---':>9} {'---':>9} {l['supplied'][0]:>9.2f} {'---':>7} {'0':>6}  {l['text'][:38]}")
            continue
        print(f"{li + 1:>3} {l['start']:>9.3f} {l['end']:>9.3f} {l['supplied'][0]:>9.2f} "
              f"{l['start'] - l['supplied'][0]:>+7.2f} {l['score']:>6.3f}  {l['text'][:38]}")

    # ---- build the timeline: lines in order, {{Music}} wherever text is not sung ----
    timeline = []

    def add(entry):
        if timeline and abs(timeline[-1]["end"] - entry["start"]) > 1e-6:
            # keep the timeline contiguous; a 1 ms rounding step is enough
            entry["start"] = timeline[-1]["end"]
        timeline.append(entry)

    if placed:
        first = min(l["start"] for l in placed)
        if first > 0.05:
            add({"kind": "music", "text": MUSIC_LABEL, "start": 0.0, "end": round(first, 3)})
    for l in lines:
        if l["start"] is None:
            continue
        if timeline and l["start"] - timeline[-1]["end"] >= args.music_gap:
            timeline.append({"kind": "music", "text": MUSIC_LABEL,
                             "start": timeline[-1]["end"], "end": l["start"]})
        add({"kind": "lyric", "text": l["text"], "start": l["start"], "end": l["end"]})
    if placed:
        last = timeline[-1]["end"]
        if args.duration - last > 0.05:
            add({"kind": "music", "text": MUSIC_LABEL, "start": last, "end": round(args.duration, 3)})

    # normalise: contiguous, rounded, no zero-length
    for i, e in enumerate(timeline):
        if e["start"] is None:
            e["start"] = timeline[i - 1]["end"] if i else 0.0
        if e["end"] is None:
            e["end"] = timeline[i + 1]["start"] if i + 1 < len(timeline) else args.duration
    timeline = [e for e in timeline if e["end"] - e["start"] > 0.001]
    timeline[0]["start"] = 0.0
    timeline[-1]["end"] = float(args.duration)
    for i in range(len(timeline) - 1):
        timeline[i + 1]["start"] = timeline[i]["end"]

    srt = []
    for i, e in enumerate(timeline, 1):
        srt.append(f"{i}\n{emit_time(e['start'])} --> {emit_time(e['end'])}\n{e['text']}\n")
    out_srt = os.path.join(args.out_dir, "Peru-Teliyakunna.aligned.srt")
    open(out_srt, "w", encoding="utf-8").write("\n".join(srt))

    report = {
        "source_srt": args.srt, "duration": args.duration,
        "supplied_cues": len(cues_in), "lines": lines,
        "timeline": timeline,
        "aligned_lines": len(placed),
        "weak_lines": [l["text"] for l in placed if l["score"] < 0.3],
        "music_cues": sum(1 for e in timeline if e["kind"] == "music"),
    }
    json.dump(report, open(os.path.join(args.out_dir, "whisperx-align-report.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print(f"\ntimeline: {len(timeline)} cues ({report['music_cues']} music), "
          f"span {timeline[0]['start']:.3f} -> {timeline[-1]['end']:.3f}")
    print(f"weak lines (score < 0.3): {len(report['weak_lines'])}")
    print(f"wrote {out_srt}")


if __name__ == "__main__":
    main()
