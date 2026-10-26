#!/usr/bin/env python3
"""Export the Soulful Bhakti catalog (track audio + every cover image) as-is.

Run from a checkout root:  python3 tool/catalog_export.py

Index
    The Supabase database rows (`tracks`, `albums`) - the exact rows the app
    reads, so names, paths and ordering are the stored values.

Bytes
    Fetched from the location each row points at, and recorded per file:
      * track cover art  -> Supabase Storage, public bucket "thumbnails"
                            (public buckets are served by URL, per
                            https://supabase.com/docs/reference/javascript/storage-from-download)
      * track audio, karaoke audio and album cover art
                         -> the project's R2 CDN (R2_BASE_URL), which is the
                            URL the app itself streams.

Guarantees
    * GET only - no upload, no delete, no write against Supabase or R2.
    * Every file keeps its stored object name; an illegal name fails the run
      instead of being silently renamed.
    * Every file is checked against the server's Content-Length and hashed
      (SHA-256); afterwards every entry is re-read from the finished zip and
      re-hashed, so the archive is proven equal to what was downloaded.
    * Any discrepancy exits non-zero. There is no partial-success mode.

Output (under ./out)
    SoulfulBhakti-Tracks-and-Covers.zip            stored (no recompression)
    SoulfulBhakti-Tracks-and-Covers.sha256.txt     sha256 of the zip
    SoulfulBhakti-Catalog/...                      the same tree, unzipped
"""

from __future__ import annotations

import csv
import hashlib
import json
import os
import sys
import time
import urllib.request
import zipfile
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit, urlunsplit

ROOT = Path("out")
STAGE = ROOT / "SoulfulBhakti-Catalog"
ZIP = ROOT / "SoulfulBhakti-Tracks-and-Covers.zip"
SIDECAR = ROOT / "SoulfulBhakti-Tracks-and-Covers.sha256.txt"

FOLDERS = {
    "audio": "audio",
    "karaoke": "audio/karaoke",
    "track-cover": "covers/track",
    "album-cover": "covers/album",
}
META_ENTRIES = ["data/albums.json", "data/tracks.json", "manifest.csv", "manifest.json", "README.txt"]
REQUIRED_ENV = ("SUPABASE_URL", "SUPABASE_ANON_KEY", "R2_BASE_URL")
ILLEGAL_NAME_CHARS = set(':?*"<>|\\')
CHUNK = 1024 * 256


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
    """Normalise a storage path: decode existing %-escapes, then escape per segment."""
    return "/".join(quote(unquote(segment), safe="") for segment in path.split("/"))


def normalise_url(url: str) -> str:
    """Stored URLs may carry raw spaces or mixed escaping; send one canonical form."""
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, encode_path(parts.path), parts.query, parts.fragment))


def rest(base: str, key: str, table: str) -> list[dict]:
    url = f"{base}/rest/v1/{table}?select=*"
    if table == "tracks":
        url += "&order=created_at.asc"
    else:
        url += "&order=name.asc"
    request = urllib.request.Request(
        url,
        headers={"apikey": key, "Authorization": f"Bearer {key}", "Accept": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def download(url: str, dest: Path, attempts: int = 3) -> tuple[int, str, str]:
    """Stream one object to disk. Returns (bytes, sha256, content-type)."""
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "sb-catalog-export"})
            with urllib.request.urlopen(request, timeout=120) as response:
                declared = int(response.headers.get("Content-Length") or -1)
                content_type = (response.headers.get("Content-Type") or "").split(";")[0].strip()
                digest = hashlib.sha256()
                written = 0
                dest.parent.mkdir(parents=True, exist_ok=True)
                with open(dest, "wb") as handle:
                    while True:
                        block = response.read(CHUNK)
                        if not block:
                            break
                        handle.write(block)
                        digest.update(block)
                        written += len(block)
            if written != declared:
                raise IOError(f"size mismatch: server said {declared}, wrote {written}")
            return written, digest.hexdigest(), content_type
        except Exception as error:  # noqa: BLE001 - transport errors are retried
            last_error = error
            if dest.exists():
                dest.unlink()
            if attempt < attempts:
                time.sleep(2 * attempt)
    raise RuntimeError(f"download failed after {attempts} attempts: {url} ({last_error})")


