import { useMemo, useState } from "react";
import { useApp } from "../store";
import { Card, Chip, ReasonList, Sparkline } from "./ui";

const SECTOR_ORDER = ["持续强势", "正在加强", "开始活跃", "震荡", "走弱", "数据不足"];
const STOCK_ORDER = ["启动观察", "趋势观察", "高位观察", "回调观察", "排除", "数据不足"];

export function Workbench() {
  const {
    snapshot,
    marketResult,
    sectorResults,
    stockResults,
    expandedSectors,
    toggleSector,
    sectorFilter,
    setSectorFilter,
    selectStock,
  } = useApp();
  const [showMarketReasons, setShowMarketReasons] = useState(false);

  const sectors = useMemo(() => {
    if (!snapshot) return [];
    const orderIdx = new Map(SECTOR_ORDER.map((s, i) => [s, i]));
    return [...snapshot.sectors].sort((a, b) => {
      const sa = sectorResults.get(a.code)?.state ?? "数据不足";
      const sb = sectorResults.get(b.code)?.state ?? "数据不足";
      return (orderIdx.get(sa) ?? 5) - (orderIdx.get(sb) ?? 5);
    });
  }, [snapshot, sectorResults]);

  const filtered = sectorFilter === "全部"
    ? sectors
    : sectors.filter(
        (s) => sectorResults.get(s.code)?.state === sectorFilter,
      );

  if (!snapshot || !marketResult) return null;

  const stockCount = (code: string, type: string) => {
    const sec = snapshot.sectors.find((s) => s.code === code);
    if (!sec) return 0;
    return sec.members.filter(
      (c) => stockResults.get(c)?.type === type,
    ).length;
  };

  return (
    <div className="view">
      <div className="view-head">
        <div>
          <h1>趋势筛选工作台</h1>
          <p className="muted">
            演示股票池：{String(snapshot.meta?.poolNote ?? "")}
            <br />
            数据日期：{String(snapshot.meta?.asOf ?? "")}
          </p>
        </div>
      </div>

      <Card
        title="第一层 · 大盘环境"
        right={<Chip label={marketResult.state} />}
      >
        <p className="implication">{marketResult.implication}</p>
        <button
          className="link-btn"
          onClick={() => setShowMarketReasons((v) => !v)}
        >
          {showMarketReasons ? "收起判断依据" : "展开判断依据"}
        </button>
        {showMarketReasons && <ReasonList reasons={marketResult.reasons} />}
      </Card>

      <Card title="第二层 · 板块强弱">
        <div className="chips-row">
          {["全部", ...SECTOR_ORDER].map((f) => (
            <button
              key={f}
              className={`filter-chip ${sectorFilter === f ? "active" : ""}`}
              onClick={() => setSectorFilter(f)}
            >
              {f}
            </button>
          ))}
        </div>
        <div className="sector-list">
          {filtered.map((sec) => {
            const res = sectorResults.get(sec.code);
            const open = expandedSectors.has(sec.code);
            if (!res) return null;
            return (
              <div className="sector-item" key={sec.code}>
                <button
                  className="sector-row"
                  onClick={() => toggleSector(sec.code)}
                >
                  <span className="sector-name">{sec.name}</span>
                  <Chip label={res.state} />
                  <span className="muted">
                    20日 {fmt(res.reasons[0]?.value)}%
                  </span>
                  <span className="muted">强势 {res.strongCount}</span>
                  <span className="caret">{open ? "▾" : "▸"}</span>
                </button>
                {open && (
                  <div className="sector-detail">
                    <div className="mini-stats">
                      <span>上涨占比 {((res.breadth20 ?? 0) * 100).toFixed(0)}%</span>
                      <span>强势股 {res.strongCount} 只</span>
                      {res.strongestMembers.length > 0 && (
                        <span>代表：{res.strongestMembers.join("、")}</span>
                      )}
                    </div>
                    {STOCK_ORDER.map((type) => {
                      const n = stockCount(sec.code, type);
                      if (!n) return null;
                      return (
                        <div className="stock-group" key={type}>
                          <div className="stock-group-head">
                            <Chip label={type} />
                            <span className="muted">{n} 只</span>
                          </div>
                          {sec.members
                            .filter((c) => stockResults.get(c)?.type === type)
                            .map((code) => {
                              const st = snapshot.stocks.find(
                                (x) => x.code === code,
                              );
                              const sr = stockResults.get(code);
                              if (!st || !sr) return null;
                              const metric = sr.reasons;
                              const ret20 = metric.find(
                                (r) => r.key === "stock.ret20",
                              )?.value;
                              const vol = metric.find(
                                (r) => r.key === "stock.volumeRatio",
                              )?.value;
                              return (
                                <button
                                  key={code}
                                  className="stock-row"
                                  onClick={() => selectStock(code)}
                                >
                                  <Sparkline close={st.close} height={26} />
                                  <span className="stock-name">{st.name}</span>
                                  <span className="muted code">{st.code}</span>
                                  <span className="num">{fmt(ret20)}%</span>
                                  <span className="muted">量比 {fmt(vol)}</span>
                                </button>
                              );
                            })}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </Card>
    </div>
  );
}

function fmt(v: number | null | undefined): string {
  if (v === null || v === undefined) return "—";
  return Number(v.toFixed(1)).toString();
}
