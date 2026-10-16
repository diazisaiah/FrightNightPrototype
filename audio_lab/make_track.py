"""Placeholder spooky boom-bap loop for Fright Night, synthesized with numpy.
90 BPM, D minor (harmonic), 16 bars that loop seamlessly.
Writes punch-craft/music/placeholder_spooky.wav (mono 16-bit).
Run: python audio_lab/make_track.py"""
import os
import wave

import numpy as np

SR = 32000
BPM = 90
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 16
LENGTH = BAR * BARS
N = int(LENGTH * SR)
rng = np.random.default_rng(13)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "punch-craft", "music", "placeholder_spooky.wav")


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
        buf[: end - N] += sound[cut:]


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
    n = int(seconds * SR)
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

def kick():
    n = int(0.45 * SR)
    t = t_of(n)
    freq = 45 + 110 * np.exp(-t * 28)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t * 7)
    click = rng.standard_normal(n) * np.exp(-t * 300) * 0.3
    return np.tanh((body + click) * 1.8) * 0.9


def snare():
    n = int(0.35 * SR)
    t = t_of(n)
    noise = fft_filter(rng.standard_normal(n), low=900, high=7000) * np.exp(-t * 16)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30)
    return (noise * 0.75 + tone * 0.5) * 0.8


def hat(open_=False):
    n = int((0.3 if open_ else 0.06) * SR)
    t = t_of(n)
    noise = fft_filter(rng.standard_normal(n), low=6500)
    return noise * np.exp(-t * (12 if open_ else 70)) * 0.25


def bass(note, dur, glide_from=None):
    n = int(dur * SR)
    t = t_of(n)
    f = np.full(n, midi(note))
    if glide_from is not None:
        f = midi(note) + (midi(glide_from) - midi(note)) * np.exp(-t * 18)
    phase = 2 * np.pi * np.cumsum(f) / SR
    env = np.minimum(1, t * 200) * np.exp(-t * 0.9)
    env[-200:] *= np.linspace(1, 0, 200)
    return np.tanh(np.sin(phase) * 1.6) * env * 0.55


def music_box(note, dur=1.6):
    n = int(dur * SR)
    t = t_of(n)
    f = midi(note)
    wobble = 1 + 0.003 * np.sin(2 * np.pi * 5 * t)
    tone = (np.sin(2 * np.pi * f * t * wobble) + 0.35 * np.sin(2 * np.pi * f * 4.02 * t) * np.exp(-t * 6)
            + 0.15 * np.sin(2 * np.pi * f * 6.9 * t) * np.exp(-t * 12))
    return tone * np.exp(-t * 2.6) * np.minimum(1, t * 800) * 0.22


def pad(notes, dur):
    n = int(dur * SR)
    t = t_of(n)
    out = np.zeros(n)
    for note in notes:
        for detune in (-0.12, 0.0, 0.11):
            f = midi(note + detune)
            # Soft saw (a few harmonics) so it sits like an old organ/choir.
            for h in range(1, 7):
                out += np.sin(2 * np.pi * f * h * t + h) / h * 0.5
    env = np.minimum(1, t / 0.8) * np.minimum(1, (dur - t) / 0.8)
    trem = 1 + 0.15 * np.sin(2 * np.pi * 0.25 * t)
    return out * env * trem * 0.018


# --- Song --------------------------------------------------------------------
# Dm  Bb  Gm  A  (harmonic minor: the A major chord is the creepy bit).
CHORDS = [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]]
ROOTS = [38, 34, 31, 33]
# Music box melody, one bar per chord, (beat, midi note); 2 variations.
MELODY_A = [[(0, 74), (1.5, 77), (2, 76), (3, 74)],
            [(0, 74), (1.5, 70), (2, 69), (3, 70)],
            [(0, 67), (1, 70), (1.5, 74), (3, 72)],
            [(0, 73), (1, 76), (2, 73), (3, 69)]]
MELODY_B = [[(0, 81), (0.5, 77), (1, 74), (2.5, 77), (3, 81)],
            [(0, 82), (1, 77), (2, 74), (3, 70)],
            [(0, 79), (1, 74), (1.5, 79), (2, 82), (3, 81)],
            [(0, 76), (0.5, 73), (1, 76), (2, 79), (3, 81)]]

drums = np.zeros(N)
low = np.zeros(N)
keys = np.zeros(N)
pads = np.zeros(N)
K, S = kick(), snare()
SWING = 0.03  # late off-beat 16ths, boom-bap feel

for bar in range(BARS):
    b0 = bar * BAR
    chord = bar % 4
    intro = bar < 2
    breakdown = bar in (12, 13)
    # Pads every bar.
    place(pads, pad(CHORDS[chord], BAR + 0.4), b0)
    # Music box: A melody, B melody in the second half.
    melody = MELODY_B if 8 <= bar < 12 else MELODY_A
    for beat, note in melody[chord]:
        place(keys, music_box(note), b0 + beat * BEAT)
    if intro:
        continue
    # Drums: boom-bap. Kicks on 1, the "and" of 2, and a ghost before 3 every other bar.
    if not breakdown:
        for beat in ([0, 1.5, 2.75] if bar % 2 else [0, 1.75, 2.5]):
            place(drums, K, b0 + beat * BEAT)
    for beat in (1, 3):
        place(drums, S * (0.6 if breakdown else 1.0), b0 + beat * BEAT)
    for i in range(8):
        at = b0 + i * BEAT / 2 + (SWING if i % 2 else 0)
        place(drums, hat(open_=(i == 7 and bar % 4 == 3)) * (1.0 if i % 2 == 0 else 0.6), at)
    if bar == 15:  # snare roll back into the top
        for i in range(4):
            place(drums, S * (0.35 + i * 0.12), b0 + (3 + i / 4) * BEAT)
    # 808: root on 1, a slide on the "and" of 2.
    if not breakdown:
        root = ROOTS[chord]
        place(low, bass(root, BEAT * 1.4), b0)
        place(low, bass(root, BEAT * 0.9, glide_from=root + 12), b0 + 1.75 * BEAT)
        nxt = ROOTS[(chord + 1) % 4]
        place(low, bass(root + 7 if chord != 3 else root + 4, BEAT * 0.9), b0 + 2.75 * BEAT)
        place(low, bass(root, BEAT * 0.6), b0 + 3.5 * BEAT)

keys = delay(keys, BEAT * 0.75, feedback=0.35, mix=0.4)
keys = reverb(keys, 2.5, 0.45)
pads = reverb(fft_filter(pads, high=1800), 3.0, 0.5)
drums = reverb(drums, 1.0, 0.12, tone=5000)
low = onepole_lp(low, 220)

# Vinyl crackle and hiss.
crackle = np.zeros(N)
pops = rng.random(N) < 0.0006
crackle[pops] = rng.standard_normal(pops.sum()) * 0.5
crackle = fft_filter(crackle, low=800) + fft_filter(rng.standard_normal(N), low=3000, high=9000) * 0.006

mix = drums * 0.7 + low * 0.9 + keys * 1.2 + pads * 1.1 + crackle * 0.6
# Gentle bus glue, then normalize.
mix = np.tanh(mix * 1.1) / 1.1
mix = mix / np.max(np.abs(mix)) * 0.89
pcm = (mix * 32767).astype(np.int16)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"wrote {os.path.normpath(OUT)}  {LENGTH:.1f}s  {os.path.getsize(OUT) / 1e6:.1f} MB")