def build_items(tracks: list[dict], albums: list[dict], r2: str, include_karaoke: bool) -> list[dict]:
    items: list[dict] = []

    def add(role: str, row_id: str, title: str, album: str, artists: str, path_or_url: str, storage: str, is_url: bool):
        url = normalise_url(path_or_url) if is_url else f"{r2}/{encode_path(path_or_url)}"
        items.append(
            {
                "role": role,
                "rowId": row_id,
                "title": title or "",
                "album": album or "",
                "artists": artists or "",
                "original": path_or_url.rstrip("/").split("/")[-1],
                "url": url,
                "storage": storage,
            }
        )

    for track in tracks:
        rid = str(track.get("id", ""))
        title = track.get("title") or ""
        album = track.get("album") or ""
        artists = track.get("artist_names_text") or ""
        if track.get("storage_path"):
            add("audio", rid, title, album, artists, track["storage_path"], "r2", False)
        if include_karaoke and track.get("karaoke_storage_path"):
            add("karaoke", rid, title, album, artists, track["karaoke_storage_path"], "r2", False)
        if track.get("thumbnail"):
            add("track-cover", rid, title, album, artists, track["thumbnail"], "supabase:thumbnails", True)
    for album_row in albums:
        if album_row.get("cover_url"):
            name = album_row.get("name") or ""
            add("album-cover", str(album_row.get("id", "")), name, name, "", album_row["cover_url"], "r2", True)
    return items


