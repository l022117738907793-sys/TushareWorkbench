import { cpSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const snapshots = readdirSync(join(root, "data"))
  .filter((d) => d.startsWith("snapshot_"))
  .sort();
if (snapshots.length === 0) {
  console.error("没有找到快照目录，先运行 data/scripts/fetch_snapshot.py");
  process.exit(1);
}
const latest = snapshots.at(-1);
const target = join(root, "web", "public", "data");
rmSync(target, { recursive: true, force: true });
mkdirSync(target, { recursive: true });
mkdirSync(join(target, latest), { recursive: true });
cpSync(join(root, "data", latest), join(target, latest), { recursive: true });
writeFileSync(
  join(target, "latest.json"),
  JSON.stringify({ snapshot: latest }),
);
console.log(`同步快照 ${latest} -> web/public/data`);
