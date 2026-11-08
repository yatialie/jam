"""把 Suno v6 生成的原始素材切片成最终音效库。"""

from __future__ import annotations

import csv
import json
import os
import subprocess
import tempfile

import librosa
import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OLD_MANIFEST = r"c:\Users\aiail\Documents\jam\audio\sfx\manifest.csv"
PLAN = os.path.join(ROOT, "_batch", "plan.json")
RAW = os.path.join(ROOT, "_raw")
OUT = ROOT
FFMPEG = r"C:\H5视频项目\node_modules\@ffmpeg-installer\win32-x64\ffmpeg.exe"
SR = 48000

ONE_SHOT = {
    "pl_footstep_metal_01", "pl_footstep_metal_02", "pl_footstep_metal_03",
    "pl_footstep_metal_heavy", "wp_shoot_01", "wp_shoot_02", "wp_shoot_03",
    "wp_hit_organic", "wp_hit_metal", "wp_hit_glass", "wp_empty",
    "en_alert_01", "en_alert_02", "en_broom_whoosh", "en_broom_hit",
    "en_hurt_01", "en_hurt_02", "en_hurt_glass", "en_ranged_spray",
    "en_ranged_land", "en_energy_shield_hit", "en_energy_disconnect",
    "ob_facility_hit_01", "ob_facility_hit_02", "ob_glass_break",
    "pu_click", "pu_rotate_01", "pu_rotate_02", "pu_error",
    "ui_menu_select", "ui_menu_confirm", "ui_menu_back", "ui_objective_update",
    "pl_low_health",
}

DURATIONS = {
    "pl_footstep_metal_01": 0.35, "pl_footstep_metal_02": 0.35,
    "pl_footstep_metal_03": 0.35, "pl_footstep_metal_heavy": 0.4,
    "pl_hurt": 0.5, "pl_death": 1.8, "pl_pickup_heal": 0.9,
    "pl_low_health": 0.8, "pl_dash": 0.45,
    "wp_shoot_01": 0.5, "wp_shoot_02": 0.5, "wp_shoot_03": 0.5,
    "wp_hit_organic": 0.4, "wp_hit_metal": 0.45, "wp_hit_glass": 0.4,
    "wp_reload": 0.9, "wp_empty": 0.3, "wp_overheat_warning": 1.3,
    "wp_cooldown_complete": 0.9, "wp_switch": 0.7,
    "en_alert_01": 0.85, "en_alert_02": 0.85, "en_melee_warning": 1.0,
    "en_broom_whoosh": 0.5, "en_broom_hit": 0.45, "en_hurt_01": 0.5,
    "en_hurt_02": 0.5, "en_hurt_glass": 0.5, "en_death": 1.4,
    "en_death_glass": 1.4, "en_ranged_charge": 0.9, "en_ranged_spray": 0.9,
    "en_ranged_land": 0.6, "en_heal_start": 1.1, "en_heal_end": 0.8,
    "en_energy_charge": 1.0, "en_energy_shield_hit": 0.5,
    "en_energy_disconnect": 0.9,
    "bo_sweep_warning": 1.1, "bo_sweep": 0.9, "bo_slam_charge": 1.3,
    "bo_slam_impact": 1.1, "bo_damage_shutdown": 2.0,
    "ob_mechanism_start": 1.3, "ob_mechanism_stop": 1.1,
    "ob_facility_hit_01": 0.45, "ob_facility_hit_02": 0.45,
    "ob_facility_destroy": 1.6, "ob_glass_break": 1.2, "ob_container_release": 1.6,
    "ob_fuel_explosion": 2.0, "ob_explosion_warning": 1.1,
    "ob_vacuum_start": 1.1, "ob_vacuum_stop": 0.9, "ob_door_open": 1.6,
    "ob_door_close": 1.4, "ob_lock_denied": 0.5, "ob_unlock": 0.8,
    "pu_terminal_enter": 1.1, "pu_terminal_exit": 0.8, "pu_click": 0.25,
    "pu_rotate_01": 0.3, "pu_rotate_02": 0.3, "pu_step_correct": 0.5,
    "pu_error": 0.5, "pu_puzzle_complete": 1.2, "pu_clue_get": 0.9,
    "pu_broadcast_start": 1.1, "pu_broadcast_end": 0.8,
    "st_death_rewind": 1.9, "st_respawn": 0.9, "st_cycle_start": 1.6,
    "st_story_anomaly": 2.0, "st_ending_clear": 4.0, "st_ending_failure": 3.0,
    "ui_menu_select": 0.2, "ui_menu_confirm": 0.45, "ui_menu_back": 0.45,
    "ui_pause": 0.9, "ui_resume": 0.8, "ui_objective_update": 0.55,
}

