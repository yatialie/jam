"""战斗、敌我、机械臂 Boss 音效生成。"""

from __future__ import annotations

import numpy as np

import sfx_core as sc
from sfx_registry import render


# ---------------------------------------------------------------------------
# 通用素材
# ---------------------------------------------------------------------------

def _canvas(duration: float) -> np.ndarray:
    return np.zeros(sc.duration_to_samples(duration))


def _metal_tick(seed: int = 0, base: float = 1800.0, duration: float = 0.06) -> np.ndarray:
    hit = sc.metallic_hit(duration, base=base, partials=5, decay=0.025, seed=seed)
    return hit * sc.env_perc(duration, 0.001, 3.0)


def _glass_tick(seed: int = 0, duration: float = 0.12) -> np.ndarray:
    n = sc.duration_to_samples(duration)
    t = np.arange(n) / sc.SR
    engine = np.random.default_rng(seed)
    partials = [2600.0, 3900.0, 5400.0, 7100.0]
    out = np.zeros(n)
    for i, freq in enumerate(partials):
        out += (0.7 / (i + 1)) * np.sin(2 * np.pi * freq * t + engine.uniform(0, 6.28)) * np.exp(-t / 0.025)
    burst = sc.band_noise(duration, 3000, 14000, seed + 1) * sc.env_perc(duration, 0.001, 4.0)
    return sc.mix(out * 0.5, burst * 0.4)


def _servo(duration: float, base: float = 75.0, load: float = 0.3,
           seed: int = 0) -> np.ndarray:
    t = sc.time_axis(duration)
    freq = base * (1.0 + 0.02 * np.sin(2 * np.pi * 0.9 * t))
    motor = sc.saw(freq, duration) * 0.4
    motor = sc.lowpass(motor, 900)
    whine = sc.band_noise(duration, 300, 1400, seed) * 0.2
    creak = sc.resonant(sc.band_noise(duration, 150, 900, seed + 1), 260, q=8) * 0.15
    mod = 0.75 + 0.25 * np.sin(2 * np.pi * 1.3 * t + 0.4)
    return (motor + whine + creak) * mod * (0.6 + load)


def _buzz(duration: float, freq: float = 110.0, seed: int = 0) -> np.ndarray:
    t = sc.time_axis(duration)
    tone = sc.square(freq, duration, duty=0.35) * 0.25 + sc.sine(freq * 2, duration) * 0.1
    noise = sc.band_noise(duration, 500, 2500, seed) * 0.05
    env = sc.env_ar(duration, 0.004, 0.03)
    return (tone + noise) * env


# ---------------------------------------------------------------------------
# 玩家
# ---------------------------------------------------------------------------

def footstep(seed: int = 1, heavy: bool = False) -> np.ndarray:
    canvas = _canvas(0.23 if not heavy else 0.26)
    thump = sc.sweep(115 if not heavy else 92, 48, 0.17) * sc.env_perc(0.17, 0.002, 4.0)
    click = _metal_tick(seed, 2100 if not heavy else 1500) * 0.55
    scuff = sc.band_noise(0.15, 800, 5200, seed + 1) * sc.env_perc(0.15, 0.004, 2.5)
    sc.place(canvas, thump, 0.0, 0.9)
    sc.place(canvas, click, 0.012, 1.0)
    sc.place(canvas, scuff, 0.018, 0.28)
    canvas = sc.lowpass(canvas, 9500)
    canvas = sc.reverb(canvas, decay=0.35, mix=0.09, lowpass_hz=5000, seed=seed)
    return sc.fade(canvas, 1.5, 25)


def hurt() -> np.ndarray:
    canvas = _canvas(0.38)
    thud = sc.sweep(150, 55, 0.18) * sc.env_perc(0.18, 0.002, 3.5)
    gasp = sc.band_noise(0.28, 350, 2800, 21) * sc.env_perc(0.28, 0.01, 2.2)
    cloth = sc.band_noise(0.32, 1200, 6000, 22) * sc.env_perc(0.32, 0.006, 2.0)
    bite = sc.band_noise(0.09, 1200, 2400, 23) * sc.env_perc(0.09, 0.002, 3.0)
    sc.place(canvas, thud, 0.0, 0.85)
    sc.place(canvas, gasp, 0.02, 0.55)
    sc.place(canvas, cloth, 0.03, 0.22)
    sc.place(canvas, bite, 0.01, 0.5)
    canvas = sc.saturate(canvas, 1.2)
    canvas = sc.reverb(canvas, decay=0.45, mix=0.1, lowpass_hz=5500, seed=24)
    return sc.fade(canvas, 1.0, 35)


