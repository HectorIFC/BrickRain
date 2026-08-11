#!/usr/bin/env python3
"""Generates BrickRain's background music: an original chiptune loop.

Synthesised from square/triangle/noise oscillators, the same approach
generate_sounds.py uses for the nine sound effects — so the music is original,
reproducible from this repository, and sits in the same sonic palette as the
effects rather than fighting them.

128 BPM, 16 bars, exactly 30 s. The arrangement thins out at the top of the
cycle and builds through it, so a single looping file reads as an intro that
grows rather than a flat wall of sound.

The loop is seamless by construction: any note whose tail runs past the end
wraps around and is summed into the beginning, so the last sample flows into
the first with no discontinuity.

Output goes to godot/music/, NOT assets/ — the Roku channel has no music, and
bsconfig.json globs assets/**/* straight into the channel zip.

Usage:
    python3 tools/generate_music.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "godot" / "music"

SR = 44100
BPM = 128
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
TOTAL = BARS * BAR

# A minor, i - VI - III - VII. Energetic, and the classic arcade progression.
CHORDS = [
    {"root": 110.00, "tones": [220.00, 261.63, 329.63]},  # Am
    {"root": 87.31, "tones": [174.61, 220.00, 261.63]},   # F
    {"root": 130.81, "tones": [261.63, 329.63, 392.00]},  # C
    {"root": 98.00, "tones": [196.00, 246.94, 293.66]},   # G
]

# Melody over the 4-bar cycle, as chord-tone indices; None is a rest.
LEAD = [
    [2, None, 1, 2, None, 0, None, None],
    [1, None, 2, 1, None, 0, None, None],
    [2, None, 1, 0, None, 1, None, None],
    [1, None, 0, 1, None, 2, None, None],
]

rng = np.random.default_rng(20260811)


def _phase(freq: float, duration: float) -> np.ndarray:
    n = max(1, int(duration * SR))
    return (np.arange(n) / SR * freq) % 1.0


def square(freq: float, duration: float, duty: float = 0.5) -> np.ndarray:
    return np.where(_phase(freq, duration) < duty, 1.0, -1.0)


def triangle(freq: float, duration: float) -> np.ndarray:
    p = _phase(freq, duration)
    return 4.0 * np.abs(p - 0.5) - 1.0


def noise(duration: float) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, max(1, int(duration * SR)))


def env(samples: np.ndarray, attack: float = 0.005, decay: float = 6.0) -> np.ndarray:
    """Short attack so notes click like a chip channel, then exponential decay."""
    n = len(samples)
    out = samples * np.exp(-decay * np.linspace(0.0, 1.0, n))
    a = max(1, int(attack * SR))
    if a < n:
        out[:a] *= np.linspace(0.0, 1.0, a)
    return out


class Loop:
    """A fixed-length buffer that sums notes, wrapping tails to the start."""

    def __init__(self, seconds: float) -> None:
        self.buffer = np.zeros(int(seconds * SR))

    def add(self, samples: np.ndarray, at: float, gain: float = 1.0) -> None:
        start = int(at * SR) % len(self.buffer)
        piece = samples * gain
        end = start + len(piece)
        if end <= len(self.buffer):
            self.buffer[start:end] += piece
        else:
            split = len(self.buffer) - start
            self.buffer[start:] += piece[:split]
            # The wrap is what makes the loop seamless.
            wrapped = piece[split:][: len(self.buffer)]
            self.buffer[: len(wrapped)] += wrapped


def kick(duration: float = 0.14) -> np.ndarray:
    n = int(duration * SR)
    sweep = np.linspace(120.0, 45.0, n)
    wave_ = np.sin(2 * np.pi * np.cumsum(sweep) / SR)
    return env(wave_, attack=0.001, decay=9.0)


def snare(duration: float = 0.12) -> np.ndarray:
    body = 0.7 * noise(duration) + 0.3 * square(190.0, duration)
    return env(body, attack=0.001, decay=11.0)


def hat(duration: float = 0.035) -> np.ndarray:
    return env(noise(duration), attack=0.0005, decay=30.0)


def build() -> np.ndarray:
    loop = Loop(TOTAL)

    for bar in range(BARS):
        chord = CHORDS[bar % 4]
        bar_at = bar * BAR
        # Intensity ramps across the cycle: sparse at the top, full by the end.
        stage = bar // 4

        # Arpeggio, 16th notes, running the whole loop.
        for step in range(16):
            tone = chord["tones"][step % 3] * (2.0 if step % 8 >= 4 else 1.0)
            note = env(square(tone, BEAT / 4, duty=0.25), decay=9.0)
            loop.add(note, bar_at + step * BEAT / 4, gain=0.16)

        # Bass from the second phrase.
        if stage >= 1:
            for step in range(8):
                note = env(square(chord["root"], BEAT / 2, duty=0.5), decay=4.5)
                loop.add(note, bar_at + step * BEAT / 2, gain=0.30)

        # Lead melody from the third phrase.
        if stage >= 2:
            for step, degree in enumerate(LEAD[bar % 4]):
                if degree is None:
                    continue
                tone = chord["tones"][degree] * 2.0
                note = env(triangle(tone, BEAT * 0.45), attack=0.008, decay=5.0)
                loop.add(note, bar_at + step * BEAT / 2, gain=0.26)

        # Percussion from the second phrase; hats fill in with the lead.
        if stage >= 1:
            for beat in range(4):
                at = bar_at + beat * BEAT
                if beat in (0, 2):
                    loop.add(kick(), at, gain=0.55)
                else:
                    loop.add(snare(), at, gain=0.28)
            if stage >= 2:
                for step in range(8):
                    loop.add(hat(), bar_at + step * BEAT / 2, gain=0.12)

    audio = loop.buffer
    peak = float(np.max(np.abs(audio)))
    if peak > 0:
        # Leave headroom so the sound effects stay audible over the music.
        audio = audio / peak * 0.72
    return audio


def write_wav(path: Path, audio: np.ndarray) -> None:
    pcm = np.clip(audio, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2")
    with wave.open(str(path), "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def main() -> None:
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg is required to encode the music; install it and retry.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    wav_path = OUTPUT_DIR / "theme.wav"
    ogg_path = OUTPUT_DIR / "theme.ogg"

    audio = build()
    write_wav(wav_path, audio)

    # Mono Ogg Vorbis: the payload budget matters far more here than stereo
    # imaging on a phone speaker.
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
         "-ac", "1", "-c:a", "libvorbis", "-qscale:a", "2", str(ogg_path)],
        check=True,
    )
    wav_path.unlink()

    size = ogg_path.stat().st_size
    print(f"  theme.ogg  {TOTAL:.1f}s  {size / 1024:.0f} KB  ({BPM} BPM, {BARS} bars)")


if __name__ == "__main__":
    main()
