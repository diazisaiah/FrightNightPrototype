"""Placeholder soundtrack for Fright Night, synthesized with numpy: one
looping track per place. Each is 16 bars that loop seamlessly (the tails of
the last bar wrap into the first), mono 16-bit at 24 kHz.

  title   78 BPM, A minor     music box and choir over a slow heartbeat
  camp    72 BPM, E minor     lo-fi campfire: soft drums, warm keys, crackle
  arena  140 BPM, D minor     spooky phonk fight anthem: cowbell riff, sliding
                              808, four-on-the-floor, saw lead on the hook (32 bars)
  crypt   66 BPM, C# phrygian  drone, tolling bells, sparse heavy drums
  league 104 BPM, D minor     driving drums, choir stabs, big 808

Writes punch-craft/music/<name>.wav. Run: python audio_lab/make_tracks.py [name ...]
"""
import os
import sys
import wave

import numpy as np

SR = 24000
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "punch-craft", "music")
rng = np.random.default_rng(13)

# Set per track by render().
BEAT = BAR = 0.0
N = 0


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def t_of(n):
    return np.arange(n) / SR


def place(buf, sound, at):
    """Adds sound at time `at`, wrapping past the end so the loop is seamless."""
    start = int(at * SR) % N
    end = start + len(sound)
    if end <= N:
        buf[start:end] += sound
    else:
        cut = N - start
        buf[start:] += sound[:cut]
        rest = sound[cut:]
        buf[: len(rest)] += rest[:N]


def onepole_lp(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def fft_filter(x, low=None, high=None):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.ones_like(f)
    if high:
        gain *= 1 / np.sqrt(1 + (f / high) ** 4)
    if low:
        gain *= 1 / np.sqrt(1 + (low / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(spec * gain, len(x))


def reverb(x, seconds=2.2, mix=0.3, tone=3500):
    """Circular convolution with a decaying noise tail (loops cleanly)."""
    n = min(int(seconds * SR), N)
    ir = rng.standard_normal(n) * np.exp(-6.9 * t_of(n) / seconds)
    ir = fft_filter(ir, high=tone)
    ir /= np.sqrt(np.sum(ir ** 2))
    pad = np.zeros(N)
    pad[:n] = ir
    wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(pad), N)
    return x * (1 - mix) + wet * mix * 1.6


def delay(x, time, feedback=0.4, mix=0.35):
    out = x.copy()
    shift = int(time * SR)
    echo = x.copy()
    for _ in range(6):
        echo = np.roll(echo, shift) * feedback
        out += echo * mix / feedback
    return out


# --- Instruments -------------------------------------------------------------

def kick(punch=1.0, length=0.45):
    n = int(length * SR)
    t = t_of(n)
    freq = 45 + 110 * punch * np.exp(-t * 28)
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 7)
    click = rng.standard_normal(n) * np.exp(-t * 300) * 0.3
    return np.tanh((body + click) * 1.8) * 0.9


def snare(tone=185, bright=7000, length=0.35):
    n = int(length * SR)
    t = t_of(n)
    noise = fft_filter(rng.standard_normal(n), low=900, high=bright) * np.exp(-t * 16)
    body = np.sin(2 * np.pi * tone * t) * np.exp(-t * 30)
    return (noise * 0.75 + body * 0.5) * 0.8


def rim():
    n = int(0.08 * SR)
    t = t_of(n)
    return (np.sin(2 * np.pi * 820 * t) + fft_filter(rng.standard_normal(n), low=2000) * 0.4) * np.exp(-t * 60) * 0.35


def hat(open_=False):
    n = int((0.3 if open_ else 0.06) * SR)
    t = t_of(n)
    return fft_filter(rng.standard_normal(n), low=6500) * np.exp(-t * (12 if open_ else 70)) * 0.25


def bass(note, dur, glide_from=None, drive=1.6):
    n = int(dur * SR)
    t = t_of(n)
    f = np.full(n, midi(note))
    if glide_from is not None:
        f = midi(note) + (midi(glide_from) - midi(note)) * np.exp(-t * 18)
    env = np.minimum(1, t * 200) * np.exp(-t * 0.9)
    env[-200:] *= np.linspace(1, 0, 200)
    return np.tanh(np.sin(2 * np.pi * np.cumsum(f) / SR) * drive) * env * 0.55


def music_box(note, dur=1.6, decay=2.6, level=0.22):
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note)
    wobble = 1 + 0.003 * np.sin(2 * np.pi * 5 * t)
    tone = (np.sin(2 * np.pi * f * t * wobble) + 0.35 * np.sin(2 * np.pi * f * 4.02 * t) * np.exp(-t * 6)
            + 0.15 * np.sin(2 * np.pi * f * 6.9 * t) * np.exp(-t * 12))
    return tone * np.exp(-t * decay) * np.minimum(1, t * 800) * level