def death() -> np.ndarray:
    canvas = _canvas(1.5)
    hiss = sc.band_noise(1.1, 500, 7000, 31) * sc.env_ad(1.1, 0.01, 0.5)
    drop = sc.sweep(240, 35, 1.1) * sc.env_ad(1.1, 0.01, 0.55)
    thud = sc.sweep(90, 38, 0.35) * sc.env_perc(0.35, 0.002, 3.0)
    tape = sc.tape_wow(sc.sine(180, 1.0) * sc.env_ad(1.0, 0.02, 0.5), 6.0, 2.4)
    sc.place(canvas, hiss, 0.0, 0.55)
    sc.place(canvas, drop, 0.02, 0.75)
    sc.place(canvas, thud, 0.02, 0.9)
    sc.place(canvas, tape, 0.05, 0.18)
    canvas = sc.saturate(canvas, 1.15)
    canvas = sc.reverb(canvas, decay=0.9, mix=0.2, lowpass_hz=4500, seed=32)
    return sc.fade(canvas, 2.0, 120)


def pickup_heal() -> np.ndarray:
    canvas = _canvas(0.72)
    notes = [(0.0, 523.25), (0.11, 659.25), (0.22, 783.99)]
    for i, (at, freq) in enumerate(notes):
        tone = sc.triangle(freq, 0.38) * sc.env_perc(0.38, 0.004, 2.2)
        shimmer = sc.sine(freq * 2.01, 0.3) * sc.env_perc(0.3, 0.01, 2.5) * 0.25
        sc.place(canvas, tone, at, 0.45 - i * 0.05)
        sc.place(canvas, shimmer, at + 0.01, 0.16)
    canvas = sc.reverb(canvas, decay=0.55, mix=0.16, lowpass_hz=7000, seed=41)
    return sc.fade(canvas, 2.0, 60)


def low_health() -> np.ndarray:
    canvas = _canvas(0.72)
    for at in (0.0, 0.3):
        beat = sc.sweep(68, 42, 0.22) * sc.env_perc(0.22, 0.005, 3.0)
        sc.place(canvas, beat, at, 0.7)
    tick = sc.sine(1500, 0.04) * sc.env_perc(0.04, 0.001, 3.0)
    sc.place(canvas, tick, 0.31, 0.06)
    canvas = sc.lowpass(canvas, 5000)
    return sc.fade(canvas, 2.0, 40)


def dash() -> np.ndarray:
    canvas = _canvas(0.34)
    whoosh = sc.band_noise(0.26, 250, 4200, 51) * sc.env_perc(0.26, 0.005, 2.0)
    fabric = sc.band_noise(0.2, 1800, 7000, 52) * sc.env_perc(0.2, 0.003, 2.5)
    thump = sc.sweep(120, 60, 0.12) * sc.env_perc(0.12, 0.002, 3.0)
    sc.place(canvas, whoosh, 0.0, 0.55)
    sc.place(canvas, fabric, 0.015, 0.2)
    sc.place(canvas, thump, 0.0, 0.3)
    return sc.fade(canvas, 1.0, 50)


# ---------------------------------------------------------------------------
# 武器
# ---------------------------------------------------------------------------

def shoot(seed: int = 61, variant: int = 0) -> np.ndarray:
    canvas = _canvas(0.3)
    crack = sc.band_noise(0.055, 2400 + variant * 300, 13000, seed) * sc.env_perc(0.055, 0.001, 3.0)
    zap = sc.sweep(1900 + variant * 260, 280, 0.17) * sc.env_ad(0.17, 0.002, 0.35)
    body = sc.sweep(190, 52, 0.2) * sc.env_ad(0.2, 0.003, 0.5)
    tail = sc.metallic_hit(0.24, base=640 + variant * 70, partials=5, decay=0.07, seed=seed + 2)
    tail *= sc.env_perc(0.24, 0.002, 2.5)
    sc.place(canvas, crack, 0.0, 0.9)
    sc.place(canvas, zap, 0.0, 0.65)
    sc.place(canvas, body, 0.0, 0.85)
    sc.place(canvas, tail, 0.01, 0.4)
    canvas = sc.saturate(canvas, 1.35)
    canvas = sc.reverb(canvas, decay=0.35, mix=0.12, lowpass_hz=5200, seed=seed + 3)
    return sc.fade(canvas, 0.8, 25)


def hit_organic() -> np.ndarray:
    canvas = _canvas(0.22)
    thump = sc.sweep(135, 50, 0.16) * sc.env_perc(0.16, 0.002, 3.5)
    wet = sc.band_noise(0.15, 220, 2600, 71) * sc.env_perc(0.15, 0.003, 2.5)
    tick = sc.sine(1350, 0.035) * sc.env_perc(0.035, 0.001, 3.0)
    sc.place(canvas, thump, 0.0, 0.8)
    sc.place(canvas, wet, 0.004, 0.45)
    sc.place(canvas, tick, 0.0, 0.12)
    canvas = sc.reverb(canvas, decay=0.25, mix=0.08, lowpass_hz=5000, seed=72)
    return sc.fade(canvas, 0.8, 20)


