#!/usr/bin/env python3
"""Generate HungrySnake's sound effects as small mono 16-bit PCM WAV files.

No external deps — pure stdlib. Re-run after tweaking to regenerate:

    python3 tools/make_sounds.py

Outputs:
    assets/sounds/crash.wav      — a soft descending "thud/buzz" on game over
    assets/sounds/turn0..4.wav   — a soft pentatonic blip, cycled on each turn

eat.wav is a real recording shipped in assets/sounds/ — it is NOT generated here.
"""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def _write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print("wrote", path, "(%.2fs)" % (len(samples) / RATE))


def _adsr(i, n, attack=0.01, release=0.25):
    t = i / RATE
    dur = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return max(0.0, min(a, r))


def crash():
    # Descending tone + noise burst — a soft "bonk".
    n = int(RATE * 0.42)
    out = []
    seed = 1234567
    for i in range(n):
        t = i / RATE
        f = 300 * (1.0 - 0.55 * (i / n))   # sag downward
        env = _adsr(i, n, 0.004, 0.34)
        tone = 0.55 * math.sin(2 * math.pi * f * t)
        # cheap deterministic noise
        seed = (1103515245 * seed + 12345) & 0x7fffffff
        noise = ((seed / 0x7fffffff) * 2 - 1) * 0.28 * (1.0 - i / n)
        out.append((tone + noise) * env)
    return out


def turn(freq):
    # A soft, short "blip" for a snake turn at a given pitch — deliberately quiet
    # since it fires on every accepted turn. A mid sine with a touch of octave
    # sparkle, a fast exponential decay, and de-clicked edges (no onset pop).
    n = int(RATE * 0.05)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 60.0)
        s = math.sin(2 * math.pi * freq * t) + 0.12 * math.sin(2 * math.pi * 2 * freq * t)
        out[i] = s * env * 0.4
    for i in range(min(24, n)):
        out[i] *= i / 24          # short fade-in kills the onset click
    return out


# A short C-major pentatonic run (C5 D5 E5 G5 A5). The game cycles through these on
# consecutive turns so it plays a little rising melody instead of one repeated blip.
TURN_SCALE = [523.25, 587.33, 659.25, 783.99, 880.00]


if __name__ == "__main__":
    # NOTE: eat.wav is a real recording shipped alongside — it is NOT generated here.
    _write("crash.wav", crash())
    for idx, freq in enumerate(TURN_SCALE):
        _write("turn%d.wav" % idx, turn(freq))
