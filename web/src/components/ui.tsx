import type { ReactNode } from "react";
import type { ReasonItem } from "../engine/engine";

export const STATE_COLORS: Record<string, string> = {
  强: "#ff5c5c",
  正常: "#f0b429",
  偏弱: "#3aa876",
  持续强势: "#ff5c5c",
  正在加强: "#ff8f3d",
  开始活跃: "#4aa3ff",
  震荡: "#9aa3ad",
  走弱: "#3aa876",
  启动观察: "#ff5c5c",
  趋势观察: "#ff8f3d",
  高位观察: "#b07bff",
  回调观察: "#4aa3ff",
  排除: "#6b7280",
  数据不足: "#d1a53f",
};

export function Chip({ label }: { label: string }) {
  const color = STATE_COLORS[label] ?? "#9aa3ad";
  return (
    <span className="chip" style={{ color, borderColor: color }}>
      {label}
    </span>
  );
}

export function Card({
  title,
  right,
  children,
  className = "",
}: {
  title?: ReactNode;
  right?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`card ${className}`}>
      {(title || right) && (
        <div className="card-head">
          <div className="card-title">{title}</div>
          {right}
        </div>
      )}
      {children}
    </div>
  );
}

export function ReasonList({ reasons }: { reasons: ReasonItem[] }) {
  return (
    <ul className="reasons">
      {reasons.map((r) => (
        <li key={r.key} className={r.pass ? "ok" : "no"}>
          <span className="mark">{r.pass ? "✓" : "✗"}</span>
          <span className="label">{r.label}</span>
          <span className="value">
            {r.value === null || r.value === undefined
              ? "—"
              : Number(r.value.toFixed(2)).toString()}
          </span>
          {r.threshold && <span className="threshold">{r.threshold}</span>}
          {r.note && <span className="note">{r.note}</span>}
        </li>
      ))}
    </ul>
  );
}

export function Sparkline({
  close,
  height = 40,
}: {
  close: Array<number | null>;
  height?: number;
}) {
  const vals = close.filter((v): v is number => v !== null).slice(-60);
  if (vals.length < 2) return <div className="spark-empty">无数据</div>;
  const min = Math.min(...vals);
  const max = Math.max(...vals);
  const range = max - min || 1;
  const pts = vals
    .map((v, i) => `${(i / (vals.length - 1)) * 100},${height - ((v - min) / range) * (height - 4) - 2}`)
    .join(" ");
  return (
    <svg className="spark" viewBox={`0 0 100 ${height}`} preserveAspectRatio="none">
      <polyline points={pts} fill="none" stroke="#4aa3ff" strokeWidth="1.4" />
    </svg>
  );
}

export function InfoRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="info-row">
      <span className="info-label">{label}</span>
      <span className="info-value">{value}</span>
    </div>
  );
}

export function Empty({ text }: { text: string }) {
  return <div className="empty">{text}</div>;
}
