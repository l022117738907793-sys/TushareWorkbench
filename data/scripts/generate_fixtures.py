#!/usr/bin/env python3
"""生成引擎一致性测试用的合成场景 fixture。

每个 fixture 内嵌 rules.json 与合成的指数/板块/个股日线，并给出期望状态。
生成前用独立的简单公式做一次“预言机”校验，确保期望值在构造上成立。
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIX_DIR = os.path.join(ROOT, "data", "fixtures")


def lin(a, b, n):
    """从 a 到 b 的 n 个线性插值（含两端）。"""
    return [a + (b - a) * i / (n - 1) for i in range(n)]


def const(v, n):
    return [float(v)] * n


def make_series(closes, base_vol=1_000_000, vol_tail=None, tail_start=None,
                high_pct=0.01, low_pct=0.01):
    n = len(closes)
    vols = [base_vol] * n
    if vol_tail is not None and tail_start is not None:
        for i in range(tail_start, n):
            vols[i] = round(base_vol * vol_tail)
    return {
        "close": [round(c, 3) for c in closes],
        "high": [round(c * (1 + high_pct), 3) for c in closes],
        "low": [round(c * (1 - low_pct), 3) for c in closes],
        "volume": vols,
    }


def ret(closes, k):
    if len(closes) <= k or closes[-1 - k] == 0:
        return None
    return (closes[-1] / closes[-1 - k] - 1) * 100


def ma(closes, x):
    vals = [v for v in closes if v is not None][-x:]
    if len(vals) < x:
        return None
    return sum(vals) / x


def oracle(metrics, expected, label):
    problems = []

    def chk(name, cond):
        if not cond:
            problems.append(name)

    if expected.get("market"):
        m = expected["market"]
        if m == "强":
            chk("market.ret20", metrics["m_ret20"] >= 3)
            chk("market.above20", metrics["m_above20"])
            chk("market.ma20up", metrics["m_ma20up"])
            chk("market.breadth", metrics["breadth"] >= 0.6)
        elif m == "偏弱":
            chk("market.weak", metrics["m_ret20"] <= -3
                or (not metrics["m_above20"] and metrics["breadth"] <= 0.35))
    if expected.get("sector"):
        s = expected["sector"]["state"]
        if s == "持续强势":
            chk("sector.strong", metrics["s_ret20"] >= 8
                and metrics["s_ret5"] > 0 and metrics["s_above20"]
                and metrics["s_breadth"] >= 0.5
                and metrics["s_strong"] >= 3)
        elif s == "正在加强":
            chk("sector.accel", metrics["s_ret20"] >= 3
                and metrics["s_accel"] >= 3
                and metrics["s_vol"] >= 1.2
                and metrics["s_breadth"] >= 0.4)
        elif s == "开始活跃":
            chk("sector.active", metrics["s_ret20"] < 3
                and metrics["s_ret5"] >= 3
                and metrics["s_vol"] >= 1.2
                and metrics["s_strong"] >= 2)
        elif s == "走弱":
            chk("sector.weak", metrics["s_ret20"] <= -3
                or (not metrics["s_above20"] and metrics["s_breadth"] <= 0.35))
    if expected.get("stock"):
        t = expected["stock"]["type"]
        st = expected["stock"]
        if t == "启动观察":
            chk("stock.start", 3 <= metrics["x_ret20"] <= 15
                and metrics["x_ret5"] > 0 and metrics["x_above20"]
                and metrics["x_ma20up"] and metrics["x_disthigh"] >= -5
                and metrics["x_vol"] >= 1.2 and metrics["x_days20"] <= 10)
        elif t == "趋势观察":
            main_ok = (metrics["x_above20"]
                       and metrics["x_dist20"] <= 15
                       and metrics["x_disthigh"] >= -10
                       and metrics["x_ret5"] > -3
                       and (metrics["x_ret20"] > 15 or metrics["x_days20"] > 10))
            fallback = metrics["x_ret20"] > 0 and metrics["x_above20"]
            chk("stock.trend", main_ok or fallback)
        elif t == "高位观察":
            chk("stock.high", metrics["x_ret20"] >= 40
                or (metrics["x_disthigh"] >= -2 and metrics["x_dist20"] >= 15)
                or (metrics["x_ret5"] >= 15 and metrics["x_vol"] >= 1.5)
                or (metrics["x_ret5"] < 3 and metrics["x_vol"] >= 1.5
                    and metrics["x_ret20"] >= 25))
        elif t == "回调观察":
            chk("stock.pullback", metrics["x_pullback"] >= 8
                and metrics["x_ret5"] <= 0
                and (metrics["x_ma20up"] or metrics["x_above60"]))
            if st.get("subtype"):
                v = metrics["x_vol"]
                if st["subtype"] == "缩量":
                    chk("stock.pullback.lowvol", v <= 1)
                elif st["subtype"] == "放量":
                    chk("stock.pullback.highvol", v >= 1.5)
        elif t == "排除":
            chk("stock.exclude", metrics["x_ret20"] <= -5
                or (not metrics["x_above20"] and not metrics["x_above60"]
                    and not metrics["x_ma60up"])
                or (metrics["x_ret5"] <= -10 and metrics["x_vol"] >= 1.3))
        elif t == "数据不足":
            chk("stock.insufficient", metrics["x_days"] < 60)
        if st.get("atrFlag"):
            flag = st["atrFlag"]
            if flag == "偏大":
                chk("atr.up", metrics["x_move5"] > metrics["x_band5"])
            elif flag == "超跌":
                chk("atr.down", metrics["x_move5"] < -metrics["x_band5"])
            elif flag == "正常":
                chk("atr.normal", abs(metrics["x_move5"]) <= metrics["x_band5"])

    if problems:
        print(f"[oracle fail] {label}: {problems}")
        return False
    return True


def vol(closes, tail_mult=None, tail_start=None, base=1_000_000):
    n = len(closes)
    vols = [base] * n
    if tail_mult is not None:
        for i in range(tail_start, n):
            vols[i] = round(base * tail_mult)
    return vols


def metrics_for(close, high, low, volume):
    n = len(close)
    c = close[-1]
    r5 = ret(close, 5)
    r20 = ret(close, 20)
    ma20 = ma(close, 20)
    ma20prev = ma(close[:-5], 20) if len(close) > 25 else None
    ma60 = ma(close, 60)
    ma60prev = ma(close[:-5], 60) if len(close) > 65 else None
    high20 = max(close[-20:])
    dist20 = (c / ma20 - 1) * 100 if ma20 else None
    disthigh = (c / high20 - 1) * 100
    vol5 = sum(volume[-5:]) / 5
    vol20 = sum(volume[-20:]) / 20
    vratio = vol5 / vol20 if vol20 else None
    days20 = 0
    if ma20:
        for v in reversed(close):
            if v > ma20:
                days20 += 1
            else:
                break
    trs = []
    valid = [(h, l, cc) for h, l, cc in zip(high, low, close)
             if h is not None and l is not None and cc is not None]
    for i in range(1, len(valid)):
        h, l, cc = valid[i]
        pc = valid[i - 1][2]
        trs.append(max(h - l, abs(h - pc), abs(l - pc)))
    atr = sum(trs[-14:]) / 14 if len(trs) >= 14 else None
    band5 = atr * (5 ** 0.5) * 1.5 if atr else None
    move5 = c - close[-6] if n > 6 and close[-6] is not None else None
    return {
        "x_ret5": r5, "x_ret20": r20, "x_above20": c > ma20 if ma20 else False,
        "x_ma20up": ma20 > ma20prev if ma20 and ma20prev else False,
        "x_above60": c > ma60 if ma60 else False,
        "x_ma60up": ma60 > ma60prev if ma60 and ma60prev else False,
        "x_dist20": dist20, "x_disthigh": disthigh, "x_pullback": -disthigh,
        "x_vol": vratio, "x_days20": days20, "x_days": n,
        "x_move5": move5, "x_band5": band5,
        "x_atr": atr,
    }


def build_scenario(sc):
    """把场景规格转成 fixture，并计算预言机指标。"""
    idx = []
    for code, name, closes, vols in sc["indices"]:
        s = make_series(closes)
        s["volume"] = vols or s["volume"]
        idx.append({"code": code, "name": name, "kind": "index", **s})

    stocks = []
    stock_by_code = {}
    for code, name, industry, closes, vols in sc["stocks"]:
        s = make_series(closes)
        s["volume"] = vols or s["volume"]
        st = {
            "code": code, "name": name, "industry": industry,
            "industryCode": sc["sector_code"], "weight": 1.0, "isST": False,
            **s,
        }
        stocks.append(st)
        stock_by_code[code] = s

    sc_series = make_series(sc["sector_closes"])
    sc_series["volume"] = sc["sector_vols"] or sc_series["volume"]
    sectors = [{
        "code": sc["sector_code"], "name": sc["sector_name"],
        **sc_series, "members": [x[0] for x in sc["stocks"]],
    }]

    # 预言机指标
    main = idx[0]
    m_ret20 = ret(main["close"], 20)
    m_ma20 = ma(main["close"], 20)
    m_ma20prev = ma(main["close"][:-5], 20)
    m_above20 = main["close"][-1] > m_ma20
    m_ma20up = m_ma20 > m_ma20prev
    up20 = sum(1 for st in stocks if (ret(st["close"], 20) or -999) > 0)
    breadth = up20 / len(stocks)
    s_ret5 = ret(sc_series["close"], 5)
    s_ret20 = ret(sc_series["close"], 20)
    s_ret5prev = (sc_series["close"][-6] / sc_series["close"][-11] - 1) * 100
    s_ma20 = ma(sc_series["close"], 20)
    s_above20 = sc_series["close"][-1] > s_ma20
    s_vol5 = sum(sc_series["volume"][-5:]) / 5
    s_vol20 = sum(sc_series["volume"][-20:]) / 20
    s_vol = s_vol5 / s_vol20
    members = [stock_by_code[c] for c in sectors[0]["members"]]
    s_breadth = sum(1 for s2 in members if (ret(s2["close"], 20) or -999) > 0) / len(members)
    s_strong = sum(1 for s2 in members if (ret(s2["close"], 20) or -999) >= 8
                   and s2["close"][-1] > ma(s2["close"], 20)
                   and (ret(s2["close"], 5) or -999) > 0)
    target = stock_by_code[sc["target"]]
    mtr = metrics_for(target["close"], target["high"], target["low"], target["volume"])
    mtr.update({
        "m_ret20": m_ret20, "m_above20": m_above20, "m_ma20up": m_ma20up,
        "breadth": breadth,
        "s_ret5": s_ret5, "s_ret20": s_ret20, "s_accel": s_ret5 - s_ret5prev,
        "s_above20": s_above20, "s_vol": s_vol,
        "s_breadth": s_breadth, "s_strong": s_strong,
    })
    ok = oracle(mtr, sc["expected"], sc["id"])
    if not ok:
        print("指标:", {k: round(v, 2) if isinstance(v, float) else v
                        for k, v in mtr.items()})
        sys.exit(1)
    return {
        "id": sc["id"],
        "indices": idx,
        "sectors": sectors,
        "stocks": stocks,
        "expected": {
            **sc["expected"],
            "stock": {**sc["expected"]["stock"], "code": sc["target"]},
        },
    }


def normal_market_idx():
    return [("000300.SH", "沪深300", lin(3000, 3300, 90), None)]


def normal_pool():
    pool = []
    for i in range(5):
        pool.append((f"P{i}", f"普通{i}", "T1", lin(100, 112, 90), None))
    for i in range(5):
        pool.append((f"Q{i}", f"偏弱{i}", "T1", lin(100, 95, 90), None))
    return pool


def weak_pool():
    pool = []
    for i in range(8):
        pool.append((f"W{i}", f"弱势{i}", "T1", lin(100, 88, 90), None))
    for i in range(2):
        pool.append((f"F{i}", f"平稳{i}", "T1", lin(100, 100, 90), None))
    return pool


def strong_pool():
    pool = []
    for i in range(5):
        pool.append(
            (f"S{i}", f"强势{i}", "T1", const(100, 60) + lin(100, 130, 30), None)
        )
    for i in range(3):
        pool.append((f"N{i}", f"中性{i}", "T1", lin(100, 100, 90), None))
    return pool


def main():
    scenarios = []

    # 1 强市 + 持续强势板块 + 启动观察个股
    start_closes = const(100, 82) + lin(101, 107.2, 8)
    start_vols = vol(start_closes, 1.6, 85)
    scenarios.append({
        "id": "market_strong_sector_strong_stock_start",
        "indices": [
            ("000300.SH", "沪深300", lin(3000, 3750, 90), None),
            ("000001.SH", "上证指数", lin(3000, 3400, 90), None),
            ("399006.SZ", "创业板指", lin(2500, 3300, 90), None),
        ],
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": const(1000, 70) + lin(1000, 1120, 20),
        "sector_vols": vol(const(1000, 70) + lin(1000, 1120, 20), 1.3, 75),
        "stocks": strong_pool() + [
            ("START", "启动股", "T1", start_closes, start_vols),
        ],
        "target": "START",
        "expected": {
            "market": "强",
            "sector": {"code": "T1.SI", "state": "持续强势"},
            "stock": {"type": "启动观察", "atrFlag": "正常"},
        },
    })

    # 2 弱市 + 走弱板块 + 排除个股
    scenarios.append({
        "id": "market_weak_sector_weak_stock_exclude",
        "indices": [
            ("000300.SH", "沪深300", lin(3000, 2580, 90), None),
            ("000001.SH", "上证指数", lin(3000, 2700, 90), None),
            ("399006.SZ", "创业板指", lin(2500, 2200, 90), None),
        ],
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": lin(1000, 910, 90),
        "sector_vols": None,
        "stocks": weak_pool() + [
            ("EXCL", "下跌股", "T1", lin(100, 82, 90), None),
        ],
        "target": "EXCL",
        "expected": {
            "market": "偏弱",
            "sector": {"code": "T1.SI", "state": "走弱"},
            "stock": {"type": "排除", "atrFlag": "正常"},
        },
    })

    # 3 正常市 + 正在加强板块 + 趋势观察个股
    accel_sec = const(1000, 75) + lin(1000, 1015, 10) + lin(1015, 1076, 5)
    accel_vols = vol(accel_sec, 1.4, 85)
    trend_closes = const(100, 60) + lin(100, 126, 30)
    scenarios.append({
        "id": "market_normal_sector_accel_stock_trend",
        "indices": normal_market_idx(),
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": accel_sec,
        "sector_vols": accel_vols,
        "stocks": normal_pool() + [
            ("TREND", "趋势股", "T1", trend_closes, None),
        ],
        "target": "TREND",
        "expected": {
            "market": "正常",
            "sector": {"code": "T1.SI", "state": "正在加强"},
            "stock": {"type": "趋势观察", "atrFlag": "正常"},
        },
    })

    # 4 正常市 + 开始活跃板块 + 高位观察个股
    active_sec = (lin(1000, 985, 70) + lin(985, 980, 10)
                  + [980] * 5 + lin(980, 1010, 5))
    active_vols = vol(active_sec, 1.4, 85)
    high_closes = const(100, 70) + lin(100, 145, 20)
    scenarios.append({
        "id": "market_normal_sector_active_stock_high",
        "indices": normal_market_idx(),
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": active_sec,
        "sector_vols": active_vols,
        "stocks": normal_pool() + [
            ("SA1", "活跃强势1", "T1", const(100, 60) + lin(100, 130, 30), None),
            ("SA2", "活跃强势2", "T1", const(100, 60) + lin(100, 130, 30), None),
            ("HIGH", "高位股", "T1", high_closes, None),
        ],
        "target": "HIGH",
        "expected": {
            "market": "正常",
            "sector": {"code": "T1.SI", "state": "开始活跃"},
            "stock": {"type": "高位观察", "atrFlag": "正常"},
        },
    })

    # 5 正常市 + 震荡板块 + 缩量回调个股
    range_sec = lin(1000, 990, 90)
    pull_closes = const(100, 70) + lin(100, 130, 15) + lin(130, 118.3, 5)
    pull_vols = vol(pull_closes, 0.8, 85)
    scenarios.append({
        "id": "market_normal_sector_range_stock_pullback_lowvol",
        "indices": normal_market_idx(),
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": range_sec,
        "sector_vols": None,
        "stocks": normal_pool() + [
            ("PULL", "回调股", "T1", pull_closes, pull_vols),
        ],
        "target": "PULL",
        "expected": {
            "market": "正常",
            "sector": {"code": "T1.SI", "state": "震荡"},
            "stock": {"type": "回调观察", "subtype": "缩量", "atrFlag": "正常"},
        },
    })

    # 6 数据不足个股
    insufficient = const(100, 30)
    scenarios.append({
        "id": "market_normal_sector_range_stock_insufficient",
        "indices": normal_market_idx(),
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": range_sec,
        "sector_vols": None,
        "stocks": normal_pool() + [
            ("NEW", "次新股", "T1", insufficient, None),
        ],
        "target": "NEW",
        "expected": {
            "market": "正常",
            "sector": {"code": "T1.SI", "state": "震荡"},
            "stock": {"type": "数据不足", "atrFlag": None},
        },
    })

    # 7 强市 + 持续强势板块 + 放量滞涨高位个股
    stall_closes = const(100, 70) + lin(100, 125.2, 15) + lin(125.2, 127, 5)
    stall_vols = vol(stall_closes, 2.0, 85)
    scenarios.append({
        "id": "market_strong_sector_strong_stock_high_stall",
        "indices": [
            ("000300.SH", "沪深300", lin(3000, 3750, 90), None),
            ("000001.SH", "上证指数", lin(3000, 3400, 90), None),
            ("399006.SZ", "创业板指", lin(2500, 3300, 90), None),
        ],
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": const(1000, 70) + lin(1000, 1120, 20),
        "sector_vols": vol(const(1000, 70) + lin(1000, 1120, 20), 1.3, 75),
        "stocks": strong_pool() + [
            ("STALL", "滞涨股", "T1", stall_closes, stall_vols),
        ],
        "target": "STALL",
        "expected": {
            "market": "强",
            "sector": {"code": "T1.SI", "state": "持续强势"},
            "stock": {"type": "高位观察", "atrFlag": "正常"},
        },
    })

    # 8 弱市 + 震荡板块 + 放量下跌排除个股
    crash_closes = const(100, 60) + lin(100, 115, 20) + lin(115, 104, 5) + lin(104, 92, 5)
    crash_vols = vol(crash_closes, 1.6, 85)
    scenarios.append({
        "id": "market_weak_sector_range_stock_exclude_volume",
        "indices": [
            ("000300.SH", "沪深300", lin(3000, 2580, 90), None),
            ("000001.SH", "上证指数", lin(3000, 2700, 90), None),
            ("399006.SZ", "创业板指", lin(2500, 2200, 90), None),
        ],
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": range_sec,
        "sector_vols": None,
        "stocks": normal_pool() + [
            ("CRASH", "放量跌", "T1", crash_closes, crash_vols),
        ],
        "target": "CRASH",
        "expected": {
            "market": "偏弱",
            "sector": {"code": "T1.SI", "state": "震荡"},
            "stock": {"type": "排除", "atrFlag": "超跌"},
        },
    })

    # 9 ATR 偏大（低波动、大 5 日涨幅）
    atr_up = const(100, 70) + lin(100, 114.3, 15) + [116.1, 117.9, 119.8, 121.7, 123.6]
    atr_up_vols = vol(atr_up, 1.2, 85)
    scenarios.append({
        "id": "market_normal_sector_range_stock_atr_up",
        "indices": normal_market_idx(),
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": range_sec,
        "sector_vols": None,
        "stocks": normal_pool() + [
            ("ATRUP", "波动偏大", "T1", atr_up, atr_up_vols),
        ],
        "target": "ATRUP",
        "expected": {
            "market": "正常",
            "sector": {"code": "T1.SI", "state": "震荡"},
            "stock": {"type": "趋势观察", "atrFlag": "偏大"},
        },
    })

    # 10 ATR 超跌（低波动、大 5 日跌幅）
    atr_down = const(100, 70) + lin(100, 120, 15) + [116, 112, 108, 104, 100]
    atr_down_vols = vol(atr_down, 1.6, 85)
    scenarios.append({
        "id": "market_normal_sector_range_stock_atr_down",
        "indices": normal_market_idx(),
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": range_sec,
        "sector_vols": None,
        "stocks": normal_pool() + [
            ("ATRDOWN", "波动超跌", "T1", atr_down, atr_down_vols),
        ],
        "target": "ATRDOWN",
        "expected": {
            "market": "正常",
            "sector": {"code": "T1.SI", "state": "震荡"},
            "stock": {"type": "排除", "atrFlag": "超跌"},
        },
    })

    # 11 走弱板块 + 兜底趋势观察（动量不足）
    mild_closes = const(100, 70) + lin(100, 102, 20)
    scenarios.append({
        "id": "market_weak_sector_weak_stock_trend_fallback",
        "indices": [
            ("000300.SH", "沪深300", lin(3000, 2580, 90), None),
            ("000001.SH", "上证指数", lin(3000, 2700, 90), None),
            ("399006.SZ", "创业板指", lin(2500, 2200, 90), None),
        ],
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": lin(1000, 910, 90),
        "sector_vols": None,
        "stocks": weak_pool() + [
            ("MILD", "温和股", "T1", mild_closes, None),
        ],
        "target": "MILD",
        "expected": {
            "market": "偏弱",
            "sector": {"code": "T1.SI", "state": "走弱"},
            "stock": {"type": "趋势观察", "atrFlag": "正常"},
        },
    })

    # 12 放量回调
    pull_high_closes = const(100, 70) + lin(100, 130, 15) + lin(130, 119, 5)
    pull_high_vols = vol(pull_high_closes, 2.0, 85)
    scenarios.append({
        "id": "market_normal_sector_range_stock_pullback_highvol",
        "indices": normal_market_idx(),
        "sector_code": "T1.SI", "sector_name": "测试行业",
        "sector_closes": range_sec,
        "sector_vols": None,
        "stocks": normal_pool() + [
            ("PULLH", "放量回调", "T1", pull_high_closes, pull_high_vols),
        ],
        "target": "PULLH",
        "expected": {
            "market": "正常",
            "sector": {"code": "T1.SI", "state": "震荡"},
            "stock": {"type": "回调观察", "subtype": "放量", "atrFlag": "正常"},
        },
    })

    with open(os.path.join(ROOT, "data", "rules.json"), encoding="utf-8") as f:
        rules = json.load(f)

    os.makedirs(FIX_DIR, exist_ok=True)
    for sc in scenarios:
        fixture = build_scenario(sc)
        fixture["rules"] = rules
        path = os.path.join(FIX_DIR, f"{fixture['id']}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(fixture, f, ensure_ascii=False, separators=(",", ":"))
        print("生成", fixture["id"])
    print(f"共 {len(scenarios)} 个 fixture ✔")


if __name__ == "__main__":
    main()
