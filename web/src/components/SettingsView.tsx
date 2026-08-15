import { useApp } from "../store";
import { Card, InfoRow } from "./ui";

const RULE_GROUPS: Array<{
  name: string;
  items: Array<{ path: string; label: string; step?: number }>;
}> = [
  {
    name: "大盘环境",
    items: [
      { path: "market.strong20Pct", label: "强势 20 日涨幅阈值(%)" },
      { path: "market.weak20Pct", label: "偏弱 20 日涨幅阈值(%)" },
      { path: "market.breadthStrong", label: "强势上涨家数占比" },
      { path: "market.breadthWeak", label: "偏弱上涨家数占比" },
    ],
  },
  {
    name: "板块强弱",
    items: [
      { path: "sector.strong20Pct", label: "持续强势 20 日涨幅(%)" },
      { path: "sector.accelAccelPct", label: "正在加强加速度(pct)" },
      { path: "sector.accelVolumeRatio", label: "加强量比" },
      { path: "sector.active5Pct", label: "开始活跃 5 日涨幅(%)" },
      { path: "sector.strongStockMin", label: "强势股数量下限" },
    ],
  },
  {
    name: "个股分类",
    items: [
      { path: "stock.start20Min", label: "启动观察 20 日涨幅下限(%)" },
      { path: "stock.start20Max", label: "启动观察 20 日涨幅上限(%)" },
      { path: "stock.startVolumeRatio", label: "启动观察量比" },
      { path: "stock.trend20Min", label: "趋势观察 20 日涨幅下限(%)" },
      { path: "stock.trend20Max", label: "趋势观察 20 日涨幅上限(%)" },
      { path: "stock.high20Min", label: "高位观察 20 日涨幅(%)" },
      { path: "stock.pullbackMin", label: "回调观察回撤(%)" },
      { path: "stock.exclude20Max", label: "排除 20 日跌幅(%)" },
    ],
  },
  {
    name: "ATR 波动",
    items: [
      { path: "stock.atrMultiplier", label: "ATR 倍数" },
      { path: "stock.atrPeriod", label: "ATR 周期" },
    ],
  },
];

export function SettingsView() {
  const {
    dataSource,
    setDataSource,
    token,
    setToken,
    overrides,
    setOverrides,
    resetRules,
    refreshLive,
    liveError,
    remoteUrl,
    remoteStatus,
    remoteBusy,
    setRemoteUrl,
    reloadRemote,
    triggerRemoteFetch,
  } = useApp();

  return (
    <div className="view">
      <div className="view-head">
        <h1>设置</h1>
      </div>

      <Card title="数据源">
        <div className="seg">
          <button
            className={dataSource === "demo" ? "active" : ""}
            onClick={() => setDataSource("demo")}
          >
            演示快照
          </button>
          <button
            className={dataSource === "tushare" ? "active" : ""}
            onClick={() => setDataSource("tushare")}
          >
            Tushare 实时
          </button>
        </div>
        {dataSource === "tushare" && (
          <>
            <InfoRow
              label="Token"
              value={
                <input
                  className="input"
                  type="password"
                  value={token}
                  placeholder="tushare token"
                  onChange={(e) => setToken(e.target.value)}
                />
              }
            />
            <button className="primary-btn" onClick={refreshLive}>
              拉取并合并最新指数
            </button>
            {liveError && <p className="warn">{liveError}</p>}
            <p className="muted small">
              实时模式只刷新三大指数；板块与个股仍用演示快照。接口失败时明确显示数据不足，不编造。
            </p>
          </>
        )}
      </Card>

      <Card title="快照服务">
        <p className="muted small">
          填写快照服务地址后，应用启动时会自动下载最新快照；服务不可用时回退到内置快照。
        </p>
        <InfoRow
          label="服务地址"
          value={
            <input
              className="input"
              value={remoteUrl}
              placeholder="http://127.0.0.1:8787"
              onChange={(e) => setRemoteUrl(e.target.value)}
            />
          }
        />
        <button className="primary-btn" onClick={reloadRemote} disabled={remoteBusy}>
          检查并下载最新快照
        </button>
        <button
          className="ghost-btn"
          onClick={triggerRemoteFetch}
          disabled={remoteBusy || !remoteUrl}
        >
          通知服务重新抓取
        </button>
        {remoteStatus && <p className="warn small">{remoteStatus}</p>}
      </Card>

      {RULE_GROUPS.map((g) => (
        <Card key={g.name} title={`阈值 · ${g.name}`}>
          {g.items.map((item) => {
            const base = valueAtPath(item.path);
            const value = overrides[item.path] ?? base;
            return (
              <InfoRow
                key={item.path}
                label={item.label}
                value={
                  <input
                    className="input num"
                    type="number"
                    step={item.step ?? 0.1}
                    value={value}
                    onChange={(e) =>
                      setOverrides(item.path, Number(e.target.value))
                    }
                  />
                }
              />
            );
          })}
        </Card>
      ))}
      <button className="ghost-btn" onClick={resetRules}>
        恢复默认阈值
      </button>
    </div>
  );
}

import { defaultRules } from "../engine/engine";

function valueAtPath(path: string): number {
  const parts = path.split(".");
  let node: any = defaultRules;
  for (const p of parts) node = node[p];
  return node as number;
}
