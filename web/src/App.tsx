import { Workbench } from "./components/Workbench";
import { AnalysisView } from "./components/Analysis";
import { SettingsView } from "./components/SettingsView";
import { HistoryView } from "./components/HistoryView";
import { useApp } from "./store";

const TABS = [
  { id: "workbench", label: "工作台" },
  { id: "analysis", label: "个股分析" },
  { id: "history", label: "学习记录" },
  { id: "settings", label: "设置" },
] as const;

function TabIcon({ name }: { name: string }) {
  const common = {
    width: 20,
    height: 20,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
  switch (name) {
    case "workbench":
      return (
        <svg {...common}>
          <path d="M3 5h18M3 12h18M3 19h18" />
          <path d="M6 5v14M11 12v7M16 5v14M21 12v7" opacity={0.55} />
        </svg>
      );
    case "analysis":
      return (
        <svg {...common}>
          <path d="M4 20V10M10 20V4M16 20v-7M21 20H3" />
        </svg>
      );
    case "history":
      return (
        <svg {...common}>
          <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V3H6.5A2.5 2.5 0 0 0 4 5.5v14Z" />
          <path d="M4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5" />
        </svg>
      );
    case "settings":
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="3" />
          <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.9 2.9l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.2a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.9-2.9l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.2a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.9-2.9l.1.1a1.7 1.7 0 0 0 1.9.3h.1a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.2a1.7 1.7 0 0 0 1 1.5h.1a1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.9 2.9l-.1.1a1.7 1.7 0 0 0-.3 1.9v.1a1.7 1.7 0 0 0 1.5 1h.2a2 2 0 1 1 0 4h-.2a1.7 1.7 0 0 0-1.5 1Z" />
        </svg>
      );
    default:
      return null;
  }
}

export function App() {
  const { loading, error, tab, setTab } = useApp();
  return (
    <div className="stage">
      <div className="phone">
        <div className="statusbar">
          <span>9:41</span>
          <span className="brand">趋势工作台</span>
          <span>◐</span>
        </div>
        <div className="screen">
          {loading && <div className="center-note">正在加载演示快照…</div>}
          {!loading && error && (
            <div className="center-note warn">{error}</div>
          )}
          {!loading && !error && tab === "workbench" && <Workbench />}
          {!loading && !error && tab === "analysis" && <AnalysisView />}
          {!loading && !error && tab === "history" && <HistoryView />}
          {!loading && !error && tab === "settings" && <SettingsView />}
        </div>
        <div className="tabbar">
          {TABS.map((t) => (
            <button
              key={t.id}
              className={tab === t.id ? "active" : ""}
              onClick={() => setTab(t.id)}
            >
              <TabIcon name={t.id} />
              {t.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