def main() -> int:
    include_karaoke = os.environ.get("INCLUDE_KARAOKE", "true").lower() in ("1", "true", "yes")

    env = load_env()
    missing = [key for key in REQUIRED_ENV if not env.get(key)]
    if missing:
        print(f"::error::missing from .env: {', '.join(missing)}")
        return 1
    base = env["SUPABASE_URL"].rstrip("/")
    key = env["SUPABASE_ANON_KEY"]
    r2 = env["R2_BASE_URL"].rstrip("/")
    print(f"index: {base}")
    print(f"cdn  : {r2}")

    print("reading catalog rows")
    tracks = rest(base, key, "tracks")
    albums = rest(base, key, "albums")
    print(f"  tracks={len(tracks)} albums={len(albums)}")

    items = build_items(tracks, albums, r2, include_karaoke)
    print(f"objects to fetch: {len(items)}")

    rows: list[dict] = []
    problems: list[str] = []
    seen: set[str] = set()
    total = 0
    for index, item in enumerate(items, 1):
        name = unquote(item["original"]).strip()
        if not name:
            problems.append(f"{item['role']}: empty object name in {item['url']}")
            continue
        illegal = sorted(set(name) & ILLEGAL_NAME_CHARS)
        if illegal:
            problems.append(f"{item['role']}: stored name has illegal characters {illegal!r}: {name!r}")
            continue
        rel = f"{FOLDERS[item['role']]}/{name}"
        if rel in seen:
            problems.append(f"duplicate target path: {rel}")
            continue
        seen.add(rel)
        try:
            size, sha, content_type = download(item["url"], STAGE / rel)
        except RuntimeError as error:
            problems.append(str(error))
            continue
        total += size
        rows.append(
            {
                "role": item["role"],
                "title": item["title"],
                "album": item["album"],
                "artists": item["artists"],
                "file": rel,
                "originalName": item["original"],
                "bytes": size,
                "sha256": sha,
                "contentType": content_type,
                "storage": item["storage"],
                "sourceUrl": item["url"],
            }
        )
        if index % 20 == 0:
            print(f"  {index}/{len(items)}  {total / 1e6:.1f} MB")
    print(f"downloaded {len(rows)}/{len(items)} files, {total / 1e6:.1f} MB")

    if not rows:
        print("::error::nothing was downloaded - refusing to write an empty archive")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    rows.sort(key=lambda row: (row["role"], row["album"], row["title"], row["file"]))
    STAGE.mkdir(parents=True, exist_ok=True)
    with open(STAGE / "manifest.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    (STAGE / "manifest.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")

    (STAGE / "data").mkdir(parents=True, exist_ok=True)
    (STAGE / "data" / "tracks.json").write_text(json.dumps(tracks, indent=2, ensure_ascii=False), encoding="utf-8")
    (STAGE / "data" / "albums.json").write_text(json.dumps(albums, indent=2, ensure_ascii=False), encoding="utf-8")

    totals: dict[str, list[int]] = {}
    for row in rows:
        bucket = totals.setdefault(row["role"], [0, 0])
        bucket[0] += 1
        bucket[1] += row["bytes"]

    lines = [
        "Soulful Bhakti - catalog export",
        f"generated: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}",
        "",
        "Index: the Supabase database rows (data/tracks.json, data/albums.json).",
        "Bytes: the location each row points at - 'supabase:thumbnails' is Supabase Storage",
        "(public bucket), 'r2' is the project's R2 CDN that the app streams from.",
        "Sizes are the server's Content-Length, verified against the bytes on disk; the",
        "SHA-256 of every file is in manifest.csv / manifest.json.",
        "",
    ]
    for role in sorted(totals):
        count, size = totals[role]
        lines.append(f"  {role:<12} {count:>3} files {size:>12,} bytes")
    lines += [
        "",
        "Folders:",
        "  audio/          main track audio, exactly the stored object name",
        "  audio/karaoke/  karaoke variants, exactly the stored object name",
        "  covers/track/   track cover art from the Supabase Storage bucket 'thumbnails'",
        "  covers/album/   album cover art",
        "  data/           the raw tracks and albums rows",
        "",
        "manifest.csv columns: role, title, album, artists, file, originalName, bytes,",
        "sha256, contentType, storage, sourceUrl.",
    ]
    (STAGE / "README.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    ROOT.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ZIP, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        for path in sorted(entry for entry in STAGE.rglob("*") if entry.is_file()):
            archive.write(path, arcname=f"SoulfulBhakti-Catalog/{path.relative_to(STAGE).as_posix()}")

    by_file = {row["file"]: row for row in rows}
    checked = 0
    with zipfile.ZipFile(ZIP) as archive:
        names = archive.namelist()
        for rel, row in by_file.items():
            arcname = f"SoulfulBhakti-Catalog/{rel}"
            if arcname not in names:
                problems.append(f"missing from archive: {arcname}")
                continue
            digest = hashlib.sha256()
            size = 0
            with archive.open(arcname) as handle:
                while True:
                    block = handle.read(CHUNK)
                    if not block:
                        break
                    digest.update(block)
                    size += len(block)
            if size != row["bytes"] or digest.hexdigest() != row["sha256"]:
                problems.append(f"archive content differs from the download: {arcname}")
            else:
                checked += 1
        expected_entries = len(rows) + len(META_ENTRIES)
        if len(names) != expected_entries:
            problems.append(f"expected {expected_entries} archive entries, found {len(names)}")
    print(f"re-verified {checked}/{len(rows)} entries (size + sha256) inside the archive")

    zip_sha = hashlib.sha256(ZIP.read_bytes()).hexdigest()
    SIDECAR.write_text(f"{zip_sha}  {ZIP.name}\n", encoding="utf-8")
    print(f"zip: {ZIP}  {ZIP.stat().st_size / 1e6:.1f} MB  sha256={zip_sha}")

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write("## Catalog export\n\n")
            handle.write(f"- files: **{len(rows)}** of {len(items)}\n")
            handle.write(f"- payload: **{total / 1e6:.1f} MB**\n")
            handle.write(f"- re-verified inside the archive: **{checked}/{len(rows)}**\n")
            handle.write(f"- zip sha256: `{zip_sha}`\n")
            for role in sorted(totals):
                count, size = totals[role]
                handle.write(f"- {role}: {count} files, {size:,} bytes\n")

    if problems:
        print(f"::error::{len(problems)} problem(s) - nothing is usable from this run")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print("all files downloaded, size-verified, hashed and re-verified from the archive")
    return 0


if __name__ == "__main__":
    sys.exit(main())
