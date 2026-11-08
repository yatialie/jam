"""批量检查音效文件的技术指标。"""

from __future__ import annotations

import csv
import os

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def spectral_centroid(x: np.ndarray, sr: int) -> float:
    if x.ndim > 1:
        x = x.mean(axis=1)
    spec = np.abs(np.fft.rfft(x))
    freqs = np.fft.rfftfreq(x.size, 1.0 / sr)
    total = np.sum(spec)
    if total < 1e-12:
        return 0.0
    return float(np.sum(freqs * spec) / total)


def main() -> None:
    with open(os.path.join(ROOT, "manifest.csv"), encoding="utf-8-sig") as fh:
        rows = list(csv.DictReader(fh))

    issues = []
    max_peak = -999.0
    min_peak = 999.0
    total_duration = 0.0

    for row in rows:
        path = os.path.join(ROOT, row["file"])
        x, sr = sf.read(path, always_2d=False)
        x = np.asarray(x)
        duration = x.shape[0] / sr
        total_duration += duration
        peak = float(np.max(np.abs(x)))
        peak_db = 20.0 * np.log10(max(peak, 1e-12))
        rms = float(np.sqrt(np.mean(np.square(x))))
        rms_db = 20.0 * np.log10(max(rms, 1e-12))
        max_peak = max(max_peak, peak_db)
        min_peak = min(min_peak, peak_db)

        if not np.isfinite(x).all():
            issues.append((row["file"], "non-finite samples"))
        if peak_db > -0.3:
            issues.append((row["file"], f"hot peak {peak_db:.2f} dBFS"))
        if rms_db < -55.0:
            issues.append((row["file"], f"very low RMS {rms_db:.1f} dBFS"))
        if duration < 0.05:
            issues.append((row["file"], f"too short {duration:.3f}s"))
        if abs(float(np.mean(x))) > 0.02:
            issues.append((row["file"], f"DC offset {float(np.mean(x)):.3f}"))
        if row["loop"] == "yes":
            head = x[: int(0.02 * sr)]
            tail = x[-int(0.02 * sr):]
            if x.ndim > 1:
                jump = max(
                    abs(float(head[0, c] - tail[-1, c]))
                    for c in range(x.shape[1])
                )
                head_rms = np.sqrt(np.mean(head ** 2, axis=0))
                tail_rms = np.sqrt(np.mean(tail ** 2, axis=0))
                level_diff = float(np.max(np.abs(
                    20.0 * np.log10((head_rms + 1e-9) / (tail_rms + 1e-9))
                )))
            else:
                jump = abs(float(head[0] - tail[-1]))
                head_rms = np.sqrt(np.mean(head ** 2))
                tail_rms = np.sqrt(np.mean(tail ** 2))
                level_diff = abs(20.0 * np.log10((head_rms + 1e-9) / (tail_rms + 1e-9)))
            if jump > 0.12:
                issues.append((row["file"], f"loop seam jump {jump:.3f}"))
            if level_diff > 6.0:
                issues.append((row["file"], f"loop seam level mismatch {level_diff:.1f} dB"))

    print(f"checked {len(rows)} files, total {total_duration:.1f}s")
    print(f"peak range: {min_peak:.2f} .. {max_peak:.2f} dBFS")
    if issues:
        print(f"issues: {len(issues)}")
        for name, message in issues:
            print(f"  {name}: {message}")
    else:
        print("issues: none")


if __name__ == "__main__":
    main()