def bell(note, dur=4.0):
    """A low tolling bell: inharmonic partials, long decay."""
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note)
    out = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 0.7), (2.0, 0.5, 1.0), (2.76, 0.4, 1.4), (5.4, 0.25, 2.5), (0.5, 0.35, 0.5)):
        out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * dec)
    return out * np.minimum(1, t * 400) * 0.16


def keys_chord(notes, dur, level=0.05):
    """Warm electric-piano-ish chord for the lo-fi camp."""
    n = int(dur * SR)
    t = t_of(n)
    out = np.zeros(n)
    for note in notes:
        f = midi(note)
        out += (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 3)) * np.exp(-t * 0.8)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * t)
    return out * trem * np.minimum(1, t * 300) * level


def pad(notes, dur, level=0.018, harmonics=7):
    n = int(dur * SR)
    t = t_of(n)
    out = np.zeros(n)
    for note in notes:
        for detune in (-0.12, 0.0, 0.11):
            f = midi(note + detune)
            for h in range(1, harmonics):
                out += np.sin(2 * np.pi * f * h * t + h) / h * 0.5
    env = np.minimum(1, t / 0.8) * np.minimum(1, np.maximum(dur - t, 0) / 0.8)
    trem = 1 + 0.15 * np.sin(2 * np.pi * 0.25 * t)
    return out * env * trem * level


def choir(notes, dur, level=0.03):
    """Breathy 'ooh': a filtered pad with vibrato."""
    n = int(dur * SR)
    t = t_of(n)
    out = np.zeros(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    for note in notes:
        f = midi(note)
        for h, a in ((1, 1.0), (2, 0.45), (3, 0.25), (4, 0.12)):
            out += a * np.sin(2 * np.pi * f * h * t * vib)
    env = np.minimum(1, t / 0.35) * np.minimum(1, np.maximum(dur - t, 0) / 0.4)
    return out * env * level


def cowbell(note, dur=0.3, level=0.2):
    """Phonk cowbell: two square-ish partials, band-limited, quick decay."""
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note)
    tone = np.tanh(3 * np.sin(2 * np.pi * f * t)) + 0.7 * np.tanh(3 * np.sin(2 * np.pi * f * 1.48 * t))
    tone = fft_filter(tone, low=350, high=5000)
    return tone * np.exp(-t * 11) * np.minimum(1, t * 2000) * level


def saw_lead(note, dur, level=0.06):
    """Detuned saw lead, a little bright, for the hook."""
    n = int(dur * SR)
    t = t_of(n)
    out = np.zeros(n)
    for detune in (-0.08, 0.08):
        f = midi(note + detune)
        for h in range(1, 14):
            out += np.sin(2 * np.pi * f * h * t) / h
    env = np.minimum(1, t * 150) * (0.55 + 0.45 * np.exp(-t * 4)) * np.minimum(1, np.maximum(dur - t, 0) * 40)
    return out * env * level


def clap(level=0.7):
    n = int(0.3 * SR)
    t = t_of(n)
    noise = fft_filter(rng.standard_normal(n), low=1000, high=7000)
    env = np.exp(-t * 22)
    for k in (0.0, 0.011, 0.022):
        env += np.where(t >= k, np.exp(-(t - k) * 140), 0) * 0.8
    return noise * env * level * 0.5


def crackle(amount=0.0006, hiss=0.006):
    out = np.zeros(N)
    pops = rng.random(N) < amount
    out[pops] = rng.standard_normal(pops.sum()) * 0.5
    return fft_filter(out, low=800) + fft_filter(rng.standard_normal(N), low=3000, high=9000) * hiss


# --- Tracks ------------------------------------------------------------------

