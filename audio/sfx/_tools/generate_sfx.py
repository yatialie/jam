"""生成《太空循环》全部音效。

用法：
    python generate_sfx.py

输出：
    audio/sfx/<category>/*.wav
    audio/sfx/manifest.csv
"""

from __future__ import annotations

import collections
import os

import gen_combat
import gen_world
import sfx_registry


def main() -> None:
    sfx_registry.ROWS.clear()
    gen_combat.build()
    gen_world.build()
    manifest = sfx_registry.write_manifest()

    counts = collections.Counter(row["category"] for row in sfx_registry.ROWS)
    total_duration = sum(float(row["duration_s"]) for row in sfx_registry.ROWS)
    print(f"generated {len(sfx_registry.ROWS)} files")
    for category, count in sorted(counts.items()):
        print(f"  {category:10s} {count:3d}")
    print(f"total duration: {total_duration:.1f}s")
    print(f"manifest: {manifest}")

    missing = [row["file"] for row in sfx_registry.ROWS
               if not os.path.exists(os.path.join(sfx_registry.ROOT, row["file"]))]
    if missing:
        print("missing files:")
        for path in missing:
            print(f"  {path}")


if __name__ == "__main__":
    main()
