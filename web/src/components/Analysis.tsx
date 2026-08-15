import { useMemo, useState } from "react";
import { useApp } from "../store";
import {
  computeStockMetrics,
  generateLearningFeedback,
  learningQuestions,
  reviewThesis,
  type LearningFeedback,
  type ThesisInput,
  type ThesisReview,
} from "../engine/engine";
import { Card, Chip, InfoRow, ReasonList, Sparkline } from "./ui";

const TYPE_ORDER = ["启动观察", "趋势观察", "高位观察", "回调观察", "排除", "数据不足"];

export function AnalysisView() {
  const { selectedStock, snapshot, rules, getReport, saveHistory, setTab } =
    useApp();
  const [answers, setAnswers] = useState<Record<number, string>>({});
  const [feedbacks, setFeedbacks] = useState<Record<number, LearningFeedback>>({});
  const [saved, setSaved] = useState(false);
  const [thesis, setThesis] = useState<ThesisInput>({
    types: [],
    horizon: "波段",
    text: "",
  });
  const [review, setReview] = useState<ThesisReview | null>(null);

  const stock = useMemo(
    () => snapshot?.stocks.find((s) => s.code === selectedStock) ?? null,
    [snapshot, selectedStock],
  );

  if (!stock || !snapshot) {
    return (
      <div className="view">
        <Card>
          <p className="muted">先在「工作台」里选择一只股票，然后在这里查看七步分析～</p>
          <button className="primary-btn" onClick={() => setTab("workbench")}>
            去工作台
          </button>
        </Card>
      </div>
    );
  }

  const report = getReport(stock.code);
  const m = computeStockMetrics(stock, rules);
  const questions = learningQuestions(report.currentType);

  const submitAnswer = (idx: number, text: string) => {
    setAnswers((prev) => ({ ...prev, [idx]: text }));
    setFeedbacks((prev) => ({
      ...prev,
      [idx]: generateLearningFeedback(report.currentType, text, report, m),
    }));
  };

  const saveRecord = () => {
    saveHistory({
      id: `${stock.code}-${Date.now()}`,
      stockCode: stock.code,
      stockName: stock.name,
      type: report.currentType,
      createdAt: new Date().toISOString(),
      answers: questions
        .map((q, i) => ({ question: q, answer: answers[i] ?? "" }))
        .filter((a) => a.answer),
      report,
    });
    setSaved(true);
  };

  return (
    <div className="view">
      <div className="view-head">
        <div>
          <h1>{stock.name}</h1>
          <p className="muted">
            {stock.code} · {stock.industry} · 数据日期 {String(snapshot.meta?.asOf ?? "")}
          </p>
        </div>
        <Chip label={report.currentType} />
      </div>
      <Card>
        <Sparkline close={stock.close} height={56} />
      </Card>

      {!report.dataSufficiency.enough && (
        <Card className="warn-card">
          <p className="warn">【数据不足，不许编造】{report.dataSufficiency.missing.join("；")}</p>
        </Card>
      )}

      <Section title="【市场环境】" state={report.market.state} extra={report.market.implication} reasons={report.market.reasons} />
      <Section
        title="【板块状态】"
        state={report.sector.state}
        reasons={report.sector.reasons}
        extra={
          <div className="mini-stats">
            <span>上涨占比 {((report.sector.breadth20 ?? 0) * 100).toFixed(0)}%</span>
            <span>强势股 {report.sector.strongCount} 只</span>
            {report.sector.strongestMembers.length > 0 && (
              <span>代表：{report.sector.strongestMembers.join("、")}</span>
            )}
          </div>
        }
      />
      <Section title="【个股走势阶段】" state={report.stockTrend.state} reasons={report.stockTrend.reasons} />
      <Section
        title="【近期价格行为】"
        state={report.priceAction.state}
        reasons={report.priceAction.reasons}
        extra={
          <div className="mini-stats">
            <span>ATR：{m.atr.available ? m.atr.flag : "数据不足"}</span>
            <span>量比 {fmt(m.volRatio)}</span>
            <span>5日 {fmt(m.ret5)}%</span>
            <span>20日 {fmt(m.ret20)}%</span>
          </div>
        }
      />
      <Section
        title="【当前位置】"
        state={report.position.state}
        reasons={report.position.reasons}
        extra={
          report.position.trendBroken !== null ? (
            <div className="mini-stats">
              <span>趋势破坏：{report.position.trendBroken ? "已破坏" : "未破坏"}</span>
              <span>回调量能：{report.position.volumeHeavy ? "放量" : "未明显放量"}</span>
            </div>
          ) : undefined
        }
      />

      <Card title="【下一步观察】">
        <ul className="steps">
          {report.nextSteps.map((s, i) => (
            <li key={i}>{s}</li>
          ))}
        </ul>
      </Card>

      <Card title="【分析结论】">
        <p className="conclusion">{report.conclusion}</p>
        <h4>为什么</h4>
        <ul className="why">
          {report.why.map((w, i) => (
            <li key={i}>{w}</li>
          ))}
        </ul>
      </Card>

      <Card title="学习模式">
        <p className="muted small">
          下面几个问题没有标准答案，目的是练习「市场 → 板块 → 个股趋势 → 涨跌程度 → 当前位置 → 下一步」这套框架。
        </p>
        {questions.map((q, i) => {
          const options = quickOptions(report.currentType, q);
          const fb = feedbacks[i];
          return (
            <div className="quiz" key={i}>
              <p className="quiz-q">
                {i + 1}. {q}
              </p>
              {options.length > 0 && (
                <div className="chips-row">
                  {options.map((o) => (
                    <button
                      key={o}
                      className={`filter-chip ${answers[i] === o ? "active" : ""}`}
                      onClick={() => submitAnswer(i, o)}
                    >
                      {o}
                    </button>
                  ))}
                </div>
              )}
              <div className="answer-row">
                <input
                  className="input"
                  value={answers[i] ?? ""}
                  placeholder="写下你的判断…"
                  onChange={(e) => {
                    setAnswers((prev) => ({ ...prev, [i]: e.target.value }));
                    setFeedbacks((prev) => {
                      const next = { ...prev };
                      delete next[i];
                      return next;
                    });
                  }}
                />
                <button
                  className="primary-btn small"
                  onClick={() => submitAnswer(i, answers[i] ?? "")}
                  disabled={!answers[i]}
                >
                  对照
                </button>
              </div>
              {fb && (
                <div className="feedback">
                  <h4>【你的判断】</h4>
                  {fb.doneRight.map((t, j) => (
                    <p key={j}>{t}</p>
                  ))}
                  <h4>【容易忽略的地方】</h4>
                  {fb.easyToMiss.length ? (
                    fb.easyToMiss.map((t, j) => <p key={j}>{t}</p>)
                  ) : (
                    <p>这次你覆盖的因素比较全，很好。</p>
                  )}
                  <h4>【进一步思考】</h4>
                  <p>{fb.thinkFurther}</p>
                  <p className="muted small">（关键词辅助复盘，仅作对照提示）</p>
                </div>
              )}
            </div>
          );
        })}
        <button className="primary-btn" onClick={saveRecord}>
          保存本次学习记录
        </button>
        {saved && <p className="ok-text">已保存到学习记录 ✓</p>}
      </Card>

      <Card title="我为什么看好这只股票 · 结构化复盘">
        <p className="muted small">
          填一下你看好的理由类型、时间预期和理由描述，系统会用数据逐项对照，不否定你的判断。
        </p>
        <div className="chips-row">
          {["技术形态", "消息催化", "基本面", "资金流向", "情绪博弈"].map((t) => (
            <button
              key={t}
              className={`filter-chip ${thesis.types.includes(t) ? "active" : ""}`}
              onClick={() =>
                setThesis((prev) => ({
                  ...prev,
                  types: prev.types.includes(t)
                    ? prev.types.filter((x) => x !== t)
                    : [...prev.types, t],
                }))
              }
            >
              {t}
            </button>
          ))}
        </div>
        <div className="chips-row">
          {["短线", "波段", "中线"].map((h) => (
            <button
              key={h}
              className={`filter-chip ${thesis.horizon === h ? "active" : ""}`}
              onClick={() => setThesis((prev) => ({ ...prev, horizon: h }))}
            >
              {h}
            </button>
          ))}
        </div>
        <textarea
          className="input"
          rows={3}
          value={thesis.text}
          placeholder="比如：我认为它放量突破 20 日线，板块正在走强，中线还有空间…"
          onChange={(e) => setThesis((prev) => ({ ...prev, text: e.target.value }))}
        />
        <button
          className="primary-btn"
          onClick={() => setReview(reviewThesis(thesis, report, m))}
        >
          对照数据复盘
        </button>
        {review && (
          <div className="thesis-review">
            <h4>系统依据 vs 你的依据</h4>
            {review.rows.map((r, i) => (
              <div className="thesis-row" key={i}>
                <InfoRow label={r.reasonType} value={r.conclusion} />
                <p className="muted small">{r.systemEvidence}</p>
              </div>
            ))}
            <h4>追问</h4>
            <p>{review.followUp}</p>
          </div>
        )}
      </Card>
    </div>
  );
}

function Section({
  title,
  state,
  reasons,
  extra,
}: {
  title: string;
  state: string;
  reasons: import("../engine/engine").ReasonItem[];
  extra?: React.ReactNode;
}) {
  return (
    <Card title={title} right={<Chip label={state} />}>
      {extra}
      <ReasonList reasons={reasons} />
    </Card>
  );
}

function quickOptions(type: string, q: string): string[] {
  if (q.includes("哪个观察类型")) return TYPE_ORDER;
  if (q.includes("缩量还是放量")) return ["缩量", "放量", "不确定"];
  if (q.includes("什么信号") && type === "高位观察") {
    return ["滞涨", "放量滞涨", "跌破20日线", "缩量整理"];
  }
  if (q.includes("哪个指标")) return ["量比", "20日线", "60日线", "ATR"];
  if (q.includes("什么条件")) {
    return ["站回20日线", "放量突破", "缩量企稳", "趋势破位"];
  }
  return [];
}

function fmt(v: number | null | undefined): string {
  if (v === null || v === undefined) return "—";
  return Number(v.toFixed(2)).toString();
}
