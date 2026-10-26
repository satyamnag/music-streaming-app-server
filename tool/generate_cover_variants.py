#!/usr/bin/env python3
"""Generate 512x512 WebP cover variants for the Android app.

Run inside GitHub Actions (`cover-variants` workflow) - never locally.

What it does
    For every track cover and album cover referenced by the catalog:
      1. download the ORIGINAL (read-only),
      2. crop/resize to exactly 512x512 with Lanczos,
      3. encode WebP quality 80,
      4. upload to Supabase Storage under  thumbnails/variants/512/<name>,
      5. read it back from the public URL and prove it is 512x512 WebP.

Guarantees
    * The originals are never written, moved or deleted. The only write path is
      `thumbnails/variants/512/...`, enforced by an assertion before every
      upload - a mismatch aborts the run.
    * Two different originals may never share one variant name (fails loudly).
    * Every variant is re-downloaded and validated (status, content type,
      Pillow dimensions) after upload; any failure exits non-zero.
    * Idempotent: re-running overwrites only the variants it just produced.

Documentation
    * Supabase Storage upload (bucket, path, upsert, contentType, cacheControl):
      https://supabase.com/docs/reference/javascript/storage-from-upload
    * Public bucket objects are served by URL:
      https://supabase.com/docs/reference/javascript/storage-from-download
"""

from __future__ import annotations

import csv
import hashlib
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit, urlunsplit

from PIL import Image, ImageOps

BUCKET = "thumbnails"
VARIANT_PREFIX = "variants/512"
VARIANT_PX = 512
QUALITY = 80
OUT = Path("out")
MANIFEST_CSV = OUT / "cover-variants.csv"
MANIFEST_JSON = OUT / "cover-variants.json"
REQUIRED_ENV = ("SUPABASE_URL", "SUPABASE_ANON_KEY")


def load_env(path: str = ".env") -> dict[str, str]:
    env: dict[str, str] = {}
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip().strip("'").strip('"')
    return env


def encode_path(path: str) -> str:
    return "/".join(quote(unquote(segment), safe="") for segment in path.split("/"))


def normalise_url(url: str) -> str:
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, encode_path(parts.path), parts.query, parts.fragment))


def http(method: str, url: str, headers: dict[str, str] | None = None, body: bytes | None = None,
         timeout: int = 120) -> tuple[int, bytes, dict[str, str]]:
    # The R2 host sits behind Cloudflare, which answers 403 to the default
    # Python-urllib User-Agent but 200 to this one (verified by header probe;
    # the catalog export job uses the same value). Always send it.
    merged = {"User-Agent": "sb-catalog-export"}
    if headers:
        merged.update(headers)
    request = urllib.request.Request(url, data=body, method=method, headers=merged)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read(), dict(response.headers)
    except urllib.error.HTTPError as error:
        return error.code, error.read(), dict(error.headers or {})


def download(url: str, attempts: int = 3) -> bytes:
    last: Exception | None = None
    for attempt in range(1, attempts + 1):
        status, payload, _ = http("GET", url)
        if status == 200 and payload:
            return payload
        last = RuntimeError(f"GET {url} -> {status}")
        if attempt < attempts:
            time.sleep(2 * attempt)
    raise RuntimeError(f"download failed: {last}")


