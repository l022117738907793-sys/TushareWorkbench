#!/usr/bin/env python3
"""校验演示快照的 schema、日期对齐与数据完整性。"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    snapshot_dir = sys.argv[1] if len(sys.argv) > 1 else None
    if not snapshot_dir:
        snapshots = sorted(
            d for d in os.listdir(os.path.join(ROOT, "data"))
            if d.startswith("snapshot_")
        )
        snapshot_dir = os.path.join(ROOT, "data", snapshots[-1])
    print("校验目录:", snapshot_dir)

    meta = load(os.path.join(snapshot_dir, "meta.json"))
    calendar = load(os.path.join(snapshot_dir, "calendar.json"))
    indices = load(os.path.join(snapshot_dir, "indices.json"))
    sectors = load(os.path.join(snapshot_dir, "sectors.json"))
    stocks = load(os.path.join(snapshot_dir, "stocks.json"))
    etfs = load(os.path.join(snapshot_dir, "etfs.json"))

    errors = []
    assert meta.get("asOf") == calendar[-1], "asOf 与日历末日不一致"
    assert len(calendar) == meta.get("days", -1), "days 与日历长度不一致"
    print(f"asOf={meta['asOf']} days={len(calendar)} "
          f"indices={len(indices)} sectors={len(sectors)} "
          f"stocks={len(stocks)} etfs={len(etfs)}")

    index_codes = {i["code"] for i in indices}
    for code in ("000300.SH", "000001.SH", "399006.SZ"):
        assert code in index_codes, f"缺少指数 {code}"

    code_re = re.compile(r"^\d{6}\.(SH|SZ|BJ)$")

    def check_series(obj, label):
        for key in ("close", "high", "low", "volume"):
            arr = obj.get(key)
            if arr is None or len(arr) != len(calendar):
                errors.append(f"{label}.{key} 长度不符")
                continue
            for i, v in enumerate(arr):
                if v is not None and not isinstance(v, (int, float)):
                    errors.append(f"{label}.{key}[{i}] 非数值")

    for i in indices:
        check_series(i, f"index:{i['code']}")
    for e in etfs:
        check_series(e, f"etf:{e['code']}")

    sector_by_code = {}
    for s in sectors:
        sector_by_code[s["code"]] = s
        check_series(s, f"sector:{s['code']}")
        for member in s.get("members", []):
            assert code_re.match(member), f"板块成分代码格式错误: {member}"
    assert len(sectors) >= 25, f"行业数量过少: {len(sectors)}"

    stock_codes = set()
    for st in stocks:
        assert code_re.match(st["code"]), f"股票代码格式错误: {st['code']}"
        assert st["industryCode"] in sector_by_code, (
            f"{st['code']} 行业代码不存在"
        )
        assert isinstance(st["isST"], bool), f"{st['code']} isST 非布尔"
        assert st["name"], f"{st['code']} 缺名称"
        check_series(st, f"stock:{st['code']}")
        valid = sum(1 for v in st["close"] if v is not None)
        if valid < 60:
            errors.append(f"{st['code']} 有效交易日不足 60: {valid}")
        stock_codes.add(st["code"])

    for s in sectors:
        for member in s.get("members", []):
            if member not in stock_codes:
                errors.append(f"板块 {s['code']} 成员 {member} 不在股票池")

    if errors:
        print("校验失败:")
        for e in errors[:30]:
            print(" -", e)
        sys.exit(1)
    print("校验通过 ✔")


if __name__ == "__main__":
    main()
