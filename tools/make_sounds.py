#!/usr/bin/env python3
"""Generate Snecko's sound effects as small mono 16-bit PCM WAV files.

No external deps — pure stdlib. Re-run after tweaking to regenerate:

    python3 tools/make_sounds.py

Outputs:
    assets/sounds/eat.wav    — a short bright "blip" when an apple is eaten
    assets/sounds/crash.wav  — a soft descending "thud/buzz" on game over
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


def eat():
    # Two quick rising tones — a cheerful "nom".
    n = int(RATE * 0.16)
    out = []
    for i in range(n):
        t = i / RATE
        f = 660 + 520 * (i / n)            # sweep up
        env = _adsr(i, n, 0.005, 0.10)
        s = 0.5 * math.sin(2 * math.pi * f * t)
        s += 0.25 * math.sin(2 * math.pi * 2 * f * t)   # a little sparkle
        out.append(s * env)
    return out


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


if __name__ == "__main__":
    _write("eat.wav", eat())
    _write("crash.wav", crash())
