import { useState } from "react";
import { useApp } from "../store";
import { Card, Chip } from "./ui";

export function HistoryView() {
  const { history, selectStock } = useApp();
  const [openId, setOpenId] = useState<string | null>(null);
  if (history.length === 0) {
    return (
      <div className="view">
        <div className="view-head"><h1>学习记录</h1></div>
        <Card><p className="muted">还没有学习记录。完成一次个股分析后，记录会保存在这里。</p></Card>
      </div>
    );
  }
  return (
    <div className="view">
      <div className="view-head"><h1>学习记录</h1></div>
      {history.map((rec) => (
        <Card
          key={rec.id}
          title={rec.stockName}
          right={<Chip label={rec.type} />}
        >
          <p className="muted small">
            {rec.stockCode} · {new Date(rec.createdAt).toLocaleString("zh-CN")}
          </p>
          <button
            className="link-btn"
            onClick={() => setOpenId(openId === rec.id ? null : rec.id)}
          >
            {openId === rec.id ? "收起" : "查看结论依据"}
          </button>
          {openId === rec.id && (
            <div className="history-detail">
              <p>大盘：{rec.report.market.state} · 板块：{rec.report.sector.state}</p>
              <ul>
                {rec.report.why.map((w, i) => (
                  <li key={i}>{w}</li>
                ))}
              </ul>
              {rec.answers.length > 0 && (
                <>
                  <h4>你的回答</h4>
                  {rec.answers.map((a, i) => (
                    <p key={i} className="small">
                      <b>{a.question}</b>
                      <br />{a.answer}
                    </p>
                  ))}
                </>
              )}
              <button
                className="ghost-btn"
                onClick={() => selectStock(rec.stockCode)}
              >
                重新分析
              </button>
            </div>
          )}
        </Card>
      ))}
    </div>
  );
}
