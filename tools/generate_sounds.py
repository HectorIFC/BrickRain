"""Generates all BrickRain sound effects as 16-bit PCM WAV files.

Chiptune-style synthesis (square/sine waves + envelopes), fully original,
no copyright concerns. Output is Roku-compatible (roAudioResource).
"""

import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44100
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def square_wave(frequency: float, duration: float, duty: float = 0.5) -> np.ndarray:
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), endpoint=False)
    return np.where((t * frequency) % 1 < duty, 1.0, -1.0)


def sine_wave(frequency: float, duration: float) -> np.ndarray:
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), endpoint=False)
    return np.sin(2 * np.pi * frequency * t)


def noise(duration: float) -> np.ndarray:
    rng = np.random.default_rng(42)
    return rng.uniform(-1, 1, int(SAMPLE_RATE * duration))


def decay_envelope(samples: np.ndarray, strength: float = 5.0) -> np.ndarray:
    t = np.linspace(0, 1, len(samples))
    return samples * np.exp(-strength * t)


def sweep(start_hz: float, end_hz: float, duration: float) -> np.ndarray:
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), endpoint=False)
    frequency = np.linspace(start_hz, end_hz, len(t))
    phase = 2 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
    return np.sin(phase)


def sequence(*parts: np.ndarray) -> np.ndarray:
    return np.concatenate(parts)


def crackle(duration: float) -> np.ndarray:
    """Firework crackle tail: short random noise snaps whose density and
    loudness decay over the duration - the third layer of a real burst."""
    rng = np.random.default_rng(20260818)
    out = np.zeros(int(SAMPLE_RATE * duration))
    t = 0.0
    while t < duration:
        progress = t / duration
        t += rng.uniform(0.004, 0.008 + 0.06 * progress)
        start = int(t * SAMPLE_RATE)
        length = int(SAMPLE_RATE * rng.uniform(0.003, 0.010))
        if start + length >= out.size:
            break
        snap = rng.uniform(-1, 1, length) * np.linspace(1, 0, length)
        out[start:start + length] += snap * (1.0 - 0.75 * progress)
    return out


def write_wav(name: str, samples: np.ndarray, volume: float = 0.6) -> None:
    normalized = samples / (np.max(np.abs(samples)) or 1)
    pcm = (normalized * volume * 32767).astype(np.int16)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT_DIR / f"{name}.wav"), "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(pcm.tobytes())
    print(f"  {name}.wav")


def note(frequency: float, duration: float, strength: float = 8.0) -> np.ndarray:
    return decay_envelope(square_wave(frequency, duration, duty=0.25), strength)


print("Generating BrickRain sounds:")

# 1. move: short low blip (left/right/soft drop)
write_wav("move", note(220, 0.05, strength=12))

# 2. rotate: quick two-tone chirp
write_wav("rotate", sequence(note(440, 0.04), note(587, 0.05)))

# 3. hard_drop: whoosh down + impact
write_wav("hard_drop", sequence(
    decay_envelope(sweep(700, 120, 0.10), 3),
    decay_envelope(sine_wave(80, 0.10) + 0.3 * noise(0.10), 8),
))

# 4. lock: dry low thud (piece settles, no line)
write_wav("lock", decay_envelope(sine_wave(98, 0.12) + 0.15 * noise(0.12), 9))

# 5. line_clear: ascending arpeggio C5-E5-G5-C6
write_wav("line_clear", sequence(
    note(523, 0.07), note(659, 0.07), note(784, 0.07), note(1047, 0.12, 5),
))

# 6. level_up: rising sweep with sparkle
write_wav("level_up", sequence(
    decay_envelope(sweep(330, 990, 0.22), 2),
    note(1319, 0.10, 5),
))

# 7. game_over: slow descending minor walk
write_wav("game_over", sequence(
    note(392, 0.16, 4), note(330, 0.16, 4), note(262, 0.16, 4), note(196, 0.30, 3),
))

# 8. new_record: victory fanfare (the "win" sound)
write_wav("new_record", sequence(
    note(523, 0.09), note(659, 0.09), note(784, 0.09),
    note(1047, 0.09), note(784, 0.07), note(1047, 0.35, 3),
))

# 9. menu_select: crisp UI click
write_wav("menu_select", note(880, 0.04, strength=15))

# 10. quad_clear: the four-line clear deserves its own fanfare - a fifth-stacked
# burst brighter and longer than line_clear, so the game's peak moment sounds
# like one.
write_wav("quad_clear", sequence(
    note(523, 0.06), note(784, 0.06), note(1047, 0.06),
    note(1568, 0.08), note(1047, 0.06), note(1568, 0.28, 4),
))

# 11. level_whoosh: rising airy sweep matching the level-up wave crossing the
# well (the web build plays it alongside level_up's sparkle).
write_wav("level_whoosh", decay_envelope(
    sweep(180, 1400, 0.30) + 0.25 * noise(0.30), 3,
))

# 12. confetti_pop: bright little burst for the new-record confetti.
write_wav("confetti_pop", sequence(
    decay_envelope(0.7 * noise(0.05), 14),
    note(1319, 0.06, 6), note(1760, 0.09, 5),
))

# 13. combo: short bright blip for the combo ladder. Recorded once at a base
# pitch; the web build raises pitch_scale roughly a semitone per combo step,
# which is why this stays a single neutral note.
write_wav("combo", sequence(note(988, 0.05, 10), note(1319, 0.07, 8)))

# 14. firework_launch: the rising whistle of the rocket going up. Only the web
# build's record celebration uses it; the wav sits unreferenced on Roku.
write_wav("firework_launch", decay_envelope(
    sweep(300, 1000, 0.40) + 0.15 * noise(0.40), 2,
))

# 15. firework_burst: the three layers of a real firework - low boom for
# weight, a mid noise burst for mass, then the crackle tail of random snaps.
write_wav("firework_burst", sequence(
    decay_envelope(sine_wave(70, 0.25) + 0.7 * noise(0.25), 9),
    0.8 * crackle(0.65),
))

print("Done.")
