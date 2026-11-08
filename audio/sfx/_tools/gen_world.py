"""机关、解谜、环境、状态与 UI 音效生成。"""

from __future__ import annotations

import numpy as np

import sfx_core as sc
from sfx_registry import render


def _canvas(duration: float) -> np.ndarray:
    return np.zeros(sc.duration_to_samples(duration))


def _metal_tick(seed: int = 0, base: float = 1200.0, duration: float = 0.06) -> np.ndarray:
    hit = sc.metallic_hit(duration, base=base, partials=5, decay=0.025, seed=seed)
    return hit * sc.env_perc(duration, 0.001, 3.0)


def _beep(freq: float, duration: float, level: float = 0.25,
          shape: str = "triangle") -> np.ndarray:
    if shape == "square":
        tone = sc.square(freq, duration, duty=0.4)
    elif shape == "sine":
        tone = sc.sine(freq, duration)
    else:
        tone = sc.triangle(freq, duration)
    return tone * sc.env_ar(duration, 0.004, 0.04) * level


def _buzz(duration: float, freq: float = 110.0, seed: int = 0) -> np.ndarray:
    tone = sc.square(freq, duration, duty=0.35) * 0.25 + sc.sine(freq * 2, duration) * 0.1
    noise = sc.band_noise(duration, 500, 2500, seed) * 0.05
    return (tone + noise) * sc.env_ar(duration, 0.004, 0.03)


def _servo(duration: float, base: float = 70.0, load: float = 0.3,
           seed: int = 0) -> np.ndarray:
    t = sc.time_axis(duration)
    freq = base * (1.0 + 0.02 * np.sin(2 * np.pi * 0.9 * t))
    motor = sc.lowpass(sc.saw(freq, duration) * 0.4, 900)
    whine = sc.band_noise(duration, 300, 1400, seed) * 0.2
    creak = sc.resonant(sc.band_noise(duration, 150, 900, seed + 1), 260, q=8) * 0.15
    mod = 0.75 + 0.25 * np.sin(2 * np.pi * 1.3 * t + 0.4)
    return (motor + whine + creak) * mod * (0.6 + load)


def _glass_shards(seed: int, duration: float = 0.7) -> np.ndarray:
    engine = np.random.default_rng(seed)
    n = sc.duration_to_samples(duration)
    t = np.arange(n) / sc.SR
    out = np.zeros(n)
    for i in range(12):
        freq = engine.uniform(1800, 9500)
        decay = engine.uniform(0.04, 0.22)
        amp = engine.uniform(0.15, 0.5) / (1 + i * 0.15)
        out += amp * np.sin(2 * np.pi * freq * t + engine.uniform(0, 6.28)) * np.exp(-t / decay)
    burst = sc.band_noise(duration, 2500, 16000, seed + 1) * sc.env_perc(duration, 0.001, 3.0)
    return sc.mix(out * 0.5, burst * 0.55)


# ---------------------------------------------------------------------------
# 机关、破坏与房门
# ---------------------------------------------------------------------------

def mechanism_start() -> np.ndarray:
    canvas = _canvas(1.15)
    motor = _servo(0.9, 50, 0.9, 401) * 0.3
    rise = sc.sweep(45, 95, 0.7) * sc.env_ad(0.7, 0.15, 0.7) * 0.2
    sc.place(canvas, motor, 0.0, 0.5)
    sc.place(canvas, rise, 0.0, 0.3)
    sc.place(canvas, _metal_tick(402, 700, 0.07), 0.02, 0.5)
    canvas = sc.reverb(canvas, decay=0.5, mix=0.12, lowpass_hz=4500, seed=403)
    return sc.fade(canvas, 3.0, 80)


def mechanism_stop() -> np.ndarray:
    canvas = _canvas(0.95)
    down = sc.sweep(95, 38, 0.55) * sc.env_ad(0.55, 0.01, 0.6) * 0.25
    sc.place(canvas, down, 0.0, 0.4)
    sc.place(canvas, _metal_tick(411, 600, 0.08), 0.42, 0.55)
    sc.place(canvas, sc.band_noise(0.3, 200, 2200, 412) * sc.env_perc(0.3, 0.01, 2.0) * 0.15, 0.4, 0.3)
    canvas = sc.reverb(canvas, decay=0.45, mix=0.12, lowpass_hz=4500, seed=413)
    return sc.fade(canvas, 2.0, 70)


def facility_hit(variant: int = 0) -> np.ndarray:
    canvas = _canvas(0.38)
    hit = sc.metallic_hit(0.3, base=520 + variant * 140, partials=6, decay=0.09, seed=421 + variant)
    hit *= sc.env_perc(0.3, 0.001, 2.2)
    zap = sc.band_noise(0.09, 1800, 10000, 423 + variant) * sc.env_perc(0.09, 0.001, 3.0)
    sc.place(canvas, hit, 0.0, 0.65)
    sc.place(canvas, zap, 0.0, 0.35)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.14, lowpass_hz=6500, seed=424 + variant)
    return sc.fade(canvas, 1.0, 35)


