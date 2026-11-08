"""程序化音效合成核心库。

所有音效均为原创合成，无外部采样。输出 48 kHz / 24-bit WAV：
- 单发音效为单声道，便于 Godot 2D 定位；
- 环境循环为立体声，已做首尾交叉淡化。
"""

from __future__ import annotations

import math
import os

import numpy as np
import soundfile as sf
from scipy import signal

SR = 48000
TWO_PI = 2.0 * math.pi


# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------

def duration_to_samples(duration: float) -> int:
    return max(1, int(round(duration * SR)))


def time_axis(duration: float) -> np.ndarray:
    return np.arange(duration_to_samples(duration), dtype=np.float64) / SR


def db_to_lin(db: float) -> float:
    return 10.0 ** (db / 20.0)


def lin_to_db(value: float) -> float:
    return 20.0 * math.log10(max(abs(value), 1e-12))


def normalize_peak(x: np.ndarray, peak_db: float = -3.0) -> np.ndarray:
    peak = float(np.max(np.abs(x))) if x.size else 0.0
    if peak < 1e-12:
        return x
    return x * (db_to_lin(peak_db) / peak)


def normalize_rms(x: np.ndarray, rms_db: float = -18.0) -> np.ndarray:
    rms = float(np.sqrt(np.mean(np.square(x)))) if x.size else 0.0
    if rms < 1e-12:
        return x
    return x * (db_to_lin(rms_db) / rms)


def dc_block(x: np.ndarray) -> np.ndarray:
    if x.size < 8:
        return x
    sos = signal.butter(2, 20.0 / (SR / 2.0), btype="highpass", output="sos")
    return signal.sosfilt(sos, x)