def arena(b):
    # Dm  Bb  Gm  A: a spooky phonk fight anthem, 32 bars.
    # 0-3 intro (cowbell + kick), 4-11 groove, 12-13 break and snare roll,
    # 14-23 full with the saw hook from 16, 24-27 groove, 28-29 break, 30-31 full.
    chords = [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]]
    roots = [38, 34, 31, 33]
    riff_a = [[(0, 74), (0.75, 74), (1.5, 77), (2, 74), (2.75, 72), (3.5, 69)],
              [(0, 74), (0.75, 74), (1.5, 77), (2, 74), (2.75, 70), (3.5, 69)],
              [(0, 74), (0.75, 74), (1.5, 79), (2, 77), (2.75, 74), (3.5, 70)],
              [(0, 73), (0.75, 73), (1.5, 76), (2, 73), (2.75, 69), (3.5, 73)]]
    riff_b = [[(0, 81), (0.5, 81), (0.75, 77), (1.5, 81), (2, 84), (2.5, 81), (3, 77), (3.5, 74)],
              [(0, 82), (0.5, 82), (0.75, 77), (1.5, 82), (2, 81), (2.5, 77), (3, 74), (3.5, 77)],
              [(0, 79), (0.5, 79), (0.75, 74), (1.5, 79), (2, 82), (2.5, 79), (3, 77), (3.5, 74)],
              [(0, 81), (0.5, 81), (0.75, 76), (1.5, 81), (2, 85), (2.5, 81), (3, 76), (3.5, 73)]]
    hook = [[(0, 74, 1.5), (1.5, 77, 0.5), (2, 81, 2.0)], [(0, 82, 1.5), (1.5, 81, 0.5), (2, 77, 2.0)],
            [(0, 79, 1.0), (1, 82, 1.0), (2, 86, 1.5), (3.5, 84, 0.5)], [(0, 85, 2.0), (2, 81, 1.0), (3, 76, 1.0)]]
    K, S, C = kick(1.25, 0.35), snare(210, 8500, 0.25), clap()
    for bar in range(32):
        b0 = bar * BAR
        c = bar % 4
        intro = bar < 4
        brk = bar in (12, 13, 28, 29)
        hooked = 16 <= bar < 24 or bar >= 30
        place(b["pads"], pad(chords[c], BAR + 0.3, 0.012 if not brk else 0.02), b0)
        for beat, note in (riff_b if 16 <= bar < 24 else riff_a)[c]:
            place(b["keys"], cowbell(note, 0.3, 0.2 if not brk else 0.26), b0 + beat * BEAT)
        if hooked:
            for beat, note, length in hook[c]:
                place(b["keys"], saw_lead(note, length * BEAT), b0 + beat * BEAT)
        if brk:
            if bar in (13, 29):
                # The snare roll into the drop, rising.
                for i in range(16):
                    place(b["drums"], S * (0.25 + i * 0.045), b0 + i * BEAT / 4)
            continue
        if intro:
            for beat in (0, 2):
                place(b["drums"], K, b0 + beat * BEAT)
            for i in range(8):
                place(b["drums"], hat() * (0.5 if i % 2 else 0.3), b0 + i * BEAT / 2)
            continue
        for beat in range(4):
            place(b["drums"], K, b0 + beat * BEAT)
            place(b["drums"], hat(True) * 0.45, b0 + (beat + 0.5) * BEAT)
        for beat in (1, 3):
            place(b["drums"], C, b0 + beat * BEAT)
            place(b["drums"], S * 0.45, b0 + beat * BEAT)
        for i in range(16):
            roll = bar % 4 == 3 and i >= 12
            place(b["drums"], hat() * (0.7 if i % 4 == 2 else 0.4), b0 + i * BEAT / 4)
            if roll:
                place(b["drums"], hat() * 0.5, b0 + (i + 0.5) * BEAT / 4)
        if bar in (11, 27, 31):
            for i in range(8):
                place(b["drums"], S * (0.35 + i * 0.07), b0 + (2 + i / 4) * BEAT)
        r = roots[c]
        place(b["low"], bass(r, BEAT * 0.7, drive=2.6), b0)
        place(b["low"], bass(r, BEAT * 0.45, drive=2.6), b0 + 0.75 * BEAT)
        place(b["low"], bass(r + 12, BEAT * 0.5, glide_from=r, drive=2.6), b0 + 1.5 * BEAT)
        place(b["low"], bass(r, BEAT * 0.7, drive=2.6), b0 + 2 * BEAT)
        place(b["low"], bass(r + 7 if c != 3 else r + 4, BEAT * 0.45, drive=2.6), b0 + 2.75 * BEAT)
        place(b["low"], bass(r, BEAT * 0.5, glide_from=r + 12, drive=2.6), b0 + 3.5 * BEAT)
    return {"keys": (0.75, 0.25, 1.4, 0.22), "pads": (2200, 2.0, 0.4), "mix": (1.0, 1.05, 1.0, 0.9, 0.1)}


