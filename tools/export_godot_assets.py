#!/usr/bin/env python3
"""Derive the Godot web implementation's assets from the Roku ones.

The Python generators (generate_sounds.py, generate_artwork.py) stay the single
source of truth and keep writing into assets/. This script converts their
output into godot/assets/.

Godot must never import from the repository-root assets/ directory: it writes
a .import sidecar next to every file it touches, and bsconfig.json globs
assets/**/* straight into the Roku .zip, so those sidecars would ship inside
the channel package.

Sounds are transcoded to Ogg Vorbis, which Godot's web export streams natively
and which is several times smaller than the source WAV.

Usage:
    python3 tools/export_godot_assets.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOUND_SRC = ROOT / "assets" / "sounds"
SOUND_DST = ROOT / "godot" / "assets" / "sounds"


def require_ffmpeg() -> None:
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg is required to transcode the sound effects; install it and retry.")


def convert_sounds() -> int:
    SOUND_DST.mkdir(parents=True, exist_ok=True)
    sources = sorted(SOUND_SRC.glob("*.wav"))
    if not sources:
        sys.exit(f"no .wav files found in {SOUND_SRC}; run tools/generate_sounds.py first.")

    for source in sources:
        target = SOUND_DST / f"{source.stem}.ogg"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel", "error",
                "-i", str(source),
                "-c:a", "libvorbis",
                "-qscale:a", "3",
                str(target),
            ],
            check=True,
        )
        src_kb = source.stat().st_size / 1024
        dst_kb = target.stat().st_size / 1024
        print(f"{source.name:>16} {src_kb:7.1f} KB  ->  {target.name:<16} {dst_kb:6.1f} KB")

    return len(sources)


def main() -> None:
    require_ffmpeg()
    count = convert_sounds()
    total = sum(f.stat().st_size for f in SOUND_DST.glob("*.ogg"))
    print(f"\n{count} sounds written to {SOUND_DST.relative_to(ROOT)} ({total / 1024:.1f} KB total)")


if __name__ == "__main__":
    main()