def hit_metal() -> np.ndarray:
    canvas = _canvas(0.28)
    hit = sc.metallic_hit(0.25, base=760, partials=7, decay=0.08, seed=81)
    hit *= sc.env_perc(0.25, 0.001, 2.2)
    tick = sc.band_noise(0.04, 3000, 12000, 82) * sc.env_perc(0.04, 0.001, 3.0)
    sc.place(canvas, hit, 0.0, 0.7)
    sc.place(canvas, tick, 0.0, 0.45)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.14, lowpass_hz=7000, seed=83)
    return sc.fade(canvas, 0.8, 30)


def hit_glass() -> np.ndarray:
    canvas = _canvas(0.2)
    tick = _glass_tick(91, 0.16)
    sc.place(canvas, tick, 0.0, 0.75)
    sc.place(canvas, sc.band_noise(0.05, 5000, 15000, 92) * sc.env_perc(0.05, 0.001, 3.0), 0.0, 0.3)
    return sc.fade(canvas, 0.6, 25)


def reload() -> np.ndarray:
    canvas = _canvas(0.62)
    # 弹匣脱出
    mag = _metal_tick(101, 900, 0.08)
    sc.place(canvas, mag, 0.03, 0.6)
    # 新弹匣插入
    insert = _metal_tick(102, 650, 0.1)
    sc.place(canvas, insert, 0.22, 0.75)
    # 机械闭锁
    lock = _metal_tick(103, 1200, 0.07)
    sc.place(canvas, lock, 0.38, 0.7)
    # 能量模块
    energy = sc.sweep(400, 900, 0.12) * sc.env_ad(0.12, 0.004, 0.4)
    sc.place(canvas, energy, 0.46, 0.18)
    canvas = sc.reverb(canvas, decay=0.3, mix=0.08, lowpass_hz=6000, seed=104)
    return sc.fade(canvas, 1.0, 40)


def empty() -> np.ndarray:
    canvas = _canvas(0.24)
    click = _metal_tick(111, 1400, 0.05)
    sc.place(canvas, click, 0.0, 0.55)
    sc.place(canvas, _buzz(0.16, 95, 112) * 0.45, 0.03, 0.4)
    return sc.fade(canvas, 0.8, 25)


def charge_loop() -> np.ndarray:
    duration, fade = 1.6, 0.3
    total = duration + fade
    t = sc.time_axis(total)
    rise = 240 + 520 * (t / total) ** 1.6
    whine = sc.sine(rise, total) * 0.35 + sc.sine(rise * 1.5, total) * 0.12
    noise = sc.band_noise(total, 900, 7000, 121) * 0.18
    mod = 0.8 + 0.2 * np.sin(2 * np.pi * (2.0 / duration) * t)
    sig = (whine + noise) * mod
    return sc.loopify(sig, duration, fade)


def overheat_warning() -> np.ndarray:
    canvas = _canvas(1.15)
    for i, at in enumerate((0.0, 0.32, 0.64)):
        beep = sc.square(880 if i % 2 == 0 else 660, 0.16, duty=0.4)
        beep *= sc.env_ar(0.16, 0.004, 0.05)
        sc.place(canvas, beep, at, 0.28)
    sc.place(canvas, _buzz(0.9, 90, 122) * 0.25, 0.0, 0.25)
    canvas = sc.lowpass(canvas, 5000)
    return sc.fade(canvas, 2.0, 50)


def cooldown_complete() -> np.ndarray:
    canvas = _canvas(0.65)
    for i, (at, freq) in enumerate(((0.0, 784.0), (0.14, 523.25))):
        tone = sc.triangle(freq, 0.4) * sc.env_perc(0.4, 0.004, 2.5)
        sc.place(canvas, tone, at, 0.4 - i * 0.08)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=6500, seed=131)
    return sc.fade(canvas, 1.5, 50)


def weapon_switch() -> np.ndarray:
    canvas = _canvas(0.46)
    servo = _servo(0.28, 90, 0.4, 141) * 0.25
    latch = _metal_tick(142, 850, 0.08)
    confirm = sc.triangle(660, 0.18) * sc.env_perc(0.18, 0.004, 2.0)
    sc.place(canvas, servo, 0.0, 0.4)
    sc.place(canvas, latch, 0.18, 0.6)
    sc.place(canvas, confirm, 0.25, 0.18)
    return sc.fade(canvas, 1.0, 35)


# ---------------------------------------------------------------------------
# 怪物
# ---------------------------------------------------------------------------