LOOP_DURATIONS = {
    "wp_charge_loop": 2.0, "en_idle_humanoid_loop": 4.0, "en_idle_bug_loop": 4.0,
    "en_heal_loop": 2.5, "bo_arm_idle_loop": 3.0, "ob_leak_spark_loop": 3.0,
    "ob_vacuum_loop": 3.0, "pu_signal_tune_loop": 6.0,
    "st_cycle_distortion_loop": 10.0,
    "amb_ship_vent_loop": 24.0, "amb_cockpit_living_loop": 24.0,
    "amb_storage_loop": 24.0, "amb_sanitation_loop": 24.0,
    "amb_comms_loop": 24.0, "amb_medical_loop": 24.0,
    "amb_life_energy_loop": 24.0, "amb_fuel_loop": 24.0,
    "amb_anomaly_hull_resonance_loop": 12.0,
    "amb_anomaly_lighting_fault_loop": 12.0,
    "amb_anomaly_damaged_alarm_loop": 12.0,
}

LOOP_PEAK_DB = {
    "amb_ship_vent_loop": -12.0, "amb_cockpit_living_loop": -12.0,
    "amb_storage_loop": -12.0, "amb_sanitation_loop": -12.0,
    "amb_comms_loop": -12.0, "amb_medical_loop": -12.0,
    "amb_life_energy_loop": -12.0, "amb_fuel_loop": -12.0,
    "amb_anomaly_hull_resonance_loop": -15.0,
    "amb_anomaly_lighting_fault_loop": -15.0,
    "amb_anomaly_damaged_alarm_loop": -14.0,
}


def decode(path: str, stereo: bool) -> np.ndarray:
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        subprocess.run(
            [FFMPEG, "-y", "-loglevel", "error", "-i", path, "-ar", str(SR),
             "-ac", "2" if stereo else "1", "-c:a", "pcm_s24le", tmp],
            check=True,
        )
        data, _ = sf.read(tmp, dtype="float64", always_2d=stereo)
        return data
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass


def db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-12))


def normalize(x: np.ndarray, peak_db: float) -> np.ndarray:
    peak = float(np.max(np.abs(x))) if x.size else 0.0
    if peak < 1e-12:
        return x
    return x * (10.0 ** (peak_db / 20.0) / peak)


