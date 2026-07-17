#!/usr/bin/env python3
"""Generate HungrySnake's sound effects as small mono 16-bit PCM WAV files.

No external deps — pure stdlib. Re-run after tweaking to regenerate:

    python3 tools/make_sounds.py

Outputs:
    assets/sounds/eat.wav    — a juicy "crunch" when an apple is eaten
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
    # A "bite/crunch": bandpassed noise (a lowpass to kill hiss + a highpass to
    # kill boom) textured by an irregular sample-and-hold grain envelope, with a
    # sharp attack and fast decay. Two overlapping snaps read as a proper bite.
    n = int(RATE * 0.20)
    out = [0.0] * n

    def snap(start, amp, decay, seed0):
        seed = seed0
        lp = 0.0
        hp_in = 0.0
        hp_out = 0.0
        sh = 0.0
        sh_ctr = 0
        sh_period = max(1, int(RATE / 300))   # grain rate ~300 Hz (irregular via S&H)
        for i in range(start, n):
            t = (i - start) / RATE
            seed = (1103515245 * seed + 12345) & 0x7fffffff
            noise = (seed / 0x7fffffff) * 2 - 1
            lp += 0.4 * (noise - lp)                   # one-pole low-pass
            hp = 0.9 * (hp_out + lp - hp_in)           # one-pole high-pass -> band
            hp_in, hp_out = lp, hp
            sh_ctr += 1
            if sh_ctr >= sh_period:
                sh_ctr = 0
                seed = (1103515245 * seed + 12345) & 0x7fffffff
                sh = seed / 0x7fffffff                 # 0..1 held amplitude
            grain = 0.3 + 0.7 * sh
            atk = min(1.0, t / 0.0015)                 # ~1.5 ms sharp attack
            env = atk * math.exp(-t * decay)
            out[i] += amp * hp * grain * env

    snap(0, 1.5, 40, 22222)
    snap(int(RATE * 0.05), 1.0, 55, 98765)             # second, smaller bite
    peak = max(1e-6, max(abs(s) for s in out))
    return [s / peak * 0.92 for s in out]              # normalize to a safe level


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
