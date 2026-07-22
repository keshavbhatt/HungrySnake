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


def _noise_rng(seed):
    # Deterministic white-noise generator in [-1, 1] (stdlib-only LCG).
    s = seed & 0x7fffffff

    def nxt():
        nonlocal s
        s = (1103515245 * s + 12345) & 0x7fffffff
        return (s / 0x7fffffff) * 2.0 - 1.0

    return nxt


def crunch(seed):
    # A real apple bite, modelled on a recorded reference: VERY bright (energy mostly
    # 3-16 kHz, centroid ~7 kHz), ~330 ms long, with a LUMPY multi-burst envelope —
    # several crunch swells that build to a peak partway through and taper off, plus a
    # characteristic late "second crunch" — not a single sharp decay. A tiny juicy
    # low-mid layer sits under it. Vary `seed` for a set of non-repeating bites.
    rnd = _noise_rng(seed)
    n = int(RATE * 0.39)
    dur = n / RATE
    out = [0.0] * n

    # A handful of random crunch swells (biting through skin, then flesh). They cluster
    # across the first ~78% so one often lands late for the second-crunch feel.
    nb = 5 + int(abs(rnd()) * 3)
    bursts = []
    for _ in range(nb):
        centre = (0.05 + 0.73 * abs(rnd())) * dur
        width = 0.016 + 0.045 * abs(rnd())
        amp = 0.45 + 0.55 * abs(rnd())
        bursts.append((centre, width, amp))

    lp1 = 0.0
    lp2 = 0.0
    hp_in = 0.0
    hp_out = 0.0
    jlp = 0.0            # "juice" low-mid layer state
    grain = 0.0
    grain_ctr = 0
    for i in range(n):
        t = i / RATE
        w = rnd()
        lp1 += 0.35 * (w - lp1)                     # two-pole low-pass (~12 dB/oct) rolls
        lp2 += 0.35 * (lp1 - lp2)                   # off the harsh top -> centroid ~7 kHz
        hp_out = 0.50 * (hp_out + lp2 - hp_in)      # gentle high-pass keeps mids, kills boom
        hp_in = lp2
        jlp += 0.06 * (w - jlp)                     # heavy low-pass -> soft "juicy" body
        if grain_ctr <= 0:                          # dense crunch grains
            a = abs(rnd())
            grain = a * a
            grain_ctr = int(RATE * (0.002 + 0.006 * abs(rnd())))   # 2-8 ms
        grain_ctr -= 1
        macro = 0.0
        for (c, wid, amp) in bursts:
            macro += amp * math.exp(-((t - c) / wid) ** 2)
        macro *= math.exp(-max(0.0, t - 0.04) * 1.0)   # gentle overall taper
        out[i] = (hp_out + 0.35 * jlp) * grain * macro

    # A bright "skin snap" right at the onset.
    for i in range(min(int(RATE * 0.012), n)):
        t = i / RATE
        out[i] += (0.7 * rnd() + 0.3 * math.sin(2 * math.pi * 3000 * t)) * math.exp(-t * 280.0) * 0.6

    peak = max(1e-6, max(abs(s) for s in out))
    g = 0.9 / peak
    out = [s * g for s in out]
    for i in range(min(300, n)):
        out[n - 1 - i] *= i / 300                   # tail fade
    return out


# Seeds for the random apple-bite set — the game plays a random one each apple.
EAT_SEEDS = [13, 4567, 90210, 314159]


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
    for idx, seed in enumerate(EAT_SEEDS):
        _write("eat%d.wav" % idx, crunch(seed))
    _write("crash.wav", crash())
    for idx, freq in enumerate(TURN_SCALE):
        _write("turn%d.wav" % idx, turn(freq))