def facility_destroy() -> np.ndarray:
    canvas = _canvas(1.4)
    tear = sc.resonant(sc.band_noise(0.8, 180, 5000, 431), 420, q=10) * sc.env_perc(0.8, 0.005, 2.0)
    sc.place(canvas, tear, 0.0, 0.45)
    arc = sc.crackle(0.7, 55, 432, 1200, 14000) * 0.4
    sc.place(canvas, arc, 0.05, 0.5)
    collapse = sc.sweep(110, 35, 0.8) * sc.env_ad(0.8, 0.01, 0.5) * 0.5
    sc.place(canvas, collapse, 0.15, 0.45)
    debris = sc.crackle(0.5, 35, 433, 500, 7000) * 0.25
    sc.place(canvas, debris, 0.35, 0.35)
    canvas = sc.reverb(canvas, decay=0.8, mix=0.18, lowpass_hz=5000, seed=434)
    return sc.fade(canvas, 2.0, 100)


def glass_break() -> np.ndarray:
    canvas = _canvas(1.0)
    shards = _glass_shards(441, 0.8)
    sc.place(canvas, shards, 0.0, 0.8)
    liquid = sc.band_noise(0.7, 250, 3000, 442) * sc.env_ad(0.7, 0.01, 0.6) * 0.25
    sc.place(canvas, liquid, 0.12, 0.35)
    canvas = sc.reverb(canvas, decay=0.6, mix=0.15, lowpass_hz=8000, seed=443)
    return sc.fade(canvas, 1.5, 80)


def container_release() -> np.ndarray:
    canvas = _canvas(1.35)
    pressure = sc.band_noise(0.6, 400, 8000, 451) * sc.env_ad(0.6, 0.02, 0.5) * 0.4
    sc.place(canvas, pressure, 0.0, 0.45)
    sc.place(canvas, _glass_shards(452, 0.4) * 0.5, 0.08, 0.45)
    wake = sc.saw(90, 0.7) * sc.env_ad(0.7, 0.05, 0.6) * 0.18
    wake = sc.lowpass(sc.saturate(wake, 2.0), 700)
    sc.place(canvas, wake, 0.35, 0.4)
    canvas = sc.reverb(canvas, decay=0.6, mix=0.15, lowpass_hz=5500, seed=453)
    return sc.fade(canvas, 2.0, 90)


def fuel_explosion() -> np.ndarray:
    canvas = _canvas(1.7)
    blast = sc.brown_noise(0.8, 461) * sc.env_perc(0.8, 0.002, 2.0)
    blast = sc.lowpass(blast, 1800)
    sc.place(canvas, blast, 0.0, 0.8)
    sub = sc.sweep(80, 28, 0.9) * sc.env_perc(0.9, 0.002, 2.5)
    sc.place(canvas, sub, 0.0, 0.8)
    crack = sc.crackle(0.9, 60, 462, 500, 12000) * 0.35
    sc.place(canvas, crack, 0.05, 0.45)
    tail = sc.band_noise(1.2, 200, 4000, 463) * sc.env_ad(1.2, 0.02, 0.5) * 0.15
    sc.place(canvas, tail, 0.15, 0.25)
    canvas = sc.reverb(canvas, decay=1.1, mix=0.2, lowpass_hz=4000, seed=464)
    return sc.fade(canvas, 2.0, 120)


def explosion_warning() -> np.ndarray:
    canvas = _canvas(0.95)
    hiss = sc.band_noise(0.5, 500, 7000, 471) * sc.env_ad(0.5, 0.02, 0.6) * 0.25
    sc.place(canvas, hiss, 0.0, 0.35)
    for i, at in enumerate((0.05, 0.3, 0.55)):
        tone = sc.sweep(480, 900, 0.16) * sc.env_ar(0.16, 0.004, 0.04)
        sc.place(canvas, tone, at, 0.22 + i * 0.03)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=6000, seed=472)
    return sc.fade(canvas, 2.0, 50)


def leak_spark_loop() -> np.ndarray:
    duration, fade = 3.0, 0.4
    total = duration + fade
    bed = sc.band_noise(total, 300, 5000, 481) * 0.08
    bed *= 0.7 + 0.3 * np.sin(2 * np.pi * (1 / duration) * sc.time_axis(total))
    sparks = sc.crackle(total, 28, 482, 1800, 14000) * 0.2
    hiss = sc.band_noise(total, 4000, 12000, 483) * 0.03
    sig = sc.mix(bed, sparks, hiss)
    return sc.loopify(sig, duration, fade)


def vacuum_start() -> np.ndarray:
    canvas = _canvas(0.95)
    motor = _servo(0.8, 40, 1.0, 491) * 0.35
    suction = sc.band_noise(0.7, 200, 5000, 492) * sc.env_ad(0.7, 0.1, 0.7) * 0.35
    sc.place(canvas, motor, 0.0, 0.5)
    sc.place(canvas, suction, 0.1, 0.45)
    canvas = sc.reverb(canvas, decay=0.5, mix=0.12, lowpass_hz=5000, seed=493)
    return sc.fade(canvas, 3.0, 60)


def vacuum_loop() -> np.ndarray:
    duration, fade = 3.0, 0.4
    total = duration + fade
    t = sc.time_axis(total)
    suction = sc.band_noise(total, 150, 4500, 501) * 0.35
    suction *= 0.8 + 0.2 * np.sin(2 * np.pi * (3 / duration) * t)
    motor = sc.lowpass(sc.saw(44, total) * 0.15, 500)
    whine = sc.sine(88, total) * 0.06
    sig = sc.mix(suction, motor, whine)
    return sc.loopify(sig, duration, fade)


def vacuum_stop() -> np.ndarray:
    canvas = _canvas(0.8)
    down = sc.sweep(80, 32, 0.45) * sc.env_ad(0.45, 0.01, 0.6) * 0.3
    sc.place(canvas, down, 0.0, 0.4)
    sc.place(canvas, _metal_tick(511, 650, 0.08), 0.35, 0.5)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=4500, seed=512)
    return sc.fade(canvas, 2.0, 60)


