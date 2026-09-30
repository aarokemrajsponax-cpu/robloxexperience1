#!/usr/bin/env python3
"""Maison Noir's own music and sounds, composed and synthesised from nothing.

Every note and every sound here is written in this file and rendered with plain maths (additive
and FM synthesis, plucked strings, filtered noise, a synthetic room): no samples, no recordings,
nothing borrowed. The results belong to the game.

Writes:
  assets/audio/maison-sounds.ogg    the sound sheet: every table sound, several takes of each
  assets/audio/maison-lounge.ogg    solo piano, a slow ballad in F (the Foyer, the Suite)
  assets/audio/maison-table.ogg     a brushed quartet in D minor, 96 bpm (the sorting rooms)
  assets/audio/maison-ballroom.ogg  the band, a swing in F, 132 bpm (the Ballroom)
  src/shared/SoundSheet.luau        where each take sits in the sheet

Every track loops without a seam: each is rendered with its reverb tail, and the tail is folded
back onto the start.

Usage (from the repo root):  python3 tools/audio/compose.py
Needs: numpy, scipy, soundfile (pip install numpy scipy soundfile).
"""

import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")

# --------------------------------------------------------------------------------------------
# Small tools
# --------------------------------------------------------------------------------------------

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'C#5' -> 73, 'Bb3' -> 58."""
    letter, rest, acc = name[0], name[1:], 0
    while rest and rest[0] in "#b":
        acc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NOTE[letter] + acc


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def secs(n):
    return np.arange(int(n * SR)) / SR


_sos = {}


def filt(x, kind, f, order=2):
    key = (kind, tuple(np.atleast_1d(f)), order)
    if key not in _sos:
        _sos[key] = signal.butter(order, f, btype=kind, fs=SR, output="sos")
    return signal.sosfilt(_sos[key], x)


def pan(mono, p):
    """Equal-power pan, p in -1..1."""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], 1)


def ramp_in(x, seconds):
    n = min(len(x), max(1, int(seconds * SR)))
    x[:n] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))
    return x


def release(x, at, seconds):
    """Dampens everything after sample `at` with an exponential release."""
    at = int(at)
    if at < len(x):
        x[at:] *= np.exp(-np.arange(len(x) - at) / SR / max(seconds, 1e-3))
    return x


def close(x, seconds=0.2):
    """Lets the end of a sound go smoothly to nothing."""
    k = min(len(x), int(seconds * SR))
    curve = np.linspace(1, 0, k) ** 2
    x[-k:] *= curve[:, None] if x.ndim == 2 else curve
    return x


def add(buf, x, start):
    start = int(start)
    if start >= len(buf):
        return
    if start < 0:
        x = x[-start:]
        start = 0
    end = min(len(buf), start + len(x))
    piece = x[: end - start]
    if end - start < len(x):
        piece = piece.copy()
        k = min(len(piece), int(0.006 * SR))
        ramp = np.linspace(1, 0, k)
        piece[-k:] *= ramp[:, None] if piece.ndim == 2 else ramp
    buf[start:end] += piece


def make_ir(seconds, seed, damp=2000.0, early=True):
    """A stereo room: decorrelated noise tails, highs dying faster than lows, a few reflections."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    ir = np.zeros((n, 2))
    for ch in range(2):
        noise = rng.standard_normal(n)
        low = filt(noise, "lowpass", damp) * np.exp(-6.9 * t / seconds)
        high = filt(noise, "highpass", damp) * np.exp(-6.9 * t / (seconds * 0.4))
        x = low + 0.35 * filt(high, "lowpass", 7000)
        x[: int(0.014 * SR)] = 0
        if early:
            for d, g in ((0.009, 0.7), (0.017, 0.5), (0.023, 0.42), (0.031, 0.33), (0.047, 0.25)):
                k = int((d + ch * 0.0027) * SR)
                x[k] += g * rng.choice((-1.0, 1.0)) * 4
        ir[:, ch] = x
    ir /= np.sqrt((ir ** 2).sum(0)).max()
    return ir


def reverb(stereo, ir, wet):
    mono = stereo.mean(1)
    out = stereo.copy()
    for ch in range(2):
        out[:, ch] += wet * signal.fftconvolve(mono, ir[:, ch])[: len(stereo)]
    return out


# --------------------------------------------------------------------------------------------
# Instruments. Each returns a mono note: (frequency, seconds held, velocity 0..1, rng).
# --------------------------------------------------------------------------------------------

_cache = {}


def cached(kind, fn, f, dur, vel, seed):
    key = (kind, round(f, 2), round(dur, 2), round(vel, 2), seed % 3)
    if key not in _cache:
        _cache[key] = fn(f, dur, vel, np.random.default_rng(seed % 3 + int(f)))
    return _cache[key]


def piano(f, dur, vel, rng):
    """A soft felt piano: stretched partials, two strings a hair apart, a felt hammer."""
    tail = 0.45
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    base_t60 = float(np.clip(9.0 * (261.6 / f) ** 0.6, 1.4, 14))
    bright = 1400 + 3200 * vel
    strings = (-0.9, 0.9) if f > 110 else (0.0,)
    for k in range(1, 18):
        fk = k * f * np.sqrt(1 + 0.00032 * k * k)
        if fk > 10000:
            break
        amp = k ** -1.05 * np.exp(-fk / bright) * (0.2 + 0.8 * abs(np.sin(np.pi * k / 7.3)))
        # A quick first decay and a long, quiet aftersound, as a real string does.
        t60 = base_t60 / (1 + 0.45 * (k - 1))
        env = 0.72 * np.exp(-6.9 * t / (t60 * 0.28)) + 0.28 * np.exp(-6.9 * t / t60)
        for cents in strings:
            fr = fk * 2 ** (cents / 1200)
            out += amp * env * np.sin(2 * np.pi * fr * t + rng.uniform(0, 2 * np.pi)) / len(strings)
    ramp_in(out, 0.003 + 0.004 * (1 - vel))
    thump = filt(rng.standard_normal(int(0.03 * SR)), "lowpass", 500 + 900 * vel)
    thump *= np.exp(-np.arange(len(thump)) / SR / 0.006)
    out[: len(thump)] += thump * 0.05 * vel
    release(out, dur * SR, 0.11)
    return out * vel


def rhodes(f, dur, vel, rng):
    """An electric piano: a sine FM pair for the bark, and a short tine ping."""
    tail = 0.5
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    index = (0.35 + 1.9 * vel) * np.exp(-t / 0.2) + 0.25 * vel
    phase = rng.uniform(0, 2 * np.pi)
    x = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t + phase))
    x *= np.exp(-t / float(np.clip(2.4 * (261.6 / f) ** 0.45, 0.8, 4.5)))
    tine = np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t / 0.045) * 0.16 * vel
    x = x + tine
    ramp_in(x, 0.0025)
    release(x, dur * SR, 0.1)
    return x * vel * 0.8


