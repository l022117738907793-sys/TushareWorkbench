# 演示快照数据格式

快照目录：`data/snapshot_<YYYYMMDD>/`，目录内 5 个 JSON 文件。所有数组按同一交易日历对齐，索引即交易日序号，从旧到新。

## meta.json

```json
{
  "asOf": "2026-08-14",
  "source": "申万官网(akshare) + 腾讯行情 + Tushare daily_basic",
  "poolNote": "演示股票池：申万一级行业按市值前 15～20 只代表股",
  "calendarNote": "以沪深300交易日为公共日历",
  "generatedAt": "ISO8601",
  "days": 120
}
```

## calendar.json

```json
["2026-02-20", "...", "2026-08-14"]
```

## indices.json

```json
[
  {
    "code": "000300.SH",
    "name": "沪深300",
    "kind": "index",
    "close": [1234.5, null, 1256.7],
    "high": [...],
    "low": [...],
    "volume": [...]
  }
]
```

## sectors.json

```json
[
  {
    "code": "801010.SI",
    "name": "农林牧渔",
    "close": [...],
    "high": [...],
    "low": [...],
    "volume": [...],
    "members": ["000505.SZ", "600598.SH"]
  }
]
```

## stocks.json

```json
[
  {
    "code": "600519.SH",
    "name": "贵州茅台",
    "industry": "食品饮料",
    "industryCode": "801120.SI",
    "weight": 9.87,
    "isST": false,
    "close": [...],
    "high": [...],
    "low": [...],
    "volume": [...]
  }
]
```

## etfs.json

与 indices.json 相同结构，`kind: "etf"`。

## 约定

- 停牌或缺失日期的值为 `null`；计算指标时跳过 null。
- 股票代码统一为 `600519.SH` / `000001.SZ` 形式。
- 成交量单位不做跨标的比较，只用于自身量比，因此不统一单位。
- 快照文件由 `data/scripts/fetch_snapshot.py` 生成，由 `data/scripts/validate_snapshot.py` 校验。
