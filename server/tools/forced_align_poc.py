#!/usr/bin/env python3
"""PROOF OF CONCEPT - read-only. Measures what lyric-anchored forced alignment
would change, without touching the database.

WHY
---
The current pipeline segments Whisper's TRANSCRIPT. Every remaining defect traces
back to transcription: whisper writes `కోపాల` for `గోపాల`, merges a whole line into
one token, and emits nothing at all for a garbled line. We do not need the
transcript's text at all - the plain lyrics ARE the text (source of truth). What
we need from the audio is only WHERE those known words are.

This script takes each existing cue, uses its exact plain-lyric line as the
alignment target, force-aligns it against the track audio with
`torchaudio.functional.forced_align` and the Telugu wav2vec2 CTC model that
WhisperX itself ships for `te`, then reports the aligned word boundaries next to
the currently stored ones.

Official sources consulted:
  whisperx (alignment model table, "te" -> anuragshas/wav2vec2-large-xlsr-53-telugu)
    https://github.com/m-bain/whisperX/blob/main/whisperx/alignment.py
  torchaudio.functional.forced_align (API + shape/serialization rules)
    https://docs.pytorch.org/audio/stable/generated/torchaudio.functional.forced_align.html
  model config (vocab_size 66, pad_token_id 65)
    https://huggingface.co/anuragshas/wav2vec2-large-xlsr-53-telugu/raw/main/config.json
  model vocab (ids 0-65, '|'=30, '[UNK]'=64, '[PAD]'=65)
    https://huggingface.co/anuragshas/wav2vec2-large-xlsr-53-telugu/raw/main/vocab.json

Nothing is written anywhere except its own JSON report.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request

import numpy as np
import torch
import torchaudio
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

SAMPLE_RATE = 16000
# wav2vec2 conv feature extractor stride: 5*2*2*2*2*2*2 = 320 samples per frame.
FRAME_SECONDS = 320 / SAMPLE_RATE
MODEL = "anuragshas/wav2vec2-large-xlsr-53-telugu"
MUSIC_LABEL = "{{Music}}"
SRT_TIME = re.compile(r"(\d+):(\d+):(\d+),(\d+) --> (\d+):(\d+):(\d+),(\d+)")


def srt_seconds(h, m, s, ms):
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000.0


def parse_srt(text):
    cues = []
    for block in re.split(r"\r?\n\r?\n", text.strip()):
        lines = [l for l in block.split("\n") if l.strip() != ""]
        ti = next((i for i, l in enumerate(lines) if "-->" in l), None)
        if ti is None:
            continue
        m = SRT_TIME.search(lines[ti])
        if not m:
            continue
        cues.append({
            "start": srt_seconds(*m.groups()[:4]),
            "end": srt_seconds(*m.groups()[4:]),
            "text": " ".join(lines[ti + 1:]).strip(),
        })
    return cues


def load_audio(url):
    """Download and decode to 16 kHz mono float32 via ffmpeg (present on runners)."""
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "in.audio")
        with urllib.request.urlopen(url, timeout=180) as r, open(src, "wb") as f:
            f.write(r.read())
        pcm = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", src, "-f", "s16le", "-acodec", "pcm_s16le",
             "-ar", str(SAMPLE_RATE), "-ac", "1", "-"],
            capture_output=True, check=True,
        ).stdout
    return np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768.0


def build_vocab(processor, vocab_size):
    """char -> ctc index, restricted to ids the model can actually emit.

    The model's own vocab.json has 66 entries (0..65). `tokenizer.get_vocab()`
    additionally reports the added tokens `<s>`/`</s>` at 66/67, which are NOT
    output columns - that mismatch is what blocked an earlier forced-alignment
    attempt ("open an issue" in ctc-forced-aligner). Filtering to
    id < vocab_size is the correct fix.
    """
    raw = processor.tokenizer.get_vocab()
    vocab = {c: i for c, i in raw.items() if i < vocab_size}
    blank = vocab.get("[PAD]")
    if blank is None:
        blank = vocab.get("<pad>", vocab_size - 1)
    return vocab, blank


def line_targets(line, vocab):
    """CTC target ids for a lyric line, plus the word index of every kept char."""
    ids, owners = [], []
    for wi, word in enumerate(line.split()):
        for ch in word:
            idx = vocab.get(ch)
            if idx is None:
                continue  # unalignable character (documented whisperx limitation)
            ids.append(idx)
            owners.append(wi)
    return ids, owners


def align_window(model, wav, t_from, t_to, ids, blank, device):
    f1 = max(0, int(t_from * SAMPLE_RATE))
    f2 = min(len(wav), int(t_to * SAMPLE_RATE))
    if f2 - f1 < 400:
        return None
    x = torch.from_numpy(wav[f1:f2]).unsqueeze(0).to(device)
    with torch.inference_mode():
        logits = model(x).logits
    log_probs = torch.log_softmax(logits, dim=-1)
    frames = log_probs.shape[1]
    # documented constraint: frames >= len(targets) + repeats
    repeats = sum(1 for i in range(1, len(ids)) if ids[i] == ids[i - 1])
    if frames < len(ids) + repeats:
        return None
    targets = torch.tensor([ids], dtype=torch.int64, device=device)
    alignment, scores = torchaudio.functional.forced_align(
        log_probs, targets, blank=blank
    )
    return {
        "alignment": alignment[0].cpu().numpy(),
        "scores": scores[0].cpu().numpy(),
        "t_from": f1 / SAMPLE_RATE,
        "frames": frames,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", required=True, help="comma separated track ids")
    ap.add_argument("--pad", type=float, default=1.0, help="seconds of context around the inter-cue gap")
    ap.add_argument("--out", default="forced-align-poc.json")
    args = ap.parse_args()

    supa = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_ANON_KEY"]
    tracks = json.load(open("track-list.json", encoding="utf-8"))
    by_id = {t["id"]: t for t in tracks}

    device = "cpu"
    processor = Wav2Vec2Processor.from_pretrained(MODEL)
    model = Wav2Vec2ForCTC.from_pretrained(MODEL).to(device).eval()
    vocab, blank = build_vocab(processor, model.config.vocab_size)
    print(f"model {MODEL}  vocab_size={model.config.vocab_size}  alignable chars={len(vocab)}  blank={blank}")

    results = []
    for tid in [x.strip() for x in args.ids.split(",") if x.strip()]:
        t = by_id.get(tid)
        if not t:
            print(f"!! {tid} not in track-list.json")
            continue
        req = urllib.request.Request(
            f"{supa}/rest/v1/tracks?id=eq.{tid}&select=plain_lyrics,synced_lyrics,duration",
            headers={"apikey": key, "Authorization": f"Bearer {key}"},
        )
        with urllib.request.urlopen(req, timeout=120) as r:
            row = json.loads(r.read())[0]

        print(f"\n=== {t['title']}  ({t['duration']}s) ===")
        wav = load_audio(t["url"])
        dur = len(wav) / SAMPLE_RATE
        print(f"audio {dur:.1f}s  ({len(wav)} samples)")

        cues = parse_srt(row["synced_lyrics"] or "")
        lyric_idx = [i for i, c in enumerate(cues) if c["text"].strip() != MUSIC_LABEL]
        report = []
        for n, ci in enumerate(lyric_idx):
            cue = cues[ci]
            line = cue["text"].strip()
            prev_end = cues[ci - 1]["end"] if ci > 0 else 0.0
            next_start = cues[ci + 1]["start"] if ci + 1 < len(cues) else dur
            # The inter-cue gap is the widest acoustically-plausible window: it lets
            # alignment place the line where it is ACTUALLY sung instead of trusting
            # whisper's token boundaries (which produced a 1.4s pallavi on Gopala).
            w_from = max(0.0, prev_end - args.pad)
            w_to = min(dur, next_start + args.pad)
            ids, owners = line_targets(line, vocab)
            if not ids:
                report.append({"line": line, "skipped": "no alignable characters"})
                continue
            res = align_window(model, wav, w_from, w_to, ids, blank, device)
            if res is None:
                report.append({"line": line, "skipped": "window too short for target length"})
                continue
            al, sc = res["alignment"], res["scores"]
            kept = al[al >= 0]
            if kept.size == 0:
                report.append({"line": line, "skipped": "backtrack produced no aligned frames"})
                continue
            # per-character frame spans
            spans = {}
            for frame, tok in enumerate(al):
                if tok < 0:
                    continue
                if tok not in spans:
                    spans[tok] = [frame, frame]
                else:
                    spans[tok][1] = frame
            words = line.split()
            wspan = {}
            for ti, (f0, f1) in spans.items():
                wi = owners[ti]
                if wi not in wspan:
                    wspan[wi] = [f0, f1]
                else:
                    wspan[wi][0] = min(wspan[wi][0], f0)
                    wspan[wi][1] = max(wspan[wi][1], f1)
            a_start = res["t_from"] + min(f for f, _ in spans.values()) * FRAME_SECONDS
            a_end = res["t_from"] + (max(f for _, f in spans.values()) + 1) * FRAME_SECONDS
            mean_lp = float(sc[al >= 0].mean())
            word_times = [
                {
                    "w": words[wi],
                    "start": round(res["t_from"] + wspan[wi][0] * FRAME_SECONDS, 3),
                    "end": round(res["t_from"] + (wspan[wi][1] + 1) * FRAME_SECONDS, 3),
                }
                for wi in sorted(wspan)
            ]
            report.append({
                "line": line,
                "window": [round(w_from, 2), round(w_to, 2)],
                "current": [round(cue["start"], 3), round(cue["end"], 3)],
                "aligned": [round(a_start, 3), round(a_end, 3)],
                "d_start": round(a_start - cue["start"], 3),
                "d_end": round(a_end - cue["end"], 3),
                "mean_logprob": round(mean_lp, 4),
                "mean_prob": round(float(np.exp(mean_lp)), 4),
                "words": word_times,
            })
            print(f"  {cue['start']:7.2f}-{cue['end']:7.2f} -> {a_start:7.2f}-{a_end:7.2f}"
                  f"  (d {a_start - cue['start']:+6.2f}/{a_end - cue['end']:+6.2f})  p={np.exp(mean_lp):.3f}  {line[:34]}")

        ok = [r for r in report if "aligned" in r]
        if ok:
            ds = [abs(r["d_start"]) for r in ok]
            de = [abs(r["d_end"]) for r in ok]
            print(f"  --> {len(ok)}/{len(report)} lines aligned; median |d_start| {np.median(ds):.2f}s, |d_end| {np.median(de):.2f}s; "
                  f"{(sum(1 for x in ds if x > 0.5))} start(s) and {(sum(1 for x in de if x > 0.5))} end(s) moved >0.5s")
        results.append({"id": tid, "title": t["title"], "duration": t["duration"], "lines": report})

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=1)
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    sys.exit(main())