def vibes(f, dur, vel, rng, motor=True):
    """A vibraphone: bar modes near 1 : 4 : 10, a slow motor tremolo, a mallet."""
    tail = 0.7
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    d1 = float(np.clip(3.2 * (523.0 / f) ** 0.3, 1.2, 5.0))
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / d1)
    x += 0.24 * vel * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t / 0.3)
    x += 0.05 * vel * np.sin(2 * np.pi * f * 9.8 * t) * np.exp(-t / 0.07)
    if motor:
        x *= 1 - 0.2 * (0.5 + 0.5 * np.sin(2 * np.pi * 4.6 * t + rng.uniform(0, 2 * np.pi)))
    click = filt(rng.standard_normal(int(0.006 * SR)), "bandpass", [1500, 5000]) * np.linspace(1, 0, int(0.006 * SR))
    x[: len(click)] += click * 0.06 * vel
    ramp_in(x, 0.0015)
    release(x, dur * SR, 0.16)
    return x * vel


def marimba(f, dur, vel, rng):
    """A rosewood bar, muted (the wrong-case knock)."""
    n = int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.13) + 0.3 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / 0.025)
    thump = filt(rng.standard_normal(int(0.02 * SR)), "lowpass", 700) * np.exp(-np.arange(int(0.02 * SR)) / SR / 0.005)
    x[: len(thump)] += thump * 0.25
    ramp_in(x, 0.001)
    return x * vel


def upright(f, dur, vel, rng):
    """A plucked double bass: a Karplus-Strong string with a soft finger and a round body."""
    tail = 0.3
    n = int((dur + tail) * SR)
    period = int(round(SR / f))
    burst = filt(rng.standard_normal(period), "lowpass", 380 + 700 * vel)
    burst /= np.abs(burst).max() + 1e-9
    y = np.zeros(n + period + 2)
    y[:period] = burst
    y[period] = 0.5 * 0.996 * y[0]
    rho = 0.9955
    i = period + 1
    while i < len(y):
        j = min(i + period, len(y))
        y[i:j] = rho * 0.5 * (y[i - period : j - period] + y[i - period - 1 : j - period - 1])
        i = j
    x = y[:n]
    t = np.arange(n) / SR
    x = x + 0.6 * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.05)
    x = filt(x, "lowpass", 1400)
    ramp_in(x, 0.004)
    release(x, dur * SR, 0.05)
    return x * vel


def bell(f, dur, vel, rng, ratio=2.0, index=1.2, decay=1.4):
    """An FM bell; ratio 2 is warm and in tune, odd ratios are clock bells."""
    n = int((dur + decay * 6) * SR)
    t = np.arange(n) / SR
    idx = index * vel * np.exp(-t / (decay * 0.35)) + 0.15
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * ratio * t + rng.uniform(0, 6.28)))
    x *= np.exp(-t / decay)
    ramp_in(x, 0.0015)
    return x * vel


# Drums, each a mono hit.
def ride(vel, rng):
    t = secs(1.2)
    noise = rng.standard_normal(len(t))
    body = filt(noise, "bandpass", [3800, 10500]) * np.exp(-t / 0.26)
    ping = sum(a * np.sin(2 * np.pi * fr * t + rng.uniform(0, 6.28)) for fr, a in ((3050, 0.5), (4460, 0.36), (5190, 0.3), (6620, 0.2))) * np.exp(-t / 0.5)
    stick = filt(noise, "highpass", 6500) * np.exp(-t / 0.006)
    return (0.55 * body + 0.1 * ping + 0.35 * stick) * vel


def chick(vel, rng):
    t = secs(0.12)
    noise = rng.standard_normal(len(t))
    return (filt(noise, "bandpass", [6000, 12000]) * np.exp(-t / 0.016) + 0.35 * filt(noise, "bandpass", [700, 1500]) * np.exp(-t / 0.01)) * vel


def brush_tap(vel, rng):
    t = secs(0.3)
    noise = rng.standard_normal(len(t))
    return filt(noise, "bandpass", [900, 5200]) * np.exp(-t / 0.055) * vel


def kick(vel, rng):
    t = secs(0.35)
    freq = 46 + 34 * np.exp(-t / 0.025)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t / 0.13) * vel


# --------------------------------------------------------------------------------------------
# Writing music down: bars of (start beat, length in beats, note) and chords per bar
# --------------------------------------------------------------------------------------------


def seq(text):
    """'r1 A4.5 C5.5 E5 1.5' -> [(beat, length, note or None)]. Tokens are NOTE+LENGTH, where
    the length follows the note name ('A4.5' = A4 for half a beat, 'C5 2' also works)."""
    out, beat = [], 0.0
    toks = text.split()
    i = 0
    while i < len(toks):
        tok = toks[i]
        if tok[0] == "r":
            length = float(tok[1:])
            beat += length
            i += 1
            continue
        # The octave digit ends the note name; what follows is the length.
        j = 1
        while tok[j] in "#b":
            j += 1
        name, rest = tok[: j + 1], tok[j + 1 :]
        if rest == "":
            length = float(toks[i + 1])
            i += 1
        else:
            length = float(rest) if not rest.startswith(".") else float("0" + rest)
        out.append((beat, length, name))
        beat += length
        i += 1
    if abs(beat - 4) > 1e-6:
        raise ValueError(f"bar adds to {beat} beats: {text}")
    return out


class Band:
    """Places notes on a timeline with swing and a human touch, into named stereo stems."""

    def __init__(self, bpm, bars, swing, seed, tail=5.0):
        self.spb = 60.0 / bpm
        self.bars = bars
        self.swing = swing
        self.length = int(round(bars * 4 * self.spb * SR))
        self.n = self.length + int(tail * SR)
        self.rng = np.random.default_rng(seed)
        self.stems = {}

    def stem(self, name):
        if name not in self.stems:
            self.stems[name] = np.zeros((self.n, 2))
        return self.stems[name]

    def at(self, bar, beat, loose=0.006):
        whole = int(np.floor(beat + 1e-9))
        frac = beat - whole
        if abs(frac - 0.5) < 1e-6:
            frac = self.swing
        seconds = (bar * 4 + whole + frac) * self.spb + self.rng.normal(0, loose)
        return max(0.0, seconds)

    def play(self, stem, inst, kind, bar, beat, length, note, vel, p=0.0, loose=0.006):
        f = hz(midi(note)) if isinstance(note, str) else hz(note)
        vel = float(np.clip(vel * (1 + self.rng.normal(0, 0.07)), 0.05, 1))
        start = self.at(bar, beat, loose)
        held = max(0.05, length * self.spb * 0.92)
        x = cached(kind, inst, f, held, round(vel * 20) / 20, int(self.rng.integers(0, 3)))
        add(self.stem(stem), pan(x, p), start * SR)

    def hit(self, stem, fn, bar, beat, vel, p=0.0, loose=0.004):
        start = self.at(bar, beat, loose)
        x = fn(float(np.clip(vel * (1 + self.rng.normal(0, 0.1)), 0.03, 1)), self.rng)
        add(self.stem(stem), pan(x, p), start * SR)


