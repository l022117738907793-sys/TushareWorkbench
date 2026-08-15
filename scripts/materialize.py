#!/usr/bin/env python3
"""强制物化云端占位文件（dataless），用于 iCloud/文件提供程序导致的读取超时。

用法：
    python3 scripts/materialize.py [路径...]

默认处理当前仓库根目录；会跳过 node_modules、dist、build 等生成目录。
"""

import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {"build", ".build", ".git", "node_modules", "dist", ".swiftpm"}


def materialize(path):
    try:
        with open(path, "rb") as f:
            while f.read(1024 * 1024):
                pass
        return None
    except Exception as e:  # noqa: BLE001
        return (path, str(e))


def main():
    roots = sys.argv[1:] or [ROOT]
    files = []
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for name in filenames:
                files.append(os.path.join(dirpath, name))
    print(f"共 {len(files)} 个文件，开始物化…", flush=True)
    failures = []
    done = 0
    with ThreadPoolExecutor(max_workers=8) as ex:
        futures = {ex.submit(materialize, f): f for f in files}
        for fut in as_completed(futures):
            done += 1
            result = fut.result()
            if result:
                failures.append(result)
            if done % 200 == 0:
                print(f"进度 {done}/{len(files)}，失败 {len(failures)}", flush=True)
    print(f"完成：成功 {len(files) - len(failures)}，失败 {len(failures)}", flush=True)
    for path, err in failures[:30]:
        print(f"失败 {path}: {err}", flush=True)
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