def title(b):
    # Am  F  Dm  E (the E major is the shiver).
    chords = [[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59]]
    roots = [33, 29, 26, 28]
    mel = [[(0, 76), (1, 72), (2, 69), (3, 71)], [(0, 72), (1.5, 69), (3, 65)],
           [(0, 74), (1, 77), (2, 74), (3, 72)], [(0, 71), (1, 68), (2, 71), (3, 76)]]
    mel_hi = [[(0, 81), (2, 79), (3, 76)], [(0, 77), (1, 76), (2, 72)], [(0, 74), (2, 77), (3, 81)], [(0, 80), (2, 76), (3.5, 71)]]
    K = kick(0.7, 0.6)
    for bar in range(16):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], choir(chords[c], BAR + 0.5, 0.028), b0)
        place(b["pads"], pad([chords[c][0] - 12], BAR + 0.4, 0.014), b0)
        for beat, note in (mel_hi if bar >= 8 else mel)[c]:
            place(b["keys"], music_box(note, 2.2, 1.8), b0 + beat * BEAT)
        # A slow heartbeat: two soft kicks.
        if bar >= 4:
            place(b["drums"], K * 0.8, b0)
            place(b["drums"], K * 0.5, b0 + 0.45 * BEAT)
            place(b["drums"], K * 0.7, b0 + 2 * BEAT)
            place(b["drums"], K * 0.45, b0 + 2.45 * BEAT)
        if bar >= 8:
            place(b["drums"], rim(), b0 + 3.5 * BEAT)
        place(b["low"], bass(roots[c], BAR * 0.95, drive=1.1) * 0.8, b0)
    return {"keys": (1.0, 0.45, 3.2, 0.55), "pads": (2200, 3.5, 0.55), "mix": (0.6, 0.6, 1.25, 1.2, 0.35)}


def camp(b):
    # Em9  Cmaj7  Am7  B7 (lo-fi campfire).
    chords = [[52, 55, 59, 66], [48, 52, 55, 59], [45, 48, 52, 55], [47, 51, 54, 57]]
    roots = [28, 24, 33, 35]
    mel = [[(0.5, 71), (2, 74), (3, 71)], [(0, 72), (1.5, 76)], [(0.5, 69), (2, 72), (3, 76)], [(0, 75), (2, 71)]]
    K, S = kick(0.8, 0.4), snare(160, 4500, 0.3)
    for bar in range(16):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], keys_chord(chords[c], BAR + 0.3), b0)
        if bar % 2 == 1 or bar >= 8:
            for beat, note in mel[c]:
                place(b["keys"], music_box(note, 1.8, 2.2, 0.17), b0 + beat * BEAT)
        if bar >= 1:
            for beat in ([0, 2.5] if bar % 2 else [0, 1.75, 2.5]):
                place(b["drums"], K * 0.8, b0 + beat * BEAT)
            for beat in (1, 3):
                place(b["drums"], S * 0.55, b0 + beat * BEAT + 0.02)
            for i in range(8):
                place(b["drums"], hat() * (0.55 if i % 2 == 0 else 0.3), b0 + i * BEAT / 2 + (0.05 if i % 2 else 0))
        place(b["low"], bass(roots[c] + 12, BEAT * 1.8, drive=1.0) * 0.7, b0)
        place(b["low"], bass(roots[c] + 12, BEAT * 0.9, drive=1.0) * 0.55, b0 + 2.5 * BEAT)
    return {"keys": (0.5, 0.3, 2.0, 0.35), "pads": (2600, 2.0, 0.35), "mix": (0.55, 0.75, 1.1, 1.3, 1.1)}


def crypt(b):
    # C# phrygian: a drone on C#, with D and B pulling at it.
    chords = [[49, 52, 56], [50, 53, 57], [49, 52, 56], [47, 50, 54]]
    K = kick(1.1, 0.7)
    S = snare(140, 3000, 0.6)
    for bar in range(16):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], pad(chords[c], BAR + 0.6, 0.02, 5), b0)
        place(b["pads"], pad([37], BAR + 0.6, 0.03, 4), b0)  # the drone
        # Bells toll on the one, a fifth answers on the three every other bar.
        place(b["keys"], bell(61 if c != 3 else 59), b0)
        if bar % 2 == 1:
            place(b["keys"], bell(68, 3.0) * 0.6, b0 + 2 * BEAT)
        if bar >= 8 and bar % 4 in (1, 3):
            for beat, note in ((0.5, 73), (1.5, 74), (2.5, 73), (3.25, 71)):
                place(b["keys"], music_box(note, 1.6, 2.0, 0.12), b0 + beat * BEAT)
        if bar >= 4:
            place(b["drums"], K, b0)
            place(b["drums"], K * 0.7, b0 + 2.5 * BEAT)
            place(b["drums"], S * 0.7, b0 + 2 * BEAT)
            if bar % 4 == 3:
                place(b["drums"], S * 0.45, b0 + 3.5 * BEAT)
            for i in range(4):
                place(b["drums"], hat() * 0.35, b0 + (i + 0.5) * BEAT)
        place(b["low"], bass(25, BAR * 0.9, drive=1.4) * 0.8, b0)
    return {"keys": (1.0, 0.3, 4.0, 0.6), "pads": (1400, 4.0, 0.6), "mix": (0.75, 0.9, 1.1, 1.2, 0.25)}