# Chord voicings (rootless, around middle C) and roots.
VOICINGS = {
    "Dm9": ["C4", "E4", "F4", "A4"],
    "Gm9": ["Bb3", "D4", "F4", "A4"],
    "C13": ["Bb3", "D4", "E4", "A4"],
    "Fmaj9": ["A3", "C4", "E4", "G4"],
    "Bbmaj9": ["A3", "C4", "D4", "F4"],
    "Bbmaj7#11": ["A3", "D4", "E4", "F4"],
    "Em7b5": ["Bb3", "D4", "E4", "G4"],
    "A7b9": ["Bb3", "C#4", "E4", "G4"],
    "Cm9": ["Bb3", "D4", "Eb4", "G4"],
    "F13": ["Eb4", "G4", "A4", "D5"],
    "Bbm6": ["Db4", "F4", "G4", "Bb4"],
    "Eb9": ["Db4", "F4", "G4", "Bb4"],
    "Am7": ["G3", "C4", "E4", "A4"],
    "D7b9": ["C4", "Eb4", "F#4", "A4"],
    "G13": ["F3", "B3", "E4", "A4"],
    "C7b9": ["Bb3", "Db4", "E4", "G4"],
    "Fmaj7": ["A3", "C4", "E4", "F4"],
    "D7": ["C4", "F#4", "A4", "B4"],
    "Gm7": ["Bb3", "D4", "F4", "G4"],
    "C7": ["Bb3", "E4", "G4", "A4"],
    "F7": ["A3", "Eb4", "F4", "C5"],
    "Bbmaj7": ["A3", "D4", "F4", "Bb4"],
    "A7": ["G3", "C#4", "E4", "B4"],
    "G7": ["F3", "B3", "E4", "A4"],
    "F6": ["A3", "D4", "F4", "C5"],
}


def root(chord):
    name = chord[:2] if len(chord) > 1 and chord[1] in "#b" else chord[:1]
    return NOTE[name[0]] + (1 if name.endswith("#") else -1 if name.endswith("b") else 0)


def chord_scale(chord):
    """Root, third, fifth, the right seventh and the ninth, as pitch classes."""
    r = root(chord)
    quality = chord[2 if len(chord) > 1 and chord[1] in "#b" else 1 :]
    tones = chord_tones(chord)
    seventh = 11 if "maj" in quality else 9 if quality.endswith("6") else 10
    ninth = 1 if "b9" in quality else 2
    return {t % 12 for t in tones} | {(r + seventh) % 12, (r + ninth) % 12}


def chord_tones(chord):
    r = root(chord)
    quality = chord[len("Bb") if len(chord) > 1 and chord[1] in "#b" else 1 :]
    third = 3 if quality.startswith("m") and not quality.startswith("maj") else 4
    fifth = 6 if "b5" in quality else 7
    return [r, r + third, r + fifth]


def walk(band, stem, bars_chords, low=midi("E1"), high=midi("D3"), vel=0.8):
    """A walking bass: root on one, chord tones through the bar, a half step into the next root.
    `bars_chords` is a list per bar of one or two chords."""
    rng = band.rng
    prev = None
    total = len(bars_chords)
    for b, chords in enumerate(bars_chords):
        nxt = bars_chords[(b + 1) % total][0]
        for half, chord in enumerate(chords):
            beats = 4 if len(chords) == 1 else 2
            start = half * 2
            r = root(chord)
            # The root nearest the last note, inside the bass's range.
            cands = [m for m in range(low, high + 1) if m % 12 == r % 12]
            rn = min(cands, key=lambda m: abs(m - (prev if prev else midi("D2"))))
            line = [rn]
            tones = [(rn + i - r) for i in chord_tones(chord)]
            if beats == 4:
                line.append(int(rng.choice([tones[1], tones[2], rn + 12 if rn + 12 <= high else tones[2]])))
                line.append(int(rng.choice([tones[2], tones[1] + 12 if tones[1] + 12 <= high else tones[1]])))
            # The last beat leans into the next root by a half step.
            nr = root(nxt if half == len(chords) - 1 else chords[half + 1])
            target = min((m for m in range(low, high + 1) if m % 12 == nr % 12), key=lambda m: abs(m - line[-1]))
            line.append(target + int(rng.choice([-1, 1])))
            for i, m in enumerate(line):
                m = int(np.clip(m, low, high))
                band.play(stem, upright, "bass", b, start + i, 1.0, m, vel * (1.0 if i == 0 else 0.86), 0.0)
                prev = m


def comp(band, stem, inst, kind, bars_chords, patterns, vel, p, octave=0):
    """Chords on a rotating set of rhythms (start, length in beats)."""
    rng = band.rng
    for b, chords in enumerate(bars_chords):
        pattern = patterns[rng.integers(0, len(patterns))]
        for start, length in pattern:
            chord = chords[0] if len(chords) == 1 or start < 2 else chords[1]
            for k, note in enumerate(VOICINGS[chord]):
                m = midi(note) + 12 * octave
                band.play(stem, inst, kind, b, start, length, m, vel * (0.9 + 0.1 * k / 3), p, loose=0.004 + 0.004 * k)


def swing_drums(band, bars, ride_vel=0.3, brush=True, kick_vel=0.18):
    for b in range(bars):
        for beat in range(4):
            band.hit("drums", ride, b, beat, ride_vel * (1.0 if beat % 2 == 0 else 0.85), p=0.35)
            if beat in (1, 3):
                band.hit("drums", ride, b, beat + 0.5, ride_vel * 0.55, p=0.35)
                band.hit("drums", chick, b, beat, ride_vel * 0.9, p=-0.3)
                if brush:
                    band.hit("drums", brush_tap, b, beat, 0.22, p=-0.1)
            band.hit("drums", kick, b, beat, kick_vel, p=0.0)
    if brush:
        # The brush's circle on the snare: a soft continuous sweep, swelling each beat.
        n = band.n
        t = np.arange(n) / SR
        noise = band.rng.standard_normal(n)
        sweep = filt(noise, "bandpass", [1400, 6200]) * 0.035
        shape = 0.55 + 0.45 * np.sin(2 * np.pi * t / band.spb) ** 2
        band.stem("drums")[:, 0] += sweep * shape * 0.8
        band.stem("drums")[:, 1] += sweep * shape * 0.6