def alert(variant: int = 0) -> np.ndarray:
    canvas = _canvas(0.66)
    seed = 151 + variant
    if variant == 0:
        growl = sc.saw(96, 0.45) * sc.env_ad(0.45, 0.01, 0.4)
        growl = sc.lowpass(growl, 900)
        growl = sc.saturate(growl, 2.2)
        sc.place(canvas, growl, 0.0, 0.5)
        chirp = sc.sweep(1100, 2400, 0.18) * sc.env_perc(0.18, 0.003, 2.5)
        sc.place(canvas, chirp, 0.18, 0.35)
    else:
        clicks = sc.crackle(0.45, 55, seed, 1500, 9000) * 0.5
        sc.place(canvas, clicks, 0.0, 0.4)
        chirp = sc.sweep(1800, 900, 0.22) * sc.env_perc(0.22, 0.003, 2.0)
        sc.place(canvas, chirp, 0.1, 0.4)
        buzz = _buzz(0.3, 150, seed) * 0.25
        sc.place(canvas, buzz, 0.05, 0.3)
    canvas = sc.reverb(canvas, decay=0.5, mix=0.14, lowpass_hz=6000, seed=seed + 2)
    return sc.fade(canvas, 2.0, 60)


def melee_warning() -> np.ndarray:
    canvas = _canvas(0.75)
    growl = sc.saw(72, 0.6) * sc.env_ad(0.6, 0.02, 0.6)
    growl = sc.lowpass(growl, 500)
    growl = sc.saturate(growl, 2.5)
    sc.place(canvas, growl, 0.0, 0.55)
    creak = sc.resonant(sc.band_noise(0.5, 120, 1200, 161), 420, q=14) * 0.18
    creak *= sc.env_ad(0.5, 0.05, 0.7)
    sc.place(canvas, creak, 0.08, 0.35)
    rise = sc.sweep(180, 520, 0.45) * sc.env_ad(0.45, 0.1, 0.7) * 0.15
    sc.place(canvas, rise, 0.15, 0.25)
    canvas = sc.reverb(canvas, decay=0.55, mix=0.16, lowpass_hz=4500, seed=162)
    return sc.fade(canvas, 2.0, 60)


def broom_whoosh() -> np.ndarray:
    canvas = _canvas(0.42)
    air = sc.band_noise(0.3, 300, 3800, 171) * sc.env_perc(0.3, 0.01, 1.8)
    air = sc.resonant(air, 700, q=4)
    brush = sc.band_noise(0.24, 2200, 8000, 172) * sc.env_perc(0.24, 0.005, 2.0)
    sc.place(canvas, air, 0.0, 0.65)
    sc.place(canvas, brush, 0.03, 0.25)
    canvas = sc.reverb(canvas, decay=0.35, mix=0.1, lowpass_hz=6000, seed=173)
    return sc.fade(canvas, 1.5, 45)


def broom_hit() -> np.ndarray:
    canvas = _canvas(0.34)
    thump = sc.sweep(120, 48, 0.2) * sc.env_perc(0.2, 0.002, 3.0)
    brush = sc.band_noise(0.22, 1200, 6000, 181) * sc.env_perc(0.22, 0.003, 2.2)
    sc.place(canvas, thump, 0.0, 0.8)
    sc.place(canvas, brush, 0.01, 0.3)
    canvas = sc.reverb(canvas, decay=0.35, mix=0.1, lowpass_hz=5000, seed=182)
    return sc.fade(canvas, 1.0, 35)


def hurt_monster(variant: int = 0) -> np.ndarray:
    canvas = _canvas(0.3)
    seed = 191 + variant
    if variant == 2:
        glass = _glass_tick(seed, 0.16) * 0.7
        squeak = sc.sweep(1600, 2300, 0.12) * sc.env_perc(0.12, 0.003, 2.0)
        sc.place(canvas, glass, 0.0, 0.6)
        sc.place(canvas, squeak, 0.02, 0.18)
    else:
        grunt = sc.saw(120 - variant * 18, 0.22) * sc.env_ad(0.22, 0.004, 0.5)
        grunt = sc.lowpass(grunt, 1100)
        grunt = sc.saturate(grunt, 2.0)
        sc.place(canvas, grunt, 0.0, 0.45)
        tick = sc.sine(1200 + variant * 220, 0.04) * sc.env_perc(0.04, 0.001, 3.0)
        sc.place(canvas, tick, 0.0, 0.1)
    canvas = sc.reverb(canvas, decay=0.3, mix=0.1, lowpass_hz=6000, seed=seed + 1)
    return sc.fade(canvas, 1.0, 25)