def door(open_door: bool) -> np.ndarray:
    canvas = _canvas(1.15)
    slide = _servo(0.75, 65 if open_door else 55, 0.8, 521 if open_door else 522) * 0.5
    sc.place(canvas, slide, 0.0, 0.55)
    if open_door:
        hiss = sc.band_noise(0.5, 500, 7000, 523) * sc.env_ad(0.5, 0.02, 0.5) * 0.3
        sc.place(canvas, hiss, 0.15, 0.4)
    else:
        hiss = sc.band_noise(0.35, 500, 7000, 523) * sc.env_ad(0.35, 0.02, 0.5) * 0.2
        sc.place(canvas, hiss, 0.55, 0.3)
    latch_at = 0.68 if open_door else 0.55
    sc.place(canvas, _metal_tick(524, 520, 0.1), latch_at, 0.5)
    sc.place(canvas, _metal_tick(525, 900, 0.07), latch_at + 0.05, 0.3)
    canvas = sc.reverb(canvas, decay=0.55, mix=0.14, lowpass_hz=5000, seed=526)
    return sc.fade(canvas, 3.0, 70)


def lock_denied() -> np.ndarray:
    canvas = _canvas(0.48)
    sc.place(canvas, _buzz(0.3, 92, 531) * 0.5, 0.0, 0.45)
    sc.place(canvas, _metal_tick(532, 420, 0.09), 0.02, 0.55)
    canvas = sc.lowpass(canvas, 5000)
    return sc.fade(canvas, 1.0, 40)


def unlock() -> np.ndarray:
    canvas = _canvas(0.6)
    sc.place(canvas, _metal_tick(541, 700, 0.08), 0.0, 0.5)
    sc.place(canvas, _beep(659.25, 0.16, 0.3), 0.12, 0.4)
    sc.place(canvas, _beep(987.77, 0.2, 0.22), 0.24, 0.35)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=6500, seed=542)
    return sc.fade(canvas, 1.5, 50)


# ---------------------------------------------------------------------------
# 解谜与交互
# ---------------------------------------------------------------------------

def terminal_enter() -> np.ndarray:
    canvas = _canvas(0.75)
    sc.place(canvas, _metal_tick(601, 800, 0.07), 0.0, 0.4)
    sc.place(canvas, sc.band_noise(0.45, 1500, 9000, 602) * sc.env_ad(0.45, 0.005, 0.4) * 0.2, 0.02, 0.3)
    sc.place(canvas, sc.sweep(500, 1800, 0.4) * sc.env_ad(0.4, 0.02, 0.5) * 0.15, 0.05, 0.3)
    sc.place(canvas, _beep(1046.5, 0.12, 0.18), 0.35, 0.25)
    canvas = sc.reverb(canvas, decay=0.35, mix=0.1, lowpass_hz=8000, seed=603)
    return sc.fade(canvas, 1.5, 50)


def terminal_exit() -> np.ndarray:
    canvas = _canvas(0.55)
    sc.place(canvas, sc.sweep(1200, 200, 0.35) * sc.env_ad(0.35, 0.005, 0.5) * 0.2, 0.0, 0.4)
    sc.place(canvas, sc.band_noise(0.2, 1000, 7000, 611) * sc.env_perc(0.2, 0.002, 2.0) * 0.15, 0.0, 0.25)
    sc.place(canvas, _metal_tick(612, 700, 0.06), 0.3, 0.35)
    return sc.fade(canvas, 1.0, 40)


def click() -> np.ndarray:
    canvas = _canvas(0.14)
    sc.place(canvas, sc.band_noise(0.03, 2000, 12000, 621) * sc.env_perc(0.03, 0.001, 3.0), 0.0, 0.35)
    sc.place(canvas, _beep(1500, 0.08, 0.28, "sine"), 0.005, 0.4)
    sc.place(canvas, _metal_tick(622, 2400, 0.04), 0.0, 0.25)
    return sc.fade(canvas, 0.5, 20)


def rotate(variant: int = 0) -> np.ndarray:
    canvas = _canvas(0.2)
    sc.place(canvas, _metal_tick(631 + variant, 900 + variant * 300, 0.05), 0.0, 0.5)
    sc.place(canvas, _beep(880 + variant * 110, 0.1, 0.18, "square"), 0.01, 0.3)
    return sc.fade(canvas, 0.5, 25)


def step_correct() -> np.ndarray:
    canvas = _canvas(0.34)
    sc.place(canvas, _beep(659.25, 0.14, 0.28), 0.0, 0.4)
    sc.place(canvas, _beep(987.77, 0.18, 0.22), 0.1, 0.35)
    canvas = sc.reverb(canvas, decay=0.35, mix=0.1, lowpass_hz=7000, seed=641)
    return sc.fade(canvas, 1.0, 35)


def error() -> np.ndarray:
    canvas = _canvas(0.42)
    sc.place(canvas, _buzz(0.3, 120, 651) * 0.55, 0.0, 0.5)
    sc.place(canvas, _beep(220, 0.2, 0.2, "square"), 0.0, 0.35)
    canvas = sc.lowpass(canvas, 4500)
    return sc.fade(canvas, 1.0, 40)


