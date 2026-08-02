#!/usr/bin/env python3
"""Offline audit for the four synthetic FCPCommandConsole fixture outputs."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


RUNTIME_ROOT = Path("/Users/marcboyer/Movies/FCPCommandConsole")
FIXTURE_ROOT = RUNTIME_ROOT / "fixtures"
EXPECTED_NAMES = ("clip-a.mov", "clip-b.mov", "living-still.png", "manifest.json")
FFPROBE = Path("/opt/homebrew/bin/ffprobe")


def fail(message: str) -> None:
    raise SystemExit(f"fixture audit: FAIL: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def probe(path: Path) -> dict[str, Any]:
    if not FFPROBE.is_file() or not os.access(FFPROBE, os.X_OK):
        fail(f"missing executable ffprobe: {FFPROBE}")
    arguments = [
        str(FFPROBE),
        "-hide_banner",
        "-v",
        "error",
        "-show_streams",
        "-show_format",
        "-of",
        "json",
        str(path),
    ]
    try:
        completed = subprocess.run(arguments, check=True, capture_output=True, text=True, timeout=30)
        return json.loads(completed.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        fail(f"ffprobe failed for {path.name}: {error}")


def number(value: Any, label: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        fail(f"{label} is not numeric: {value!r}")


def check_media(entry: dict[str, Any], path: Path, still: bool = False) -> None:
    if entry.get("path") != str(path):
        fail(f"manifest path mismatch for {path.name}")
    if path.is_symlink():
        fail(f"symlinked output is not allowed: {path}")
    if not path.is_file():
        fail(f"missing output: {path}")
    if entry.get("sha256") != sha256(path):
        fail(f"SHA-256 mismatch for {path.name}")
    if entry.get("bytes") != path.stat().st_size:
        fail(f"byte-size mismatch for {path.name}")
    metadata = entry.get("media")
    if not isinstance(metadata, dict):
        fail(f"missing media metadata for {path.name}")

    details = probe(path)
    streams = details.get("streams", [])
    if still:
        video = next((stream for stream in streams if stream.get("codec_type") == "video"), None)
        if video is None or int(video.get("width", 0)) != 1920 or int(video.get("height", 0)) != 1080:
            fail("living-still.png is not 1920x1080")
        if metadata.get("width") != 1920 or metadata.get("height") != 1080:
            fail("manifest still dimensions mismatch")
        return

    video = next((stream for stream in streams if stream.get("codec_type") == "video"), None)
    audio = next((stream for stream in streams if stream.get("codec_type") == "audio"), None)
    if video is None or audio is None:
        fail(f"{path.name} must contain video and audio")
    frame_rate = str(video.get("r_frame_rate", ""))
    duration = number(video.get("duration", details.get("format", {}).get("duration")), f"{path.name} duration")
    if abs(duration - 8.0) > (1.0 / 30.0):
        fail(f"{path.name} duration {duration} is not 8 seconds within one frame")
    if int(video.get("width", 0)) != 1920 or int(video.get("height", 0)) != 1080 or frame_rate != "30/1":
        fail(f"{path.name} video is not 1920x1080 at 30 fps")
    if video.get("codec_name") not in {"prores", "prores_ks"}:
        fail(f"{path.name} is not ProRes: {video.get('codec_name')}")
    if not str(video.get("pix_fmt", "")).startswith("yuv422"):
        fail(f"{path.name} pixel format is not 4:2:2: {video.get('pix_fmt')}")
    if not str(audio.get("codec_name", "")).startswith("pcm_"):
        fail(f"{path.name} audio is not PCM: {audio.get('codec_name')}")
    manifest_video = metadata.get("video", {})
    manifest_audio = metadata.get("audio", {})
    for key, value in (("width", 1920), ("height", 1080), ("frame_rate", "30/1"), ("codec", video.get("codec_name")), ("pixel_format", video.get("pix_fmt"))):
        if manifest_video.get(key) != value:
            fail(f"manifest {path.name} video {key} mismatch")
    if manifest_audio.get("codec") != audio.get("codec_name"):
        fail(f"manifest {path.name} audio codec mismatch")


def main() -> None:
    if len(sys.argv) > 2:
        fail("usage: scripts/audit-fixtures.py [runtime-fixtures-directory]")
    root = Path(sys.argv[1]).expanduser() if len(sys.argv) == 2 else FIXTURE_ROOT
    if root.is_symlink():
        fail(f"fixture root may not be a symlink: {root}")
    root = root.resolve()
    if root != FIXTURE_ROOT:
        fail(f"fixture root must be exactly {FIXTURE_ROOT}, got {root}")
    manifest_path = root / "manifest.json"
    if not manifest_path.is_file():
        fail(f"missing manifest: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        fail(f"manifest unreadable: {error}")
    if manifest.get("schema_version") != "1.0":
        fail("unsupported manifest schema")
    if manifest.get("canonical_root") != str(root):
        fail("manifest canonical_root mismatch")
    if manifest.get("synthetic_no_personal_media") is not True:
        fail("synthetic_no_personal_media must be true")
    outputs = manifest.get("outputs")
    if not isinstance(outputs, dict) or set(outputs) != set(EXPECTED_NAMES):
        fail(f"manifest outputs must be exactly {EXPECTED_NAMES}")
    check_media(outputs["clip-a.mov"], root / "clip-a.mov")
    check_media(outputs["clip-b.mov"], root / "clip-b.mov")
    check_media(outputs["living-still.png"], root / "living-still.png", still=True)
    if sha256(root / "clip-a.mov") == sha256(root / "clip-b.mov"):
        fail("clip hashes must be distinct")
    print("fixture audit: PASS")
    for name in EXPECTED_NAMES:
        path = root / name
        print(f"{name}: bytes={path.stat().st_size} sha256={sha256(path)}")


if __name__ == "__main__":
    main()