def melody(band, stem, inst, kind, bars, vel, p, octave=0, loose=0.01):
    for b, text in enumerate(bars):
        if text is None:
            continue
        for beat, length, note in seq(text):
            band.play(stem, inst, kind, b, beat, length, midi(note) + 12 * octave, vel * (1.08 if beat == 0 else 1.0), p, loose=loose)


def improvise(band, stem, inst, kind, bars_chords, vel, p, low=midi("A4"), high=midi("D6"), density=0.62):
    """A simple, singing line: chord tones on the beats, steps between, a breath every two bars."""
    rng = band.rng
    note = midi("D5")
    for b, chords in enumerate(bars_chords):
        if b % 4 == 3 and rng.random() < 0.5:
            continue
        for eighth in range(8):
            beat = eighth / 2
            if b % 2 == 1 and eighth >= 6:
                break
            if rng.random() > density:
                continue
            chord = chords[0] if len(chords) == 1 or beat < 2 else chords[1]
            tones = chord_scale(chord)
            if eighth % 2 == 0:
                cands = [m for m in range(low, high + 1) if m % 12 in tones]
            else:
                cands = [m for m in range(low, high + 1) if abs(m - note) <= 2]
            if not cands:
                continue
            step = rng.choice([-1, 1]) * rng.choice([1, 2, 3])
            goal = int(np.clip(note + step, low, high))
            note = min(cands, key=lambda m: abs(m - goal))
            length = 0.5 if rng.random() < 0.8 else 1.0
            band.play(stem, inst, kind, b, beat, length, note, vel * (1.0 if eighth % 2 == 0 else 0.82), p, loose=0.012)


def master(band, wet_by_stem, gains, ir_seconds, seed, target_rms_db=-18.0):
    ir = make_ir(ir_seconds, seed)
    mix = np.zeros((band.n, 2))
    for name, x in band.stems.items():
        mix += reverb(x * gains.get(name, 1.0), ir, wet_by_stem.get(name, 0.15))
    # Low end kept tidy, a gentle warmth on top.
    for ch in range(2):
        mix[:, ch] = filt(mix[:, ch], "highpass", 32)
    # Fold the tail back onto the start so the loop has no seam.
    L = band.length
    out = mix[:L].copy()
    tail = mix[L:]
    out[: len(tail)] += tail[: min(len(tail), L)]
    rms = np.sqrt((out ** 2).mean())
    out *= 10 ** (target_rms_db / 20) / (rms + 1e-12)
    # Soft ceiling at -1 dBFS.
    ceiling = 10 ** (-1 / 20)
    out = ceiling * np.tanh(out / ceiling)
    return out


def write(name, stereo, quality=0.55):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    data = stereo.astype(np.float32)
    # Written in blocks: libsndfile's Vorbis encoder can fall over on one very large write.
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 8192):
            f.write(data[i : i + 8192])
    return path


# --------------------------------------------------------------------------------------------
# The tracks
# --------------------------------------------------------------------------------------------


def table_track():
    """The sorting rooms: brushes, walking bass, electric piano comping, a vibraphone tune.
    D minor, 96 bpm, AABA twice: the head, then a quieter chorus with a light solo."""
    A = [["Dm9"], ["Dm9"], ["Gm9"], ["C13"], ["Fmaj9"], ["Bbmaj7#11"], ["Em7b5"], ["A7b9"]]
    B = [["Gm9"], ["C13"], ["Fmaj9"], ["Dm9"], ["Gm9"], ["C13"], ["Em7b5"], ["A7b9"]]
    chorus = A + A + B + A
    form = chorus + chorus
    band = Band(96, len(form), swing=0.64, seed=11)
    tune_a = [
        "r1 A4.5 C5.5 E5 1.5 D5.5",
        "C5 1.5 A4.5 r2",
        "r1 D5.5 F5.5 A5 1.5 G5.5",
        "F5 1.5 E5.5 r2",
        "r.5 E5.5 G5.5 A5.5 C6 1 A5 1",
        "G5 1 F5.5 E5 1.5 D5 1",
        "D5.5 C5.5 Bb4 1 r.5 G4.5 Bb4.5 D5.5",
        "C#5 1.5 Bb4.5 A4 1 r1",
    ]
    tune_a2 = tune_a[:6] + ["D5 1 Bb4.5 G4.5 E5 2", "C#5.5 E5.5 G5.5 F5.5 E5 1 r1"]
    tune_b = [
        "A5 1.5 G5.5 F5.5 D5.5 Bb4 1",
        "A4.5 G4.5 Bb4.5 D5.5 E5 2",
        "r1 C5.5 E5.5 G5 1 F5 1",
        "E5 3 r1",
        "r.5 D5.5 F5.5 A5.5 C6 1 Bb5 1",
        "A5 1.5 G5.5 E5 2",
        "G5.5 F5.5 D5.5 Bb4.5 C5 1 D5 1",
        "C#5 2 E5.5 G5.5 Bb5 1",
    ]
    head = tune_a + tune_a2 + tune_b + tune_a
    melody(band, "lead", vibes, "vibes", head, 0.62, 0.3)
    # Second chorus: a light solo in the A sections, the bridge tune an octave down, the last A as the head.
    second = chorus
    improvise(band, "solo", vibes, "vibes", [c for c in second[:16]], 0.5, 0.3)
    melody(band, "lead2", vibes, "vibes", [None] * 16 + tune_b + tune_a, 0.5, 0.25, octave=-1)
    # Shift the solo and second-chorus lines into the second half of the form.
    offset = int(round(32 * 4 * band.spb * SR))
    for name in ("solo", "lead2"):
        x = band.stems[name]
        shifted = np.zeros_like(x)
        shifted[offset:] = x[: len(x) - offset]
        band.stems[name] = shifted
    patterns = [
        [(0, 1.5), (2.5, 1)],
        [(0.5, 1), (3, 0.75)],
        [(1.5, 0.5), (2.5, 1.5)],
        [(0, 0.5), (1.5, 2)],
        [(1, 1), (3.5, 0.5)],
    ]
    comp(band, "keys", rhodes, "rhodes", form, patterns, 0.42, -0.35)
    walk(band, "bass", form, vel=0.85)
    swing_drums(band, len(form), ride_vel=0.26, brush=True, kick_vel=0.16)
    out = master(
        band,
        wet_by_stem={"lead": 0.3, "lead2": 0.3, "solo": 0.3, "keys": 0.22, "bass": 0.06, "drums": 0.12},
        gains={"lead": 0.55, "lead2": 0.5, "solo": 0.45, "keys": 0.5, "bass": 0.9, "drums": 0.55},
        ir_seconds=2.0,
        seed=3,
        target_rms_db=-19.0,
    )
    return out


