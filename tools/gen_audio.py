#!/usr/bin/env python3
"""Synthesises the game's sound effects and ambience (original, deterministic) into assets/audio.

The music is not generated: it is the owner's two songs (assets/audio/music_*.ogg).
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
    # (The old noise bed's draws are kept so every sound after it stays byte-identical; the bed
    # itself is aquarium_bed(), which has its own random stream.)
    L = int(8 * SR)
    noise(L), noise(L)
    aquarium_bed()
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


def creatures():
    # Expansion 5's creatures (docs/ECOSYSTEM.md). Own generator, so the sounds above never change.
    r = np.random.default_rng(5005)
    n = lambda d: int(d * SR)
    # Crab guardian: a dry double clack (warning), then a skitter.
    s = np.zeros(n(0.5))
    for k, f in enumerate([2400, 2900]):
        c = bandpass_fast(r.standard_normal(n(0.05)), f * 0.6, f * 1.4) * expdecay(n(0.05), 0.008)
        place(s, 0.02 + k * 0.14, c, 1.0, wrap=False)
    write_wav("sfx_crab_clack", s)
    s = np.zeros(n(0.6))
    for k in range(9):
        c = bandpass_fast(r.standard_normal(n(0.03)), 1500, 4200) * expdecay(n(0.03), 0.006)
        place(s, k * 0.06 + r.uniform(0, 0.02), c, r.uniform(0.4, 0.8), wrap=False)
    write_wav("sfx_crab_skitter", s)
    # Reed stalker: a rising breathy hiss through the reeds (the telegraph), then the pounce whoosh.
    tt = t_axis(0.9)
    s = bandpass_fast(r.standard_normal(len(tt)), 2500, 7000) * np.clip(tt / 0.8, 0, 1) ** 1.5 * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * tt))
    s += sweep_noise(0.9, 300, 900) * env_adsr(len(tt), 0.3, 0.2, 0.8, 0.2) * 0.4
    write_wav("sfx_stalker_hiss", s)
    s = sweep_noise(0.35, 900, 200) * env_adsr(n(0.35), 0.01, 0.1, 0.6, 0.2) + lowpass_fast(r.standard_normal(n(0.35)), 300) * expdecay(n(0.35), 0.08) * 0.8
    write_wav("sfx_stalker_pounce", s)
    # Cave eel: bubbles rising from the crevice (the telegraph), then a snap.
    s = bubbles(0.9, 14, 300, 1100) + lowpass_fast(r.standard_normal(n(0.9)), 200) * 0.15
    write_wav("sfx_eel_bubbles", reverb(s, 0.45))
    tt = t_axis(0.25)
    s = np.sin(2 * np.pi * (180 - 300 * tt) * tt) * expdecay(len(tt), 0.05) + bandpass_fast(r.standard_normal(len(tt)), 800, 3000) * expdecay(len(tt), 0.02) * 0.7
    write_wav("sfx_eel_strike", reverb(s, 0.3))
    # Pufferfish: a rubbery inflating swell, and a soft boing when it is batted away.
    tt = t_axis(0.6)
    s = np.sin(2 * np.pi * np.cumsum(120 + 260 * tt) / SR) * env_adsr(len(tt), 0.05, 0.1, 0.8, 0.2) + bubbles(0.6, 5, 300, 800) * 0.6
    write_wav("sfx_puff_inflate", s)
    tt = t_axis(0.35)
    s = np.sin(2 * np.pi * np.cumsum(340 - 500 * tt * np.exp(-tt * 8)) / SR) * expdecay(len(tt), 0.1)
    write_wav("sfx_puff_bounce", s)
    # Shrimp shoal scattering: a flurry of tiny ticks and bubbles.
    s = np.zeros(n(0.5))
    for k in range(14):
        c = bandpass_fast(r.standard_normal(n(0.02)), 3000, 8000) * expdecay(n(0.02), 0.004)
        place(s, r.uniform(0, 0.35), c, r.uniform(0.3, 0.7), wrap=False)
    s += bubbles(0.5, 6, 900, 2400) * 0.5
    write_wav("sfx_shrimp_scatter", s)
    # A new species discovered: a soft two-note chime.
    s = np.zeros(n(1.2))
    place(s, 0.0, kalimba(note_f(79), 1.0), 0.6, wrap=False)
    place(s, 0.14, kalimba(note_f(86), 1.0), 0.5, wrap=False)
    write_wav("sfx_discover", reverb(s, 0.4))


def parasites():
    # Expansion 6: the parasites' combat voices (docs/ECOSYSTEM.md, parasites). Own generator, so
    # every sound above stays the same.
    r = np.random.default_rng(6006)
    n = lambda d: int(d * SR)
    # Alert: a quick rising chitter when one spots him (it tells the others).
    s = np.zeros(n(0.35))
    for k in range(5):
        tt = t_axis(0.04)
        c = np.sin(2 * np.pi * (1800 + k * 260) * tt) * expdecay(len(tt), 0.012)
        place(s, k * 0.045, c, 0.8 - k * 0.08, wrap=False)
    s += bandpass_fast(r.standard_normal(n(0.35)), 2500, 6000) * expdecay(n(0.35), 0.08) * 0.25
    write_wav("sfx_parasite_alert", s)
    # Large parasite's charge wind-up: a low grinding swell (1.1 s), then the charge's heavy rush.
    tt = t_axis(1.1)
    grind = bandpass_fast(r.standard_normal(len(tt)), 90, 420) * (0.6 + 0.4 * np.sin(2 * np.pi * 17 * tt))
    s = (grind + np.sin(2 * np.pi * np.cumsum(55 + 40 * tt) / SR) * 0.6) * np.clip(tt / 1.0, 0, 1) ** 1.3
    write_wav("sfx_parasite_charge_windup", reverb(s, 0.25))
    s = sweep_noise(0.6, 180, 700) * env_adsr(n(0.6), 0.02, 0.2, 0.7, 0.3) + lowpass_fast(r.standard_normal(n(0.6)), 160) * expdecay(n(0.6), 0.15)
    write_wav("sfx_parasite_charge", s)
    # Spitter: a swelling gurgle (the wind-up), the spit, and the glob's splat.
    s = bubbles(0.85, 16, 250, 900) + np.sin(2 * np.pi * np.cumsum(140 + 220 * t_axis(0.85)) / SR) * env_adsr(n(0.85), 0.3, 0.2, 0.7, 0.1) * 0.35
    write_wav("sfx_parasite_spit_windup", reverb(s, 0.3))
    tt = t_axis(0.22)
    s = np.sin(2 * np.pi * (420 - 900 * tt) * tt) * expdecay(len(tt), 0.05) + bandpass_fast(r.standard_normal(len(tt)), 600, 2400) * expdecay(len(tt), 0.03) * 0.6
    write_wav("sfx_parasite_spit", s)
    s = bubbles(0.4, 8, 400, 1400) + lowpass_fast(r.standard_normal(n(0.4)), 900) * expdecay(n(0.4), 0.05) * 0.8
    write_wav("sfx_parasite_splat", s)
    # Hurt and fleeing: a high skittering squeal.
    s = np.zeros(n(0.5))
    for k in range(8):
        c = bandpass_fast(r.standard_normal(n(0.03)), 2500, 6500) * expdecay(n(0.03), 0.006)
        place(s, k * 0.05 + r.uniform(0, 0.015), c, r.uniform(0.4, 0.8), wrap=False)
    tt = t_axis(0.3)
    place(s, 0.0, np.sin(2 * np.pi * np.cumsum(2200 - 900 * tt) / SR) * expdecay(len(tt), 0.1) * 0.4, 1.0, wrap=False)
    write_wav("sfx_parasite_flee", s)


def loopify(x, n, fade):
    """The first n samples of x (which holds n + fade), crossfaded so the end runs into the start."""
    out = np.array(x[:n], dtype=np.float64)
    r = np.linspace(0.0, 1.0, fade)
    out[:fade] = x[n:n + fade] * (1.0 - r) + x[:fade] * r
    return out


def aquarium_bed():
    """The household-aquarium bed heard from launch (docs/research/2026-09-30-DEVICE_AUDIT.md §G).
    Two layers on co-prime loops so the pair repeats only every 221 s:
    amb_water (17 s): soft water movement pitched where phone speakers play (≈180–750 Hz, slow
    swells, a few low glugs), nothing hissy above ~1.5 kHz.
    amb_aerator (13 s): a distant bubbler, irregular trains of small pitched bubbles, rolled off
    above ~2.6 kHz. The old bed (220 Hz rumble + a >3 kHz hiss band) read as static on phones."""
    r = np.random.default_rng(4077)
    fade = int(0.8 * SR)
    # Water movement.
    n = int(17 * SR)
    x = bandpass_fast(r.standard_normal(n + fade), 180, 750)
    env = lowpass_fast(r.standard_normal(n + fade), 0.35)
    env = env / (np.max(np.abs(env)) + 1e-9)
    x *= 0.72 + 0.28 * env
    for _ in range(9):
        f0 = r.uniform(170, 380)
        place(x, r.uniform(0, (n + fade) / SR - 0.3), drop(f0, f0 * 1.5, r.uniform(0.08, 0.16)), r.uniform(0.25, 0.5), wrap=False)
    w = loopify(x, n, fade)
    w = lowpass_fast(np.tile(w, 2), 1500)[n:]
    write_wav("amb_water", w, loop=True, peak=0.5)
    # Aerator.
    n = int(13 * SR)
    b = np.zeros(n)
    t = r.uniform(0.0, 0.3)
    while t < 13.0:
        count = int(r.integers(3, 10))
        base = r.uniform(650, 1350)
        tt = t
        for _ in range(count):
            f0 = base * r.uniform(0.85, 1.2)
            place(b, tt, drop(f0, f0 * 1.8, r.uniform(0.03, 0.07)), r.uniform(0.15, 0.6))
            tt += r.uniform(0.025, 0.09)
        t += r.exponential(0.55) + 0.12
    b = reverb(b, 0.35, 0.8, circular=True)
    b = lowpass_fast(np.tile(b, 2), 2600)[n:]   # (filtered around the loop: no click at the seam)
    write_wav("amb_aerator", b, loop=True, peak=0.45)


def main():
    os.makedirs(OUT, exist_ok=True)
    # (--only=skills writes just the skill-tree sounds, leaving every other file untouched.)
    import sys
    if "--only=bed" in sys.argv:
        aquarium_bed()
        print("audio written to", os.path.abspath(OUT))
        return
    if "--only=tunnel" in sys.argv:
        tunnel_and_ooze()
        print("audio written to", os.path.abspath(OUT))
        return
    if "--only=juice" in sys.argv:
        juice()
        print("audio written to", os.path.abspath(OUT))
        return
    if "--only=skills" not in sys.argv:
        sfx()
        ambience()
        outside()
        creatures()
        parasites()
        gill()
        tunnel_and_ooze()
        juice()
    skills()
    print("audio written to", os.path.abspath(OUT))


def tunnel_and_ooze():
    """Owner, 2026-10-01. The water tunnel opening (replaces sfx() 's vortex_connect): a soft swell with
    rising, twinkly bell sparkles over the whole 4.8 s shot. The ravine ooze: a thick low gurgle as
    Gill sinks in. Own random generator, so every other sound stays byte-identical."""
    r = np.random.default_rng(4242)
    dur = 4.8
    tt = t_axis(dur)
    swell = np.sin(np.pi * np.clip(tt / dur, 0, 1)) ** 1.5
    s = np.zeros(len(tt))
    for f in (note_f(60), note_f(64), note_f(67), note_f(72)):
        for det in (-0.004, 0.0, 0.005):
            s += np.sin(2 * np.pi * f * (1 + det) * tt + r.random() * 6.28) * 0.06
    s = lowpass_fast(s, 1400) * swell
    # A rising sparkle arpeggio (C major pentatonic, climbing two octaves), then a scatter of twinkles.
    scale = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96]
    for k, m in enumerate(scale):
        place(s, 0.15 + k * 0.17, bell(note_f(m), 1.4), 0.22, wrap=False)
    for k in range(34):
        m = scale[int(r.integers(4, len(scale)))] + 12 * int(r.integers(0, 2))
        place(s, r.uniform(1.6, dur - 0.9), bell(note_f(min(m, 103)), 0.9), r.uniform(0.06, 0.16), wrap=False)
    shimmer = highpass_fast(np.array([r.uniform(-1, 1) for _ in range(len(tt))]), 6000) * 0.05 * swell
    write_wav("sfx_vortex_connect", reverb(s + shimmer, 0.5))
    # The ooze: slow, thick, low bubbles and a sinking moan.
    dur = 1.6
    tt = t_axis(dur)
    g = np.zeros(len(tt))
    for k in range(16):
        f0 = r.uniform(90, 260)
        place(g, r.uniform(0, dur * 0.8), drop(f0, f0 * 1.6, r.uniform(0.08, 0.16)), r.uniform(0.4, 0.9), wrap=False)
    f = 160 * (1 - 0.45 * tt / dur)
    moan = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / dur) * 0.25
    g = lowpass_fast(g, 900) + moan
    write_wav("sfx_ooze_sink", reverb(g, 0.25))


def skills():
    """The red starfish pickup and the skill-tree unlock (docs/SKILL_TREE.md). No shared random
    generator is drawn from, so every sound above stays byte-identical.

    Starfish: a quick rising "bloop" (a bubble's upward glide, the transient that carries off-centre)
    straight into two bright kalimba plucks a fifth apart (E6 then B6) with a soft sparkle on top:
    plucked, not the Motes' bell (sfx_mote_capture) nor the cave rewards' bell run (sfx_upgrade).
    Unlock: a warm marimba run up a major chord with a low pluck under it and a small swell: a
    satisfying 'yes' for the menu, unlike either."""
    n = lambda d: int(d * SR)
    s = np.zeros(n(0.95))
    tt = t_axis(0.075)
    f = 520 + 1100 * (tt / 0.075) ** 0.6
    bloop = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_adsr(len(tt), 0.003, 0.02, 0.8, 0.03)
    place(s, 0.0, bloop, 0.55, wrap=False)
    place(s, 0.05, kalimba(note_f(88), 0.7), 0.8, wrap=False)
    place(s, 0.13, kalimba(note_f(95), 0.75), 0.7, wrap=False)
    shimmer = t_axis(0.5)
    sh = (np.sin(2 * np.pi * 3950 * shimmer) + 0.6 * np.sin(2 * np.pi * 5270 * shimmer)) * expdecay(len(shimmer), 0.09)
    sh *= 0.5 + 0.5 * np.sin(2 * np.pi * 22 * shimmer)
    place(s, 0.14, sh, 0.12, wrap=False)
    write_wav("sfx_starfish", reverb(s, 0.28), peak=0.8)
    s = np.zeros(n(1.5))
    for k, m in enumerate([60, 64, 67, 72, 76]):
        place(s, k * 0.055, marimba(note_f(m), 1.0), 0.45 + 0.05 * k, wrap=False)
    place(s, 0.0, pluck_bass(note_f(48), 0.9), 0.5, wrap=False)
    sw = pad([note_f(72), note_f(76), note_f(79)], 1.2, 0.35, 0.25)
    place(s, 0.2, sw * env_adsr(len(sw), 0.25, 0.3, 0.5, 0.5), 0.35, wrap=False)
    write_wav("sfx_skill_unlock", reverb(s, 0.35), peak=0.8)


def gill():
    # After dev-000024 (owner): a tiny, cute yawn for Gill's stretch idle. Own generator, so every
    # sound above stays the same. A small voice (high pitch) opening "a" then closing to "o",
    # rising then sighing down, breathy, a soft "mm" as the mouth shuts and a squeak at the end.
    r = np.random.default_rng(7117)
    dur = 1.15
    tt = t_axis(dur)
    n = len(tt)
    u = tt / dur
    # Pitch: a lift into the yawn, a long sigh down, a little squeak at the close.
    f0 = np.interp(u, [0.0, 0.12, 0.3, 0.6, 0.88, 1.0], [420, 520, 600, 470, 370, 380])
    f0 = f0 + 520 * np.exp(-((u - 0.93) / 0.025) ** 2)
    f0 = f0 * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * tt))
    phase = 2 * np.pi * np.cumsum(f0) / SR
    # Vowel: "a" (formants 900/1400) closing to "o" (520/900), then to a hum.
    k_open = np.clip((u - 0.05) / 0.25, 0, 1) * np.clip((0.85 - u) / 0.2, 0, 1)
    F1 = 520 + 380 * k_open
    F2 = 900 + 500 * k_open
    voice = np.zeros(n)
    for k in range(1, 12):
        fk = f0 * k
        w = np.exp(-((fk - F1) / 260) ** 2) + 0.6 * np.exp(-((fk - F2) / 330) ** 2) + 0.25 / k
        voice += np.sin(k * phase) * w
    amp = np.clip(u / 0.12, 0, 1) ** 1.5 * np.clip((1.0 - u) / 0.25, 0, 1)
    breath = bandpass_fast(r.standard_normal(n), 1200, 5000) * 0.18 * k_open
    hum = np.sin(phase * 0.5) * 0.35 * np.exp(-((u - 0.86) / 0.05) ** 2)
    s = (voice * 0.5 + breath + hum) * amp
    # Underwater: a touch muffled, a couple of bubbles after.
    s = lowpass_fast(s, 3800)
    s = np.concatenate([s, np.zeros(int(0.25 * SR))])
    place(s, 1.02, bubbles(0.3, 3, 700, 1500), 0.35, wrap=False)
    write_wav("sfx_gill_yawn", reverb(s, 0.18), peak=0.7)


def hint_bubbles():
    """Restoration hint (owner, 2026-10-06): a soft, short "blub-blub-blub" as a string of bubbles leaves
    Gill. Gentle and round, never an alarm; quiet enough to repeat."""
    global rng
    rng = np.random.default_rng(4411)
    dur = 0.55
    buf = np.zeros(int(dur * SR))
    for i, (t0, f0) in enumerate([(0.0, 520), (0.08, 640), (0.15, 560), (0.23, 720), (0.31, 610), (0.38, 780)]):
        place(buf, t0, drop(f0, f0 * 1.7, 0.07), 0.75 - i * 0.07, wrap=False)
    buf = lowpass_fast(buf, 2600)
    write_wav("sfx_hint_bubbles", reverb(buf, 0.22), peak=0.6)


def spore_bloom():
    """Toxic spore bloom (owner, 2026-10-06): a soft, rising, wet hiss while it swells (the warning),
    then a muffled "pff" as it bursts. Organic, not mechanical; quiet."""
    global rng
    rng = np.random.default_rng(5521)
    dur = 2.3
    n = int(dur * SR)
    tt = np.arange(n) / SR
    hiss = sweep_noise(dur, 700, 2600, 2.2) * np.clip(tt / dur, 0, 1) ** 1.6 * (1.0 - np.clip((tt - dur + 0.12) / 0.12, 0, 1))
    wob = 1.0 + 0.25 * np.sin(tt * 2 * np.pi * 7.0)
    s = lowpass_fast(hiss * wob, 3200) + bubbles(dur, 4, 250, 600) * 0.15
    write_wav("sfx_spore_hiss", reverb(s, 0.2), peak=0.45)
    dur = 0.7
    n = int(dur * SR)
    tt = np.arange(n) / SR
    puff = lowpass_fast(rng.standard_normal(n), 900) * np.exp(-tt / 0.16) * np.clip(tt / 0.015, 0, 1)
    s = puff + sweep_noise(dur, 1800, 400, 1.8) * np.exp(-tt / 0.3) * 0.35
    write_wav("sfx_spore_puff", reverb(s, 0.25), peak=0.55)


def juice():
    """v107 game feel (owner, 2026-10-08): three new sounds, each on its own seed so no other file
    changes. A moss ball fully restored: a warm, rising, bubbly bloom (shorter and smaller than the
    whole tank's all-clear). A pearl: a glassy, peach-warm shimmer. A step on moss: a tiny soft
    muffled pat, quiet enough to sit under everything."""
    global rng
    rng = np.random.default_rng(7101)
    n = lambda d: int(d * SR)
    s = np.zeros(n(2.6))
    for k, f in enumerate([392, 523, 659, 784, 1046]):
        place(s, k * 0.11, marimba(f, 1.4, 0.8), 0.32 - k * 0.02, wrap=False)
    for k, f in enumerate([1568, 2093]):
        place(s, 0.62 + k * 0.12, bell(f, 1.6), 0.12, wrap=False)
    s += np.pad(pad([note_f(55), note_f(60), note_f(64), note_f(67)], 2.2, 0.35, 0.5), (0, n(0.4))) * 0.45
    s[:n(2.6)] += np.pad(bubbles(1.2, 10, 600, 1700), (n(0.3), n(2.6) - n(0.3) - n(1.2))) * 0.25
    write_wav("sfx_ball_restored", reverb(s, 0.45), peak=0.8)
    rng = np.random.default_rng(7102)
    s = np.zeros(n(1.3))
    for k, f in enumerate([1318, 1661, 1976, 2637]):
        place(s, k * 0.05, bell(f, 1.1) * (1.0 + 0.004 * k), 0.28 - k * 0.04, wrap=False)
    s += np.pad(sweep_noise(0.5, 2600, 5200) * np.exp(-np.arange(n(0.5)) / SR / 0.18) * 0.12, (0, n(1.3) - n(0.5)))
    write_wav("sfx_pearl", reverb(lowpass_fast(s, 7000), 0.4), peak=0.7)
    rng = np.random.default_rng(7103)
    tt = np.arange(n(0.09)) / SR
    pat = lowpass_fast(rng.standard_normal(len(tt)), 520) * np.exp(-tt / 0.022) * np.clip(tt / 0.004, 0, 1)
    pat += np.sin(2 * np.pi * 140 * tt) * np.exp(-tt / 0.03) * 0.35
    write_wav("sfx_moss_step", pat, peak=0.5)


if __name__ == "__main__":
    main()