def puzzle_complete() -> np.ndarray:
    canvas = _canvas(1.0)
    # 925 三音动机
    for i, (at, freq) in enumerate(((0.0, 493.88), (0.14, 587.33), (0.28, 783.99))):
        sc.place(canvas, _beep(freq, 0.45, 0.42 - i * 0.03), at, 0.5)
        sc.place(canvas, _beep(freq * 2.01, 0.3, 0.1), at + 0.01, 0.2)
    sc.place(canvas, _metal_tick(661, 700, 0.08), 0.52, 0.3)
    canvas = sc.reverb(canvas, decay=0.65, mix=0.16, lowpass_hz=8000, seed=662)
    return sc.fade(canvas, 2.0, 80)


def clue_get() -> np.ndarray:
    canvas = _canvas(0.75)
    for i, at in enumerate((0.0, 0.1, 0.2, 0.3)):
        sc.place(canvas, _beep(1200 + i * 180, 0.06, 0.16, "sine"), at, 0.25)
    sc.place(canvas, sc.band_noise(0.4, 1500, 9000, 671) * sc.env_ad(0.4, 0.01, 0.5) * 0.12, 0.05, 0.2)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=8000, seed=672)
    return sc.fade(canvas, 1.5, 50)


def signal_tune_loop() -> np.ndarray:
    duration, fade = 6.0, 0.8
    total = duration + fade
    t = sc.time_axis(total)
    # 缓慢扫动的窄带噪声，像调谐逐渐变清晰
    static = sc.band_noise(total, 300, 6000, 681) * 0.18
    sweep_freq = 600 + 2200 * (0.5 + 0.5 * np.sin(2 * np.pi * (1 / duration) * t - 1.2))
    tone = sc.sine(sweep_freq, total) * 0.06
    crackle = sc.crackle(total, 18, 682, 800, 9000) * 0.08
    sig = sc.mix(static, tone, crackle)
    return sc.loopify(sig, duration, fade)


def broadcast_start() -> np.ndarray:
    canvas = _canvas(0.95)
    sc.place(canvas, _beep(880, 0.12, 0.25), 0.0, 0.35)
    sc.place(canvas, _beep(660, 0.18, 0.2), 0.14, 0.3)
    sc.place(canvas, sc.band_noise(0.7, 300, 4000, 691) * sc.env_ad(0.7, 0.01, 0.6) * 0.16, 0.2, 0.25)
    canvas = sc.reverb(canvas, decay=0.5, mix=0.14, lowpass_hz=6000, seed=692)
    return sc.fade(canvas, 2.0, 60)


def broadcast_end() -> np.ndarray:
    canvas = _canvas(0.65)
    sc.place(canvas, _metal_tick(701, 800, 0.06), 0.0, 0.35)
    sc.place(canvas, sc.band_noise(0.45, 300, 4000, 702) * sc.env_ad(0.45, 0.005, 0.6) * 0.12, 0.0, 0.2)
    return sc.fade(canvas, 1.0, 45)


# ---------------------------------------------------------------------------
# 环境循环
# ---------------------------------------------------------------------------

def _amb_base(total: float, seed: int) -> np.ndarray:
    t = sc.time_axis(total)
    air = sc.band_noise(total, 120, 2400, seed) * (0.55 + 0.15 * np.sin(2 * np.pi * 0.05 * t))
    low = sc.lowpass(sc.brown_noise(total, seed + 1), 160) * 0.6
    hum = (sc.sine(50, total) * 0.12 + sc.sine(100, total) * 0.05
           + sc.sine(150, total) * 0.025)
    hum *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.07 * t)
    metal = sc.resonant(sc.band_noise(total, 300, 4500, seed + 2), 780, q=18) * 0.05
    metal *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.03 * t + 1.0)
    sig = sc.mix(air * 0.55, low * 0.6, hum * 0.4, metal * 0.2)
    return sc.tape_wow(sig, 0.8, 0.11)


def _room_loop(duration: float, fade: float, builder) -> np.ndarray:
    total = duration + fade
    canvas = builder(total)
    return sc.loopify(canvas, duration, fade)


def amb_ship_vent() -> np.ndarray:
    duration, fade = 24.0, 2.0
    return _room_loop(duration, fade, lambda total: _amb_base(total, 711))


def amb_cockpit() -> np.ndarray:
    duration, fade = 24.0, 2.0
    total = duration + fade
    canvas = _amb_base(total, 721)
    hum = sc.sine(220, total) * 0.04 + sc.sine(330, total) * 0.02
    canvas = sc.mix(canvas, hum)
    for i, at in enumerate((4.5, 12.5, 19.5)):
        blip = _beep(1180 + i * 120, 0.07, 0.06, "sine")
        sc.place(canvas, blip, at, 0.4)
    return sc.loopify(canvas, duration, fade)


def amb_storage() -> np.ndarray:
    duration, fade = 24.0, 2.0
    total = duration + fade
    canvas = _amb_base(total, 731)
    servo = _servo(total, 58, 0.15, 732) * 0.05
    canvas = sc.mix(canvas, servo)
    for i, at in enumerate((5.0, 10.5, 17.0, 21.0)):
        rattle = sc.band_noise(0.25, 400, 3500, 733 + i) * sc.env_perc(0.25, 0.01, 2.0) * 0.06
        sc.place(canvas, rattle, at, 0.5)
    return sc.loopify(canvas, duration, fade)


