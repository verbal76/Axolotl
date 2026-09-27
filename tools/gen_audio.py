#!/usr/bin/env python3
"""Synthesises every sound in the game (original, deterministic) into assets/audio.

Music: each moss ball has a loop split into layers that fade in with restoration.
All layers of a ball share one length so they stay locked together at runtime.
Loops carry a WAV 'smpl' chunk so Godot imports them as seamlessly looping.

Run from the repository root:  python3 tools/gen_audio.py
"""
import os
import struct

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1234)


# ----------------------------------------------------------------------------- utilities

def write_wav(name, data, loop=False, peak=0.85):
    data = np.asarray(data, np.float64)
    m = np.max(np.abs(data)) if data.size else 0.0
    if m > 1e-9:
        data = data / m * peak
    pcm = np.clip(data * 32767.0, -32768, 32767).astype("<i2").tobytes()
    chunks = b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16)
    chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
    if len(pcm) % 2:
        chunks += b"\x00"
    if loop:
        n = len(data)
        smpl = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<IIIIII", 0, 0, 0, n - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    riff = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(riff)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a=0.01, d=0.1, s=0.7, r=0.2, sustain_len=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n) if sustain_len is None else int(sustain_len * SR)
    e = np.concatenate([np.linspace(0, 1, a_n, endpoint=False), np.linspace(1, s, d_n, endpoint=False),
                        np.full(s_n, s), np.linspace(s, 0, r_n)])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def expdecay(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lowpass_fast(x, cutoff, passes=2):
    # IIR one-pole via scipy-free recursion is slow; use FFT brickwall-ish smooth filter.
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    H = 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2 * passes))
    return np.fft.irfft(X * H, len(x))


def highpass_fast(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    H = 1.0 - 1.0 / np.sqrt(1.0 + (f / max(cutoff, 1)) ** 4)
    return np.fft.irfft(X * H, len(x))


def bandpass_fast(x, lo, hi):
    return highpass_fast(lowpass_fast(x, hi), lo)


def reverb(x, wet=0.3, size=1.0, circular=False):
    """Small Schroeder reverb. If circular, tails wrap (for seamless loops)."""
    n = len(x)
    out = np.zeros(n)
    combs = [(int(0.0297 * SR * size), 0.78), (int(0.0371 * SR * size), 0.76), (int(0.0411 * SR * size), 0.74), (int(0.0437 * SR * size), 0.72)]
    for delay, g in combs:
        y = np.zeros(n)
        # Build impulse response of a feedback comb then convolve via FFT.
        ir_len = int(SR * 2.5 * size)
        ir = np.zeros(ir_len)
        k = 0
        amp = 1.0
        while k < ir_len and amp > 1e-3:
            ir[k] = amp
            k += delay
            amp *= g
        if circular:
            L = n
            irw = np.zeros(L)
            for i in range(0, ir_len):
                irw[i % L] += ir[i]
            y = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(irw)))
        else:
            L = n + ir_len
            y = np.real(np.fft.ifft(np.fft.fft(x, L) * np.fft.fft(ir, L)))[:n]
        out += y
    out = lowpass_fast(out, 5000) / len(combs)
    return x * (1 - wet) + out * wet * 0.6