def league(b):
    # Dm  Bb  C  A, driving.
    chords = [[62, 65, 69], [58, 62, 65], [60, 64, 67], [61, 64, 69]]
    roots = [38, 34, 36, 33]
    stabs = [(0, 1), (0.75, 0.6), (2.5, 0.8)]
    mel = [[(0, 74), (0.5, 77), (1, 81), (2, 79), (3, 77)], [(0, 74), (1, 70), (2, 74), (3, 77)],
           [(0, 76), (0.5, 79), (1, 84), (2, 81), (3, 79)], [(0, 81), (1, 76), (2, 73), (3, 76)]]
    K, S = kick(1.2, 0.4), snare(200, 8000, 0.3)
    for bar in range(16):
        b0 = bar * BAR
        c = bar % 4
        for beat, amp in stabs:
            place(b["pads"], choir(chords[c], BEAT * 0.6, 0.04 * amp), b0 + beat * BEAT)
        place(b["pads"], pad([chords[c][0] - 12], BAR + 0.2, 0.012), b0)
        if bar >= 4:
            for beat, note in mel[c]:
                place(b["keys"], music_box(note, 1.0, 3.5, 0.2), b0 + beat * BEAT)
        brk = bar in (12, 13)
        for beat in ([0, 0.75, 1.5, 2.5, 3.25] if not brk else [0, 2]):
            place(b["drums"], K, b0 + beat * BEAT)
        for beat in (1, 3):
            place(b["drums"], S, b0 + beat * BEAT)
        for i in range(16):
            place(b["drums"], hat(i == 15 and bar % 2 == 1) * (0.8 if i % 4 == 2 else 0.45), b0 + i * BEAT / 4)
        if bar == 15:
            for i in range(8):
                place(b["drums"], S * (0.3 + i * 0.08), b0 + (2 + i / 4) * BEAT)
        if not brk:
            r = roots[c]
            place(b["low"], bass(r, BEAT * 0.9, drive=2.2), b0)
            place(b["low"], bass(r, BEAT * 0.6, glide_from=r + 12, drive=2.2), b0 + 1.5 * BEAT)
            place(b["low"], bass(r + 12, BEAT * 0.4, drive=2.2), b0 + 2.5 * BEAT)
            place(b["low"], bass(r, BEAT * 0.6, drive=2.2), b0 + 3 * BEAT)
    return {"keys": (0.5, 0.3, 1.6, 0.3), "pads": (3000, 1.8, 0.3), "mix": (0.85, 1.0, 0.9, 1.0, 0.2)}


TRACKS = {"title": (78, title), "camp": (72, camp), "arena": (140, arena), "crypt": (66, crypt), "league": (104, league)}
## Bars per loop (16 unless listed).
BARS = {"arena": 32}


def render(name):
    global BEAT, BAR, N
    bpm, song = TRACKS[name]
    BEAT = 60.0 / bpm
    BAR = BEAT * 4
    N = int(BAR * BARS.get(name, 16) * SR)
    b = {k: np.zeros(N) for k in ("drums", "low", "keys", "pads")}
    fx = song(b)
    d_beats, fb, verb, verb_mix = fx["keys"]
    keys = delay(b["keys"], BEAT * d_beats, feedback=fb, mix=0.4)
    keys = reverb(keys, verb, verb_mix)
    pad_tone, pad_verb, pad_mix = fx["pads"]
    pads = reverb(fft_filter(b["pads"], high=pad_tone), pad_verb, pad_mix)
    drums = reverb(b["drums"], 1.0, 0.12, tone=5000)
    low = onepole_lp(b["low"], 220)
    md, ml, mk, mp, mc = fx["mix"]
    mix = drums * md + low * ml + keys * mk + pads * mp + crackle() * mc
    mix = np.tanh(mix * 1.1) / 1.1
    mix = mix / np.max(np.abs(mix)) * 0.89
    pcm = (mix * 32767).astype(np.int16)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    rms = 20 * np.log10(np.sqrt(np.mean(mix ** 2)))
    print(f"{name:7s} {N / SR:5.1f}s  {os.path.getsize(path) / 1e6:.1f} MB  rms {rms:.1f} dB")


for name in (sys.argv[1:] or TRACKS):
    render(name)