def amb_sanitation() -> np.ndarray:
    duration, fade = 24.0, 2.0
    total = duration + fade
    canvas = _amb_base(total, 741)
    t = sc.time_axis(total)
    liquid = sc.band_noise(total, 200, 1600, 742) * 0.05
    liquid *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.08 * t)
    canvas = sc.mix(canvas, liquid)
    for i, at in enumerate((3.0, 8.0, 15.0, 21.0)):
        drip = sc.sweep(900, 500, 0.1) * sc.env_perc(0.1, 0.001, 2.5) * 0.08
        sc.place(canvas, drip, at, 0.6)
    valve = sc.band_noise(0.4, 600, 5000, 743) * sc.env_perc(0.4, 0.01, 2.0) * 0.08
    sc.place(canvas, valve, 11.0, 0.5)
    return sc.loopify(canvas, duration, fade)


def amb_comms() -> np.ndarray:
    duration, fade = 24.0, 2.0
    total = duration + fade
    canvas = _amb_base(total, 751)
    radio = sc.band_noise(total, 300, 3000, 752) * 0.04
    canvas = sc.mix(canvas, radio)
    for i, at in enumerate((2.5, 6.0, 9.5, 14.0, 18.5, 22.0)):
        pulse = _beep(1800 + (i % 3) * 220, 0.05, 0.05, "sine")
        sc.place(canvas, pulse, at, 0.4)
    for i, at in enumerate((7.5, 16.0)):
        burst = sc.crackle(0.35, 30, 753 + i, 800, 9000) * 0.05
        sc.place(canvas, burst, at, 0.4)
    return sc.loopify(canvas, duration, fade)


def amb_medical() -> np.ndarray:
    duration, fade = 24.0, 2.0
    total = duration + fade
    canvas = _amb_base(total, 761)
    hum = sc.sine(440, total) * 0.025 + sc.sine(110, total) * 0.03
    canvas = sc.mix(canvas, hum)
    for at in (2.5, 7.5, 12.5, 17.5, 22.5):
        monitor = _beep(880, 0.08, 0.06, "sine")
        sc.place(canvas, monitor, at, 0.4)
    return sc.loopify(canvas, duration, fade)


def amb_life_energy() -> np.ndarray:
    duration, fade = 24.0, 2.0
    total = duration + fade
    canvas = _amb_base(total, 771)
    t = sc.time_axis(total)
    energy = sc.sine(40, total) * 0.1 + sc.sine(80, total) * 0.04
    energy *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.05 * t)
    canvas = sc.mix(canvas, energy)
    for i, at in enumerate((3.5, 7.0, 12.0, 16.5, 21.0)):
        bubble = sc.sweep(500 + i * 60, 1100 + i * 80, 0.09) * sc.env_perc(0.09, 0.002, 2.0) * 0.05
        sc.place(canvas, bubble, at, 0.4)
    pump = sc.sine(55, 0.4) * sc.env_perc(0.4, 0.02, 2.0) * 0.06
    for at in (0.5, 4.5, 8.5, 12.5, 16.5, 20.5):
        sc.place(canvas, pump, at, 0.3)
    return sc.loopify(canvas, duration, fade)


def amb_fuel() -> np.ndarray:
    duration, fade = 24.0, 2.0
    total = duration + fade
    canvas = _amb_base(total, 781)
    pressure = sc.sine(90, total) * 0.04 + sc.sine(135, total) * 0.02
    canvas = sc.mix(canvas, pressure)
    for i, at in enumerate((5.0, 13.0, 20.0)):
        valve = _metal_tick(782 + i, 420, 0.07) * 0.6
        sc.place(canvas, valve, at, 0.4)
    return sc.loopify(canvas, duration, fade)


def amb_anomaly_hull() -> np.ndarray:
    duration, fade = 12.0, 1.2
    total = duration + fade
    t = sc.time_axis(total)
    low = sc.sine(32, total) * 0.18 + sc.sine(48, total) * 0.1 + sc.sine(64, total) * 0.05
    low *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.07 * t)
    groan = sc.resonant(sc.band_noise(total, 40, 600, 791), 90, q=10) * 0.12
    groan *= sc.env_ad(total, 1.0, 0.5) * 0.5
    sig = sc.mix(low, groan)
    return sc.loopify(sig, duration, fade)


def amb_anomaly_lighting() -> np.ndarray:
    duration, fade = 8.0, 1.0
    total = duration + fade
    t = sc.time_axis(total)
    buzz = sc.square(120, total, duty=0.35) * 0.06
    buzz *= 0.4 + 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 3.0 * t))
    crack = sc.crackle(total, 22, 801, 1500, 14000) * 0.16
    hum = sc.sine(60, total) * 0.04
    sig = sc.mix(buzz, crack, hum)
    return sc.loopify(sig, duration, fade)


def amb_anomaly_alarm() -> np.ndarray:
    duration, fade = 12.0, 1.2
    total = duration + fade
    canvas = sc.band_noise(total, 150, 2000, 811) * 0.03
    for start in (1.0, 5.0, 9.0):
        for i in range(3):
            beep = _beep(740 if i % 2 == 0 else 560, 0.18, 0.1, "square")
            sc.place(canvas, beep, start + i * 0.28, 0.5)
    return sc.loopify(canvas, duration, fade)


# ---------------------------------------------------------------------------
# 状态与 UI
# ---------------------------------------------------------------------------

