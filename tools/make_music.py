#!/usr/bin/env python3
"""Generate Snecko's looping background music as small mono 16-bit PCM WAV files.

No external deps — pure stdlib (mirrors tools/make_sounds.py). Re-run to regen:

    python3 tools/make_music.py

Each track is a short, seamlessly-looping piece with a calm jungle / retro-game
vibe (soft pad chords + gentle arpeggios / bells + a mellow bass). Everything is
synthesised additively; every note's envelope opens from and returns to silence
inside the loop, so the end meets the start with no click.

To keep the bundle tiny the files are mono, 22050 Hz, 16-bit PCM.

Outputs (assets/sounds/music/):
    canopy_calm.wav   — bright C-major sway, pad + eighth-note arpeggio
    moonlit_vines.wav — slow, wistful A-minor with a soft bell melody
    sunny_grove.wav   — brisk, cheerful G-major with plucky arpeggios
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds", "music")

_PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
       "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10,
       "B": 11}


def freq(name):
    """'A4' / 'C#3' → frequency in Hz (A4 = 440)."""
    pc, octave = name[:-1], int(name[-1])
    midi = (octave + 1) * 12 + _PC[pc]
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def _env(t, dur, a, d, s, r):
    """Simple ADSR (all times in seconds), fully contained in [0, dur]."""
    if t < a:
        return t / a if a > 0 else 1.0
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / d) if d > 0 else s
    if t < dur - r:
        return s
    if t < dur:
        return s * (1.0 - (t - (dur - r)) / r) if r > 0 else 0.0
    return 0.0


def add_note(buf, start, dur, f, amp, harmonics, a=0.01, d=0.1, s=0.7, r=0.2):
    """Render one note (sum of harmonics × ADSR) additively into buf."""
    i0 = int(start * RATE)
    n = int(dur * RATE)
    for i in range(n):
        idx = i0 + i
        if idx < 0 or idx >= len(buf):
            continue
        t = i / RATE
        e = _env(t, dur, a, d, s, r)
        if e <= 0.0:
            continue
        v = 0.0
        for mult, hamp in harmonics:
            v += hamp * math.sin(2.0 * math.pi * f * mult * t)
        buf[idx] += v * amp * e


# Timbres: list of (harmonic multiple, amplitude).
PAD = [(1, 0.50), (2, 0.14), (3, 0.05)]
BASS = [(1, 0.60), (2, 0.16)]
PLUCK = [(1, 0.52), (2, 0.22), (3, 0.09)]
BELL = [(1, 0.50), (2, 0.26), (4, 0.10)]


def _finish(buf):
    """Normalise to comfortable headroom and hard-guarantee zero endpoints."""
    peak = max((abs(x) for x in buf), default=1.0) or 1.0
    g = 0.82 / peak
    out = [x * g for x in buf]
    # Tiny 4 ms fade at the very edges — belt-and-braces against loop clicks.
    fade = int(RATE * 0.004)
    for i in range(fade):
        k = i / fade
        out[i] *= k
        out[-1 - i] *= k
    return out


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


def _bars(bpm, bars, beats_per_bar=4):
    beat = 60.0 / bpm
    return beat, [0.0] * int(RATE * beat * beats_per_bar * bars)


# ── Track 1: Canopy Calm — C major, gentle I–V–vi–IV sway ─────────────────────
def canopy_calm():
    bpm = 88
    beat, buf = _bars(bpm, 8)
    bar = beat * 4
    prog = [  # (pad triad, bass root, arp octave notes)
        (["C4", "E4", "G4"], "C2", ["C4", "E4", "G4", "E4"]),
        (["G3", "B3", "D4"], "G2", ["G3", "B3", "D4", "B3"]),
        (["A3", "C4", "E4"], "A2", ["A3", "C4", "E4", "C4"]),
        (["F3", "A3", "C4"], "F2", ["F3", "A3", "C4", "A3"]),
        (["C4", "E4", "G4"], "C2", ["C4", "E4", "G4", "E4"]),
        (["G3", "B3", "D4"], "G2", ["G3", "B3", "D4", "B3"]),
        (["F3", "A3", "C4"], "F2", ["F3", "A3", "C4", "A3"]),
        (["G3", "B3", "D4"], "G2", ["G3", "B3", "D4", "F4"]),
    ]
    for b, (chord, bass, arp) in enumerate(prog):
        t0 = b * bar
        for n in chord:  # soft swelling pad, one per bar
            add_note(buf, t0, bar, freq(n), 0.16, PAD, a=0.35, d=0.4, s=0.75, r=0.55)
        add_note(buf, t0, bar * 0.5, freq(bass), 0.30, BASS, a=0.02, d=0.25, s=0.5, r=0.35)
        add_note(buf, t0 + bar * 0.5, bar * 0.5, freq(bass), 0.24, BASS, a=0.02, d=0.25, s=0.4, r=0.35)
        for j, n in enumerate(arp * 2):  # eighth-note arpeggio
            add_note(buf, t0 + j * (beat * 0.5), beat * 0.5, freq(n), 0.15,
                     PLUCK, a=0.005, d=0.18, s=0.25, r=0.12)
    return _finish(buf)


# ── Track 2: Moonlit Vines — A minor, slow, soft bell melody ──────────────────
def moonlit_vines():
    bpm = 72
    beat, buf = _bars(bpm, 6)
    bar = beat * 4
    prog = [
        (["A3", "C4", "E4"], "A2"),
        (["F3", "A3", "C4"], "F2"),
        (["C4", "E4", "G4"], "C2"),
        (["G3", "B3", "D4"], "G2"),
        (["A3", "C4", "E4"], "A2"),
        (["E3", "G#3", "B3"], "E2"),
    ]
    for b, (chord, bass) in enumerate(prog):
        t0 = b * bar
        for n in chord:
            add_note(buf, t0, bar, freq(n), 0.15, PAD, a=0.5, d=0.5, s=0.78, r=0.7)
        add_note(buf, t0, bar, freq(bass), 0.28, BASS, a=0.04, d=0.4, s=0.55, r=0.5)
    # Wistful bell melody over the progression (beat offset, dur beats, note).
    mel = [
        (0, 2, "E5"), (2, 1.5, "C5"), (3.5, 0.5, "D5"),
        (4, 2, "C5"), (6, 2, "A4"),
        (8, 2, "G4"), (10, 1.5, "C5"), (11.5, 0.5, "B4"),
        (12, 2, "D5"), (14, 2, "B4"),
        (16, 2, "C5"), (18, 1, "E5"), (19, 1, "D5"),
        (20, 1.5, "B4"), (21.5, 0.5, "G#4"), (22, 2, "E4"),
    ]
    for start, dur, n in mel:
        add_note(buf, start * beat, dur * beat, freq(n), 0.17, BELL,
                 a=0.01, d=0.6, s=0.3, r=min(dur * beat * 0.5, 0.6))
    return _finish(buf)


# ── Track 3: Sunny Grove — G major, brisk & plucky ────────────────────────────
def sunny_grove():
    bpm = 100
    beat, buf = _bars(bpm, 8)
    bar = beat * 4
    prog = [
        (["G3", "B3", "D4"], "G2", ["G4", "D4", "B4", "D4"]),
        (["D4", "F#4", "A4"], "D2", ["D4", "A4", "F#4", "A4"]),
        (["E3", "G3", "B3"], "E2", ["E4", "B3", "G4", "B3"]),
        (["C4", "E4", "G4"], "C2", ["C4", "G4", "E4", "G4"]),
        (["G3", "B3", "D4"], "G2", ["G4", "D4", "B4", "D4"]),
        (["D4", "F#4", "A4"], "D2", ["D4", "A4", "F#4", "A4"]),
        (["C4", "E4", "G4"], "C2", ["C4", "G4", "E4", "G4"]),
        (["D4", "F#4", "A4"], "D2", ["A4", "F#4", "D4", "F#4"]),
    ]
    for b, (chord, bass, arp) in enumerate(prog):
        t0 = b * bar
        for n in chord:
            add_note(buf, t0, bar, freq(n), 0.13, PAD, a=0.28, d=0.35, s=0.7, r=0.5)
        add_note(buf, t0, bar * 0.5, freq(bass), 0.30, BASS, a=0.02, d=0.2, s=0.5, r=0.3)
        add_note(buf, t0 + bar * 0.5, bar * 0.5, freq(bass), 0.24, BASS, a=0.02, d=0.2, s=0.4, r=0.3)
        for j, n in enumerate(arp * 2):  # sixteenth-ish bright plucks
            add_note(buf, t0 + j * (beat * 0.5), beat * 0.5, freq(n), 0.16,
                     PLUCK, a=0.004, d=0.14, s=0.2, r=0.1)
    return _finish(buf)


if __name__ == "__main__":
    _write("canopy_calm.wav", canopy_calm())
    _write("moonlit_vines.wav", moonlit_vines())
    _write("sunny_grove.wav", sunny_grove())