def death_monster(glass: bool = False) -> np.ndarray:
    canvas = _canvas(1.1 if glass else 0.95)
    if glass:
        shards = _glass_tick(211, 0.5) * 0.6
        sc.place(canvas, shards, 0.0, 0.55)
        liquid = sc.band_noise(0.6, 300, 3000, 212) * sc.env_ad(0.6, 0.01, 0.6) * 0.25
        sc.place(canvas, liquid, 0.12, 0.3)
        drop = sc.sweep(180, 50, 0.5) * sc.env_perc(0.5, 0.005, 3.0)
        sc.place(canvas, drop, 0.1, 0.35)
    else:
        thud = sc.sweep(95, 40, 0.35) * sc.env_perc(0.35, 0.003, 3.0)
        sc.place(canvas, thud, 0.0, 0.7)
        power = sc.sweep(320, 45, 0.7) * sc.env_ad(0.7, 0.01, 0.5) * 0.3
        sc.place(canvas, power, 0.03, 0.3)
        cloth = sc.band_noise(0.5, 1200, 5000, 213) * sc.env_perc(0.5, 0.01, 2.0) * 0.18
        sc.place(canvas, cloth, 0.05, 0.3)
    canvas = sc.reverb(canvas, decay=0.7, mix=0.16, lowpass_hz=5000, seed=214)
    return sc.fade(canvas, 2.0, 80)


def idle_humanoid_loop() -> np.ndarray:
    duration, fade = 4.0, 0.6
    total = duration + fade
    canvas = _canvas(total)
    # 拖步
    for i, at in enumerate((0.9, 1.8, 2.7, 3.6)):
        step = sc.band_noise(0.18, 300, 2600, 221 + i) * sc.env_perc(0.18, 0.02, 2.0)
        thud = sc.sweep(90, 55, 0.12) * sc.env_perc(0.12, 0.01, 3.0)
        sc.place(canvas, step, at, 0.12)
        sc.place(canvas, thud, at, 0.16)
    cloth = sc.band_noise(total, 900, 4500, 225) * 0.04
    gear = sc.resonant(sc.band_noise(total, 200, 1400, 226), 380, q=10) * 0.06
    drone = sc.sine(58, total) * 0.05 + sc.sine(87, total) * 0.03
    canvas = sc.mix(canvas, cloth, gear, drone)
    return sc.loopify(canvas, duration, fade)


def idle_bug_loop() -> np.ndarray:
    duration, fade = 4.0, 0.6
    total = duration + fade
    canvas = _canvas(total)
    for i, at in enumerate((0.7, 1.1, 1.9, 2.6, 3.1, 3.7)):
        click = sc.crackle(0.08, 30, 231 + i, 1200, 9000) * 0.25
        sc.place(canvas, click, at, 0.35)
    crawl = sc.band_noise(total, 180, 1800, 237) * 0.07
    chirp = sc.resonant(sc.band_noise(total, 1200, 6000, 238), 2800, q=20) * 0.025
    canvas = sc.mix(canvas, crawl, chirp)
    return sc.loopify(canvas, duration, fade)


def ranged_charge() -> np.ndarray:
    canvas = _canvas(0.8)
    rise = sc.sweep(220, 1100, 0.7) * sc.env_ad(0.7, 0.05, 0.7) * 0.35
    hiss = sc.band_noise(0.7, 700, 6000, 241) * sc.env_ad(0.7, 0.05, 0.7) * 0.2
    sc.place(canvas, rise, 0.0, 0.4)
    sc.place(canvas, hiss, 0.0, 0.25)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=6000, seed=242)
    return sc.fade(canvas, 3.0, 50)


def ranged_spray() -> np.ndarray:
    canvas = _canvas(0.85)
    spray = sc.band_noise(0.6, 250, 5000, 251) * sc.env_ad(0.6, 0.02, 0.6)
    sputter = sc.crackle(0.6, 35, 252, 300, 5000)
    sc.place(canvas, spray, 0.05, 0.5)
    sc.place(canvas, sputter, 0.05, 0.25)
    canvas = sc.reverb(canvas, decay=0.45, mix=0.12, lowpass_hz=5500, seed=253)
    return sc.fade(canvas, 2.0, 60)


def ranged_land() -> np.ndarray:
    canvas = _canvas(0.5)
    splat = sc.band_noise(0.3, 180, 2800, 261) * sc.env_perc(0.3, 0.003, 2.0)
    thud = sc.sweep(120, 50, 0.18) * sc.env_perc(0.18, 0.002, 3.0)
    sc.place(canvas, splat, 0.0, 0.5)
    sc.place(canvas, thud, 0.0, 0.4)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=4500, seed=262)
    return sc.fade(canvas, 1.5, 50)


def heal_start() -> np.ndarray:
    canvas = _canvas(0.95)
    rise = sc.sine(330, 0.8) * sc.env_ad(0.8, 0.1, 0.6) * 0.3
    fifth = sc.sine(495, 0.8) * sc.env_ad(0.8, 0.12, 0.6) * 0.2
    shimmer = sc.band_noise(0.8, 3000, 9000, 271) * sc.env_ad(0.8, 0.2, 0.7) * 0.08
    sc.place(canvas, rise, 0.0, 0.4)
    sc.place(canvas, fifth, 0.05, 0.25)
    sc.place(canvas, shimmer, 0.05, 0.15)
    canvas = sc.reverb(canvas, decay=0.8, mix=0.18, lowpass_hz=7000, seed=272)
    return sc.fade(canvas, 10.0, 100)