def death_rewind() -> np.ndarray:
    canvas = _canvas(1.5)
    rev = sc.reverse(sc.reverb(sc.band_noise(0.9, 300, 7000, 821) * sc.env_ad(0.9, 0.01, 0.6), 0.8, 0.3, 6000, 822))
    sc.place(canvas, rev, 0.0, 0.4)
    drop = sc.sweep(600, 40, 1.1) * sc.env_ad(1.1, 0.01, 0.5) * 0.4
    sc.place(canvas, drop, 0.1, 0.4)
    stop = sc.tape_wow(sc.sine(140, 0.9) * sc.env_ad(0.9, 0.02, 0.5), 8.0, 2.2) * 0.18
    sc.place(canvas, stop, 0.1, 0.3)
    canvas = sc.reverb(canvas, decay=0.8, mix=0.18, lowpass_hz=5000, seed=823)
    return sc.fade(canvas, 3.0, 120)


def respawn() -> np.ndarray:
    canvas = _canvas(0.75)
    thud = sc.sweep(100, 45, 0.25) * sc.env_perc(0.25, 0.002, 3.0)
    sc.place(canvas, thud, 0.0, 0.45)
    rise = sc.band_noise(0.45, 300, 5000, 831) * sc.env_ad(0.45, 0.15, 0.5) * 0.18
    sc.place(canvas, rise, 0.05, 0.3)
    sc.place(canvas, _metal_tick(832, 900, 0.06), 0.35, 0.3)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=5500, seed=833)
    return sc.fade(canvas, 1.5, 60)


def cycle_start() -> np.ndarray:
    canvas = _canvas(1.25)
    sub = sc.sweep(60, 30, 0.5) * sc.env_perc(0.5, 0.002, 2.5)
    sc.place(canvas, sub, 0.0, 0.7)
    shimmer = sc.reverse(sc.reverb(sc.band_noise(0.7, 2000, 9000, 841) * sc.env_ad(0.7, 0.05, 0.6), 0.6, 0.25, 8000, 842))
    sc.place(canvas, shimmer, 0.05, 0.18)
    sc.place(canvas, _metal_tick(843, 700, 0.08), 0.2, 0.4)
    canvas = sc.reverb(canvas, decay=0.7, mix=0.16, lowpass_hz=6000, seed=844)
    return sc.fade(canvas, 2.0, 100)


def cycle_distortion_loop() -> np.ndarray:
    duration, fade = 10.0, 1.2
    total = duration + fade
    canvas = _amb_base(total, 851) * 0.6
    radio = sc.band_noise(total, 300, 3000, 852) * 0.08
    detune = sc.sine(220, total) * 0.04 + sc.sine(233, total) * 0.03
    buzz = sc.square(90, total, duty=0.3) * 0.02
    canvas = sc.mix(canvas, radio, detune, buzz)
    for i, at in enumerate((2.0, 5.0, 8.0)):
        glitch = sc.band_noise(0.12, 800, 9000, 853 + i) * sc.env_perc(0.12, 0.001, 2.0) * 0.12
        sc.place(canvas, glitch, at, 0.4)
    canvas = sc.tape_wow(canvas, 3.0, 0.35)
    return sc.loopify(canvas, duration, fade)


def story_anomaly() -> np.ndarray:
    canvas = _canvas(1.9)
    hit = sc.sweep(70, 35, 0.8) * sc.env_perc(0.8, 0.005, 3.0)
    sc.place(canvas, hit, 0.0, 0.6)
    rev = sc.reverse(sc.reverb(sc.band_noise(1.1, 200, 4000, 861) * sc.env_ad(1.1, 0.1, 0.6), 1.0, 0.25, 5000, 862))
    sc.place(canvas, rev, 0.0, 0.18)
    low = sc.sine(42, 1.4) * sc.env_ad(1.4, 0.2, 0.6) * 0.12
    sc.place(canvas, low, 0.1, 0.3)
    canvas = sc.reverb(canvas, decay=1.0, mix=0.2, lowpass_hz=4500, seed=863)
    return sc.fade(canvas, 3.0, 150)


def ending_clear() -> np.ndarray:
    canvas = _canvas(3.8)
    # 温暖但未完全解决的 D 小调 add9 和弦
    for i, freq in enumerate((146.83, 220.0, 293.66, 329.63, 440.0)):
        tone = sc.triangle(freq, 3.2) * sc.env_ad(3.2, 0.6, 0.7) * (0.14 / (1 + i * 0.2))
        sc.place(canvas, tone, 0.0, 0.5)
    shimmer = sc.band_noise(3.0, 3000, 10000, 871) * sc.env_ad(3.0, 1.0, 0.7) * 0.04
    sc.place(canvas, shimmer, 0.2, 0.3)
    sc.place(canvas, sc.tape_wow(sc.sine(110, 1.5) * sc.env_ad(1.5, 0.1, 0.6), 4.0, 0.7) * 0.05, 1.2, 0.2)
    canvas = sc.reverb(canvas, decay=1.4, mix=0.24, lowpass_hz=6000, seed=872)
    return sc.fade(canvas, 500.0, 800.0)


def ending_failure() -> np.ndarray:
    canvas = _canvas(3.0)
    down = sc.sweep(180, 28, 1.2) * sc.env_ad(1.2, 0.02, 0.5) * 0.4
    sc.place(canvas, down, 0.0, 0.4)
    flatline = sc.sine(880, 1.4) * sc.env_ad(1.4, 0.1, 0.5) * 0.06
    sc.place(canvas, flatline, 0.6, 0.2)
    static = sc.band_noise(1.5, 400, 5000, 881) * sc.env_ad(1.5, 0.3, 0.6) * 0.08
    sc.place(canvas, static, 0.6, 0.25)
    canvas = sc.reverb(canvas, decay=1.0, mix=0.2, lowpass_hz=4500, seed=882)
    return sc.fade(canvas, 3.0, 200)