def lounge_track():
    """The Foyer's piano: a slow ballad in F, played twice, the second time an octave brighter
    in places. 72 bpm, gently rubato."""
    changes = [
        ["Fmaj9"], ["Em7b5", "A7b9"], ["Dm9"], ["Cm9", "F13"],
        ["Bbmaj9"], ["Bbm6", "Eb9"], ["Am7", "D7b9"], ["Gm9", "C13"],
        ["Fmaj9"], ["Em7b5", "A7b9"], ["Dm9", "G13"], ["Gm9", "C7b9"],
        ["Am7", "D7b9"], ["Gm9", "C13"], ["Fmaj9", "D7b9"], ["Gm9", "C13"],
    ]
    tune = [
        "A4 1 C5 1 E5 1.5 D5.5",
        "C5 1 Bb4 1 A4 1 C#5 1",
        "E5 2 F5.5 E5.5 D5 1",
        "Eb5 1 D5 1 C5 1 A4 1",
        "D5 1.5 C5.5 D5 1 F5 1",
        "Db5 1 F5 1 G5 1 F5 1",
        "E5 1 C5 1 Eb5 1 F#5 1",
        "A5 1.5 G5.5 E5 2",
        "r.5 A4.5 C5 1 E5 1 G5 1",
        "G5 1 D5 1 C#5 1.5 E5.5",
        "F5 1 E5 1 D5 1 B4 1",
        "Bb4 1 D5 1 Db5 1 E5 1",
        "C5 1.5 A4.5 F#4 1 A4 1",
        "Bb4 1 A4 1 G4 1 E4 1",
        "F4 2 r1 A4.5 C5.5",
        "D5 1 F5 1 E5 1.5 C5.5",
    ]
    form = changes + changes
    band = Band(72, len(form), swing=0.5, seed=5)
    melody(band, "rh", piano, "piano", tune, 0.62, 0.05, loose=0.018)
    # The second time, the tune an octave up for the first eight bars, then home again.
    second = np.zeros_like(band.stems["rh"])
    band.stems["rh2"] = second
    melody(band, "rh2", piano, "piano", [None] * 16 + tune[:8] + [None] * 8, 0.5, 0.1, octave=1, loose=0.02)
    melody(band, "rh2", piano, "piano", [None] * 24 + tune[8:], 0.6, 0.05, loose=0.018)
    # The left hand: a low root on one, the chord just after, the second chord on three.
    for b, chords in enumerate(form):
        for half, chord in enumerate(chords):
            beat = 0 if half == 0 else 2
            r = root(chord)
            low = midi("F2") + ((r - midi("F2")) % 12)
            if low > midi("D3"):
                low -= 12
            band.play("lh", piano, "piano", b, beat, 2 if len(chords) == 2 else 1.5, low, 0.5, -0.1, loose=0.012)
            for k, note in enumerate(VOICINGS[chord]):
                band.play("lh", piano, "piano", b, beat + 0.5 + 0.06 * k, 1.5 if len(chords) == 2 else 3.2, note, 0.32, -0.05 + 0.05 * k, loose=0.006)
    out = master(
        band,
        wet_by_stem={"rh": 0.32, "rh2": 0.32, "lh": 0.3},
        gains={"rh": 0.8, "rh2": 0.7, "lh": 0.62},
        ir_seconds=2.6,
        seed=9,
        target_rms_db=-20.0,
    )
    return out


def ballroom_track():
    """The band: a swing in F on rhythm changes, 132 bpm. The head, then a vibraphone solo over
    the same form, with the piano doubling the tune the first time through."""
    A1 = [["Fmaj7", "D7"], ["Gm7", "C7"], ["Am7", "D7"], ["Gm7", "C7"], ["Fmaj7", "F7"], ["Bbmaj7", "Bbm6"], ["Am7", "D7"], ["Gm7", "C7"]]
    A2 = A1[:7] + [["Gm7", "C7"]]
    B = [["A7"], ["A7"], ["D7"], ["D7"], ["G7"], ["G7"], ["C7"], ["C7"]]
    chorus = A1 + A2 + B + A1
    form = chorus + chorus
    band = Band(132, len(form), swing=0.66, seed=21)
    head_a = [
        "r.5 C5.5 D5.5 F5 1 D5.5 F5 1",
        "G5.5 F5.5 D5 1 E5 1.5 r.5",
        "r.5 C5.5 D5.5 F5 1 D5.5 F#5 1",
        "G5.5 A5.5 Bb5.5 A5.5 G5.5 E5.5 C5 1",
        "A5 1 F5.5 A5 1.5 Eb5 1",
        "D5 1.5 F5.5 Db5 1.5 F5.5",
        "E5.5 C5.5 A4 1 F#5 1 A5 1",
        "G5 1.5 F5.5 E5 1 r1",
    ]
    head_a2 = head_a[:7] + ["F5 3 r1"]
    head_b = [
        "E5 1 C#5 1 E5 1 G5 1",
        "A5 2 G5 1 E5 1",
        "F#5 1 D5 1 F#5 1 A5 1",
        "C6 2 A5 1 F#5 1",
        "D5 1 B4 1 D5 1 F5 1",
        "G5 2 F5 1 D5 1",
        "E5 1 C5 1 E5 1 G5 1",
        "Bb5 2 A5 1 G5 1",
    ]
    head = head_a + head_a2 + head_b + head_a
    melody(band, "lead", vibes, "vibes", head, 0.7, 0.3)
    melody(band, "double", piano, "piano", head, 0.45, -0.2, octave=-1)
    improvise(band, "solo", vibes, "vibes", chorus, 0.6, 0.3, density=0.7)
    offset = int(round(32 * 4 * band.spb * SR))
    x = band.stems["solo"]
    shifted = np.zeros_like(x)
    shifted[offset:] = x[: len(x) - offset]
    band.stems["solo"] = shifted
    patterns = [
        [(0, 0.5), (1.5, 0.5), (2.5, 1)],
        [(0.5, 0.5), (2, 0.5), (3.5, 0.5)],
        [(1, 0.5), (2.5, 0.5)],
        [(0, 1), (2.5, 1)],
    ]
    comp(band, "keys", rhodes, "rhodes", form, patterns, 0.45, -0.35)
    comp(band, "piano", piano, "piano", form, [[(1.5, 0.5), (3.5, 0.5)], [(0.5, 0.5), (2.5, 0.5)]], 0.3, 0.15)
    walk(band, "bass", form, low=midi("E1"), high=midi("D3"), vel=0.9)
    swing_drums(band, len(form), ride_vel=0.36, brush=True, kick_vel=0.2)
    out = master(
        band,
        wet_by_stem={"lead": 0.28, "double": 0.25, "solo": 0.28, "keys": 0.2, "piano": 0.22, "bass": 0.06, "drums": 0.14},
        gains={"lead": 0.55, "double": 0.35, "solo": 0.5, "keys": 0.4, "piano": 0.35, "bass": 0.95, "drums": 0.6},
        ir_seconds=2.4,
        seed=4,
        target_rms_db=-18.0,
    )
    return out


