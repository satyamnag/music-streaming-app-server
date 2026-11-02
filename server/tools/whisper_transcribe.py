# ============================================================================
# Whisper (faster-whisper) transcription of a Soulful Bhakti track, ON Modal GPU.
#
# Proof-of-concept for ONE track: transcribes the audio with Whisper large-v3
# (multilingual, MIT-licensed) with word-level timestamps, and writes the raw
# result to a txt file so it can be compared head-to-head against the Deepgram
# dump (Kavalini-Eleti-deepgram-output.txt).
#
# Run with Modal:
#   modal run whisper_transcribe.py
# or run the @app.local_entrypoint locally (CPU) for a smoke test.
#
# Output: ./whisper-output/<track-label>.txt
# ============================================================================

import os
import json

import modal

# A100 40GB is ample for large-v3 fp16; T4 (16GB) also works via int8.
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("faster-whisper")
)

app = modal.App("soulful-bhakti-whisper", image=image)

# The same track used for the Deepgram dump, for a fair A/B comparison. These
# are overridable via TRACK_URL / TRACK_LABEL env for the general sync path.
TRACK_URL = os.environ.get("TRACK_URL", "https://music.soulfulbhakti.com/1792132043466-Kavalini%20Yeledi.opus")
TRACK_LABEL = os.environ.get("TRACK_LABEL", "Kavalini-Eleti")
MODEL_SIZE = "large-v3"
LANGUAGE = "te"  # Telugu; pin it so Whisper doesn't auto-detect wrong


@app.function(cpu=4, memory=8192)
def transcribe_one():
    from faster_whisper import WhisperModel

    # CPU fallback (free tier): large-v3 int8 needs ~4GB RAM; slower but proves
    # the pipeline. GPU (T4/A100) requires a payment method on the Modal account.
    model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")

    segments, info = model.transcribe(
        TRACK_URL,
        language=LANGUAGE,
        beam_size=5,
        word_timestamps=True,
        condition_on_previous_text=False,
    )

    # `segments` is a generator; materialize it to actually run inference.
    segs = list(segments)

    lines = [
        f"TRACK: {TRACK_LABEL}",
        f"MODEL: faster-whisper {MODEL_SIZE} (int8, CPU)",
        f"LANGUAGE: detected={info.language} prob={info.language_probability:.4f}",
        f"DURATION: {info.duration:.2f}s",
        "",
        "=== WORD-LEVEL TIMESTAMPS ===",
        "",
    ]
    n_words = 0
    confs = []
    for s in segs:
        lines.append(f"[{s.start:8.2f} -> {s.end:8.2f}]  {s.text.strip()}")
        for w in (s.words or []):
            n_words += 1
            confs.append(w.probability if w.probability is not None else 0.0)
            lines.append(
                f"    {w.start:8.2f} -> {w.end:8.2f}  {w.word}"
                + (f"  (p={w.probability:.3f})" if w.probability is not None else "")
            )

    avg = (sum(confs) / len(confs)) if confs else 0.0
    low = sum(1 for c in confs if c < 0.5)
    lines += [
        "",
        "=== SUMMARY ===",
        f"segments: {len(segs)}",
        f"words: {n_words}",
        f"avg word probability: {avg:.3f}",
        f"words with p < 0.5: {low}/{n_words}",
    ]

    text = "\n".join(lines) + "\n"

    os.makedirs("whisper-output", exist_ok=True)
    out_path = os.path.join("whisper-output", f"{TRACK_LABEL}-whisper-output.txt")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(text)

    # Machine-readable words for the aligner: [{"word","start","end","confidence"}]
    words = []
    for s in segs:
        for w in (s.words or []):
            words.append({
                "word": w.word,
                "start": round(w.start, 3),
                "end": round(w.end, 3),
                "confidence": round(w.probability, 4) if w.probability is not None else 0.0,
            })

    print(text)
    print(f"\nWROTE {out_path}")
    # Emit a single JSON line the Node caller can parse deterministically.
    print("__WHISPER_JSON__" + json.dumps({
        "language": info.language,
        "language_probability": round(info.language_probability, 4),
        "duration": round(info.duration, 3),
        "words": words,
    }, ensure_ascii=False))
    return out_path


@app.local_entrypoint()
def main():
    out = transcribe_one.remote()
    print("saved:", out)
