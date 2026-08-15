import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  analyzeMarket,
  analyzeSector,
  buildReport,
  classifyStock,
  computeStockMetrics,
  defaultRules,
  type AnalysisReport,
  type Rules,
  type SectorData,
  type Snapshot,
  type StockData,
} from "./engine/engine";
import { tushareCall } from "./lib/tushare";

export type Tab = "workbench" | "analysis" | "history" | "settings";

export interface HistoryRecord {
  id: string;
  stockCode: string;
  stockName: string;
  type: string;
  createdAt: string;
  answers: Array<{ question: string; answer: string }>;
  report: AnalysisReport;
}

interface AppState {
  snapshot: Snapshot | null;
  loading: boolean;
  error: string | null;
  liveError: string | null;
  remoteUrl: string;
  remoteStatus: string | null;
  remoteBusy: boolean;
  dataSource: "demo" | "tushare";
  token: string;
  rules: Rules;
  overrides: Record<string, number>;
  marketResult: ReturnType<typeof analyzeMarket> | null;
  sectorResults: Map<string, ReturnType<typeof analyzeSector>>;
  stockResults: Map<string, ReturnType<typeof classifyStock>>;
  tab: Tab;
  selectedStock: string | null;
  history: HistoryRecord[];
  expandedSectors: Set<string>;
  sectorFilter: string;
  setTab: (t: Tab) => void;
  selectStock: (code: string) => void;
  setOverrides: (path: string, value: number) => void;
  resetRules: () => void;
  setDataSource: (ds: "demo" | "tushare") => void;
  setToken: (t: string) => void;
  refreshLive: () => Promise<void>;
  setRemoteUrl: (u: string) => void;
  reloadRemote: () => Promise<void>;
  triggerRemoteFetch: () => Promise<void>;
  saveHistory: (r: HistoryRecord) => void;
  toggleSector: (code: string) => void;
  setSectorFilter: (f: string) => void;
  getReport: (code: string) => AnalysisReport;
}

const Ctx = createContext<AppState | null>(null);

function deepMerge(base: Rules, patch: Record<string, number>): Rules {
  const clone = JSON.parse(JSON.stringify(base)) as Rules;
  for (const [path, value] of Object.entries(patch)) {
    const parts = path.split(".");
    let node: any = clone;
    for (let i = 0; i < parts.length - 1; i += 1) {
      node = node[parts[i]];
    }
    node[parts[parts.length - 1]] = value;
  }
  return clone;
}

function loadJson(base: string, file: string) {
  return fetch(`${base}/${file}`).then((r) => {
    if (!r.ok) throw new Error(`${file} 加载失败`);
    return r.json();
  });
}

function snapshotFiles(): string[] {
  return [
    "meta.json",
    "calendar.json",
    "indices.json",
    "sectors.json",
    "stocks.json",
    "etfs.json",
  ];
}

async function loadRemoteSnapshot(base: string): Promise<Snapshot> {
  const latest = await fetch(`${base}/latest`).then((r) => {
    if (!r.ok) throw new Error(`latest ${r.status}`);
    return r.json();
  });
  const name = latest.snapshot as string;
  const files = snapshotFiles();
  const [meta, calendar, indices, sectors, stocks, etfs] =
    await Promise.all(
      files.map((f) =>
        fetch(`${base}/snapshots/${name}/${f}`).then((r) => {
          if (!r.ok) throw new Error(`${f} ${r.status}`);
          return r.json();
        }),
      ),
    );
  return { meta, calendar, indices, sectors, stocks, etfs };
}

async function cacheRemoteSnapshot(base: string, snapshot: Snapshot) {
  if (typeof caches === "undefined") return;
  const cache = await caches.open("wb-snapshots");
  const latest = {
    snapshot: String(snapshot.meta?.asOf ?? "unknown"),
    asOf: snapshot.meta?.asOf,
  };
  await cache.put(`${base}/latest`, new Response(JSON.stringify(latest)));
  const files = snapshotFiles();
  for (const f of files) {
    await cache.put(
      `${base}/snapshots/${latest.snapshot}/${f}`,
      new Response(JSON.stringify((snapshot as any)[f.replace(".json", "")])),
    );
  }
}

async function loadCachedRemoteSnapshot(base: string): Promise<Snapshot | null> {
  if (typeof caches === "undefined") return null;
  try {
    const cache = await caches.open("wb-snapshots");
    const latestRes = await cache.match(`${base}/latest`);
    if (!latestRes) return null;
    const latest = await latestRes.json();
    const name = latest.snapshot as string;
    const files = snapshotFiles();
    const [meta, calendar, indices, sectors, stocks, etfs] =
      await Promise.all(
        files.map(async (f) => {
          const r = await cache.match(`${base}/snapshots/${name}/${f}`);
          return r ? r.json() : null;
        }),
      );
    if (!meta || !indices || !sectors || !stocks) return null;
    return { meta, calendar, indices, sectors, stocks, etfs };
  } catch {
    return null;
  }
}