# --------------------------------------------------------------------------------------------
# The sound sheet: every table sound, in takes
# --------------------------------------------------------------------------------------------


def noise(n, rng):
    return rng.standard_normal(int(n))


def env_exp(n, tau):
    return np.exp(-np.arange(int(n)) / SR / tau)


def cue_pickup(rng):
    """Lifting a piece off felt: a tiny wooden tick and a brush of cloth."""
    t = secs(0.18)
    fr = rng.uniform(1500, 2100)
    tick = np.sin(2 * np.pi * fr * t) * np.exp(-t / 0.007) * 0.55
    knock = np.sin(2 * np.pi * rng.uniform(420, 520) * t) * np.exp(-t / 0.014) * 0.5
    brush = filt(noise(len(t), rng), "bandpass", [700, 2400]) * np.sin(np.pi * np.clip(t / 0.1, 0, 1)) ** 2 * 0.14
    lift = filt(noise(len(t), rng), "lowpass", 500) * np.exp(-t / 0.012) * 0.3
    return tick + knock + brush + lift


def cue_place(rng):
    """A piece settling into a velvet-lined case: a soft thump, a muffled tap, the glass answering."""
    t = secs(0.45)
    f0 = rng.uniform(135, 165)
    freq = f0 * (0.8 + 0.2 * np.exp(-t / 0.03))
    thump = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t / 0.06)
    tap = filt(noise(len(t), rng), "lowpass", 1400) * np.exp(-t / 0.02) * 0.6
    ring = (np.sin(2 * np.pi * rng.uniform(3000, 3300) * t) + 0.6 * np.sin(2 * np.pi * rng.uniform(4600, 4900) * t)) * np.exp(-t / 0.12) * 0.06
    return thump * 0.8 + tap + ring


def cue_drop(rng):
    """Back onto the felt."""
    t = secs(0.2)
    thump = np.sin(2 * np.pi * rng.uniform(170, 210) * t) * np.exp(-t / 0.035)
    tap = filt(noise(len(t), rng), "lowpass", 2200) * np.exp(-t / 0.018) * 0.7
    return thump * 0.6 + tap


def cue_deal(rng):
    """A piece landing in the deal: a little slide, then down."""
    t = secs(0.16)
    slide = filt(noise(len(t), rng), "bandpass", [900, 3600]) * np.clip(1 - t / 0.03, 0, 1) * 0.25
    down = np.zeros(len(t))
    k = int(0.028 * SR)
    down[k:] = filt(noise(len(t) - k, rng), "lowpass", rng.uniform(1800, 2600)) * np.exp(-np.arange(len(t) - k) / SR / 0.016)
    thump = np.zeros(len(t))
    thump[k:] = np.sin(2 * np.pi * rng.uniform(220, 280) * np.arange(len(t) - k) / SR) * np.exp(-np.arange(len(t) - k) / SR / 0.025) * 0.5
    return slide + down + thump


def cue_slide(rng):
    """A piece pulled quickly across the felt."""
    t = secs(0.15)
    lo, hi = rng.uniform(600, 900), rng.uniform(2800, 4200)
    return filt(noise(len(t), rng), "bandpass", [lo, hi]) * np.sin(np.pi * t / t[-1]) ** 1.5 * 0.5


def cue_hover(rng):
    """A held piece over a case: the glass gives a tiny tick."""
    t = secs(0.08)
    fr = rng.uniform(2900, 3400)
    return (np.sin(2 * np.pi * fr * t) * np.exp(-t / 0.018) + filt(noise(len(t), rng), "highpass", 5000) * np.exp(-t / 0.002) * 0.4) * 0.6


def cue_chime(rng, vel):
    """The house chime: a warm bell with a vibraphone's body, at C5, played up the scale by the game."""
    f = hz(midi("C5"))
    n = int(1.8 * SR)
    left, right = np.zeros(n), np.zeros(n)
    add(left, bell(f, 0.2, vel, rng, ratio=2.0, index=0.9, decay=1.1), 0)
    add(right, bell(f * 2 ** (4 / 1200), 0.2, vel, rng, ratio=2.0, index=0.9, decay=1.1), 0)
    body = vibes(f, 0.6, vel, rng, motor=False) * 0.55
    add(left, body, 0)
    add(right, body, 0)
    return close(np.stack([left, right], 1), 0.3)


def cue_harp(rng, vel):
    f = hz(midi("C5"))
    period = int(round(SR / f))
    n = int(2.0 * SR)
    burst = filt(rng.standard_normal(period), "lowpass", 5000)
    y = np.zeros(n + period + 2)
    y[:period] = burst / (np.abs(burst).max() + 1e-9)
    i = period + 1
    while i < len(y):
        j = min(i + period, len(y))
        y[i:j] = 0.9985 * 0.5 * (y[i - period : j - period] + y[i - period - 1 : j - period - 1])
        i = j
    x = filt(y[:n], "lowpass", 6000) * vel
    ramp_in(x, 0.001)
    return close(x, 0.4)


def cue_musicbox(rng, vel):
    f = hz(midi("C5"))
    t = secs(1.8)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.9) + 0.18 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.12)
    x += 0.5 * np.sin(2 * np.pi * f * 2 ** (6 / 1200) * t) * np.exp(-t / 0.8)
    click = filt(rng.standard_normal(int(0.004 * SR)), "highpass", 3000)
    x[: len(click)] += click * 0.3
    ramp_in(x, 0.0008)
    return close(x * vel * 0.7, 0.4)


def cue_celesta(rng, vel):
    f = hz(midi("C5"))
    t = secs(1.5)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.75) + 0.25 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.2) + 0.08 * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t / 0.1)
    thump = filt(rng.standard_normal(int(0.015 * SR)), "lowpass", 900) * env_exp(0.015 * SR, 0.004)
    x[: len(thump)] += thump * 0.15
    ramp_in(x, 0.002)
    return close(x * vel, 0.4)


def cue_glass(rng, vel):
    f = hz(midi("C5"))
    t = secs(2.0)
    swell = np.clip(t / 0.09, 0, 1) ** 1.5
    x = (np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * (f + 1.3) * t)) * 0.5 + 0.22 * np.sin(2 * np.pi * 2 * f * t) + 0.06 * np.sin(2 * np.pi * 3 * f * t)
    return close(x * swell * np.exp(-t / 0.7) * vel * 0.8, 0.4)