def heal_loop() -> np.ndarray:
    duration, fade = 2.5, 0.5
    total = duration + fade
    t = sc.time_axis(total)
    pad = (sc.sine(330, total) * 0.22 + sc.sine(440, total) * 0.12
           + sc.sine(660, total) * 0.06)
    pad *= 0.7 + 0.3 * np.sin(2 * np.pi * (2 / duration) * t)
    shimmer = sc.band_noise(total, 4000, 10000, 281) * 0.035
    shimmer *= 0.6 + 0.4 * np.sin(2 * np.pi * (3 / duration) * t + 1.0)
    sig = pad + shimmer
    sig = sc.reverb(sig, decay=0.7, mix=0.2, lowpass_hz=7500, seed=282)
    return sc.loopify(sig, duration, fade)


def heal_end() -> np.ndarray:
    canvas = _canvas(0.55)
    fall = sc.sweep(520, 260, 0.4) * sc.env_ad(0.4, 0.01, 0.5) * 0.25
    sc.place(canvas, fall, 0.0, 0.4)
    canvas = sc.reverb(canvas, decay=0.5, mix=0.15, lowpass_hz=6000, seed=291)
    return sc.fade(canvas, 3.0, 60)


def energy_charge() -> np.ndarray:
    canvas = _canvas(0.95)
    rise = sc.sweep(120, 700, 0.8) * sc.env_ad(0.8, 0.05, 0.7) * 0.35
    buzz = _buzz(0.8, 60, 301) * 0.15
    spark = sc.crackle(0.7, 25, 302, 2000, 12000) * 0.18
    sc.place(canvas, rise, 0.0, 0.4)
    sc.place(canvas, buzz, 0.0, 0.2)
    sc.place(canvas, spark, 0.05, 0.25)
    canvas = sc.reverb(canvas, decay=0.45, mix=0.12, lowpass_hz=6500, seed=303)
    return sc.fade(canvas, 3.0, 60)


def energy_shield_hit() -> np.ndarray:
    canvas = _canvas(0.45)
    chime = _glass_tick(311, 0.3)
    sc.place(canvas, chime, 0.0, 0.55)
    zap = sc.band_noise(0.12, 2000, 10000, 312) * sc.env_perc(0.12, 0.001, 3.0)
    sc.place(canvas, zap, 0.0, 0.4)
    canvas = sc.reverb(canvas, decay=0.45, mix=0.16, lowpass_hz=8000, seed=313)
    return sc.fade(canvas, 1.0, 35)


def energy_disconnect() -> np.ndarray:
    canvas = _canvas(0.65)
    drop = sc.sweep(600, 60, 0.5) * sc.env_ad(0.5, 0.005, 0.5)
    crack = sc.crackle(0.3, 50, 321, 1000, 12000) * 0.35
    sc.place(canvas, drop, 0.0, 0.45)
    sc.place(canvas, crack, 0.0, 0.4)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.12, lowpass_hz=6000, seed=322)
    return sc.fade(canvas, 1.5, 50)


# ---------------------------------------------------------------------------
# 机械臂 Boss
# ---------------------------------------------------------------------------

def arm_idle_loop() -> np.ndarray:
    duration, fade = 3.0, 0.4
    total = duration + fade
    servo = _servo(total, 62, 0.2, 331) * 0.2
    hum = sc.sine(48, total) * 0.06 + sc.sine(96, total) * 0.03
    creak = sc.resonant(sc.band_noise(total, 160, 900, 332), 240, q=12) * 0.04
    sig = sc.mix(servo, hum, creak)
    return sc.loopify(sig, duration, fade)


def slam_charge() -> np.ndarray:
    canvas = _canvas(1.1)
    pressure = sc.brown_noise(0.9, 341) * sc.env_ad(0.9, 0.2, 0.7) * 0.35
    pressure = sc.lowpass(pressure, 260)
    sc.place(canvas, pressure, 0.0, 0.5)
    for i, at in enumerate((0.1, 0.32, 0.54, 0.76)):
        tick = _metal_tick(342 + i, 700, 0.05)
        sc.place(canvas, tick, at, 0.22 + i * 0.03)
    rise = sc.sweep(70, 140, 0.8) * sc.env_ad(0.8, 0.2, 0.7) * 0.15
    sc.place(canvas, rise, 0.1, 0.3)
    canvas = sc.reverb(canvas, decay=0.5, mix=0.12, lowpass_hz=3500, seed=346)
    return sc.fade(canvas, 5.0, 70)


