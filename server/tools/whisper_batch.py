# ============================================================================
# Batch Whisper transcription for the whole Soulful Bhakti catalogue, ON Modal.
#
# Why Modal: this is the heavy compute step (376+ minutes of audio through
# Whisper large-v3). It must not run on the web dyno, and a GitHub runner has no
# GPU. Modal gives real containers, and the HuggingFace cache lives in a Volume so
# the 1.3 GB model is downloaded ONCE for the whole batch.
#
# Each container loads the model once, then transcribes a CHUNK of tracks, so the
# load cost is amortised. Chunks run in parallel via `.map()`.
#
# RESULTS ARE ORDER-INDEPENDENT: every track is written to its own file in a
# results Volume as soon as it finishes, and an existing file is skipped. That
# makes the batch resumable and means a slow chunk can never block progress.
#
# Output: one <track_id>.json per track in the volume, then downloaded locally.
# Nothing is written to any database by this script.
#
# Run:
#   modal run whisper_batch.py --chunk-size 6 [--limit N]
#   modal volume get soulful-bhakti-whisper-results / whisper-results
# ============================================================================

import json
import os
import modal

MODEL_SIZE = "large-v3"
LANGUAGE = "te"

hf_cache = modal.Volume.from_name("soulful-bhakti-hf-cache", create_if_missing=True)
results_vol = modal.Volume.from_name("soulful-bhakti-whisper-results", create_if_missing=True)

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("faster-whisper")
    .env({"HF_HOME": "/cache", "HF_HUB_DISABLE_TELEMETRY": "1"})
)

app = modal.App("soulful-bhakti-whisper-batch", image=image)

# Kavalini Eleti is already verified and live; don't spend compute on it.
SKIP_IDS = {"72e585fd-7a6e-42ff-a8e6-d56a9a836f33"}


@app.function(
    cpu=4,
    memory=8192,
    timeout=7200,
    volumes={"/cache": hf_cache, "/results": results_vol},
    # Kept low on purpose: ~20 simultaneous containers starved each other of CPU.
    max_containers=6,
)
def transcribe_chunk(items):
    from faster_whisper import WhisperModel

    model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")
    new = 0
    for it in items:
        out_path = f"/results/{it['id']}.json"
        if os.path.exists(out_path):
            continue  # already done in an earlier run
        try:
            segments, info = model.transcribe(
                it["url"],
                language=LANGUAGE,
                # Greedy decoding: ~4-5x faster than beam 5 on CPU. Word timings
                # are what this pipeline consumes, and every result is validated
                # downstream, so a slightly weaker transcript costs nothing here.
                beam_size=1,
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
            rec = {
                "id": it["id"],
                "title": it["title"],
                "duration": it["duration"],
                "language": info.language,
                "language_probability": round(info.language_probability, 4),
                "words": words,
                "error": None,
            }
            print(f"  ok  {it['title'][:44]:44s} words={len(words)}")
        except Exception as e:  # one bad track must not kill the batch
            rec = {"id": it["id"], "title": it["title"], "duration": it["duration"],
                   "words": [], "error": f"{type(e).__name__}: {e}"[:200]}
            print(f"  ERR {it['title'][:44]:44s} {type(e).__name__}")

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(rec, f, ensure_ascii=False)
        results_vol.commit()
        new += 1
    return new


@app.local_entrypoint()
def main(chunk_size: int = 6, limit: int = 0):
    tracks = [t for t in json.load(open("track-list.json", encoding="utf-8"))
              if t["id"] not in SKIP_IDS]
    if limit:
        tracks = tracks[:limit]

    chunks = [tracks[i:i + chunk_size] for i in range(0, len(tracks), chunk_size)]
    print(f"tracks: {len(tracks)}  chunks: {len(chunks)} (containers skip finished tracks)")

    total = 0
    for i, n in enumerate(transcribe_chunk.map(chunks)):
        total += n
        print(f"chunk {i + 1}/{len(chunks)} done -> {total} new track(s)")

    print(f"\nDONE  new transcriptions: {total}")
    print("download with: modal volume get soulful-bhakti-whisper-results / whisper-results")