async function loadBundledSnapshot(): Promise<Snapshot> {
  const latest = await fetch("data/latest.json").then((r) => r.json());
  const base = `data/${latest.snapshot}`;
  const [meta, calendar, indices, sectors, stocks, etfs] =
    await Promise.all(
      snapshotFiles().map((f) => loadJson(base, f)),
    );
  return { meta, calendar, indices, sectors, stocks, etfs };
}

export function AppProvider({ children }: { children: ReactNode }) {
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [liveError, setLiveError] = useState<string | null>(null);
  const [remoteUrl, setRemoteUrlState] = useState(
    () => localStorage.getItem("wb.remoteUrl") || "",
  );
  const [remoteStatus, setRemoteStatus] = useState<string | null>(null);
  const [remoteBusy, setRemoteBusy] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);
  const [dataSource, setDataSourceState] = useState<"demo" | "tushare">(
    () => (localStorage.getItem("wb.dataSource") as "demo" | "tushare") || "demo",
  );
  const [token, setTokenState] = useState(
    () => localStorage.getItem("wb.token") || "",
  );
  const [overrides, setOverridesState] = useState<Record<string, number>>(() => {
    try {
      return JSON.parse(localStorage.getItem("wb.overrides") || "{}");
    } catch {
      return {};
    }
  });
  const [tab, setTab] = useState<Tab>("workbench");
  const [selectedStock, setSelectedStock] = useState<string | null>(null);
  const [history, setHistory] = useState<HistoryRecord[]>(() => {
    try {
      return JSON.parse(localStorage.getItem("wb.history") || "[]");
    } catch {
      return [];
    }
  });
  const [expandedSectors, setExpandedSectors] = useState<Set<string>>(new Set());
  const [sectorFilter, setSectorFilter] = useState("全部");
  const refreshToken = useRef(0);

  const rules = useMemo(() => deepMerge(defaultRules, overrides), [overrides]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    (async () => {
      try {
        let source: Snapshot | null = null;
        let note = "";
        if (remoteUrl) {
          try {
            source = await loadRemoteSnapshot(remoteUrl);
            await cacheRemoteSnapshot(remoteUrl, source);
            note = `已使用远程快照（${String(source.meta?.asOf ?? "")}）`;
          } catch (e) {
            const cached = await loadCachedRemoteSnapshot(remoteUrl);
            if (cached) {
              source = cached;
              note = "远程快照暂不可用，已使用缓存副本";
            } else {
              note = `远程快照不可用（${String((e as Error).message || e)}），使用内置快照`;
            }
          }
        }
        if (!source) {
          source = await loadBundledSnapshot();
          if (!note) note = `内置快照（${String(source.meta?.asOf ?? "")}）`;
        }
        if (cancelled) return;
        setSnapshot(source);
        setRemoteStatus(note);
        setLoading(false);
      } catch (e) {
        if (cancelled) return;
        setError(String((e as Error).message || e));
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [remoteUrl, reloadKey]);

  const marketResult = useMemo(
    () => (snapshot ? analyzeMarket(snapshot, rules) : null),
    [snapshot, rules],
  );

  const sectorResults = useMemo(() => {
    const map = new Map();
    if (!snapshot) return map;
    const stocksByCode = new Map(snapshot.stocks.map((s) => [s.code, s]));
    for (const s of snapshot.sectors) {
      map.set(s.code, analyzeSector(s, stocksByCode, rules));
    }
    return map;
  }, [snapshot, rules]);

  const stockResults = useMemo(() => {
    const map = new Map();
    if (!snapshot) return map;
    for (const s of snapshot.stocks) {
      map.set(s.code, classifyStock(s, rules));
    }
    return map;
  }, [snapshot, rules]);

  const getReport = useCallback(
    (code: string) => {
      if (!snapshot) throw new Error("快照未加载");
      return buildReport(snapshot, code, rules);
    },
    [snapshot, rules],
  );

  const setOverrides = useCallback((path: string, value: number) => {
    setOverridesState((prev) => {
      const next = { ...prev, [path]: value };
      localStorage.setItem("wb.overrides", JSON.stringify(next));
      return next;
    });
  }, []);

  const resetRules = useCallback(() => {
    setOverridesState({});
    localStorage.removeItem("wb.overrides");
  }, []);

  const setDataSource = useCallback((ds: "demo" | "tushare") => {
    setDataSourceState(ds);
    localStorage.setItem("wb.dataSource", ds);
  }, []);

  const setToken = useCallback((t: string) => {
    setTokenState(t);
    localStorage.setItem("wb.token", t);
  }, []);

  const setRemoteUrl = useCallback((u: string) => {
    setRemoteUrlState(u);
    localStorage.setItem("wb.remoteUrl", u);
  }, []);

  const reloadRemote = useCallback(async () => {
    setRemoteBusy(true);
    setReloadKey((k) => k + 1);
    setRemoteBusy(false);
  }, []);

  const triggerRemoteFetch = useCallback(async () => {
    if (!remoteUrl) return;
    setRemoteBusy(true);
    try {
      const r = await fetch(`${remoteUrl}/refresh`, { method: "POST" });
      if (!r.ok) throw new Error(`refresh ${r.status}`);
      setRemoteStatus("已通知服务重新抓取，稍后自动刷新");
      window.setTimeout(() => setReloadKey((k) => k + 1), 5000);
    } catch (e) {
      setRemoteStatus(`通知失败：${String((e as Error).message || e)}`);
    } finally {
      setRemoteBusy(false);
    }
  }, [remoteUrl]);

  const refreshLive = useCallback(async () => {
    if (!token) {
      setLiveError("请先在设置里填写 Tushare Token");
      return;
    }
    const id = ++refreshToken.current;
    setLiveError(null);
    try {
      const rows = await Promise.all(
        ["000300.SH", "000001.SH", "399006.SZ"].map((code) =>
          tushareCall("index_daily", token, {
            ts_code: code,
            start_date: "20260801",
            end_date: "20260815",
          }),
        ),
      );
      if (id !== refreshToken.current || !snapshot) return;
      const latestRows = rows.map((r) => {
        const sorted = [...r.items].sort((a, b) =>
          (a[1] as string).localeCompare(b[1] as string),
        );
        return sorted[sorted.length - 1];
      });
      const dates = latestRows.map((r) => String(r[1]));
      const newDate = dates[0];
      if (newDate <= String((snapshot.meta as any)?.asOf ?? "")) {
        setLiveError("实时数据日期未超过快照日期，继续使用快照");
        return;
      }
      const fieldIdx = (fields: string[], name: string) => fields.indexOf(name);
      const updatedIndices = snapshot.indices.map((idx) => {
        const row = latestRows.find(
          (r) => String(r[0]) === idx.code.replace(".SH", "").replace(".SZ", ""),
        ) ?? latestRows.find((r) => r[0] === idx.code);
        if (!row) return idx;
        const fields = rows[0].fields;
        const close = row[fieldIdx(fields, "close")] as number;
        const high = row[fieldIdx(fields, "high")] as number;
        const low = row[fieldIdx(fields, "low")] as number;
        const volume = row[fieldIdx(fields, "vol")] as number;
        return {
          ...idx,
          close: [...idx.close, close],
          high: [...idx.high, high],
          low: [...idx.low, low],
          volume: [...idx.volume, volume],
        };
      });
      setSnapshot((prev) =>
        prev
          ? {
              ...prev,
              meta: { ...prev.meta, asOf: newDate, liveMerged: true },
              calendar: [...(prev.calendar ?? []), newDate],
              indices: updatedIndices,
            }
          : prev,
      );
      setLiveError("已合并实时指数数据（板块与个股仍为演示快照）");
    } catch (e: any) {
      setLiveError(`实时拉取失败：${e.message || e}（继续使用演示数据，不编造）`);
    }
  }, [token, snapshot]);

  const saveHistory = useCallback((r: HistoryRecord) => {
    setHistory((prev) => {
      const next = [r, ...prev].slice(0, 100);
      localStorage.setItem("wb.history", JSON.stringify(next));
      return next;
    });
  }, []);

  const toggleSector = useCallback((code: string) => {
    setExpandedSectors((prev) => {
      const next = new Set(prev);
      if (next.has(code)) next.delete(code);
      else next.add(code);
      return next;
    });
  }, []);

  const selectStock = useCallback((code: string) => {
    setSelectedStock(code);
    setTab("analysis");
  }, []);

  const value: AppState = {
    snapshot,
    loading,
    error,
    liveError,
    remoteUrl,
    remoteStatus,
    remoteBusy,
    dataSource,
    token,
    rules,
    overrides,
    marketResult,
    sectorResults,
    stockResults,
    tab,
    selectedStock,
    history,
    expandedSectors,
    sectorFilter,
    setTab,
    selectStock,
    setOverrides,
    resetRules,
    setDataSource,
    setToken,
    refreshLive,
    setRemoteUrl,
    reloadRemote,
    triggerRemoteFetch,
    saveHistory,
    toggleSector,
    setSectorFilter,
    getReport,
  };
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useApp(): AppState {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useApp 必须在 AppProvider 内使用");
  return ctx;
}

export { computeStockMetrics };
