# ============================================================================
# Batch Whisper transcription for the whole Soulful Bhakti catalogue, ON Modal.
#
# Why Modal: this is the heavy compute step (376+ minutes of audio through
# Whisper large-v3). It must not run on the web dyno, and a GitHub runner has no
# GPU. Modal gives real CPU/GPU containers, and the HuggingFace cache lives in a
# Volume so the 1.3 GB model is downloaded ONCE for the whole batch.
#
# Each container loads the model once, then transcribes a CHUNK of tracks, so the
# load cost is amortised. Chunks run in parallel via `.map()`.
#
# Output: whisper-words.json  (one entry per track, with word-level timings).
# Nothing is written to any database by this script.
#
# Run:
#   modal run whisper_batch.py --chunk-size 4 [--gpu]
# ============================================================================

import json
import os
import modal

MODEL_SIZE = "large-v3"
LANGUAGE = "te"

hf_cache = modal.Volume.from_name("soulful-bhakti-hf-cache", create_if_missing=True)

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("faster-whisper")
    .env({"HF_HOME": "/cache", "HF_HUB_DISABLE_TELEMETRY": "1"})
)

app = modal.App("soulful-bhakti-whisper-batch", image=image)


@app.function(
    cpu=4,
    memory=8192,
    timeout=7200,
    volumes={"/cache": hf_cache},
    max_containers=24,
)
def transcribe_chunk(items):
    from faster_whisper import WhisperModel

    # GPU if the account allows it (T4/A100 require a payment method), else CPU.
    device = os.environ.get("WHISPER_DEVICE", "cpu")
    compute = "int8_float16" if device == "cuda" else "int8"
    model = WhisperModel(MODEL_SIZE, device=device, compute_type=compute)

    out = []
    for it in items:
        try:
            segments, info = model.transcribe(
                it["url"],
                language=LANGUAGE,
                beam_size=5,
                word_timestamps=True,
                condition_on_previous_text=False,
            )
            words = []
            for s in segments:
                for w in (s.words or []):
                    words.append({
                        "word": w.word,
                        "start": round(w.start, 3),
                        "end": round(w.end, 3),
                        "confidence": round(w.probability, 4) if w.probability is not None else 0.0,
                    })
            out.append({
                "id": it["id"],
                "title": it["title"],
                "duration": it["duration"],
                "language": info.language,
                "language_probability": round(info.language_probability, 4),
                "words": words,
                "error": None,
            })
            print(f"  ok  {it['title'][:44]:44s} words={len(words)}")
        except Exception as e:  # one bad track must not kill the batch
            out.append({"id": it["id"], "title": it["title"], "duration": it["duration"],
                        "words": [], "error": f"{type(e).__name__}: {e}"[:200]})
            print(f"  ERR {it['title'][:44]:44s} {type(e).__name__}")
    hf_cache.commit()
    return out


@app.local_entrypoint()
def main(chunk_size: int = 4, limit: int = 0):
    # Kavalini Eleti is already verified and live; don't spend compute on it.
    SKIP_IDS = {"72e585fd-7a6e-42ff-a8e6-d56a9a836f33"}

    tracks = [t for t in json.load(open("track-list.json", encoding="utf-8"))
              if t["id"] not in SKIP_IDS]

    all_results = []
    if os.path.exists("whisper-words.json"):
        all_results = json.load(open("whisper-words.json", encoding="utf-8"))
        print(f"resuming with {len(all_results)} existing result(s)")

    done_ids = {r["id"] for r in all_results if r.get("words")}
    todo = [t for t in tracks if t["id"] not in done_ids]
    if limit:
        todo = todo[:limit]
    print(f"to transcribe: {len(todo)} track(s) in chunks of {chunk_size}")

    if not todo:
        print("nothing to do")
        return

    chunks = [todo[i:i + chunk_size] for i in range(0, len(todo), chunk_size)]
    # .map() runs the chunks in PARALLEL; iterating yields each finished chunk so
    # progress is persisted as we go (a killed run can resume).
    for i, results in enumerate(transcribe_chunk.map(chunks)):
        all_results.extend(results)
        with open("whisper-words.json", "w", encoding="utf-8") as f:
            json.dump(all_results, f, ensure_ascii=False, indent=1)
        print(f"chunk {i + 1}/{len(chunks)} done -> {len(all_results)} tracks total")

    ok = sum(1 for r in all_results if r.get("words"))
    print(f"\nDONE  transcribed={ok}/{len(all_results)}  -> whisper-words.json")