def ui_select() -> np.ndarray:
    canvas = _canvas(0.1)
    sc.place(canvas, _beep(1200, 0.06, 0.2, "sine"), 0.0, 0.4)
    sc.place(canvas, sc.band_noise(0.02, 3000, 12000, 891) * sc.env_perc(0.02, 0.001, 3.0) * 0.1, 0.0, 0.3)
    return sc.fade(canvas, 0.5, 15)


def ui_confirm() -> np.ndarray:
    canvas = _canvas(0.26)
    sc.place(canvas, _beep(659.25, 0.12, 0.25), 0.0, 0.4)
    sc.place(canvas, _beep(987.77, 0.16, 0.2), 0.08, 0.35)
    canvas = sc.reverb(canvas, decay=0.3, mix=0.1, lowpass_hz=8000, seed=892)
    return sc.fade(canvas, 1.0, 30)


def ui_back() -> np.ndarray:
    canvas = _canvas(0.24)
    sc.place(canvas, _beep(784, 0.1, 0.2), 0.0, 0.4)
    sc.place(canvas, _beep(523.25, 0.14, 0.18), 0.07, 0.35)
    return sc.fade(canvas, 1.0, 30)


def pause() -> np.ndarray:
    canvas = _canvas(0.7)
    sc.place(canvas, sc.tape_wow(sc.sine(220, 0.5) * sc.env_ad(0.5, 0.01, 0.5), 5.0, 1.6) * 0.18, 0.0, 0.3)
    sc.place(canvas, _metal_tick(901, 600, 0.07), 0.05, 0.35)
    sc.place(canvas, sc.band_noise(0.35, 200, 3000, 902) * sc.env_perc(0.35, 0.01, 2.0) * 0.08, 0.0, 0.2)
    return sc.fade(canvas, 1.0, 50)


def resume() -> np.ndarray:
    canvas = _canvas(0.55)
    sc.place(canvas, sc.sweep(120, 440, 0.3) * sc.env_ad(0.3, 0.02, 0.5) * 0.16, 0.0, 0.3)
    sc.place(canvas, _metal_tick(911, 700, 0.06), 0.05, 0.35)
    return sc.fade(canvas, 1.0, 40)


def objective_update() -> np.ndarray:
    canvas = _canvas(0.42)
    sc.place(canvas, _beep(783.99, 0.14, 0.18), 0.0, 0.35)
    sc.place(canvas, _beep(1046.5, 0.18, 0.14), 0.1, 0.3)
    canvas = sc.reverb(canvas, decay=0.35, mix=0.1, lowpass_hz=8000, seed=921)
    return sc.fade(canvas, 1.0, 35)


# ---------------------------------------------------------------------------
# 构建
# ---------------------------------------------------------------------------

