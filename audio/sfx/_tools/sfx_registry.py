"""音效输出登记与 manifest 生成。"""

from __future__ import annotations

import csv
import os

from sfx_core import write_wav

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ROWS: list[dict] = []


def render(folder: str, name: str, sound, sfx_id: str, category: str,
           description: str, loop: bool = False, peak_db: float = -3.0,
           stereo: bool = False) -> None:
    path = os.path.join(ROOT, folder, name)
    meta = write_wav(path, sound, peak_db=peak_db, stereo=stereo)
    ROWS.append({
        "id": sfx_id,
        "file": f"{folder}/{name}",
        "category": category,
        "description": description,
        "loop": "yes" if loop else "no",
        "loop_start": "0.000" if loop else "",
        "loop_end": f"{meta['duration']:.3f}" if loop else "",
        "duration_s": f"{meta['duration']:.3f}",
        "sample_rate": "48000",
        "channels": str(meta["channels"]),
        "peak_dbfs": f"{meta['peak_dbfs']:.2f}",
        "rms_dbfs": f"{meta['rms_dbfs']:.2f}",
    })


def write_manifest() -> str:
    path = os.path.join(ROOT, "manifest.csv")
    fields = ["id", "file", "category", "description", "loop", "loop_start",
              "loop_end", "duration_s", "sample_rate", "channels",
              "peak_dbfs", "rms_dbfs"]
    with open(path, "w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(ROWS)
    return path