def cue_wrong(rng):
    """Not that one: two soft, muted wooden notes, falling."""
    t = secs(0.45)
    x = np.zeros(len(t))
    first = marimba(hz(midi("A3")) * rng.uniform(0.99, 1.01), 0.1, 0.9, rng)
    second = marimba(hz(midi("F3")) * rng.uniform(0.99, 1.01), 0.15, 0.8, rng)
    add(x, first, 0)
    add(x, second, int(0.12 * SR))
    x += filt(noise(len(t), rng), "lowpass", 500) * np.exp(-t / 0.03) * 0.3
    return filt(x, "lowpass", 2600)


def cue_streak_lost(rng):
    """A streak slipping away: a soft falling breath of air."""
    t = secs(0.6)
    x = filt(noise(len(t), rng), "bandpass", [400, 2400]) * np.sin(np.pi * t / t[-1]) ** 2 * 0.25
    f = 230 * np.exp(-t / 0.6) + 110
    x += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22) * 0.35
    return close(filt(x, "lowpass", 2500), 0.25)


def cue_arpeggio(rng, notes, gap, inst=vibes, vel=0.7, hold=0.6, length=1.6):
    out = np.zeros(int(length * SR))
    for i, name in enumerate(notes):
        x = inst(hz(midi(name)), hold, vel * (0.85 + 0.15 * i / max(1, len(notes) - 1)), rng)
        add(out, x, int(i * gap * SR + rng.normal(0, 0.003) * SR))
    return out


def cue_shimmer(rng):
    out = np.zeros(int(0.9 * SR))
    names = ["C6", "D6", "E6", "G6", "A6", "C7"]
    for _ in range(11):
        f = hz(midi(names[rng.integers(0, len(names))]))
        t = secs(0.3)
        grain = close(np.sin(2 * np.pi * f * t) * np.exp(-t / 0.12) * rng.uniform(0.3, 0.7), 0.1)
        add(out, grain, rng.uniform(0, 0.4) * SR)
    return out


def cue_chord(rng, chords, gap, strum, inst=rhodes, vel=0.55, hold=1.2, length=2.6, top=None):
    out = np.zeros(int(length * SR))
    for c, chord in enumerate(chords):
        for k, note in enumerate(VOICINGS[chord]):
            x = inst(hz(midi(note)), hold, vel, rng)
            add(out, x, (c * gap + k * strum) * SR)
    if top:
        for i, (note, at) in enumerate(top):
            add(out, bell(hz(midi(note)), 0.2, 0.5, rng, ratio=2.0, index=0.8, decay=0.9), at * SR)
    return out


def cue_low(rng):
    """The clock: a far-off bell, low."""
    return bell(hz(midi("G3")), 0.2, 0.8, rng, ratio=2.76, index=1.1, decay=1.6)


def cue_enter(rng):
    """Sitting down to sort: air rushing in, and a warm chord blooming."""
    t = secs(1.3)
    sweep_centre = 400 * (1 + 5 * np.clip(t / 0.45, 0, 1))
    air = np.zeros(len(t))
    raw = noise(len(t), rng)
    # A rising band of air, made from a few overlapping bands.
    for lo in (400, 900, 1800):
        band = filt(raw, "bandpass", [lo, lo * 2.2])
        weight = np.exp(-((sweep_centre - lo * 1.5) / (lo * 1.2)) ** 2)
        air += band * weight
    air *= np.sin(np.pi * np.clip(t / 0.55, 0, 1)) ** 2 * 0.18
    bloom = cue_chord(rng, ["Fmaj9"], 0, 0.035, inst=rhodes, vel=0.45, hold=0.9, length=1.3)
    ramp_in(bloom, 0.05)
    x = np.zeros(len(t))
    add(x, air, 0)
    add(x, bloom * 0.8, 0.18 * SR)
    return x


def cue_leave(rng):
    t = secs(1.0)
    raw = noise(len(t), rng)
    air = filt(raw, "bandpass", [500, 2600]) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 2 * np.exp(-t / 0.4) * 0.16
    chord = cue_chord(rng, ["Dm9"], 0, 0.02, inst=rhodes, vel=0.38, hold=0.5, length=1.0)
    return air + chord * 0.7


def cue_chair(rng):
    t = secs(0.32)
    body = filt(noise(len(t), rng), "bandpass", [140, 700]) * np.exp(-t / 0.06)
    low = np.sin(2 * np.pi * rng.uniform(95, 120) * t) * np.exp(-t / 0.07) * 0.6
    creak = filt(noise(len(t), rng), "bandpass", [900, 1500]) * np.exp(-((t - 0.12) / 0.04) ** 2) * 0.06
    return body * 0.7 + low + creak


def cue_door(rng):
    t = secs(0.8)
    latch = filt(noise(len(t), rng), "bandpass", [1800, 6000]) * np.exp(-t / 0.006) * 0.5
    k = int(0.05 * SR)
    latch2 = np.zeros(len(t))
    latch2[k:] = filt(noise(len(t) - k, rng), "bandpass", [1500, 5000]) * np.exp(-np.arange(len(t) - k) / SR / 0.005) * 0.3
    swing = filt(noise(len(t), rng), "bandpass", [200, 900]) * np.sin(np.pi * np.clip((t - 0.08) / 0.6, 0, 1)) ** 2 * 0.25
    thud = np.sin(2 * np.pi * 85 * t) * np.exp(-t / 0.12) * 0.4
    return latch + latch2 + swing + thud


def cue_click(rng):
    """A key pressed: in, and out."""
    t = secs(0.07)
    x = np.zeros(len(t))
    for at, g in ((0.0, 0.7), (rng.uniform(0.016, 0.022), 0.4)):
        k = int(at * SR)
        m = len(t) - k
        burst = filt(noise(m, rng), "bandpass", [2000, 7000]) * np.exp(-np.arange(m) / SR / 0.0025)
        body = np.sin(2 * np.pi * rng.uniform(1000, 1250) * np.arange(m) / SR) * np.exp(-np.arange(m) / SR / 0.008) * 0.5
        x[k:] += (burst + body) * g
    return x


def cue_tick(rng):
    t = secs(0.04)
    return (filt(noise(len(t), rng), "bandpass", [3000, 8000]) * np.exp(-t / 0.0018) + np.sin(2 * np.pi * rng.uniform(2300, 2600) * t) * np.exp(-t / 0.005) * 0.4) * 0.6


def cue_reward(rng):
    notes = ["G5", "A5", "C6", "D6", "E6", "G6"]
    x = cue_arpeggio(rng, notes, 0.055, inst=vibes, vel=0.6, hold=0.5, length=1.5)
    t = secs(1.5)
    shaker = filt(noise(len(t), rng), "highpass", 5000) * np.exp(-t / 0.25) * 0.05
    return x + shaker