def slam_impact() -> np.ndarray:
    canvas = _canvas(0.95)
    boom = sc.sweep(75, 32, 0.5) * sc.env_perc(0.5, 0.002, 3.0)
    sc.place(canvas, boom, 0.0, 0.9)
    metal = sc.metallic_hit(0.7, base=220, partials=7, decay=0.16, seed=351)
    metal *= sc.env_perc(0.7, 0.001, 2.2)
    sc.place(canvas, metal, 0.0, 0.45)
    debris = sc.crackle(0.5, 30, 352, 800, 8000) * 0.2
    sc.place(canvas, debris, 0.05, 0.35)
    canvas = sc.reverb(canvas, decay=0.7, mix=0.16, lowpass_hz=4000, seed=353)
    return sc.fade(canvas, 2.0, 80)


def sweep_warning() -> np.ndarray:
    canvas = _canvas(0.95)
    motor = _servo(0.7, 55, 0.6, 361) * 0.3
    sc.place(canvas, motor, 0.0, 0.4)
    for i, at in enumerate((0.1, 0.38, 0.66)):
        beep = sc.square(740, 0.12, duty=0.5) * sc.env_ar(0.12, 0.004, 0.04)
        sc.place(canvas, beep, at, 0.22)
    canvas = sc.reverb(canvas, decay=0.5, mix=0.14, lowpass_hz=5000, seed=362)
    return sc.fade(canvas, 2.0, 50)


def sweep() -> np.ndarray:
    canvas = _canvas(0.8)
    motor = _servo(0.55, 60, 0.8, 371) * 0.35
    whoosh = sc.band_noise(0.45, 200, 3500, 372) * sc.env_perc(0.45, 0.01, 1.8)
    sc.place(canvas, motor, 0.0, 0.4)
    sc.place(canvas, whoosh, 0.12, 0.55)
    canvas = sc.reverb(canvas, decay=0.4, mix=0.1, lowpass_hz=5000, seed=373)
    return sc.fade(canvas, 1.5, 50)


def arm_damage_shutdown() -> np.ndarray:
    canvas = _canvas(1.7)
    down = sc.sweep(180, 30, 1.2) * sc.env_ad(1.2, 0.01, 0.5)
    sc.place(canvas, down, 0.0, 0.45)
    jam = sc.resonant(sc.band_noise(0.8, 200, 3000, 381), 520, q=12) * 0.25
    jam *= sc.env_perc(0.8, 0.005, 2.0)
    sc.place(canvas, jam, 0.1, 0.4)
    crack = sc.crackle(0.6, 45, 382, 1000, 10000) * 0.3
    sc.place(canvas, crack, 0.15, 0.4)
    for i, at in enumerate((0.6, 0.85, 1.1)):
        relay = _metal_tick(383 + i, 500, 0.06)
        sc.place(canvas, relay, at, 0.25)
    canvas = sc.reverb(canvas, decay=1.0, mix=0.2, lowpass_hz=4500, seed=386)
    return sc.fade(canvas, 3.0, 100)


# ---------------------------------------------------------------------------
# 构建
# ---------------------------------------------------------------------------

