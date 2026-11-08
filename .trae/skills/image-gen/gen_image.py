#!/usr/bin/env python3
"""项目级生图 CLI：固定走 api.openai-next.com 的 gpt-image-2.5 通道。

用法示例：
    python .trae/skills/image-gen/gen_image.py --preset prop --name cargo_crate \
        --prompt "heavy reinforced cargo crate with cyan status strip" --candidates 4

密钥读取顺序：环境变量 IMAGE_API_KEY -> config.local.json -> config.json。
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import sys
import time
import uuid
import urllib.error
import urllib.request
from datetime import datetime

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SKILL_DIR, "..", "..", ".."))
MODEL_LOCK = "gpt-image-2.5"
GENERATED_ROOT = os.path.join(PROJECT_ROOT, "art_placeholder", "_generated")


def load_json(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def build_config() -> dict:
    cfg = load_json(os.path.join(SKILL_DIR, "config.json"))
    cfg.update(load_json(os.path.join(SKILL_DIR, "config.local.json")))
    cfg["api_key"] = os.environ.get("IMAGE_API_KEY") or cfg.get("api_key", "")
    return cfg


def compose_prompt(cfg: dict, preset_key: str, prompt: str) -> str:
    preset = cfg.get("presets", {}).get(preset_key, {})
    body = ", ".join(
        part.strip(" ,")
        for part in (cfg.get("common_prefix", ""), preset.get("prefix", ""), prompt)
        if part and part.strip(" ,")
    )
    if "negative_override" in preset:
        avoid = str(preset.get("negative_override", "")).strip(" ,")
    else:
        avoid = ", ".join(
            part.strip(" ,")
            for part in (cfg.get("common_negative", ""), preset.get("negative", ""))
            if part and part.strip(" ,")
        )
    if avoid:
        body += ". Avoid: " + avoid
    return body


def http_json(url: str, key: str, payload: dict, timeout: int) -> dict:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) image-gen-skill",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_multipart(url: str, key: str, fields: dict, files: list[str], timeout: int) -> dict:
    boundary = uuid.uuid4().hex
    body = bytearray()
    for name, value in fields.items():
        body += (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n"
        ).encode("utf-8")
    for path in files:
        filename = os.path.basename(path)
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        body += (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="image"; filename="{filename}"\r\n'
            f"Content-Type: {ctype}\r\n\r\n"
        ).encode("utf-8")
        with open(path, "rb") as fh:
            body += fh.read()
        body += b"\r\n"
    body += f"--{boundary}--\r\n".encode("utf-8")

    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Accept": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) image-gen-skill",
    }
    req = urllib.request.Request(url, data=bytes(body), headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def request_with_retry(fn, timeout: int, attempts: int = 3) -> dict:
    for attempt in range(1, attempts + 1):
        try:
            return fn()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            retryable = exc.code in (408, 429, 500, 502, 503, 504)
            print(f"[warn] HTTP {exc.code}（第 {attempt}/{attempts} 次）：{detail[:300]}", file=sys.stderr)
            if not retryable or attempt == attempts:
                raise SystemExit(f"生图请求失败：HTTP {exc.code}\n{detail[:2000]}")
            time.sleep(5 * attempt)
        except (urllib.error.URLError, TimeoutError) as exc:
            print(f"[warn] 网络错误（第 {attempt}/{attempts} 次）：{exc}", file=sys.stderr)
            if attempt == attempts:
                raise SystemExit(f"生图请求失败：{exc}")
            time.sleep(5 * attempt)
    raise SystemExit("生图请求失败")


def fetch_image(item: dict, timeout: int) -> bytes:
    b64 = item.get("b64_json")
    if b64:
        return base64.b64decode(b64)
    url = item.get("url")
    if not url:
        raise SystemExit(f"响应中没有图片数据：{json.dumps(item)[:400]}")
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return resp.read()


def sanitize(name: str) -> str:
    cleaned = re.sub(r"[^\w\-]+", "_", name.strip())
    return cleaned.strip("_") or "image"


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    cfg = build_config()
    if cfg.get("model") != MODEL_LOCK:
        raise SystemExit(f"配置被改动：本通道只允许 {MODEL_LOCK}，当前为 {cfg.get('model')!r}")

    parser = argparse.ArgumentParser(description="项目生图通道（固定 gpt-image-2.5）")
    parser.add_argument("--prompt", "-p", required=True, help="英文画面描述，具体、可视觉化")
    parser.add_argument("--name", "-n", default="image", help="输出文件名前缀（snake_case）")
    parser.add_argument("--preset", default=cfg.get("default_preset", "env"),
                        choices=sorted(cfg.get("presets", {}).keys()), help="风格预设")
    parser.add_argument("--candidates", "-c", type=int, default=cfg.get("default_candidates", 4),
                        help="同提示词生成几张候选（默认 4）")
    parser.add_argument("--size", default=cfg.get("default_size", "1024x1024"),
                        help="尺寸，如 1024x1024 / 1536x1024 / 1024x1536")
    parser.add_argument("--out", help="输出目录（默认 art_placeholder/_generated/<preset>/<日期>）")
    parser.add_argument("--reference", action="append", default=[],
                        help="参考图路径，可重复；使用 /v1/images/edits 保持风格一致")
    parser.add_argument("--transparent", action="store_true", help="请求透明背景（PNG）")
    parser.add_argument("--json", action="store_true", help="只输出 JSON 结果")
    args = parser.parse_args()

    key = cfg.get("api_key", "")
    if not key:
        raise SystemExit("缺少 API Key：请写入 config.local.json 或设置 IMAGE_API_KEY")

    for ref in args.reference:
        if not os.path.exists(ref):
            raise SystemExit(f"参考图不存在：{ref}")
    if len(args.reference) > 4:
        raise SystemExit("参考图最多 4 张")

    preset = args.preset
    out_dir = args.out or os.path.join(GENERATED_ROOT, preset, datetime.now().strftime("%Y%m%d"))
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    if out_dir.startswith(GENERATED_ROOT):
        ignore = os.path.join(GENERATED_ROOT, ".gdignore")
        if not os.path.exists(ignore):
            with open(ignore, "w", encoding="utf-8") as fh:
                fh.write("")

    final_prompt = compose_prompt(cfg, preset, args.prompt)
    base_url = cfg["base_url"].rstrip("/")
    timeout = int(cfg.get("timeout_seconds", 300))
    stem = sanitize(args.name)
    candidates = max(1, args.candidates)

    if not args.json:
        print(f"模型：{MODEL_LOCK}　预设：{preset}　尺寸：{args.size}　候选：{candidates}")
        print(f"输出：{out_dir}")
        if args.reference:
            print("参考图：" + " | ".join(args.reference))

    fields = {"model": MODEL_LOCK, "prompt": final_prompt, "size": args.size}
    if args.transparent:
        fields["background"] = "transparent"
        fields["output_format"] = "png"

    saved = []
    for index in range(1, candidates + 1):
        if args.reference:
            result = request_with_retry(
                lambda: http_multipart(f"{base_url}/v1/images/edits", key, fields, args.reference, timeout),
                timeout,
            )
        else:
            payload = dict(fields)
            payload["n"] = 1
            result = request_with_retry(
                lambda: http_json(f"{base_url}/v1/images/generations", key, payload, timeout),
                timeout,
            )

        items = result.get("data") or []
        if not items:
            raise SystemExit(f"响应异常：{json.dumps(result, ensure_ascii=False)[:800]}")
        data = fetch_image(items[0], timeout)
        path = os.path.join(out_dir, f"{stem}_v{index}.png")
        with open(path, "wb") as fh:
            fh.write(data)
        saved.append(path)
        if not args.json:
            print(f"  [{index}/{candidates}] {path}")

    meta_path = os.path.join(out_dir, f"{stem}_meta.json")
    meta = {
        "model": MODEL_LOCK,
        "preset": preset,
        "size": args.size,
        "candidates": candidates,
        "reference": args.reference,
        "user_prompt": args.prompt,
        "final_prompt": final_prompt,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "files": saved,
    }
    with open(meta_path, "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)

    if args.json:
        print(json.dumps(meta, ensure_ascii=False, indent=2))
    else:
        print(f"完成，共 {len(saved)} 张。元数据：{meta_path}")


if __name__ == "__main__":
    main()
