"""从 manifest.csv 生成可试听的本地预览页。"""

from __future__ import annotations

import csv
import html
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

CATEGORY_LABELS = {
    "player": "玩家",
    "weapons": "武器与射击",
    "enemies": "怪物",
    "boss": "机械臂 BOSS",
    "objects": "机关 / 破坏 / 房门",
    "puzzle": "解谜与交互",
    "ambience": "七舱环境循环",
    "state": "死亡回退 / 循环 / 剧情",
    "ui": "界面",
}

CATEGORY_ORDER = ["player", "weapons", "enemies", "boss", "objects",
                  "puzzle", "ambience", "state", "ui"]


def main() -> None:
    with open(os.path.join(ROOT, "manifest.csv"), encoding="utf-8-sig") as fh:
        rows = list(csv.DictReader(fh))

    grouped: dict[str, list[dict]] = {key: [] for key in CATEGORY_ORDER}
    for row in rows:
        grouped.setdefault(row["category"], []).append(row)

    total_duration = sum(float(row["duration_s"]) for row in rows)
    loop_count = sum(1 for row in rows if row["loop"] == "yes")

    sections = []
    for category in CATEGORY_ORDER:
        items = grouped.get(category, [])
        if not items:
            continue
        cards = []
        for row in items:
            badge = '<span class="badge loop">LOOP</span>' if row["loop"] == "yes" else ""
            cards.append(f"""
            <article class="card">
              <div class="meta">
                <div class="line1"><span class="id">{html.escape(row['id'])}</span>
                  <span class="name">{html.escape(os.path.basename(row['file']))}</span>{badge}</div>
                <div class="desc">{html.escape(row['description'])}</div>
                <div class="tech">{row['duration_s']}s · {row['channels']}ch · peak {row['peak_dbfs']} dBFS</div>
              </div>
              <audio controls preload="none" src="{html.escape(row['file'])}"></audio>
            </article>""")
        sections.append(f"""
        <section>
          <h2>{CATEGORY_LABELS.get(category, category)}<span class="count">{len(items)}</span></h2>
          <div class="grid">{''.join(cards)}</div>
        </section>""")

    page = f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SPACE LOOP // SFX LIBRARY</title>
<style>
  :root {{
    --bg: #080d13;
    --panel: rgba(16, 26, 36, 0.82);
    --line: rgba(57, 214, 232, 0.22);
    --cyan: #39d6e8;
    --amber: #f2a63b;
    --text: #dce8ef;
    --dim: #7f96a6;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 40px 32px 80px;
    background:
      radial-gradient(circle at 20% 0%, rgba(57,214,232,.08), transparent 42%),
      repeating-linear-gradient(0deg, rgba(255,255,255,.025) 0 1px, transparent 1px 4px),
      var(--bg);
    color: var(--text);
    font-family: "Bahnschrift", "Microsoft YaHei", "Segoe UI", sans-serif;
  }}
  header {{ max-width: 1180px; margin: 0 auto 28px; border-bottom: 1px solid var(--line); padding-bottom: 18px; }}
  .kicker {{ color: var(--cyan); letter-spacing: .28em; font-size: 12px; }}
  h1 {{ margin: 8px 0 6px; font-size: 40px; letter-spacing: .08em; font-weight: 600; }}
  .sub {{ color: var(--dim); font-size: 13px; letter-spacing: .08em; }}
  .stats {{ margin-top: 14px; color: var(--amber); font-size: 13px; letter-spacing: .1em; }}
  section {{ max-width: 1180px; margin: 34px auto 0; }}
  h2 {{
    display: flex; align-items: center; gap: 12px;
    font-size: 16px; letter-spacing: .18em; color: var(--cyan);
    border-left: 3px solid var(--cyan); padding-left: 12px; margin-bottom: 14px;
  }}
  h2 .count {{ color: var(--dim); font-size: 12px; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(520px, 1fr)); gap: 10px; }}
  .card {{
    display: flex; align-items: center; gap: 14px;
    background: var(--panel); border: 1px solid var(--line);
    padding: 10px 14px; border-radius: 2px;
  }}
  .meta {{ flex: 1; min-width: 0; }}
  .line1 {{ display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }}
  .id {{ color: var(--amber); font-size: 11px; letter-spacing: .12em; }}
  .name {{ font-size: 13px; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 300px; }}
  .badge {{ font-size: 9px; letter-spacing: .14em; padding: 2px 5px; border: 1px solid var(--line); color: var(--dim); }}
  .badge.loop {{ color: var(--cyan); border-color: rgba(57,214,232,.5); }}
  .desc {{ color: var(--dim); font-size: 12px; margin-top: 3px; }}
  .tech {{ color: rgba(127,150,166,.7); font-size: 10px; margin-top: 3px; letter-spacing: .04em; }}
  audio {{ width: 220px; height: 32px; filter: invert(.86) hue-rotate(160deg); flex: none; }}
  @media (max-width: 640px) {{
    body {{ padding: 24px 14px 60px; }}
    h1 {{ font-size: 28px; }}
    .grid {{ grid-template-columns: 1fr; }}
    .card {{ flex-direction: column; align-items: stretch; }}
    audio {{ width: 100%; }}
  }}
</style>
</head>
<body>
<header>
  <div class="kicker">SPACE LOOP // SUNO V6 // SFX LIBRARY</div>
  <h1>舱室音效库 // SUNO V6</h1>
  <div class="sub">Suno v6 生成 + 瞬态切片 / 循环化 · 48 kHz / 24-bit WAV · 单发单声道 · 环境循环立体声</div>
  <div class="stats">{len(rows)} FILES · {loop_count} LOOPS · {total_duration:.1f}s TOTAL</div>
</header>
{''.join(sections)}
</body>
</html>"""

    out = os.path.join(ROOT, "preview.html")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(out)


if __name__ == "__main__":
    main()