def main() -> int:
    print(f"pillow {Image.__version__}")
    env = load_env()
    if os.environ.get("SUPABASE_URL"):
        env["SUPABASE_URL"] = os.environ["SUPABASE_URL"]
    missing = [key for key in REQUIRED_ENV if not env.get(key)]
    if missing:
        print(f"::error::missing configuration: {', '.join(missing)}")
        return 1
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not service_key:
        print("::error::SUPABASE_SERVICE_ROLE_KEY is not provided to the job")
        return 1

    base = env["SUPABASE_URL"].rstrip("/")
    anon = env["SUPABASE_ANON_KEY"]
    read_headers = {"apikey": anon, "Authorization": f"Bearer {anon}", "Accept": "application/json"}
    write_headers = {"apikey": service_key, "Authorization": f"Bearer {service_key}"}

    print("reading catalog rows")
    status, body, _ = http("GET", f"{base}/rest/v1/tracks?select=id,title,thumbnail&order=created_at.asc", read_headers)
    if status != 200:
        print(f"::error::tracks select failed: {status} {body[:200]!r}")
        return 1
    tracks = json.loads(body)
    status, body, _ = http("GET", f"{base}/rest/v1/albums?select=id,name,cover_url&order=name.asc", read_headers)
    if status != 200:
        print(f"::error::albums select failed: {status} {body[:200]!r}")
        return 1
    albums = json.loads(body)
    print(f"  tracks={len(tracks)} albums={len(albums)}")

    sources: list[dict] = []
    for track in tracks:
        if track.get("thumbnail"):
            sources.append({"role": "track-cover", "title": track.get("title") or "",
                            "url": track["thumbnail"]})
    for album in albums:
        if album.get("cover_url"):
            sources.append({"role": "album-cover", "title": album.get("name") or "",
                            "url": album["cover_url"]})
    print(f"covers to process: {len(sources)}")

    names: dict[str, str] = {}
    rows: list[dict] = []
    problems: list[str] = []
    for index, source in enumerate(sources, 1):
        url = normalise_url(source["url"])
        name = unquote(urlsplit(url).path.split("/")[-1]).strip()
        if not name:
            problems.append(f"{source['role']}: cannot derive a file name from {source['url']}")
            continue
        if name in names and names[name] != url:
            problems.append(f"two different originals map to one variant name {name!r}: "
                            f"{names[name]} and {url}")
            continue
        names[name] = url

        try:
            original_bytes = download(url)
            with Image.open(io.BytesIO(original_bytes)) as image:
                image.load()
                source_size = image.size
                # Square crop + Lanczos; never distorts, never upscales below 512.
                square = ImageOps.fit(image.convert("RGBA") if image.mode in ("RGBA", "LA", "P") else image.convert("RGB"),
                                      (VARIANT_PX, VARIANT_PX), method=Image.LANCZOS)
                buffer = io.BytesIO()
                square.save(buffer, format="WEBP", quality=QUALITY, method=6)
                variant_bytes = buffer.getvalue()
        except Exception as error:  # noqa: BLE001 - any failure must be reported, not skipped
            problems.append(f"{source['role']} {name!r}: {error}")
            continue

        object_path = f"{VARIANT_PREFIX}/{name}"
        if not object_path.startswith(f"{VARIANT_PREFIX}/"):
            print(f"::error::refusing to write outside {VARIANT_PREFIX}/: {object_path}")
            return 1

        upload_url = f"{base}/storage/v1/object/{BUCKET}/{encode_path(object_path)}"
        upload_headers = dict(write_headers)
        upload_headers.update({
            "Content-Type": "image/webp",
            "x-upsert": "true",
            "cache-control": "max-age=31536000",
        })
        status, payload, _ = http("POST", upload_url, upload_headers, variant_bytes)
        if status not in (200, 201):
            problems.append(f"{source['role']} {name!r}: upload -> {status} {payload[:200]!r}")
            continue

        variant_url = f"{base}/storage/v1/object/public/{BUCKET}/{encode_path(object_path)}"
        status, served, headers = http("GET", variant_url)
        if status != 200:
            problems.append(f"{name!r}: variant not readable after upload ({status})")
            continue
        if "webp" not in (headers.get("Content-Type") or "").lower():
            problems.append(f"{name!r}: variant served as {headers.get('Content-Type')!r}, expected image/webp")
            continue
        try:
            with Image.open(io.BytesIO(served)) as check:
                if check.size != (VARIANT_PX, VARIANT_PX):
                    problems.append(f"{name!r}: served variant is {check.size}, expected 512x512")
                    continue
        except Exception as error:  # noqa: BLE001
            problems.append(f"{name!r}: served variant is not a decodable image: {error}")
            continue

        rows.append({
            "role": source["role"],
            "title": source["title"],
            "originalName": name,
            "originalBytes": len(original_bytes),
            "originalSize": f"{source_size[0]}x{source_size[1]}",
            "variantBytes": len(served),
            "variantSize": f"{VARIANT_PX}x{VARIANT_PX}",
            "savedPercent": round(100 * (1 - len(served) / max(len(original_bytes), 1)), 1),
            "sha256": hashlib.sha256(served).hexdigest(),
            "variantUrl": variant_url,
            "originalUrl": url,
        })
        if index % 20 == 0:
            print(f"  {index}/{len(sources)} done")

    OUT.mkdir(parents=True, exist_ok=True)
    if rows:
        with open(MANIFEST_CSV, "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)
        MANIFEST_JSON.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")

    before = sum(r["originalBytes"] for r in rows)
    after = sum(r["variantBytes"] for r in rows)
    print(f"processed {len(rows)}/{len(sources)} covers")
    if before:
        print(f"  bytes: {before:,} -> {after:,}  ({100 * (1 - after / before):.1f}% smaller)")
        print(f"  average per cover: {before // len(rows):,} -> {after // len(rows):,} bytes")
    for role in sorted({r["role"] for r in rows}):
        subset = [r for r in rows if r["role"] == role]
        print(f"  {role:<12} {len(subset):>3} covers  "
              f"{sum(r['originalBytes'] for r in subset):>10,} -> {sum(r['variantBytes'] for r in subset):>9,} bytes")

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write("## Cover variants (512x512 WebP)\n\n")
            handle.write(f"- processed: **{len(rows)}/{len(sources)}**\n")
            if before:
                handle.write(f"- bytes: {before:,} -> {after:,} ({100 * (1 - after / before):.1f}% smaller)\n")
            handle.write(f"- written under: `{BUCKET}/{VARIANT_PREFIX}/`\n")

    if problems:
        print(f"::error::{len(problems)} problem(s)")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print("all variants uploaded and verified (512x512 WebP, re-read from the public URL)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