def peak_norm(x, db=-3.0):
    peak = np.abs(x).max()
    return x * (10 ** (db / 20) / (peak + 1e-12))


def trim(x, floor_db=-54, longest=2.4):
    """Cuts the silence before and after (a take must start the instant it is played), and any
    offset from zero."""
    x = x.copy()
    for ch in range(x.shape[1]) if x.ndim == 2 else ():
        x[:, ch] = filt(x[:, ch], "highpass", 28)
    level = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    thresh = level.max() * 10 ** (floor_db / 20)
    idx = np.nonzero(level > thresh)[0]
    first = np.nonzero(level > level.max() * 10 ** (-48 / 20))[0]
    begin = max(0, first[0] - int(0.001 * SR)) if len(first) else 0
    end = idx[-1] + int(0.01 * SR) if len(idx) else len(x)
    capped = end - begin > int(longest * SR)
    x = x[begin : min(len(x), end, begin + int(longest * SR))].copy()
    lead = min(len(x), int(0.001 * SR))
    x[:lead] *= np.linspace(0, 1, lead)[:, None] if x.ndim == 2 else np.linspace(0, 1, lead)
    # A long ring is let go gently rather than cut; a short one just closes.
    tail = min(len(x) // 3, int((0.3 if capped else 0.008) * SR))
    curve = np.linspace(1, 0, tail) ** 2
    x[-tail:] *= curve[:, None] if x.ndim == 2 else curve
    return x


def sheet():
    rng = np.random.default_rng(2026)
    room = make_ir(0.9, 17)
    takes = {}

    def mono_takes(name, fn, count, db=-3.0, wet=0.0):
        out = []
        for i in range(count):
            x = fn(np.random.default_rng(1000 * len(takes) + i))
            st = pan(x, 0.0) * np.sqrt(2)
            if wet > 0:
                st = np.concatenate([st, np.zeros((int(0.9 * SR), 2))])
                st = reverb(st, room, wet)
            out.append(peak_norm(trim(st), db))
        takes[name] = out

    mono_takes("pickup", cue_pickup, 4)
    mono_takes("place", cue_place, 4)
    mono_takes("drop", cue_drop, 3)
    mono_takes("deal", cue_deal, 4)
    mono_takes("slide", cue_slide, 4)
    mono_takes("hover", cue_hover, 3)
    mono_takes("wrong", cue_wrong, 3, wet=0.08)
    mono_takes("streakLost", cue_streak_lost, 2, db=-6, wet=0.1)
    mono_takes("click", cue_click, 4)
    mono_takes("tick", cue_tick, 3, db=-6)
    mono_takes("chair", cue_chair, 3)
    mono_takes("door", cue_door, 2)
    mono_takes("low", cue_low, 2, wet=0.15)
    mono_takes("shimmer", cue_shimmer, 3, db=-5, wet=0.2)
    mono_takes("combo", lambda r: cue_arpeggio(r, ["C5", "E5", "G5", "B5", "D6"], 0.05, vel=0.7), 3, wet=0.18)
    mono_takes("reward", cue_reward, 2, wet=0.18)
    mono_takes("round", lambda r: cue_chord(r, ["Fmaj9"], 0, 0.03, top=[("C6", 0.12)]), 2, wet=0.2)
    mono_takes("complete", lambda r: cue_chord(r, ["Bbmaj9", "Fmaj9"], 0.42, 0.028, length=3.2, top=[("A5", 0.42), ("C6", 0.55)]), 2, wet=0.22)
    mono_takes("enter", cue_enter, 2, db=-4, wet=0.15)
    mono_takes("leave", cue_leave, 2, db=-5, wet=0.15)

    def chime_takes(name, fn, vels, wet=0.1):
        out = []
        for i, v in enumerate(vels):
            x = fn(np.random.default_rng(77 + i + 13 * len(takes)), v)
            st = x if x.ndim == 2 else pan(x, 0.0) * np.sqrt(2)
            st = np.concatenate([st, np.zeros((int(0.9 * SR), 2))])
            st = reverb(st, room, wet)
            out.append(peak_norm(trim(st), -3.0))
        takes[name] = out

    chime_takes("chime", cue_chime, [0.85, 0.95, 1.0])
    chime_takes("chime_harp", cue_harp, [0.9, 1.0])
    chime_takes("chime_musicBox", cue_musicbox, [0.9, 1.0])
    chime_takes("chime_celesta", cue_celesta, [0.9, 1.0])
    chime_takes("chime_glass", cue_glass, [0.9, 1.0])

    # Lay them end to end with a quarter second of silence between.
    gap = int(0.25 * SR)
    pieces, cues, cursor = [np.zeros((gap, 2))], {}, gap
    for name, xs in takes.items():
        cues[name] = []
        for x in xs:
            start = cursor
            pieces.append(x)
            cursor += len(x)
            cues[name].append((round(start / SR, 4), round(cursor / SR, 4)))
            pieces.append(np.zeros((gap, 2)))
            cursor += gap
    audio = np.concatenate(pieces)
    return audio, cues


def write_sheet_map(cues, length):
    lines = [
        "--!strict",
        "-- Where each sound sits in the house's sound sheet (assets/audio/maison-sounds.ogg), in seconds:",
        "-- { start, stop } for every take. Written by tools/audio/compose.py with the audio; regenerate",
        "-- them together, never edit this by hand.",
        "",
        "local SoundSheet = {}",
        "",
        f"SoundSheet.length = {length:.4f}",
        "SoundSheet.cues = {",
    ]
    for name, spans in cues.items():
        body = ", ".join(f"{{ {a:.4f}, {b:.4f} }}" for a, b in spans)
        key = name if name.isidentifier() else f'["{name}"]'
        lines.append(f"\t{key} = {{ {body} }},")
    lines += ["} :: { [string]: { { number } } }", "", "return SoundSheet", ""]
    with open(os.path.join(ROOT, "src", "shared", "SoundSheet.luau"), "w") as f:
        f.write("\n".join(lines))


def main(which):
    if "sheet" in which:
        audio, cues = sheet()
        path = write("maison-sounds.ogg", audio)
        write_sheet_map(cues, len(audio) / SR)
        print(f"{path}: {len(audio) / SR:.1f} s, {sum(len(v) for v in cues.values())} takes of {len(cues)} sounds")
    for name, fn in (("lounge", lounge_track), ("table", table_track), ("ballroom", ballroom_track)):
        if name in which:
            audio = fn()
            path = write(f"maison-{name}.ogg", audio)
            print(f"{path}: {len(audio) / SR:.1f} s")


if __name__ == "__main__":
    main(sys.argv[1:] or ["sheet", "lounge", "table", "ballroom"])
