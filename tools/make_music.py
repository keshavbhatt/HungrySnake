#!/usr/bin/env python3
"""Generate HungrySnake's looping background music as small mono 16-bit PCM WAV files.

No external deps — pure stdlib (mirrors tools/make_sounds.py). Re-run to regen:

    python3 tools/make_music.py

Each track is a short, seamlessly-looping piece with a calm jungle / retro-game
vibe (soft pad chords + gentle arpeggios / bells + a mellow bass). Everything is
synthesised additively; every note's envelope opens from and returns to silence
inside the loop, so the end meets the start with no click.

To keep the bundle tiny the files are mono, 22050 Hz, 16-bit PCM.

Outputs (assets/sounds/music/):
    canopy_calm.wav    — bright C-major sway, pad + eighth-note arpeggio
    moonlit_vines.wav  — slow, wistful A-minor with a soft bell melody
    sunny_grove.wav    — brisk, cheerful G-major with plucky arpeggios
    dewdrop_swing.wav  — mellow lo-fi swing in F major, swung eighth plucks
    dusky_hollow.wav   — slow, mysterious E-minor with a low, brooding bell
    berry_bounce.wav   — playful, bouncy D-major with a hopping staccato bass
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


# ── Track 4: Dewdrop Swing — F major, mellow lo-fi with a swung eighth feel ────
def dewdrop_swing():
    bpm = 76
    beat, buf = _bars(bpm, 8)
    bar = beat * 4
    swing = 0.62  # long-short ratio inside each beat → lazy shuffle groove
    prog = [  # (pad triad, bass root, arpeggio chord tones)
        (["F3", "A3", "C4"],  "F2",  ["F3", "A3", "C4", "A3"]),
        (["D3", "F3", "A3"],  "D2",  ["D3", "F3", "A3", "F3"]),
        (["Bb2", "D3", "F3"], "Bb1", ["Bb3", "D4", "F4", "D4"]),
        (["C4", "E4", "G4"],  "C2",  ["C4", "E4", "G4", "E4"]),
        (["F3", "A3", "C4"],  "F2",  ["F3", "A3", "C4", "A3"]),
        (["A3", "C4", "E4"],  "A2",  ["A3", "C4", "E4", "C4"]),
        (["Bb2", "D3", "F3"], "Bb1", ["Bb3", "D4", "F4", "D4"]),
        (["C4", "E4", "G4"],  "C2",  ["C4", "E4", "G4", "Bb4"]),
    ]
    for b, (chord, bass, arp) in enumerate(prog):
        t0 = b * bar
        for n in chord:  # warm, hazy pad held across the bar
            add_note(buf, t0, bar, freq(n), 0.15, PAD, a=0.4, d=0.45, s=0.72, r=0.6)
        # Soft, round bass — one relaxed note per half-bar.
        add_note(buf, t0, bar * 0.5, freq(bass), 0.30, BASS, a=0.03, d=0.3, s=0.5, r=0.4)
        add_note(buf, t0 + bar * 0.5, bar * 0.5, freq(bass), 0.24, BASS, a=0.03, d=0.3, s=0.42, r=0.4)
        # Swung eighth-note plucks: on-beat notes are long, off-beats short & late.
        for k in range(8):
            bi, off = k // 2, k % 2
            if off:
                start = t0 + (bi + swing) * beat
                dur = (1.0 - swing) * beat
            else:
                start = t0 + bi * beat
                dur = swing * beat
            n = arp[bi]
            add_note(buf, start, dur, freq(n), 0.14, PLUCK,
                     a=0.005, d=0.16, s=0.2, r=min(dur * 0.6, 0.12))
    return _finish(buf)


# ── Track 5: Dusky Hollow — E minor, slow, mysterious, brooding low bell ──────
def dusky_hollow():
    bpm = 66
    beat, buf = _bars(bpm, 6)
    bar = beat * 4
    prog = [
        (["E3", "G3", "B3"],  "E2"),
        (["C3", "E3", "G3"],  "C2"),
        (["A2", "C3", "E3"],  "A1"),
        (["D3", "F#3", "A3"], "D2"),
        (["E3", "G3", "B3"],  "E2"),
        (["B2", "D#3", "F#3"], "B1"),  # dominant lift back to the top
    ]
    for b, (chord, bass) in enumerate(prog):
        t0 = b * bar
        for n in chord:  # dim, slow-swelling pad
            add_note(buf, t0, bar, freq(n), 0.14, PAD, a=0.6, d=0.6, s=0.74, r=0.8)
        add_note(buf, t0, bar, freq(bass), 0.30, BASS, a=0.05, d=0.5, s=0.55, r=0.55)
    # Sparse, brooding bell melody sitting low in the mix (beat, dur, note).
    mel = [
        (0, 2, "B4"), (2, 2, "G4"),
        (4, 3, "E4"), (7, 1, "G4"),
        (8, 2, "A4"), (10, 2, "E4"),
        (12, 2, "F#4"), (14, 1.5, "A4"), (15.5, 0.5, "G4"),
        (16, 2, "G4"), (18, 2, "B4"),
        (20, 2, "F#4"), (22, 1, "D#4"), (23, 1, "B3"),
    ]
    for start, dur, n in mel:
        add_note(buf, start * beat, dur * beat, freq(n), 0.16, BELL,
                 a=0.02, d=0.7, s=0.28, r=min(dur * beat * 0.5, 0.7))
    return _finish(buf)


# ── Track 6: Berry Bounce — D major, fast, playful, hopping staccato bass ─────
def berry_bounce():
    bpm = 116
    beat, buf = _bars(bpm, 8)
    bar = beat * 4
    prog = [  # (pad triad, bass root, bass fifth, arpeggio chord tones)
        (["D4", "F#4", "A4"], "D2", "A2", ["D4", "F#4", "A4", "F#4"]),
        (["B3", "D4", "F#4"], "B1", "F#2", ["B3", "D4", "F#4", "D4"]),
        (["G3", "B3", "D4"],  "G1", "D2", ["G4", "D4", "B3", "D4"]),
        (["A3", "C#4", "E4"], "A1", "E2", ["A3", "C#4", "E4", "C#4"]),
        (["D4", "F#4", "A4"], "D2", "A2", ["D4", "F#4", "A4", "F#4"]),
        (["B3", "D4", "F#4"], "B1", "F#2", ["B3", "D4", "F#4", "D4"]),
        (["G3", "B3", "D4"],  "G1", "D2", ["G4", "D4", "B3", "D4"]),
        (["A3", "C#4", "E4"], "A1", "E2", ["E4", "C#4", "A3", "C#4"]),
    ]
    for b, (chord, bass, fifth, arp) in enumerate(prog):
        t0 = b * bar
        for n in chord:  # light, springy pad
            add_note(buf, t0, bar, freq(n), 0.11, PAD, a=0.2, d=0.3, s=0.66, r=0.4)
        # Hopping staccato bass: root on the beat, fifth on the off-beat.
        for beatn in range(4):
            add_note(buf, t0 + beatn * beat, beat * 0.4, freq(bass), 0.30, BASS,
                     a=0.005, d=0.12, s=0.3, r=0.12)
            add_note(buf, t0 + (beatn + 0.5) * beat, beat * 0.35, freq(fifth), 0.18, BASS,
                     a=0.005, d=0.1, s=0.25, r=0.1)
        for j, n in enumerate(arp * 2):  # bright, bouncy eighth plucks
            add_note(buf, t0 + j * (beat * 0.5), beat * 0.5, freq(n), 0.15,
                     PLUCK, a=0.004, d=0.13, s=0.22, r=0.1)
    return _finish(buf)


if __name__ == "__main__":
    _write("canopy_calm.wav", canopy_calm())
    _write("moonlit_vines.wav", moonlit_vines())
    _write("sunny_grove.wav", sunny_grove())
    _write("dewdrop_swing.wav", dewdrop_swing())
    _write("dusky_hollow.wav", dusky_hollow())
    _write("berry_bounce.wav", berry_bounce())
