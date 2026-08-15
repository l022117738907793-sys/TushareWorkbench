#!/usr/bin/env python3
"""轻量快照数据服务：定时抓取最新快照，供 App 启动时自动下载。

用法：
    python3 -u server/server.py [--host 127.0.0.1] [--port 8787]
        [--interval 1800] [--fetch-after 18:00] [--force-on-start]

接口：
    GET  /latest                    最新快照元信息
    GET  /snapshots/<name>/<file>   快照文件内容
    GET  /health                    健康检查
    POST /refresh                   立即重新抓取快照
"""

import argparse
import json
import os
import subprocess
import sys
import threading
import time
from datetime import date, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
FETCH_SCRIPT = os.path.join(ROOT, "data", "scripts", "fetch_snapshot.py")


def latest_snapshot_dir():
    if not os.path.isdir(DATA_DIR):
        return None
    dirs = sorted(
        d for d in os.listdir(DATA_DIR)
        if d.startswith("snapshot_") and
        os.path.isdir(os.path.join(DATA_DIR, d))
    )
    return dirs[-1] if dirs else None


def latest_meta():
    name = latest_snapshot_dir()
    if not name:
        return None
    meta_path = os.path.join(DATA_DIR, name, "meta.json")
    if not os.path.exists(meta_path):
        return None
    with open(meta_path, encoding="utf-8") as f:
        meta = json.load(f)
    files = sorted(
        f for f in os.listdir(os.path.join(DATA_DIR, name))
        if f.endswith(".json")
    )
    return {"snapshot": name, "asOf": meta.get("asOf"), "files": files, **meta}


def run_fetch():
    env = dict(os.environ)
    proc = subprocess.run(
        [sys.executable, "-u", FETCH_SCRIPT],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        timeout=3600,
    )
    return proc.returncode == 0, proc.stdout[-500:], proc.stderr[-500:]


class Handler(BaseHTTPRequestHandler):
    server_version = "SnapshotServer/0.1"

    def log_message(self, fmt, *args):
        print(
            f"[{datetime.now().isoformat(timespec='seconds')}] "
            f"{self.client_address[0]} {fmt % args}",
            flush=True,
        )

    def _send_json(self, obj, status=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _send_file(self, path):
        if not os.path.isfile(path):
            self._send_json({"error": "not found"}, 404)
            return
        with open(path, "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send_json({"ok": True, "latest": latest_snapshot_dir()})
            return
        if parsed.path == "/latest":
            meta = latest_meta()
            if not meta:
                self._send_json({"error": "no snapshot"}, 404)
            else:
                self._send_json(meta)
            return
        parts = parsed.path.strip("/").split("/")
        if parts and parts[0] == "snapshots" and len(parts) == 3:
            snap_name, file_name = parts[1], parts[2]
        elif len(parts) == 2 and parts[0].startswith("snapshot_"):
            snap_name, file_name = parts[0], parts[1]
        else:
            snap_name = file_name = None
        if snap_name and file_name and file_name.endswith(".json"):
            snap_dir = os.path.join(DATA_DIR, snap_name)
            if os.path.isdir(snap_dir):
                self._send_file(os.path.join(snap_dir, file_name))
                return
        self._send_json({"error": "not found"}, 404)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/refresh":
            self._send_json({"error": "not found"}, 404)
            return
        self._send_json({"status": "started"})

        def work():
            ok, out, err = run_fetch()
            print(
                f"[refresh] {'OK' if ok else 'FAILED'}\n{out}\n{err}",
                flush=True,
            )

        threading.Thread(target=work, daemon=True).start()


def scheduler(args):
    while True:
        try:
            now = datetime.now()
            meta = latest_meta()
            today = date.today().isoformat()
            due = (
                now.isoweekday() <= 5
                and now.strftime("%H:%M") >= args.fetch_after
                and (meta is None or str(meta.get("asOf", "")) < today)
            )
            if due:
                print("[scheduler] 开始定时抓取快照", flush=True)
                ok, out, err = run_fetch()
                print(f"[scheduler] {'OK' if ok else 'FAILED'}\n{out}\n{err}", flush=True)
        except Exception as e:  # noqa: BLE001
            print(f"[scheduler] 异常: {e}", flush=True)
        time.sleep(args.interval)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--interval", type=int, default=1800,
                        help="定时检查间隔（秒）")
    parser.add_argument("--fetch-after", default="18:00",
                        help="工作日几点之后允许抓取，如 18:00")
    parser.add_argument("--force-on-start", action="store_true",
                        help="启动时立即抓取一次")
    args = parser.parse_args()

    if args.force_on_start:
        print("[start] 启动时抓取快照…", flush=True)
        ok, out, err = run_fetch()
        print(f"[start] {'OK' if ok else 'FAILED'}\n{out}\n{err}", flush=True)

    threading.Thread(target=scheduler, args=(args,), daemon=True).start()
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"快照服务已启动: http://{args.host}:{args.port}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止", flush=True)


if __name__ == "__main__":
    main()