def fade(x: np.ndarray, in_ms: float = 2.0, out_ms: float = 8.0) -> np.ndarray:
    y = x.copy()
    n_in = min(duration_to_samples(in_ms / 1000.0), y.shape[0] // 2)
    n_out = min(duration_to_samples(out_ms / 1000.0), y.shape[0] // 2)
    if n_in > 0:
        y[:n_in] *= np.linspace(0.0, 1.0, n_in) ** 0.6
    if n_out > 0:
        y[-n_out:] *= np.linspace(1.0, 0.0, n_out) ** 1.4
    return y


def saturate(x: np.ndarray, drive: float = 2.0) -> np.ndarray:
    if drive <= 1.0:
        return x
    return np.tanh(x * drive) / np.tanh(drive)


def soft_clip(x: np.ndarray) -> np.ndarray:
    return np.tanh(x)


# ---------------------------------------------------------------------------
# 噪声
# ---------------------------------------------------------------------------

def white_noise(duration: float, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, 1.0, duration_to_samples(duration))


def pink_noise(duration: float, seed: int = 0) -> np.ndarray:
    n = duration_to_samples(duration)
    rng = np.random.default_rng(seed)
    white = rng.normal(0.0, 1.0, n)
    spec = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    scale = np.ones_like(freqs)
    scale[1:] = 1.0 / np.sqrt(freqs[1:])
    scale[0] = 0.0
    shaped = np.fft.irfft(spec * scale, n)
    return normalize_peak(shaped, -1.0)


def brown_noise(duration: float, seed: int = 0) -> np.ndarray:
    white = white_noise(duration, seed)
    brown = np.cumsum(white)
    brown -= np.linspace(brown[0], brown[-1], brown.size)
    return normalize_peak(brown, -1.0)


def band_noise(duration: float, low: float, high: float, seed: int = 0,
               order: int = 4) -> np.ndarray:
    n = duration_to_samples(duration)
    white = np.random.default_rng(seed).normal(0.0, 1.0, n)
    nyq = SR / 2.0
    low_n = max(low / nyq, 1e-5)
    high_n = min(high / nyq, 0.999)
    sos = signal.butter(order, [low_n, high_n], btype="bandpass", output="sos")
    return signal.sosfilt(sos, white)


def crackle(duration: float, density: float = 40.0, seed: int = 0,
            low: float = 1200.0, high: float = 9000.0) -> np.ndarray:
    """稀疏爆裂声，用于电弧、燃烧、老旧扬声器。"""
    n = duration_to_samples(duration)
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    count = max(1, int(density * duration))
    positions = rng.integers(0, n, count)
    for pos in positions:
        length = min(n - pos, int(rng.integers(8, 80)))
        if length <= 0:
            continue
        env = np.exp(-np.arange(length) / max(length * 0.25, 1.0))
        burst = rng.normal(0.0, 1.0, length) * env
        out[pos:pos + length] += burst * rng.uniform(0.2, 1.0)
    out = signal.sosfilt(
        signal.butter(2, [low / (SR / 2.0), high / (SR / 2.0)],
                      btype="bandpass", output="sos"), out)
    return out


# ---------------------------------------------------------------------------
# 振荡器与扫频
# ---------------------------------------------------------------------------

def _phase_from_freq(freq: np.ndarray) -> np.ndarray:
    return np.cumsum(freq) / SR


def sine(freq, duration: float, phase: float = 0.0) -> np.ndarray:
    t = time_axis(duration)
    f = np.full_like(t, float(freq)) if np.isscalar(freq) else np.asarray(freq)
    return np.sin(TWO_PI * _phase_from_freq(f) + phase)


def saw(freq, duration: float) -> np.ndarray:
    t = time_axis(duration)
    f = np.full_like(t, float(freq)) if np.isscalar(freq) else np.asarray(freq)
    return signal.sawtooth(TWO_PI * _phase_from_freq(f))


def triangle(freq, duration: float) -> np.ndarray:
    t = time_axis(duration)
    f = np.full_like(t, float(freq)) if np.isscalar(freq) else np.asarray(freq)
    return signal.sawtooth(TWO_PI * _phase_from_freq(f), width=0.5)


def square(freq, duration: float, duty: float = 0.5) -> np.ndarray:
    t = time_axis(duration)
    f = np.full_like(t, float(freq)) if np.isscalar(freq) else np.asarray(freq)
    return signal.square(TWO_PI * _phase_from_freq(f), duty=duty)


def sweep(f0: float, f1: float, duration: float, curve: str = "exp") -> np.ndarray:
    t = time_axis(duration)
    if curve == "exp" and f0 > 0 and f1 > 0:
        freq = f0 * (f1 / f0) ** (t / duration)
    else:
        freq = np.linspace(f0, f1, t.size)
    return np.sin(TWO_PI * _phase_from_freq(freq))


def fm(carrier: float, modulator: float, index: float, duration: float) -> np.ndarray:
    t = time_axis(duration)
    return np.sin(TWO_PI * carrier * t + index * np.sin(TWO_PI * modulator * t))


def metallic_hit(duration: float, base: float = 420.0, partials: int = 7,
                 decay: float = 0.35, seed: int = 0) -> np.ndarray:
    """非谐波金属敲击，用于命中金属、机械碰撞、设施受击。"""
    rng = np.random.default_rng(seed)
    t = time_axis(duration)
    out = np.zeros_like(t)
    ratios = [1.0, 2.76, 5.40, 8.93, 13.34, 18.64, 24.82][:partials]
    for i, ratio in enumerate(ratios):
        freq = base * ratio * rng.uniform(0.97, 1.03)
        amp = 1.0 / (i + 1) ** 0.8
        d = decay * rng.uniform(0.6, 1.1)
        out += amp * np.sin(TWO_PI * freq * t + rng.uniform(0, math.pi)) * np.exp(-t / d)
    return out


# ---------------------------------------------------------------------------
# 包络
# ---------------------------------------------------------------------------

def env_ad(duration: float, attack: float = 0.005, decay: float = 0.2,
           power: float = 1.0) -> np.ndarray:
    n = duration_to_samples(duration)
    a = min(duration_to_samples(attack), n)
    d = max(n - a, 1)
    env = np.concatenate([
        np.linspace(0.0, 1.0, a) if a > 0 else np.array([]),
        np.exp(-np.arange(d) / max(d * decay, 1.0) * power),
    ])
    return env[:n]


def env_perc(duration: float, attack: float = 0.003, decay_power: float = 3.0) -> np.ndarray:
    n = duration_to_samples(duration)
    a = min(duration_to_samples(attack), n)
    env = np.zeros(n)
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a)
    if n > a:
        env[a:] = np.exp(-np.linspace(0.0, decay_power, n - a))
    return env


def env_ar(duration: float, attack: float = 0.01, release: float = 0.2) -> np.ndarray:
    n = duration_to_samples(duration)
    a = min(duration_to_samples(attack), n)
    r = min(duration_to_samples(release), n - a)
    env = np.ones(n)
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r > 0:
        env[-r:] *= np.linspace(1.0, 0.0, r)
    return env


def lfo(duration: float, rate: float, depth: float = 1.0,
        phase: float = 0.0) -> np.ndarray:
    t = time_axis(duration)
    return 1.0 + depth * np.sin(TWO_PI * rate * t + phase)


# ---------------------------------------------------------------------------
# 滤波与音色处理
# ---------------------------------------------------------------------------

def lowpass(x: np.ndarray, freq: float, order: int = 4) -> np.ndarray:
    sos = signal.butter(order, min(freq / (SR / 2.0), 0.999),
                        btype="lowpass", output="sos")
    return signal.sosfilt(sos, x)


def highpass(x: np.ndarray, freq: float, order: int = 4) -> np.ndarray:
    sos = signal.butter(order, max(freq / (SR / 2.0), 1e-5),
                        btype="highpass", output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x: np.ndarray, low: float, high: float, order: int = 4) -> np.ndarray:
    nyq = SR / 2.0
    sos = signal.butter(order, [max(low / nyq, 1e-5), min(high / nyq, 0.999)],
                        btype="bandpass", output="sos")
    return signal.sosfilt(sos, x)


def resonant(x: np.ndarray, freq: float, q: float = 12.0) -> np.ndarray:
    b, a = signal.iirpeak(min(freq / (SR / 2.0), 0.995), q)
    return signal.lfilter(b, a, x)


def reverb(x: np.ndarray, decay: float = 0.8, mix: float = 0.18,
           lowpass_hz: float = 6500.0, seed: int = 0) -> np.ndarray:
    """用合成脉冲响应做短混响，模拟金属舱室。"""
    ir_duration = max(decay * 3.0, 0.2)
    n_ir = duration_to_samples(ir_duration)
    rng = np.random.default_rng(seed)
    ir = rng.normal(0.0, 1.0, n_ir)
    ir *= np.exp(-np.arange(n_ir) / max(decay * SR, 1.0))
    ir = lowpass(ir, lowpass_hz)
    ir /= max(np.sqrt(np.sum(ir ** 2)), 1e-9)
    wet = signal.fftconvolve(x, ir, mode="full")[: x.size]
    wet = normalize_peak(wet, lin_to_db(np.max(np.abs(x)) + 1e-9))
    return (1.0 - mix) * x + mix * wet


def tape_wow(x: np.ndarray, depth_ms: float = 1.5, rate: float = 0.6) -> np.ndarray:
    t = np.arange(x.size) / SR
    delay = (depth_ms / 1000.0) * (0.5 + 0.5 * np.sin(TWO_PI * rate * t))
    idx = np.arange(x.size) - delay * SR
    return np.interp(idx, np.arange(x.size), x, left=0.0, right=0.0)


def resample(x: np.ndarray, ratio: float) -> np.ndarray:
    """比例 > 1 音高升高、时长变短。"""
    if abs(ratio - 1.0) < 1e-6:
        return x
    n_out = max(1, int(x.size / ratio))
    idx = np.linspace(0.0, x.size - 1.0, n_out)
    return np.interp(idx, np.arange(x.size), x)


def reverse(x: np.ndarray) -> np.ndarray:
    return x[::-1].copy()


def bitcrush(x: np.ndarray, bits: int = 8, downsample: int = 2) -> np.ndarray:
    levels = 2 ** bits
    y = np.round(x * levels) / levels
    if downsample > 1:
        y = np.repeat(y[::downsample], downsample)[: x.size]
    return y


def stereoize(x: np.ndarray, width: float = 0.25, delay_ms: float = 7.0) -> np.ndarray:
    """用循环延迟制造宽度，延迟从尾部回绕，保证循环接缝连续。"""
    delay_samples = duration_to_samples(delay_ms / 1000.0)
    left = x
    right = np.roll(x, delay_samples) if delay_samples > 0 else x
    return np.stack([left * (1.0 - width * 0.5), right * (1.0 + width * 0.5)], axis=1)


# ---------------------------------------------------------------------------
# 组合
# ---------------------------------------------------------------------------

def mix(*signals: np.ndarray) -> np.ndarray:
    signals = [s for s in signals if s is not None and s.size > 0]
    if not signals:
        return np.zeros(1)
    n = max(s.shape[0] for s in signals)
    out = np.zeros(n)
    for s in signals:
        out[: s.shape[0]] += s
    return out


def place(canvas: np.ndarray, sound: np.ndarray, at: float,
          gain: float = 1.0) -> np.ndarray:
    start = duration_to_samples(at)
    if start >= canvas.size:
        return canvas
    end = min(canvas.size, start + sound.size)
    canvas[start:end] += sound[: end - start] * gain
    return canvas


def loopify(x: np.ndarray, duration: float, fade: float = 1.0) -> np.ndarray:
    """把稍长的素材首尾交叉淡化，输出可无缝循环的循环段。"""
    n = duration_to_samples(duration)
    f = duration_to_samples(fade)
    source = x
    if source.size < n + f:
        source = np.pad(source, (0, n + f - source.size))
    head = source[:f].copy()
    tail = source[n:n + f]
    fade_curve = np.linspace(0.0, 1.0, f)
    source[:f] = head * fade_curve + tail * (1.0 - fade_curve)
    return source[:n]


def write_wav(path: str, x: np.ndarray, peak_db: float = -3.0,
              stereo: bool = False) -> dict:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = np.nan_to_num(x, nan=0.0, posinf=0.0, neginf=0.0)
        x = dc_block(x)
        x = normalize_peak(x, peak_db)
        if stereo:
            x = stereoize(x)
    else:
        x = np.nan_to_num(x, nan=0.0, posinf=0.0, neginf=0.0)
        x = np.stack([dc_block(x[:, 0]), dc_block(x[:, 1])], axis=1)
        peak = float(np.max(np.abs(x)))
        if peak > 1e-12:
            x = x * (db_to_lin(peak_db) / peak)
    sf.write(path, x.astype(np.float32), SR, subtype="PCM_24")
    peak = float(np.max(np.abs(x)))
    rms = float(np.sqrt(np.mean(np.square(x))))
    return {
        "path": path,
        "duration": round(x.shape[0] / SR, 3),
        "channels": 2 if x.ndim > 1 else 1,
        "peak_dbfs": round(lin_to_db(peak), 2),
        "rms_dbfs": round(lin_to_db(rms), 2),
    }