def build() -> None:
    # 机关、破坏与房门
    render("objects", "ob_mechanism_start.wav", mechanism_start(), "OB-01", "objects", "通用机关启动", peak_db=-4.0)
    render("objects", "ob_mechanism_stop.wav", mechanism_stop(), "OB-01", "objects", "通用机关停止", peak_db=-4.0)
    render("objects", "ob_facility_hit_01.wav", facility_hit(0), "OB-02", "objects", "设施受击变体 A", peak_db=-3.0)
    render("objects", "ob_facility_hit_02.wav", facility_hit(1), "OB-02", "objects", "设施受击变体 B", peak_db=-3.0)
    render("objects", "ob_facility_destroy.wav", facility_destroy(), "OB-03", "objects", "设施彻底破坏", peak_db=-2.0)
    render("objects", "ob_glass_break.wav", glass_break(), "OB-04", "objects", "玻璃容器破裂", peak_db=-3.0)
    render("objects", "ob_container_release.wav", container_release(), "OB-05", "objects", "容器释放怪物", peak_db=-3.0)
    render("objects", "ob_fuel_explosion.wav", fuel_explosion(), "OB-06", "objects", "燃料容器爆炸", peak_db=-2.0)
    render("objects", "ob_explosion_warning.wav", explosion_warning(), "OB-07", "objects", "爆炸前预警", peak_db=-4.0)
    render("objects", "ob_leak_spark_loop.wav", leak_spark_loop(), "OB-08", "objects",
           "泄漏/电火花循环", loop=True, peak_db=-12.0)
    render("objects", "ob_vacuum_start.wav", vacuum_start(), "OB-09", "objects", "真空抽取机启动", peak_db=-4.0)
    render("objects", "ob_vacuum_loop.wav", vacuum_loop(), "OB-09", "objects",
           "真空抽取机吸力循环", loop=True, peak_db=-9.0)
    render("objects", "ob_vacuum_stop.wav", vacuum_stop(), "OB-09", "objects", "真空抽取机停机", peak_db=-4.0)
    render("objects", "ob_door_open.wav", door(True), "OB-10", "objects", "舱门打开", peak_db=-4.0)
    render("objects", "ob_door_close.wav", door(False), "OB-10", "objects", "舱门关闭", peak_db=-4.0)
    render("objects", "ob_lock_denied.wav", lock_denied(), "OB-11", "objects", "锁门/无法通行", peak_db=-6.0)
    render("objects", "ob_unlock.wav", unlock(), "OB-11", "objects", "解锁确认", peak_db=-6.0)

    # 解谜与交互
    render("puzzle", "pu_terminal_enter.wav", terminal_enter(), "PU-01", "puzzle", "进入终端", peak_db=-5.0)
    render("puzzle", "pu_terminal_exit.wav", terminal_exit(), "PU-01", "puzzle", "退出终端", peak_db=-6.0)
    render("puzzle", "pu_click.wav", click(), "PU-02", "puzzle", "按钮/选项点击", peak_db=-8.0)
    render("puzzle", "pu_rotate_01.wav", rotate(0), "PU-03", "puzzle", "拨动/旋转刻度 A", peak_db=-7.0)
    render("puzzle", "pu_rotate_02.wav", rotate(1), "PU-03", "puzzle", "拨动/旋转刻度 B", peak_db=-7.0)
    render("puzzle", "pu_step_correct.wav", step_correct(), "PU-04", "puzzle", "局部步骤正确", peak_db=-7.0)
    render("puzzle", "pu_error.wav", error(), "PU-05", "puzzle", "输入错误/操作无效", peak_db=-5.0)
    render("puzzle", "pu_puzzle_complete.wav", puzzle_complete(), "PU-06", "puzzle", "谜题完成", peak_db=-4.0)
    render("puzzle", "pu_clue_get.wav", clue_get(), "PU-07", "puzzle", "线索/记录获得", peak_db=-7.0)
    render("puzzle", "pu_signal_tune_loop.wav", signal_tune_loop(), "PU-08", "puzzle",
           "信号调谐循环", loop=True, peak_db=-12.0)
    render("puzzle", "pu_broadcast_start.wav", broadcast_start(), "PU-09", "puzzle", "广播开始", peak_db=-6.0)
    render("puzzle", "pu_broadcast_end.wav", broadcast_end(), "PU-09", "puzzle", "广播结束", peak_db=-7.0)

    # 环境
    render("ambience", "amb_ship_vent_loop.wav", amb_ship_vent(), "AMB-00", "ambience",
           "全船空气循环/通风底噪", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_cockpit_living_loop.wav", amb_cockpit(), "AMB-01", "ambience",
           "驾驶舱/生活舱环境层", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_storage_loop.wav", amb_storage(), "AMB-02", "ambience",
           "储物补给舱环境层", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_sanitation_loop.wav", amb_sanitation(), "AMB-03", "ambience",
           "卫生与废物处理舱环境层", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_comms_loop.wav", amb_comms(), "AMB-04", "ambience",
           "通信舱环境层", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_medical_loop.wav", amb_medical(), "AMB-05", "ambience",
           "医疗与休眠舱环境层", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_life_energy_loop.wav", amb_life_energy(), "AMB-06", "ambience",
           "生命能源舱环境层", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_fuel_loop.wav", amb_fuel(), "AMB-07", "ambience",
           "燃料舱环境层", loop=True, peak_db=-12.0, stereo=True)
    render("ambience", "amb_anomaly_hull_resonance_loop.wav", amb_anomaly_hull(), "AMB-08", "ambience",
           "环境异常：船体低沉共振", loop=True, peak_db=-15.0, stereo=True)
    render("ambience", "amb_anomaly_lighting_fault_loop.wav", amb_anomaly_lighting(), "AMB-09", "ambience",
           "环境异常：照明故障电流", loop=True, peak_db=-15.0, stereo=True)
    render("ambience", "amb_anomaly_damaged_alarm_loop.wav", amb_anomaly_alarm(), "AMB-10", "ambience",
           "环境异常：破损设备间歇告警", loop=True, peak_db=-14.0, stereo=True)

    # 状态与 UI
    render("state", "st_death_rewind.wav", death_rewind(), "ST-01", "state", "死亡回退过渡", peak_db=-3.0)
    render("state", "st_respawn.wav", respawn(), "ST-02", "state", "回到上一房间/恢复控制", peak_db=-4.0)
    render("state", "st_cycle_start.wav", cycle_start(), "ST-03", "state", "新循环开始", peak_db=-3.0)
    render("state", "st_cycle_distortion_loop.wav", cycle_distortion_loop(), "ST-04", "state",
           "循环异化底噪循环", loop=True, peak_db=-12.0, stereo=True)
    render("state", "st_story_anomaly.wav", story_anomaly(), "ST-05", "state", "剧情异常/关键真相", peak_db=-4.0)
    render("state", "st_ending_clear.wav", ending_clear(), "ST-06", "state", "结局/通关，温暖未解决和弦", peak_db=-3.0)
    render("state", "st_ending_failure.wav", ending_failure(), "ST-06", "state", "结局/失效提示", peak_db=-3.0)
    render("ui", "ui_menu_select.wav", ui_select(), "UI-01", "ui", "菜单选中", peak_db=-9.0)
    render("ui", "ui_menu_confirm.wav", ui_confirm(), "UI-01", "ui", "菜单确认", peak_db=-8.0)
    render("ui", "ui_menu_back.wav", ui_back(), "UI-01", "ui", "菜单返回", peak_db=-8.0)
    render("ui", "ui_pause.wav", pause(), "UI-02", "ui", "暂停", peak_db=-8.0)
    render("ui", "ui_resume.wav", resume(), "UI-02", "ui", "恢复", peak_db=-8.0)
    render("ui", "ui_objective_update.wav", objective_update(), "UI-03", "ui", "目标更新/房间完成", peak_db=-8.0)
