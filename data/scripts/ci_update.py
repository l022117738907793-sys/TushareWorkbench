#!/usr/bin/env python3
"""GitHub Actions 每日快照更新入口。

流程：抓取快照 → 校验 → 同步 iOS 资源 → 有变化则提交并推送。
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(cmd):
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def main():
    run([sys.executable, "-u", "data/scripts/fetch_snapshot.py"])
    run([sys.executable, "data/scripts/validate_snapshot.py"])
    run([sys.executable, "data/scripts/sync_ios_assets.py"])

    status = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    if not status:
        print("无变化（可能是节假日或数据未更新），跳过提交", flush=True)
        return

    print("检测到快照更新，准备提交：", flush=True)
    print(status[:1000], flush=True)
    run(["git", "add", "-A"])
    run([
        "git",
        "-c", "user.name=github-actions[bot]",
        "-c", "user.email=github-actions[bot]@users.noreply.github.com",
        "commit", "-m", "每日快照自动更新",
    ])

    token = os.environ.get("GITHUB_TOKEN", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    if token and repo:
        run([
            "git", "remote", "set-url", "origin",
            f"https://x-access-token:{token}@github.com/{repo}.git",
        ])
        run(["git", "push", "origin", "HEAD:main"])
        print("已推送到 main，网页将自动重新部署", flush=True)
        out_path = os.environ.get("GITHUB_OUTPUT", "")
        if out_path:
            with open(out_path, "a", encoding="utf-8") as f:
                f.write("deployed=true\n")
    else:
        print("未检测到 GITHUB_TOKEN/GITHUB_REPOSITORY，跳过推送（本地模式）", flush=True)


if __name__ == "__main__":
    main()