def fade(x: np.ndarray, in_ms: float = 3.0, out_ms: float = 30.0) -> np.ndarray:
    y = x.copy()
    n_in = min(int(SR * in_ms / 1000.0), y.shape[0] // 2)
    n_out = min(int(SR * out_ms / 1000.0), y.shape[0] // 2)
    if n_in > 0:
        shape = (n_in,) + (1,) * (y.ndim - 1)
        y[:n_in] *= np.linspace(0, 1, n_in).reshape(shape) ** 0.6
    if n_out > 0:
        shape = (n_out,) + (1,) * (y.ndim - 1)
        y[-n_out:] *= np.linspace(1, 0, n_out).reshape(shape) ** 1.4
    return y


def trim_silence(x: np.ndarray, threshold_db: float = -48.0,
                 pre: float = 0.01, post: float = 0.04) -> np.ndarray:
    mono = x.mean(axis=1) if x.ndim > 1 else x
    frame, hop = 960, 480
    if mono.size < frame:
        return x
    count = 1 + (mono.size - frame) // hop
    rms = np.array([np.sqrt(np.mean(mono[i * hop:i * hop + frame] ** 2))
                    for i in range(count)])
    active = np.where(rms > 10.0 ** (threshold_db / 20.0))[0]
    if active.size == 0:
        return x
    start = max(0, active[0] * hop - int(pre * SR))
    end = min(mono.size, (active[-1] + 1) * hop + int(post * SR))
    return x[start:end]


def best_onset(x: np.ndarray) -> int:
    mono = x.mean(axis=1) if x.ndim > 1 else x
    onsets = librosa.onset.onset_detect(
        y=mono, sr=SR, hop_length=256, units="samples", backtrack=True
    )
    if len(onsets) == 0:
        return int(np.argmax(np.abs(mono)))
    best, best_score = int(onsets[0]), -1.0
    for onset in onsets:
        seg = mono[onset:onset + int(0.25 * SR)]
        if seg.size == 0:
            continue
        score = float(np.sqrt(np.mean(seg ** 2)) + 0.2 * np.max(np.abs(seg)))
        if score > best_score:
            best_score = score
            best = int(onset)
    return best


def slice_channels(x: np.ndarray, start: int, end: int) -> np.ndarray:
    return x[start:end].copy()


def make_one_shot(x: np.ndarray, max_dur: float) -> np.ndarray:
    x = trim_silence(x)
    if x.size == 0:
        return x
    onset = best_onset(x)
    start = max(0, onset - int(0.006 * SR))
    end = min(x.shape[0], start + int(max_dur * SR))
    seg = slice_channels(x, start, end)
    seg = trim_silence(seg, -50.0, 0.002, 0.02)
    return fade(seg)


def make_whole(x: np.ndarray, max_dur: float) -> np.ndarray:
    x = trim_silence(x)
    if x.size == 0:
        return x
    end = min(x.shape[0], int(max_dur * SR))
    seg = x[:end].copy()
    seg = trim_silence(seg, -50.0, 0.002, 0.03)
    return fade(seg)


def make_loop(x: np.ndarray, target: float) -> np.ndarray:
    fade_sec = min(1.5, max(0.4, target * 0.15))
    n, f = int(target * SR), int(fade_sec * SR)
    if x.shape[0] < n + f:
        if x.ndim > 1:
            reps = int(np.ceil((n + f) / x.shape[0]))
            x = np.tile(x, (reps, 1))
        else:
            reps = int(np.ceil((n + f) / x.shape[0]))
            x = np.tile(x, reps)
    max_start = max(0, x.shape[0] - (n + f))
    start = min(int(x.shape[0] * 0.1), max_start)
    seg = x[start:start + n + f].copy()
    curve = np.linspace(0.0, 1.0, f)
    if seg.ndim > 1:
        head = seg[:f].copy()
        tail = seg[n:n + f]
        seg[:f] = head * curve[:, None] + tail * (1.0 - curve[:, None])
    else:
        head = seg[:f].copy()
        tail = seg[n:n + f]
        seg[:f] = head * curve + tail * (1.0 - curve)
    return seg[:n]


def choose_raw(stem: str) -> str | None:
    for i in range(4):
        path = os.path.join(RAW, f"{stem}_{i}.m4a")
        if os.path.exists(path) and os.path.getsize(path) > 1000:
            return path
    return None


def main() -> None:
    plan = json.load(open(PLAN, encoding="utf-8"))
    old = {row["file"]: row for row in csv.DictReader(
        open(OLD_MANIFEST, encoding="utf-8-sig"))}

    rows = []
    for entry in plan:
        file = entry["file"]
        stem = os.path.splitext(os.path.basename(file))[0]
        raw = choose_raw(stem)
        if not raw:
            print(f"MISSING RAW {file}")
            continue
        is_loop = bool(entry["loop"])
        x = decode(raw, stereo=is_loop)
        if is_loop:
            target = LOOP_DURATIONS.get(stem, 8.0)
            out = make_loop(x, target)
            peak = LOOP_PEAK_DB.get(stem, -10.0)
            out = normalize(out, peak)
            channels = 2 if out.ndim > 1 else 1
        elif stem in ONE_SHOT:
            out = make_one_shot(x, DURATIONS.get(stem, 0.6))
            out = normalize(out, -3.0)
            channels = 1 if out.ndim == 1 else 2
        else:
            out = make_whole(x, DURATIONS.get(stem, 1.0))
            out = normalize(out, -3.0)
            channels = 1 if out.ndim == 1 else 2

        out_path = os.path.join(OUT, file)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        sf.write(out_path, out.astype(np.float32), SR, subtype="PCM_24")

        peak = float(np.max(np.abs(out)))
        rms = float(np.sqrt(np.mean(np.square(out))))
        old_row = old[file]
        rows.append({
            "id": old_row["id"],
            "file": file,
            "category": old_row["category"],
            "description": old_row["description"],
            "loop": "yes" if is_loop else "no",
            "loop_start": "0.000" if is_loop else "",
            "loop_end": f"{out.shape[0] / SR:.3f}" if is_loop else "",
            "duration_s": f"{out.shape[0] / SR:.3f}",
            "sample_rate": str(SR),
            "channels": str(channels),
            "peak_dbfs": f"{db(peak):.2f}",
            "rms_dbfs": f"{db(rms):.2f}",
            "source": "suno-v6",
        })
        print(f"BUILD {file}: {out.shape[0] / SR:.2f}s ch={channels} peak={db(peak):.1f}")

    with open(os.path.join(OUT, "manifest.csv"), "w", newline="", encoding="utf-8-sig") as fh:
        fields = ["id", "file", "category", "description", "loop", "loop_start",
                  "loop_end", "duration_s", "sample_rate", "channels",
                  "peak_dbfs", "rms_dbfs", "source"]
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} files")


if __name__ == "__main__":
    main()