def note_f(n):
    """MIDI note number to frequency."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


def place(buf, start_s, sig, gain=1.0, wrap=True):
    i = int(start_s * SR)
    n = len(sig)
    L = len(buf)
    for k in range(0, n, L):
        seg = sig[k:k + L]
        a = (i + k) % L if wrap else i + k
        end = a + len(seg)
        if end <= L:
            buf[a:end] += seg * gain
        elif wrap:
            cut = L - a
            buf[a:] += seg[:cut] * gain
            buf[:end - L] += seg[cut:] * gain
        else:
            buf[a:L] += seg[:L - a] * gain
    return buf


# ----------------------------------------------------------------------------- instruments

def marimba(f, dur=1.4, bright=1.0):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * f * t) * expdecay(len(t), 0.55)
    s += 0.35 * bright * np.sin(2 * np.pi * f * 3.93 * t) * expdecay(len(t), 0.09)
    s += 0.12 * bright * np.sin(2 * np.pi * f * 9.2 * t) * expdecay(len(t), 0.03)
    return s * env_adsr(len(t), 0.003, 0.05, 1.0, 0.05)


def kalimba(f, dur=1.2):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * f * t) * expdecay(len(t), 0.45)
    s += 0.3 * np.sin(2 * np.pi * f * 5.4 * t) * expdecay(len(t), 0.05)
    s += 0.15 * np.sin(2 * np.pi * f * 2.0 * t) * expdecay(len(t), 0.2)
    return s * env_adsr(len(t), 0.002, 0.02, 1.0, 0.05)


def pluck_bass(f, dur=1.0):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * expdecay(len(t), 0.2)
    return s * expdecay(len(t), 0.5) * env_adsr(len(t), 0.01, 0.05, 1.0, 0.08)


def bell(f, dur=2.0):
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * f * 3.5 * t) * 2.2 * expdecay(len(t), 0.5)
    s = np.sin(2 * np.pi * f * t + mod) * expdecay(len(t), 0.8)
    return s * env_adsr(len(t), 0.004, 0.05, 1.0, 0.1)


def pad(freqs, dur, bright=0.5, attack=0.8):
    t = t_axis(dur)
    s = np.zeros(len(t))
    for f in freqs:
        for det in (-0.25, 0.0, 0.3):
            ff = f * 2 ** (det / 100 * 8)
            ph = rng.random() * 2 * np.pi
            saw = 2 * ((ff * t + ph / (2 * np.pi)) % 1.0) - 1
            s += 0.5 * np.sin(2 * np.pi * ff * t + ph) + 0.25 * bright * saw
    s = lowpass_fast(s, 600 + 2200 * bright)
    return s * env_adsr(len(t), attack, 0.3, 0.85, min(1.2, dur * 0.4)) / (len(freqs) * 2)


def flute(f, dur):
    t = t_axis(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    s = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    breath = bandpass_fast(rng.standard_normal(len(t)), f * 0.8, f * 3) * 0.08
    return (s + breath) * env_adsr(len(t), 0.08, 0.1, 0.8, 0.25)


def choir(freqs, dur):
    t = t_axis(dur)
    s = np.zeros(len(t))
    for f in freqs:
        vib = 1 + 0.004 * np.sin(2 * np.pi * 4.6 * t + rng.random() * 6)
        ph = 2 * np.pi * np.cumsum(f * vib) / SR
        saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
        s += saw
    # Formant-ish "ooh": emphasise ~400 Hz and ~800 Hz.
    s = bandpass_fast(s, 250, 1100)
    return s * env_adsr(len(t), 0.9, 0.3, 0.8, min(1.4, dur * 0.4)) / len(freqs)


def kick(dur=0.35):
    t = t_axis(dur)
    f = 55 + 70 * np.exp(-t / 0.04)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * expdecay(len(t), 0.12)


def shaker(dur=0.09):
    n = int(dur * SR)
    return highpass_fast(rng.standard_normal(n), 5000) * expdecay(n, 0.025) * env_adsr(n, 0.004, 0.01, 1, 0.01)


def wood(f=900, dur=0.12):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * f * t) * expdecay(len(t), 0.03) + 0.4 * np.sin(2 * np.pi * f * 2.7 * t) * expdecay(len(t), 0.015)
    return s


def log_drum(f=180, dur=0.4):
    t = t_axis(dur)
    return (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.5 * t) * expdecay(len(t), 0.05)) * expdecay(len(t), 0.13)


def drop(f0=700, f1=1400, dur=0.12):
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur) ** 0.5
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * expdecay(len(t), 0.03) * env_adsr(len(t), 0.002, 0.01, 1, 0.02)


def mx(*parts):
    """Sum signals of different lengths (zero-padded)."""
    L = max(len(p) for p in parts)
    out = np.zeros(L)
    for p in parts:
        out[:len(p)] += p
    return out


def noise(n):
    return rng.standard_normal(n)


# ----------------------------------------------------------------------------- music

def render_layers(bpm, beats, layers_fn, name, reverbs):
    beat = 60.0 / bpm
    L = int(round(beats * beat * SR))
    for i, fn in enumerate(layers_fn):
        buf = np.zeros(L)
        fn(buf, beat)
        buf = reverb(buf, wet=reverbs[i], size=1.0, circular=True)
        # Short crossfade-free loop: rendering is circular, so the loop point is seamless.
        write_wav(f"music_{name}_l{i}", buf, loop=True, peak=0.6 if i else 0.75)


def ball1():
    # Classic lush marimo: gentle C major/lydian, marimba lead. 80 BPM, 16 beats.
    prog = [[48, 52, 55, 59], [45, 48, 52, 55], [41, 45, 48, 52], [43, 47, 50, 52]]
    mel = [(0, 76, 1), (1, 79, 0.5), (1.5, 77, 0.5), (2, 76, 1), (3, 72, 1),
           (4, 74, 1.5), (5.5, 72, 0.5), (6, 69, 2),
           (8, 72, 1), (9, 74, 0.5), (9.5, 76, 0.5), (10, 77, 1), (11, 76, 1),
           (12, 74, 1), (13, 71, 1), (14, 72, 2)]

    def l0(buf, b):
        for i, ch in enumerate(prog):
            place(buf, i * 4 * b, pad([note_f(n) for n in ch], 4 * b + 1.0, bright=0.35), 1.0)

    def l1(buf, b):
        for i, ch in enumerate(prog):
            for k, off in enumerate([0, 2.5, 3]):
                place(buf, (i * 4 + off) * b, pluck_bass(note_f(ch[0] - 12 + (7 if k == 2 else 0)), 1.2), 0.9 if k == 0 else 0.5)

    def l2(buf, b):
        for st, n, d in mel:
            place(buf, st * b, marimba(note_f(n), 1.6), 0.8)
            place(buf, (st + 0.02) * b, marimba(note_f(n - 12), 1.2, 0.5), 0.25)

    def l3(buf, b):
        for i in range(16):
            if i % 4 == 0:
                place(buf, i * b, kick(), 0.8)
            for h in range(2):
                place(buf, (i + h * 0.5) * b, shaker(), 0.18 + 0.1 * (h == 1))
            if i % 4 == 2:
                place(buf, (i + 0.75) * b, wood(1200), 0.35)

    def l4(buf, b):
        arp = [0, 2, 1, 3]
        for i, ch in enumerate(prog):
            for k in range(8):
                n = ch[arp[k % 4]] + 24
                if (k + i) % 3 != 1:
                    place(buf, (i * 4 + k * 0.5) * b, bell(note_f(n), 1.5), 0.22)
        for s in [1.25, 5.75, 9.25, 13.75]:
            place(buf, s * b, drop(900, 1700), 0.3)

    render_layers(80, 16, [l0, l1, l2, l3, l4], "b1", [0.35, 0.2, 0.3, 0.12, 0.45])


def ball2():
    # Current-swept overgrowth: D dorian, flowing flute, harp arpeggios. 88 BPM.
    prog = [[50, 53, 57, 60, 64], [43, 50, 55, 59, 62], [52, 55, 59, 62], [45, 52, 55, 57, 62]]
    mel = [(0, 74, 1.5), (1.5, 76, 0.5), (2, 77, 2), (4, 79, 1), (5, 77, 1), (6, 74, 2),
           (8, 72, 1), (9, 74, 1), (10, 76, 1.5), (11.5, 74, 0.5), (12, 69, 3)]

    def l0(buf, b):
        for i, ch in enumerate(prog):
            place(buf, i * 4 * b, pad([note_f(n) for n in ch], 4 * b + 1.2, bright=0.45, attack=1.2), 1.0)

    def l1(buf, b):
        for i, ch in enumerate(prog):
            for off in [0, 1.5, 3]:
                place(buf, (i * 4 + off) * b, pluck_bass(note_f(ch[0] - 12), 1.0), 0.8 if off == 0 else 0.45)

    def l2(buf, b):
        for st, n, d in mel:
            place(buf, st * b, flute(note_f(n), d * b + 0.1), 0.55)

    def l3(buf, b):
        for i in range(16):
            for q in range(4):
                place(buf, (i + q * 0.25) * b, shaker(0.07), 0.12 + 0.1 * (q == 2))
            if i % 2 == 0:
                place(buf, i * b, kick(), 0.55)
            if i % 4 == 3:
                place(buf, (i + 0.5) * b, wood(700), 0.3)

    def l4(buf, b):
        for i, ch in enumerate(prog):
            for k in range(8):
                n = ch[k % len(ch)] + 12
                place(buf, (i * 4 + k * 0.5) * b, kalimba(note_f(n), 1.0), 0.28)

    render_layers(88, 16, [l0, l1, l2, l3, l4], "b2", [0.4, 0.2, 0.35, 0.12, 0.4])


def ball3():
    # Underwater jungle: A minor pentatonic, kalimba ostinato, log drums, choir. 96 BPM.
    prog = [[45, 52, 57, 60], [41, 48, 53, 57], [48, 55, 60, 64], [43, 50, 55, 59]]
    ost = [69, 72, 76, 72, 74, 72, 69, 67]
    mel = [(0, 81, 1), (1, 79, 1), (2, 76, 2), (4, 79, 1), (5, 81, 1), (6, 84, 2),
           (8, 83, 1), (9, 81, 1), (10, 79, 1.5), (11.5, 76, 0.5), (12, 76, 1), (13, 74, 1), (14, 69, 2)]

    def l0(buf, b):
        place(buf, 0, pad([note_f(33), note_f(40)], 16 * b + 1.0, bright=0.2, attack=2.0), 0.6)
        for i, ch in enumerate(prog):
            place(buf, i * 4 * b, pad([note_f(n) for n in ch], 4 * b + 1.0, bright=0.3), 0.8)

    def l1(buf, b):
        for i in range(32):
            place(buf, i * 0.5 * b, kalimba(note_f(ost[i % 8]), 1.0), 0.45)

    def l2(buf, b):
        pat = [0, 0.75, 1.5, 2, 2.75, 3.5]
        for bar in range(4):
            for k, p in enumerate(pat):
                place(buf, (bar * 4 + p) * b, log_drum(160 if k % 3 else 110), 0.6)
            for q in range(8):
                place(buf, (bar * 4 + q * 0.5) * b, shaker(0.06), 0.1)
            place(buf, (bar * 4 + 1) * b, wood(1500), 0.25)
            place(buf, (bar * 4 + 3.25) * b, wood(1100), 0.2)

    def l3(buf, b):
        for st, n, d in mel:
            place(buf, st * b, marimba(note_f(n), 1.5), 0.7)

    def l4(buf, b):
        for i, ch in enumerate(prog):
            place(buf, i * 4 * b, choir([note_f(n + 12) for n in ch[1:]], 4 * b + 0.8), 0.7)
        for s in [2.5, 6.25, 10.5, 14.25]:
            place(buf, s * b, drop(600, 1500, 0.15), 0.25)

    render_layers(96, 16, [l0, l1, l2, l3, l4], "b3", [0.35, 0.25, 0.12, 0.3, 0.5])


# ----------------------------------------------------------------------------- sfx

def sweep_noise(dur, f0, f1, q=1.6):
    n = int(dur * SR)
    x = noise(n)
    out = np.zeros(n)
    seg = 512
    for i in range(0, n, seg):
        k = i / n
        fc = f0 + (f1 - f0) * k
        chunk = x[i:i + seg]
        out[i:i + seg] = bandpass_fast(np.pad(chunk, (0, seg - len(chunk))), fc / q, fc * q)[:len(chunk)]
    return out


def bubbles(dur, count, lo=500, hi=1600):
    buf = np.zeros(int(dur * SR))
    for i in range(count):
        f0 = rng.uniform(lo, hi)
        place(buf, rng.uniform(0, dur * 0.85), drop(f0, f0 * 1.9, rng.uniform(0.04, 0.09)), rng.uniform(0.3, 0.8), wrap=False)
    return buf


def sfx():
    n = lambda d: int(d * SR)
    t = t_axis

    s = sweep_noise(0.3, 400, 1500) * env_adsr(n(0.3), 0.02, 0.05, 0.6, 0.2) * 0.7 + bubbles(0.3, 3)
    write_wav("sfx_jump", s)
    s = sweep_noise(0.45, 300, 2200) * env_adsr(n(0.45), 0.01, 0.1, 0.6, 0.3) + bubbles(0.45, 8, 600, 2000) * 0.8
    write_wav("sfx_burst", s)
    s = sweep_noise(0.25, 1800, 500) * env_adsr(n(0.25), 0.02, 0.05, 0.7, 0.15)
    write_wav("sfx_swipe", s)
    s = sweep_noise(0.25, 1800, 500) * env_adsr(n(0.25), 0.02, 0.05, 0.7, 0.15) * 0.7
    tt = t(0.2)
    s[:len(tt)] += np.sin(2 * np.pi * 320 * tt) * expdecay(len(tt), 0.04) * 0.9
    write_wav("sfx_swipe_hit", s)
    tt = t(0.22)
    s = (np.sin(2 * np.pi * (260 - 400 * tt) * tt) * 0.8 + lowpass_fast(noise(len(tt)), 1200) * 0.5) * expdecay(len(tt), 0.06)
    write_wav("sfx_hit", s)
    tt = t(1.2)
    s = np.zeros(len(tt))
    for k, f in enumerate([1320, 1046, 880, 660, 523]):
        place(s, k * 0.12, bell(f, 0.8), 0.4, wrap=False)
    write_wav("sfx_drain", reverb(s, 0.35))
    tt = t(1.6)
    s = np.zeros(len(tt))
    for k, f in enumerate([523, 659, 784, 1046]):
        place(s, k * 0.09, marimba(f, 1.2), 0.5, wrap=False)
        place(s, k * 0.09 + 0.02, bell(f * 2, 1.0), 0.18, wrap=False)
    write_wav("sfx_restore", reverb(s, 0.4))
    s = mx(bell(1568, 0.8) * 0.6, bell(2093, 0.6) * 0.3)
    write_wav("sfx_mote_capture", reverb(s, 0.35))
    s = sweep_noise(0.2, 900, 400) * env_adsr(n(0.2), 0.01, 0.03, 0.6, 0.12) * 0.6
    write_wav("sfx_lunge", s)
    tt = t(0.18)
    s = np.sin(2 * np.pi * (500 - 1200 * tt) * tt) * expdecay(len(tt), 0.05)
    s = np.concatenate([s, drop(500, 1000, 0.08)])
    write_wav("sfx_eat", s)
    s = np.concatenate([s, s * 0.8, np.zeros(n(0.05))])
    s = np.concatenate([s, bell(1760, 0.6) * 0.4])
    write_wav("sfx_eat_big", reverb(s, 0.25))
    tt = t(0.2)
    write_wav("sfx_land_soft", lowpass_fast(noise(len(tt)), 400) * expdecay(len(tt), 0.04))
    tt = t(0.5)
    s = kick(0.5) * 0.9 + sweep_noise(0.5, 1500, 300) * expdecay(len(tt), 0.1) * 0.6 + bubbles(0.5, 6) * 0.5
    write_wav("sfx_land_hard", s)
    tt = t(0.9)
    s = np.pad(kick(0.6), (0, n(0.3))) * 1.0 + sweep_noise(0.9, 2000, 200) * expdecay(len(tt), 0.2) * 0.7 + bubbles(0.9, 14) * 0.6
    write_wav("sfx_land_extreme", reverb(s, 0.25))
    tt = t(0.25)
    f = 900 + 500 * np.sin(np.pi * tt / 0.25)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_adsr(len(tt), 0.01, 0.05, 0.7, 0.1) * 0.6
    write_wav("sfx_hurt", s)
    s = np.zeros(n(1.6))
    for k, f in enumerate([659, 784, 988]):
        place(s, k * 0.1, bell(f, 1.2), 0.4, wrap=False)
    write_wav("sfx_checkpoint", reverb(s, 0.45))
    s = np.zeros(n(1.2))
    for k in range(10):
        place(s, k * 0.08, bell(2000 - k * 110, 0.5), 0.2, wrap=False)
    write_wav("sfx_dissolve", reverb(s, 0.5))
    s = np.zeros(n(1.2))
    for k in range(10):
        place(s, k * 0.06, bell(900 + k * 120, 0.5), 0.2, wrap=False)
    write_wav("sfx_reform", reverb(s, 0.5))
    tt = t(1.4)
    s = sweep_noise(1.4, 200, 900) * np.sin(np.pi * tt / 1.4) ** 2
    write_wav("sfx_vortex_pulse", s)
    tt = t(3.0)
    s = sweep_noise(3.0, 150, 1200) * np.sin(np.pi * tt / 3.0) ** 2 * 0.5
    ch = pad([note_f(60), note_f(67), note_f(72), note_f(76)], 3.0, 0.4, 0.6)
    write_wav("sfx_vortex_connect", reverb(s + ch * 1.4, 0.4))
    tt = t(1.0)
    write_wav("sfx_vortex_enter", sweep_noise(1.0, 300, 2500) * env_adsr(len(tt), 0.05, 0.2, 0.7, 0.4) + bubbles(1.0, 10) * 0.6)
    tt = t(0.6)
    write_wav("sfx_vortex_exit", sweep_noise(0.6, 2000, 300) * env_adsr(len(tt), 0.01, 0.1, 0.6, 0.3) + bubbles(0.6, 8) * 0.7)
    s = pad([note_f(60), note_f(64), note_f(67), note_f(72)], 2.2, 0.3, 0.3)
    write_wav("sfx_zone_bloom", reverb(s, 0.4))
    s = np.zeros(n(1.6))
    for k, f in enumerate([523, 659, 784, 1046, 1318]):
        place(s, k * 0.08, bell(f, 1.2), 0.35, wrap=False)
    write_wav("sfx_upgrade", reverb(s, 0.45))
    s = np.zeros(n(0.6))
    for k in range(14):
        place(s, rng.uniform(0, 0.5), highpass_fast(noise(n(0.02)), 2000) * expdecay(n(0.02), 0.005), rng.uniform(0.3, 1.0), wrap=False)
    write_wav("sfx_crumble", s)
    tt = t(0.5)
    f = 180 + 60 * np.sin(np.pi * tt / 0.5)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.5) * 0.5 + sweep_noise(0.5, 600, 300) * 0.3
    write_wav("sfx_leaf_bend", s)
    s = np.zeros(n(0.6))
    for k in range(9):
        place(s, k * 0.06, highpass_fast(noise(n(0.015)), 3000) * expdecay(n(0.015), 0.004), 0.3 + k * 0.08, wrap=False)
    write_wav("sfx_parasite_windup", s)
    tt = t(0.12)
    write_wav("sfx_parasite_snap", highpass_fast(noise(len(tt)), 1500) * expdecay(len(tt), 0.015) + np.sin(2 * np.pi * 600 * tt) * expdecay(len(tt), 0.02))
    write_wav("sfx_dart", drop(1200, 2600, 0.07))
    tt = t(0.3)
    write_wav("sfx_burrow", sweep_noise(0.3, 900, 250) * env_adsr(len(tt), 0.01, 0.05, 0.5, 0.2))
    tt = t(0.06)
    write_wav("sfx_ui_tap", np.sin(2 * np.pi * 1400 * tt) * expdecay(len(tt), 0.01))
    s = np.zeros(n(4.0))
    for k, f in enumerate([523, 659, 784, 988, 1175]):
        place(s, k * 0.35, bell(f, 3.0), 0.3, wrap=False)
    s += np.pad(pad([note_f(60), note_f(64), note_f(67), note_f(71)], 3.5, 0.3, 1.0), (0, n(0.5))) * 0.6
    write_wav("sfx_all_clear", reverb(s, 0.5))


def ambience():
    # Water: low rumble + soft hiss, seamless (circular reverb / filtering).
    L = int(8 * SR)
    x = lowpass_fast(noise(L), 220) * 0.8 + highpass_fast(noise(L), 3000) * 0.05
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * np.arange(L) / L * 2)
    write_wav("amb_water", x, loop=True, peak=0.5)
    L = int(6 * SR)
    b = np.zeros(L)
    for i in range(70):
        f0 = rng.uniform(300, 1200)
        place(b, rng.uniform(0, 6), drop(f0, f0 * 2.2, rng.uniform(0.03, 0.08)), rng.uniform(0.2, 0.7))
    b += lowpass_fast(noise(L), 600) * 0.15
    write_wav("amb_bubbler", b, loop=True, peak=0.55)
    L = int(4 * SR)
    tt = np.arange(L) / SR
    v = bandpass_fast(noise(L), 200, 1400) * (0.75 + 0.25 * np.sin(2 * np.pi * tt * 1.5))
    write_wav("amb_vortex", v, loop=True, peak=0.5)
    L = int(10 * SR)
    life = np.zeros(L)
    for i in range(40):
        f0 = rng.uniform(900, 2400)
        place(life, rng.uniform(0, 10), drop(f0, f0 * 1.4, 0.04), rng.uniform(0.1, 0.35))
    for i in range(12):
        place(life, rng.uniform(0, 10), bell(rng.choice([1318, 1568, 1760, 2093]), 1.0), 0.08)
    write_wav("amb_life", reverb(life, 0.4, circular=True), loop=True, peak=0.45)
    L = int(3 * SR)
    tt = np.arange(L) / SR
    tr = bandpass_fast(noise(L), 300, 3000) * (0.8 + 0.2 * np.sin(2 * np.pi * tt * 2))
    write_wav("amb_travel", tr, loop=True, peak=0.6)


def outside():
    # Muffled bedroom sounds heard through water and dirty glass.
    s = np.zeros(int(4.2 * SR))
    for k in range(7):
        step = lowpass_fast(noise(int(0.12 * SR)), 180) * expdecay(int(0.12 * SR), 0.03)
        step += np.sin(2 * np.pi * 60 * t_axis(0.12)) * expdecay(int(0.12 * SR), 0.05) * 0.8
        place(s, 0.2 + k * 0.55, step, 0.7 + 0.3 * np.sin(k * np.pi / 6), wrap=False)
    write_wav("out_footsteps", reverb(s, 0.3))
    s = np.zeros(int(1.4 * SR))
    place(s, 0.0, lowpass_fast(sweep_noise(0.6, 300, 700), 900) * 0.6, 1.0, wrap=False)
    place(s, 0.65, kick(0.3) * 0.8 + lowpass_fast(noise(int(0.3 * SR)), 400) * expdecay(int(0.3 * SR), 0.05), 1.0, wrap=False)
    write_wav("out_drawer", reverb(s, 0.25))
    s = np.zeros(int(1.6 * SR))
    tt = t_axis(0.8)
    creak = np.sin(2 * np.pi * np.cumsum(150 + 80 * np.sin(2 * np.pi * 3 * tt)) / SR) * np.sin(np.pi * tt / 0.8) * 0.4
    place(s, 0.0, lowpass_fast(creak, 900), 1.0, wrap=False)
    place(s, 0.9, lowpass_fast(noise(int(0.15 * SR)), 500) * expdecay(int(0.15 * SR), 0.03), 1.0, wrap=False)
    write_wav("out_door", reverb(s, 0.3))
    s = np.zeros(int(0.8 * SR))
    place(s, 0.05, np.sin(2 * np.pi * 110 * t_axis(0.3)) * expdecay(int(0.3 * SR), 0.06) + lowpass_fast(noise(int(0.3 * SR)), 700) * expdecay(int(0.3 * SR), 0.03), 1.0, wrap=False)
    write_wav("out_place", reverb(s, 0.25))


def main():
    os.makedirs(OUT, exist_ok=True)
    sfx()
    ambience()
    outside()
    ball1()
    ball2()
    ball3()
    print("audio written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