def build() -> None:
    # 玩家
    for i in range(1, 4):
        render("player", f"pl_footstep_metal_{i:02d}.wav", footstep(10 + i), "PL-01",
               "player", "金属地板脚步，轻量变体", peak_db=-8.0)
    render("player", "pl_footstep_metal_heavy.wav", footstep(14, heavy=True), "PL-01",
           "player", "金属地板脚步，沉重变体", peak_db=-7.0)
    render("player", "pl_hurt.wav", hurt(), "PL-02", "player", "玩家受伤，短促清晰")
    render("player", "pl_death.wav", death(), "PL-03", "player", "玩家死亡失能音")
    render("player", "pl_pickup_heal.wav", pickup_heal(), "PL-04", "player", "生命恢复/补给拾取", peak_db=-6.0)
    render("player", "pl_low_health.wav", low_health(), "PL-05", "player", "低生命提示短脉冲", peak_db=-9.0)
    render("player", "pl_dash.wav", dash(), "PL-06", "player", "闪避/冲刺气流与衣料声", peak_db=-7.0)

    # 武器
    for i in range(3):
        render("weapons", f"wp_shoot_{i + 1:02d}.wav", shoot(61 + i * 3, i), "WP-01",
               "weapons", "能量步枪开火变体", peak_db=-2.0)
    render("weapons", "wp_hit_organic.wav", hit_organic(), "WP-02", "weapons", "子弹命中有机体")
    render("weapons", "wp_hit_metal.wav", hit_metal(), "WP-03", "weapons", "子弹命中金属")
    render("weapons", "wp_hit_glass.wav", hit_glass(), "WP-04", "weapons", "子弹命中玻璃")
    render("weapons", "wp_reload.wav", reload(), "WP-05", "weapons", "换弹机械流程", peak_db=-5.0)
    render("weapons", "wp_empty.wav", empty(), "WP-06", "weapons", "空弹/不能开火", peak_db=-6.0)
    render("weapons", "wp_charge_loop.wav", charge_loop(), "WP-07", "weapons",
           "武器充能升调循环", loop=True, peak_db=-8.0)
    render("weapons", "wp_overheat_warning.wav", overheat_warning(), "WP-07", "weapons",
           "武器过热警告", peak_db=-5.0)
    render("weapons", "wp_cooldown_complete.wav", cooldown_complete(), "WP-07", "weapons",
           "冷却完成提示", peak_db=-7.0)
    render("weapons", "wp_switch.wav", weapon_switch(), "WP-08", "weapons", "切换/获得武器", peak_db=-6.0)

    # 怪物
    render("enemies", "en_alert_01.wav", alert(0), "EN-01", "enemies", "怪物发现玩家，类人变体", peak_db=-5.0)
    render("enemies", "en_alert_02.wav", alert(1), "EN-01", "enemies", "怪物发现玩家，虫形变体", peak_db=-6.0)
    render("enemies", "en_melee_warning.wav", melee_warning(), "EN-02", "enemies",
           "近战怪攻击预警，伤害判定前", peak_db=-4.0)
    render("enemies", "en_broom_whoosh.wav", broom_whoosh(), "EN-03", "enemies", "扫帚挥击空气声", peak_db=-5.0)
    render("enemies", "en_broom_hit.wav", broom_hit(), "EN-04", "enemies", "扫帚命中闷击", peak_db=-3.0)
    render("enemies", "en_hurt_01.wav", hurt_monster(0), "EN-05", "enemies", "怪物受伤，有机体变体 A", peak_db=-5.0)
    render("enemies", "en_hurt_02.wav", hurt_monster(1), "EN-05", "enemies", "怪物受伤，有机体变体 B", peak_db=-5.0)
    render("enemies", "en_hurt_glass.wav", hurt_monster(2), "EN-05", "enemies", "玻璃罐怪受伤", peak_db=-6.0)
    render("enemies", "en_death.wav", death_monster(False), "EN-06", "enemies", "怪物死亡通用", peak_db=-4.0)
    render("enemies", "en_death_glass.wav", death_monster(True), "EN-06", "enemies", "玻璃罐怪死亡破裂", peak_db=-4.0)
    render("enemies", "en_idle_humanoid_loop.wav", idle_humanoid_loop(), "EN-07", "enemies",
           "类人怪待机拖步循环", loop=True, peak_db=-12.0)
    render("enemies", "en_idle_bug_loop.wav", idle_bug_loop(), "EN-07", "enemies",
           "虫形怪爬行循环", loop=True, peak_db=-12.0)
    render("enemies", "en_ranged_charge.wav", ranged_charge(), "EN-08", "enemies", "远程怪蓄力", peak_db=-5.0)
    render("enemies", "en_ranged_spray.wav", ranged_spray(), "EN-08", "enemies", "远程怪喷出", peak_db=-4.0)
    render("enemies", "en_ranged_land.wav", ranged_land(), "EN-08", "enemies", "远程液团落地", peak_db=-5.0)
    render("enemies", "en_heal_start.wav", heal_start(), "EN-09", "enemies", "医疗怪回血开始", peak_db=-7.0)
    render("enemies", "en_heal_loop.wav", heal_loop(), "EN-09", "enemies",
           "医疗怪回血持续循环", loop=True, peak_db=-14.0)
    render("enemies", "en_heal_end.wav", heal_end(), "EN-09", "enemies", "医疗怪回血结束/打断", peak_db=-7.0)
    render("enemies", "en_energy_charge.wav", energy_charge(), "EN-10", "enemies", "能源怪充能", peak_db=-5.0)
    render("enemies", "en_energy_shield_hit.wav", energy_shield_hit(), "EN-10", "enemies", "能源怪护盾命中", peak_db=-4.0)
    render("enemies", "en_energy_disconnect.wav", energy_disconnect(), "EN-10", "enemies", "能源连接断开", peak_db=-4.0)

    # 机械臂
    render("boss", "bo_arm_idle_loop.wav", arm_idle_loop(), "BO-01", "boss",
           "机械臂待机伺服循环", loop=True, peak_db=-13.0)
    render("boss", "bo_sweep_warning.wav", sweep_warning(), "BO-02", "boss",
           "机械臂横扫预警", peak_db=-4.0)
    render("boss", "bo_sweep.wav", sweep(), "BO-03", "boss", "机械臂横扫", peak_db=-3.0)
    render("boss", "bo_slam_charge.wav", slam_charge(), "BO-04", "boss", "机械臂砸击蓄力", peak_db=-4.0)
    render("boss", "bo_slam_impact.wav", slam_impact(), "BO-05", "boss", "机械臂砸地", peak_db=-2.0)
    render("boss", "bo_damage_shutdown.wav", arm_damage_shutdown(), "BO-06", "boss",
           "机械臂损坏/停机", peak_db=-4.0)
