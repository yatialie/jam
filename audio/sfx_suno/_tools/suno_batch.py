"""Suno v6 音效批量任务：提交、轮询、下载。"""

from __future__ import annotations

import argparse
import json
import os
import time
import urllib.error
import urllib.request

API = "https://api.openai-next.com"
KEY = os.environ.get("SUNO_API_KEY", "")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
HEADERS = {
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
    "User-Agent": UA,
}

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PLAN = os.path.join(ROOT, "_batch", "plan.json")
STATE = os.path.join(ROOT, "_batch", "tasks.json")
RAW = os.path.join(ROOT, "_raw")


def load_json(path: str):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    return None


def save_json(path: str, data) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def request_json(path: str, payload=None, timeout: int = 120):
    data = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(API + path, data=data, headers=HEADERS,
                                 method="POST" if payload is not None else "GET")
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError:
            raise
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            time.sleep(2.0 * (attempt + 1))
    raise last_error


def submit(limit: int, batch_delay: float) -> None:
    plan = load_json(PLAN)
    state = load_json(STATE) or {}
    count = 0
    for entry in plan:
        if count >= limit:
            break
        file = entry["file"]
        if state.get(file, {}).get("task"):
            continue
        if entry["mode"] == "20":
            payload = {
                "model": "suno-v6",
                "input_type": "20",
                "prompt": "[Instrumental]",
                "tags": entry["tags"],
                "title": entry["title"],
                "make_instrumental": True,
            }
        else:
            payload = {
                "model": "suno-v6",
                "input_type": "10",
                "gpt_description_prompt": entry["prompt"],
                "make_instrumental": True,
            }

        for attempt in range(3):
            try:
                r = request_json("/suno-music/submit/music", payload)
                if r.get("code") != "success":
                    raise RuntimeError(r.get("message", str(r)))
                state[file] = {
                    "task": r["data"],
                    "id": entry["id"],
                    "status": "submitted",
                    "mode": entry["mode"],
                    "title": entry["title"],
                    "submitted_at": time.time(),
                }
                print(f"SUBMIT {entry['id']} {file} -> {r['data']}")
                break
            except Exception as exc:  # noqa: BLE001
                print(f"SUBMIT FAIL {file} attempt {attempt + 1}: {exc}")
                if attempt == 2:
                    state[file] = {"status": "submit_failed", "error": str(exc)}
                else:
                    time.sleep(20)
        save_json(STATE, state)
        count += 1
        time.sleep(batch_delay)


def poll(timeout_min: float, interval: float) -> None:
    state = load_json(STATE) or {}
    pending = [f for f, e in state.items()
               if e.get("task") and e.get("status") in ("submitted", "in_progress")]
    print(f"polling {len(pending)} tasks")
    start = time.time()
    while pending and (time.time() - start) < timeout_min * 60:
        for file in list(pending):
            entry = state[file]
            try:
                r = request_json(f"/suno-music/fetch/{entry['task']}")
                data = r.get("data") or {}
                clips = ((data.get("data") or {}).get("clips") or [])
                good = [c for c in clips if c.get("status") == "SUCCESS" and c.get("audio_url")]
                if good:
                    entry["clips"] = good
                    entry["status"] = "done" if len(good) == len(clips) else "partial"
                    entry["result_status"] = data.get("status")
                    pending.remove(file)
                    print(f"OK {entry.get('id', file)} {file}: {len(good)} clip(s)")
                elif data.get("status") in ("FAILED", "ERROR"):
                    entry["status"] = "failed"
                    entry["error"] = data.get("fail_reason", data.get("status"))
                    pending.remove(file)
                    print(f"FAILED {entry.get('id', file)} {file}: {entry['error']}")
            except Exception as exc:  # noqa: BLE001
                print(f"POLL ERROR {file}: {exc}")
        save_json(STATE, state)
        if pending:
            time.sleep(interval)
    for file in pending:
        state[file]["status"] = "timeout"
    save_json(STATE, state)
    print(f"remaining pending/timeout: {len(pending)}")


def download() -> None:
    state = load_json(STATE) or {}
    os.makedirs(RAW, exist_ok=True)
    total = 0
    for file, entry in state.items():
        clips = entry.get("clips") or []
        stem = os.path.splitext(os.path.basename(file))[0]
        for i, clip in enumerate(clips):
            url = clip.get("audio_url")
            if not url:
                continue
            out = os.path.join(RAW, f"{stem}_{i}.m4a")
            if os.path.exists(out) and os.path.getsize(out) > 1000:
                total += 1
                continue
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            try:
                with urllib.request.urlopen(req, timeout=300) as resp, open(out, "wb") as fh:
                    while True:
                        chunk = resp.read(1024 * 256)
                        if not chunk:
                            break
                        fh.write(chunk)
                total += 1
                print(f"DOWNLOAD {out}")
            except Exception as exc:  # noqa: BLE001
                print(f"DOWNLOAD FAIL {url}: {exc}")
    print(f"downloaded {total} clips -> {RAW}")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p_submit = sub.add_parser("submit")
    p_submit.add_argument("--limit", type=int, default=20)
    p_submit.add_argument("--delay", type=float, default=1.5)
    p_poll = sub.add_parser("poll")
    p_poll.add_argument("--timeout", type=float, default=10.0)
    p_poll.add_argument("--interval", type=float, default=10.0)
    sub.add_parser("download")
    args = parser.parse_args()

    if not KEY:
        raise SystemExit("SUNO_API_KEY is not set")

    if args.command == "submit":
        submit(args.limit, args.delay)
    elif args.command == "poll":
        poll(args.timeout, args.interval)
    elif args.command == "download":
        download()


if __name__ == "__main__":
    main()
