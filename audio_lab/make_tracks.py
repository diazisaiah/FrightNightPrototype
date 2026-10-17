"""Placeholder soundtrack for Fright Night, synthesized with numpy: one
looping track per place. Each is 16 bars that loop seamlessly (the tails of
the last bar wrap into the first), mono 16-bit at 24 kHz.

  title   78 BPM, A minor     music box and choir over a slow heartbeat
  camp    72 BPM, E minor     lo-fi campfire: soft drums, warm keys, crackle
  arena  140 BPM, D minor     spooky phonk fight anthem: cowbell riff, sliding
                              808, four-on-the-floor, saw lead on the hook (32 bars)
  crypt   66 BPM, C# phrygian  drone, tolling bells, sparse heavy drums
  league 104 BPM, D minor     driving drums, choir stabs, big 808

Writes punch-craft/music/<name>.ogg (Ogg Vorbis, looped in game). Run: python audio_lab/make_tracks.py [name ...]
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 24000
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "punch-craft", "music")
rng = np.random.default_rng(13)
# ffmpeg for the Ogg encode (imageio-ffmpeg ships one; or set FFMPEG).
try:
    import imageio_ffmpeg
    FFMPEG = os.environ.get("FFMPEG") or imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    FFMPEG = os.environ.get("FFMPEG", "ffmpeg")

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


# --- More instruments (2026-10-17) ----------------------------------------------

def marimba(note, dur=0.5, level=0.2):
    """Wooden bone-xylophone: a sine with a bright knock, quick decay."""
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note)
    tone = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 30)
    return tone * np.exp(-t * 7) * np.minimum(1, t * 3000) * level


def pluck(note, dur=0.8, bright=0.5, level=0.25):
    """Karplus-Strong string: guitar twang (bright < 0.5) or harpsichord (high)."""
    n = int(dur * SR)
    period = max(2, int(SR / midi(note)))
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    blend = 0.5 + bright * 0.49
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = blend * buf[j] + (1 - blend) * buf[(j + 1) % period]
        buf[j] *= 0.996
    return out * np.minimum(1, np.maximum(dur - t_of(n), 0) * 30) * level


def theremin(note, dur, glide_from=None, level=0.1):
    """Ghostly sine lead with wide vibrato and a slide in."""
    n = int(dur * SR)
    t = t_of(n)
    f = np.full(n, midi(note))
    if glide_from is not None:
        f = midi(note) + (midi(glide_from) - midi(note)) * np.exp(-t * 9)
    f = f * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))
    env = np.minimum(1, t * 8) * np.minimum(1, np.maximum(dur - t, 0) * 6)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env * level


def brass(note, dur, level=0.07):
    """Brass stab: saw harmonics with a brightness swell."""
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note)
    out = np.zeros(n)
    bright = 1 + 9 * np.minimum(1, t * 12) * np.exp(-t * 2.5)
    for h in range(1, 14):
        out += np.sin(2 * np.pi * f * h * t) / h * np.minimum(1, bright / h)
    env = np.minimum(1, t * 60) * np.minimum(1, np.maximum(dur - t, 0) * 20)
    return out * env * level


def calliope(note, dur, level=0.07):
    """Fairground pipes: a breathy pulse wave."""
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note) * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t))
    phase = np.cumsum(f) / SR % 1.0
    tone = np.where(phase < 0.3, 1.0, -0.45) + fft_filter(rng.standard_normal(n), low=2000) * 0.08
    env = np.minimum(1, t * 40) * np.minimum(1, np.maximum(dur - t, 0) * 25)
    return tone * env * level


def tom(pitch=90, length=0.6, level=0.8):
    """Big drum (taiko / timpani-ish)."""
    n = int(length * SR)
    t = t_of(n)
    freq = pitch * (1 + 0.6 * np.exp(-t * 20))
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 5)
    hit = fft_filter(rng.standard_normal(n), high=2500) * np.exp(-t * 40) * 0.4
    return np.tanh((body + hit) * 1.5) * level


def strings(notes, dur, level=0.02):
    """Slow-attack saw strings."""
    n = int(dur * SR)
    t = t_of(n)
    out = np.zeros(n)
    for note in notes:
        for detune in (-0.07, 0.07):
            f = midi(note + detune)
            for h in range(1, 9):
                out += np.sin(2 * np.pi * f * h * t + h * 0.7) / h
    env = np.minimum(1, t / 0.5) * np.minimum(1, np.maximum(dur - t, 0) / 0.4)
    return out * env * level


def whistle(note, dur, level=0.08):
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note) * (1 + 0.006 * np.sin(2 * np.pi * 5 * t))
    breath = fft_filter(rng.standard_normal(n), low=2500, high=7000) * 0.05
    env = np.minimum(1, t * 30) * np.minimum(1, np.maximum(dur - t, 0) * 12)
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) + breath) * env * level


# --- Arena tracks for the deeper divisions -------------------------------------------

def _beat4(b, b0, K, S, hats=16, clap=None, kicks=(0, 1, 2, 3)):
    for beat in kicks:
        place(b["drums"], K, b0 + beat * BEAT)
    for beat in (1, 3):
        place(b["drums"], S, b0 + beat * BEAT)
        if clap is not None:
            place(b["drums"], clap, b0 + beat * BEAT)
    for i in range(hats):
        place(b["drums"], hat() * (0.6 if i % (hats // 4) == hats // 8 else 0.35), b0 + i * BAR / hats)


def arena_bone(b):
    # E phrygian bone-xylophone over driving drums (150 BPM, 24 bars).
    roots = [40, 41, 40, 38]
    riff = [[(0, 64), (0.5, 67), (1, 71), (1.5, 72), (2, 71), (2.5, 67), (3, 65), (3.5, 64)],
            [(0, 65), (0.5, 69), (1, 72), (1.5, 74), (2, 72), (2.5, 69), (3, 67), (3.5, 65)],
            [(0, 64), (0.25, 64), (0.5, 71), (1, 72), (1.5, 76), (2, 72), (3, 71), (3.5, 67)],
            [(0, 62), (0.5, 65), (1, 69), (1.5, 71), (2, 74), (2.5, 72), (3, 69), (3.5, 71)]]
    K, S = kick(1.2, 0.35), snare(220, 8000, 0.22)
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        brk = bar in (10, 11)
        for beat, note in riff[c]:
            place(b["keys"], marimba(note + (12 if 12 <= bar < 20 else 0), 0.45, 0.22), b0 + beat * BEAT)
        place(b["pads"], pad([roots[c] + 12, roots[c] + 19], BAR + 0.2, 0.012), b0)
        if bar < 2 or brk:
            if bar == 11:
                for i in range(8):
                    place(b["drums"], tom(120 + i * 12, 0.3, 0.45), b0 + (2 + i / 4) * BEAT)
            continue
        _beat4(b, b0, K, S, 8)
        for i in (1, 3):
            place(b["drums"], tom(70, 0.5, 0.5), b0 + (i + 0.5) * BEAT)
        r = roots[c]
        for beat in (0, 0.75, 1.5, 2.5, 3.25):
            place(b["low"], bass(r, BEAT * 0.5, drive=2.4), b0 + beat * BEAT)
    return {"keys": (0.5, 0.25, 1.6, 0.3), "pads": (2500, 2.0, 0.4), "mix": (1.0, 1.0, 1.1, 0.8, 0.05)}


def arena_ghost(b):
    # F# minor ghost-surf: tremolo twang guitar and a theremin over a shuffle (128 BPM, 24 bars).
    chords = [[54, 57, 61], [50, 54, 57], [52, 56, 59], [49, 53, 56]]
    roots = [42, 38, 40, 37]
    lead = [[(0, 78, 1.5), (1.5, 76, 0.5), (2, 73, 2)], [(0, 74, 2), (2, 73, 1), (3, 69, 1)],
            [(0, 76, 1), (1, 80, 1), (2, 83, 2)], [(0, 81, 3), (3, 77, 1)]]
    K, S = kick(1.0, 0.35), snare(190, 6000, 0.3)
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], choir(chords[c], BAR + 0.3, 0.02), b0)
        # The twang: tremolo-picked eighths on the chord.
        for i in range(8):
            note = chords[c][i % 3] + 12
            place(b["keys"], pluck(note, 0.25, 0.3, 0.12 if i % 2 else 0.16), b0 + i * BEAT / 2)
        if 8 <= bar < 16 or bar >= 20:
            for beat, note, length in lead[c]:
                place(b["keys"], theremin(note, length * BEAT, glide_from=note - 3), b0 + beat * BEAT)
        if bar < 2:
            continue
        for beat in (0, 1.5, 2, 3.5) if bar % 2 else (0, 2, 2.75):
            place(b["drums"], K, b0 + beat * BEAT)
        for beat in (1, 3):
            place(b["drums"], S, b0 + beat * BEAT)
        for i in range(8):
            place(b["drums"], hat() * (0.5 if i % 2 == 0 else 0.3), b0 + i * BEAT / 2 + (0.06 if i % 2 else 0))
        r = roots[c]
        place(b["low"], bass(r, BEAT * 1.5, drive=1.6), b0)
        place(b["low"], bass(r + 7, BEAT * 0.9, drive=1.6), b0 + 2 * BEAT)
        place(b["low"], bass(r + 5, BEAT * 0.9, drive=1.6), b0 + 3 * BEAT)
    return {"keys": (0.75, 0.35, 2.6, 0.4), "pads": (2200, 3.0, 0.5), "mix": (0.9, 1.0, 1.1, 0.9, 0.1)}


def arena_plague(b):
    # C minor sick carnival: calliope melody, oom-pah bass, swung hats and an 808 (120 BPM, 24 bars).
    roots = [36, 41, 43, 36]
    chords = [[60, 63, 67], [60, 65, 68], [59, 62, 67], [60, 63, 67]]
    mel = [[(0, 72), (0.5, 75), (1, 79), (2, 78), (2.5, 79), (3, 75)], [(0, 77), (0.5, 80), (1, 84), (2, 80), (3, 77)],
           [(0, 79), (0.5, 78), (1, 79), (1.5, 83), (2, 86), (3, 83)], [(0, 84), (1, 79), (2, 75), (3, 72)]]
    K, S = kick(1.1, 0.4), snare(200, 7000, 0.3)
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        for beat, note in mel[c]:
            place(b["keys"], calliope(note + (12 if bar >= 16 else 0), BEAT * 0.45), b0 + beat * BEAT)
        for beat in (1, 2, 3):
            place(b["pads"], calliope(chords[c][0] - 12, BEAT * 0.3, 0.035) + calliope(chords[c][1] - 12, BEAT * 0.3, 0.035), b0 + beat * BEAT)
        place(b["low"], bass(roots[c], BEAT * 0.8, drive=1.4), b0)
        place(b["low"], bass(roots[c] + 7, BEAT * 0.8, drive=1.4), b0 + 2 * BEAT)
        if bar < 4:
            continue
        place(b["drums"], K, b0)
        place(b["drums"], K * 0.8, b0 + 2.5 * BEAT)
        for beat in (1, 3):
            place(b["drums"], S, b0 + beat * BEAT)
        for i in range(12):
            place(b["drums"], hat() * (0.45 if i % 3 == 0 else 0.25), b0 + i * BEAT / 3)
        if bar % 4 == 3:
            place(b["low"], bass(roots[c], BEAT * 0.5, glide_from=roots[c] + 12, drive=2.4), b0 + 3.5 * BEAT)
    return {"keys": (0.75, 0.25, 1.8, 0.3), "pads": (2600, 1.6, 0.3), "mix": (0.95, 1.0, 1.1, 0.8, 0.25)}


def arena_crown(b):
    # D harmonic minor epic: brass stabs, toms, choir and a big beat (145 BPM, 24 bars).
    chords = [[62, 65, 69], [58, 62, 65], [55, 58, 62], [57, 61, 64]]
    roots = [38, 34, 31, 33]
    stabs = [(0, 1.0), (0.75, 0.7), (1.5, 0.8), (3, 0.9)]
    hook = [[(0, 74, 1), (1, 77, 1), (2, 81, 2)], [(0, 82, 2), (2, 81, 1), (3, 77, 1)],
            [(0, 79, 1), (1, 77, 1), (2, 74, 2)], [(0, 73, 2), (2, 76, 1), (3, 81, 1)]]
    K, S, C = kick(1.25, 0.35), snare(210, 8500, 0.25), clap()
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], choir(chords[c], BAR + 0.3, 0.03), b0)
        for beat, amp in stabs:
            for note in chords[c]:
                place(b["keys"], brass(note, BEAT * 0.45, 0.05 * amp), b0 + beat * BEAT)
        if bar >= 8:
            for beat, note, length in hook[c]:
                place(b["keys"], brass(note + 12, length * BEAT * 0.95, 0.06), b0 + beat * BEAT)
        brk = bar in (6, 7, 18, 19)
        for beat in (0, 2):
            place(b["drums"], tom(60, 0.8, 0.7), b0 + beat * BEAT)
        if brk:
            continue
        _beat4(b, b0, K, S, 16, C)
        r = roots[c]
        for beat in (0, 0.75, 1.5, 2, 2.75, 3.5):
            place(b["low"], bass(r, BEAT * 0.45, drive=2.6), b0 + beat * BEAT)
    return {"keys": (0.5, 0.2, 2.0, 0.3), "pads": (2400, 2.4, 0.45), "mix": (1.0, 1.0, 1.0, 0.85, 0.1)}


# --- Crypt tracks for the deeper tiers -----------------------------------------------

def crypt_bone(b):
    # 64 BPM: a low drone, bone chimes clattering, a slow heartbeat.
    K = kick(0.8, 0.6)
    for bar in range(16):
        b0 = bar * BAR
        place(b["pads"], pad([40, 47], BAR + 0.6, 0.022, 5), b0)
        for i in range(rng.integers(2, 6)):
            place(b["keys"], marimba(int(rng.choice([76, 79, 81, 83, 88, 91])), 0.6, 0.08), b0 + rng.random() * BAR)
        if bar >= 2:
            place(b["drums"], K * 0.8, b0)
            place(b["drums"], K * 0.5, b0 + 0.4 * BEAT)
            place(b["drums"], K * 0.7, b0 + 2 * BEAT)
            place(b["drums"], K * 0.45, b0 + 2.4 * BEAT)
        if bar % 4 == 2:
            place(b["keys"], bell(52, 3.5) * 0.7, b0 + BEAT)
        place(b["low"], bass(28, BAR * 0.9, drive=1.2) * 0.7, b0)
    return {"keys": (1.0, 0.45, 4.0, 0.6), "pads": (1500, 4.0, 0.6), "mix": (0.6, 0.85, 1.1, 1.2, 0.2)}


def crypt_ghost(b):
    # 60 BPM: dripping water, a choir breathing, a theremin wandering.
    chords = [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]]
    mel = [[(0, 76, 3)], [(1, 72, 2), (3, 74, 1)], [(0, 71, 2), (2, 74, 2)], [(0, 68, 4)]]
    for bar in range(16):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], choir(chords[c], BAR + 0.5, 0.024), b0)
        for i in range(rng.integers(3, 7)):
            drip_note = int(rng.choice([84, 86, 88, 91, 93]))
            place(b["keys"], music_box(drip_note, 0.4, 9.0, 0.05), b0 + rng.random() * BAR)
        if bar >= 4:
            for beat, note, length in mel[c]:
                place(b["keys"], theremin(note, length * BEAT, glide_from=note + 2, level=0.07), b0 + beat * BEAT)
        place(b["low"], bass(33, BAR * 0.9, drive=1.0) * 0.6, b0)
    return {"keys": (1.0, 0.5, 4.5, 0.65), "pads": (1800, 4.5, 0.65), "mix": (0.5, 0.8, 1.15, 1.2, 0.25)}


def crypt_plague(b):
    # 70 BPM in 3/4 (two waltz bars per 4/4 bar): a detuned music-box waltz over a sick drone.
    mel = [72, 75, 79, 78, 75, 72, 71, 74, 77, 75, 72, 68]
    for bar in range(16):
        b0 = bar * BAR
        place(b["pads"], pad([36, 43, 46], BAR + 0.6, 0.018, 5), b0)
        for w in range(2):
            w0 = b0 + w * 2 * BEAT
            step = (bar * 2 + w) % 4
            for k in range(3):
                note = mel[(step * 3 + k) % len(mel)]
                place(b["keys"], music_box(note + rng.uniform(-0.15, 0.15), 1.4, 2.6, 0.14), w0 + k * BEAT * 2 / 3)
            place(b["low"], bass(36 if step % 2 == 0 else 43, BEAT * 0.6, drive=1.0) * 0.6, w0)
        if bar >= 4 and bar % 2 == 1:
            place(b["drums"], rim() * 0.8, b0 + 3.5 * BEAT)
    return {"keys": (0.667, 0.4, 3.0, 0.5), "pads": (1600, 3.5, 0.55), "mix": (0.6, 0.8, 1.2, 1.1, 0.35)}


def crypt_crown(b):
    # 66 BPM: regal low strings, a harp arpeggio, bells tolling in the distance.
    chords = [[50, 57, 62, 65], [46, 53, 58, 62], [43, 50, 55, 58], [45, 52, 57, 61]]
    for bar in range(16):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], strings(chords[c], BAR + 0.4, 0.016), b0)
        for i in range(8):
            note = chords[c][i % 4] + 12 + (12 if i >= 4 else 0)
            place(b["keys"], pluck(note, 0.9, 0.85, 0.08), b0 + i * BEAT / 2)
        if bar % 2 == 0:
            place(b["keys"], bell(chords[c][0], 4.0) * 0.6, b0)
        if bar >= 8:
            place(b["drums"], tom(55, 1.0, 0.5), b0)
            place(b["drums"], tom(55, 1.0, 0.35), b0 + 2 * BEAT)
        place(b["low"], bass(chords[c][0] - 12, BAR * 0.9, drive=1.0) * 0.6, b0)
    return {"keys": (1.0, 0.35, 3.5, 0.5), "pads": (2200, 3.5, 0.5), "mix": (0.7, 0.8, 1.1, 1.2, 0.15)}


# --- Contender themes (Dead League) ----------------------------------------------------

def boss_bellman(b):
    # 118 BPM iron-bell doom: taiko toms, tolling bells, a crushing bass (24 bars).
    roots = [33, 33, 34, 31]
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        place(b["keys"], bell(57 if c != 2 else 58, 4.0) * 0.9, b0)
        if bar % 2 == 1:
            place(b["keys"], bell(64, 3.0) * 0.5, b0 + 2 * BEAT)
        place(b["pads"], pad([roots[c] + 24, roots[c] + 31], BAR + 0.3, 0.016), b0)
        if bar < 2:
            continue
        for beat, pitch in ((0, 55), (0.75, 70), (1.5, 55), (2, 85), (2.5, 55), (3, 70), (3.5, 100)):
            place(b["drums"], tom(pitch, 0.7, 0.75), b0 + beat * BEAT)
        for beat in (1, 3):
            place(b["drums"], snare(160, 4000, 0.4), b0 + beat * BEAT)
        r = roots[c]
        place(b["low"], bass(r, BEAT * 1.4, drive=3.0), b0)
        place(b["low"], bass(r, BEAT * 0.9, drive=3.0), b0 + 1.5 * BEAT)
        place(b["low"], bass(r + 1, BEAT * 0.9, drive=3.0), b0 + 2.5 * BEAT)
    return {"keys": (1.0, 0.3, 3.0, 0.45), "pads": (1800, 2.5, 0.45), "mix": (1.0, 1.0, 1.0, 0.8, 0.1)}


def boss_headless(b):
    # 160 BPM galloping horror-western: gallop drums, twang lead, a lonely whistle (24 bars).
    chords = [[52, 55, 59], [48, 52, 55], [50, 53, 57], [47, 50, 54]]
    roots = [40, 36, 38, 35]
    whistle_line = [[(0, 76, 2), (2, 79, 1), (3, 76, 1)], [(0, 72, 3), (3, 74, 1)],
                    [(0, 74, 2), (2, 77, 1), (3, 81, 1)], [(0, 83, 3), (3, 78, 1)]]
    K, S = kick(1.0, 0.3), snare(200, 6500, 0.22)
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], pad(chords[c], BAR + 0.3, 0.012), b0)
        # The gallop: da-da-DUM on every beat.
        for beat in range(4):
            place(b["drums"], tom(110, 0.2, 0.3), b0 + (beat - 1 / 3) * BEAT)
            place(b["drums"], tom(110, 0.2, 0.3), b0 + (beat - 1 / 6) * BEAT)
            place(b["drums"], K, b0 + beat * BEAT)
        if bar >= 2:
            for beat in (1, 3):
                place(b["drums"], S, b0 + beat * BEAT)
        for i in range(4):
            place(b["keys"], pluck(chords[c][i % 3] + 12, 0.4, 0.35, 0.14), b0 + i * BEAT)
        if 4 <= bar < 12 or bar >= 16:
            for beat, note, length in whistle_line[c]:
                place(b["keys"], whistle(note + 12, length * BEAT * 0.95), b0 + beat * BEAT)
        r = roots[c]
        place(b["low"], bass(r, BEAT * 0.8, drive=1.8), b0)
        place(b["low"], bass(r + 7, BEAT * 0.8, drive=1.8), b0 + 2 * BEAT)
    return {"keys": (0.75, 0.35, 2.8, 0.45), "pads": (2000, 3.0, 0.5), "mix": (0.95, 0.9, 1.1, 0.8, 0.1)}


def boss_southpaw(b):
    # 140 BPM gothic drill: harpsichord arpeggios, sliding 808, drill hats, choir (24 bars).
    chords = [[57, 60, 64], [53, 57, 60], [52, 56, 59], [57, 60, 64]]
    roots = [33, 29, 28, 33]
    K, S = kick(1.2, 0.4), snare(230, 9000, 0.25)
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], choir(chords[c], BAR + 0.3, 0.022), b0)
        for i in range(12):
            note = chords[c][[0, 1, 2, 1][i % 4]] + 12 + (12 if i >= 8 else 0)
            place(b["keys"], pluck(note, 0.35, 0.9, 0.1), b0 + i * BEAT / 3)
        if bar < 2:
            continue
        # Drill: kick on 1 and the "and" of 2, snare on 3, sliding hat triplets.
        place(b["drums"], K, b0)
        place(b["drums"], K, b0 + 1.5 * BEAT)
        place(b["drums"], S, b0 + 2 * BEAT)
        if bar % 2:
            place(b["drums"], K * 0.8, b0 + 3.25 * BEAT)
        for i in range(12):
            if rng.random() < 0.85:
                place(b["drums"], hat() * (0.45 if i % 3 == 0 else 0.28), b0 + i * BEAT / 3)
        r = roots[c]
        place(b["low"], bass(r, BEAT * 1.2, drive=2.6), b0)
        place(b["low"], bass(r + 12, BEAT * 0.8, glide_from=r, drive=2.6), b0 + 1.5 * BEAT)
        place(b["low"], bass(r + 3, BEAT * 0.8, glide_from=r + 12, drive=2.6), b0 + 3 * BEAT)
    return {"keys": (0.667, 0.3, 2.2, 0.35), "pads": (2200, 2.6, 0.45), "mix": (1.0, 1.0, 1.0, 0.85, 0.1)}


def boss_plague_doctor(b):
    # 96 BPM carnival waltz-trap: calliope and pizzicato in 6/8 over an 808 (24 bars).
    chords = [[57, 60, 64], [52, 56, 59], [53, 57, 60], [52, 56, 59]]
    roots = [33, 28, 29, 28]
    mel = [[(0, 76), (0.67, 77), (1.33, 76), (2, 72), (3, 69)], [(0, 71), (0.67, 72), (1.33, 71), (2, 68), (3, 64)],
           [(0, 72), (0.67, 74), (1.33, 76), (2, 77), (3, 81)], [(0, 80), (1, 76), (2, 71), (3, 68)]]
    K, S = kick(1.15, 0.4), snare(190, 7000, 0.3)
    for bar in range(24):
        b0 = bar * BAR
        c = bar % 4
        for i in range(6):
            place(b["keys"], pluck(chords[c][i % 3] + 12, 0.2, 0.6, 0.12), b0 + i * BEAT * 2 / 3)
        if bar >= 4:
            for beat, note in mel[c]:
                place(b["keys"], calliope(note, BEAT * 0.6, 0.06), b0 + beat * BEAT)
        place(b["pads"], pad(chords[c], BAR + 0.3, 0.012), b0)
        if bar < 2:
            continue
        place(b["drums"], K, b0)
        place(b["drums"], K * 0.8, b0 + 2 * BEAT * 2 / 3 * 2)
        place(b["drums"], S, b0 + 2 * BEAT)
        for i in range(6):
            place(b["drums"], hat() * (0.45 if i % 3 == 0 else 0.25), b0 + i * BEAT * 2 / 3)
        if bar % 4 == 3:
            for i in range(6):
                place(b["drums"], S * (0.3 + i * 0.1), b0 + (2 + i / 3) * BEAT)
        r = roots[c]
        place(b["low"], bass(r, BEAT * 1.3, drive=2.4), b0)
        place(b["low"], bass(r, BEAT * 0.8, glide_from=r + 12, drive=2.4), b0 + 2.67 * BEAT)
    return {"keys": (0.667, 0.3, 2.4, 0.4), "pads": (2000, 2.6, 0.45), "mix": (0.95, 1.0, 1.1, 0.8, 0.25)}


def boss_coffin_king(b):
    # 132 BPM epic finale: string ostinato, brass, choir, timpani, a big beat (32 bars).
    chords = [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]]
    roots = [38, 34, 36, 33]
    hook = [[(0, 74, 1.5), (1.5, 77, 0.5), (2, 81, 2)], [(0, 82, 1.5), (1.5, 81, 0.5), (2, 77, 2)],
            [(0, 79, 1), (1, 84, 1), (2, 83, 1), (3, 79, 1)], [(0, 81, 2), (2, 85, 2)]]
    K, S, C = kick(1.3, 0.35), snare(220, 9000, 0.25), clap()
    for bar in range(32):
        b0 = bar * BAR
        c = bar % 4
        place(b["pads"], choir(chords[c] + [chords[c][0] + 12], BAR + 0.3, 0.03), b0)
        # The ostinato: driving sixteenths on the root and fifth.
        for i in range(16):
            note = chords[c][0] + (7 if i % 4 == 2 else 0) + 12
            place(b["keys"], pluck(note, 0.18, 0.7, 0.07), b0 + i * BEAT / 4)
        if bar >= 8 and not (16 <= bar < 20):
            for beat, note, length in hook[c]:
                place(b["keys"], brass(note, length * BEAT * 0.95, 0.07), b0 + beat * BEAT)
                place(b["keys"], brass(note - 12, length * BEAT * 0.95, 0.05), b0 + beat * BEAT)
        for beat in (0, 2):
            place(b["drums"], tom(55, 0.9, 0.75), b0 + beat * BEAT)
        if bar < 4 or 16 <= bar < 18:
            if bar in (3, 17):
                for i in range(8):
                    place(b["drums"], tom(70 + i * 8, 0.3, 0.5), b0 + (2 + i / 4) * BEAT)
            continue
        _beat4(b, b0, K, S, 16, C)
        r = roots[c]
        for beat in (0, 0.75, 1.5, 2, 2.75, 3.5):
            place(b["low"], bass(r, BEAT * 0.45, drive=2.6), b0 + beat * BEAT)
    return {"keys": (0.5, 0.2, 2.2, 0.35), "pads": (2500, 2.6, 0.5), "mix": (1.0, 1.0, 1.0, 0.9, 0.05)}


TRACKS = {
    "title": (78, title), "camp": (72, camp), "arena": (140, arena), "crypt": (66, crypt), "league": (104, league),
    "arena_bone": (150, arena_bone), "arena_ghost": (128, arena_ghost), "arena_plague": (120, arena_plague),
    "arena_crown": (145, arena_crown),
    "crypt_bone": (64, crypt_bone), "crypt_ghost": (60, crypt_ghost), "crypt_plague": (70, crypt_plague),
    "crypt_crown": (66, crypt_crown),
    "boss_bellman": (118, boss_bellman), "boss_headless": (160, boss_headless), "boss_southpaw": (140, boss_southpaw),
    "boss_plague_doctor": (96, boss_plague_doctor), "boss_coffin_king": (132, boss_coffin_king),
}
## Bars per loop (16 unless listed).
BARS = {"arena": 32, "arena_bone": 24, "arena_ghost": 24, "arena_plague": 24, "arena_crown": 24,
        "boss_bellman": 24, "boss_headless": 24, "boss_southpaw": 24, "boss_plague_doctor": 24, "boss_coffin_king": 32}


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
    wav = os.path.join(OUT_DIR, name + ".tmp.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    # Ogg Vorbis keeps the web build small (the game loops it, Sfx.play_music).
    path = os.path.join(OUT_DIR, name + ".ogg")
    subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.remove(wav)
    rms = 20 * np.log10(np.sqrt(np.mean(mix ** 2)))
    print(f"{name:18s} {N / SR:5.1f}s  {os.path.getsize(path) / 1e6:.2f} MB  rms {rms:.1f} dB")


for name in (sys.argv[1:] or TRACKS):
    render(name)
