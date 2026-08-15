#!/usr/bin/env python3
"""把最新快照与 fixture 同步到 iOS 工程资源目录。"""

import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    snapshots = sorted(
        d for d in os.listdir(os.path.join(ROOT, "data"))
        if d.startswith("snapshot_")
    )
    latest = snapshots[-1]
    demo_dir = os.path.join(ROOT, "ios", "TushareWorkbench", "Resources", "demo-data")
    shutil.rmtree(demo_dir, ignore_errors=True)
    shutil.copytree(
        os.path.join(ROOT, "data", latest),
        demo_dir,
    )
    shutil.copyfile(
        os.path.join(ROOT, "data", "rules.json"),
        os.path.join(ROOT, "ios", "TushareWorkbench", "Resources", "rules.json"),
    )
    fix_dir = os.path.join(ROOT, "ios", "TushareWorkbenchCore", "Tests", "CoreTests", "Fixtures")
    shutil.rmtree(fix_dir, ignore_errors=True)
    shutil.copytree(os.path.join(ROOT, "data", "fixtures"), fix_dir)
    print(f"iOS 资源已同步：{latest} + {len(os.listdir(fix_dir))} 个 fixture")


if __name__ == "__main__":
    main()
